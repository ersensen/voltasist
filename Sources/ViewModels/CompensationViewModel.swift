// CompensationViewModel.swift
// VoltAsist
//
// Reaktif güç kompanzasyonu hesaplamalarını yöneten ViewModel.
// CompensationEngine ile entegre çalışır; 7 sekmelik sonuç ekranını destekler.
// Harmonik risk renklendirmesi, cosφ göstergesi ve geri ödeme metni üretir.

import Foundation
import Combine
import SwiftUI

// MARK: - CompensationViewModel

/// Kompanzasyon hesap makinesinin iş mantığını ve görüntüleme verilerini yönetir.
/// Güç faktörü iyileştirme, kondansatör basamakları, harmonik analiz ve
/// geri ödeme süresi hesaplamalarını ReactiveX tarzı Combine ile yayınlar.
final class CompensationViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Kompanzasyon girdi parametreleri (gerçekçi varsayılanlar)
    @Published var input = CompensationInput(
        activePowerKW: 100.0,
        apparentPowerKVA: 130.0,
        measuredCosPhi: 0.77,
        targetCosPhi: 0.95,
        systemVoltageV: 400.0,
        transformerKVA: 250.0,
        totalHarmonicDistortion: 5.0,
        electricityTariff: 2.5,
        investmentCostTL: 80_000.0,
        discountRate: 0.15
    )

    /// Hesaplama sonucu — nil ise henüz çalıştırılmadı
    @Published var result: CompensationResult? = nil

    /// Hata mesajı
    @Published var errorMessage: String? = nil

    /// Aktif sekme indeksi (0–6: Özet, Güç, Kondansatör, Harmonik, Transformatör, Ekonomi, Öneri)
    @Published var selectedTab: Int = 0

    /// cosφ göstergesinin animasyon durumu
    @Published var isAnimatingGauge: Bool = false

    // MARK: - Init

    init() {}

    // MARK: - Hesaplama

    /// CompensationEngine'i çağırarak tüm kompanzasyon hesaplamalarını yapar.
    /// Sonuç elde edildiğinde cosφ göstergesi animasyonlu olarak güncellenir.
    func calculate() {
        errorMessage = nil
        do {
            let res = try CompensationEngine.calculate(input: input)
            result = res
            // Gösterge animasyonu tetikle
            withAnimation(.easeInOut(duration: 0.8)) {
                isAnimatingGauge = true
            }
        } catch let error as CalculationError {
            errorMessage = error.localizedDescription
            result       = nil
        } catch {
            errorMessage = "Hesaplama hatası: \(error.localizedDescription)"
            result       = nil
        }
    }

    // MARK: - Teklif'e Ekle

    /// Kompanzasyon sonucundan oluşan kalemleri QuoteViewModel'e ekler.
    /// Kondansatör grubu + reaktör (gerekiyorsa) + montaj işçiliği kalemleri oluşturulur.
    /// - Parameter quoteVM: Kalemlerin ekleneceği teklif ViewModel'i
    func addToQuote(quoteVM: QuoteViewModel) {
        guard let res = result else { return }

        // Ana kompanzasyon panosu kalemi
        let panelItem = QuoteItem(
            description: "Otomatik Kompanzasyon Panosu — \(String(format: "%.1f", res.requiredCapacityKVAr)) kVAr",
            unit: "Adet",
            quantity: 1,
            unitPrice: calculatePanelPrice(kvar: res.requiredCapacityKVAr),
            vatRate: 20,
            category: .compensation
        )
        quoteVM.addItem(panelItem)

        // Reaktör gerekiyorsa ayrı kalem
        if res.reactorRequired {
            let reactorItem = QuoteItem(
                description: "Harmonik Filtreli Detuned Reaktör — THD %\(String(format: "%.1f", input.totalHarmonicDistortion))",
                unit: "Adet",
                quantity: 1,
                unitPrice: calculateReactorPrice(kvar: res.requiredCapacityKVAr),
                vatRate: 20,
                category: .compensation
            )
            quoteVM.addItem(reactorItem)
        }

        // Montaj işçiliği
        let laborItem = QuoteItem(
            description: "Kompanzasyon Panosu Montajı ve Devreye Alma",
            unit: "Adet",
            quantity: 1,
            unitPrice: 3_500,
            vatRate: 20,
            category: .compensation
        )
        quoteVM.addItem(laborItem)
    }

    // MARK: - Görüntüleme Hesaplamaları

    /// THD değerine göre harmonik risk rengini döndürür.
    /// < 5%: Yeşil (düşük), 5–10%: Turuncu (orta), > 10%: Kırmızı (yüksek)
    var harmonicRiskColor: Color {
        let thd = input.totalHarmonicDistortion
        if thd >= 10.0 { return .red }
        if thd >= 5.0  { return .orange }
        return .green
    }

    /// THD değerine göre harmonik risk etiketi
    var harmonicRiskLabel: String {
        let thd = input.totalHarmonicDistortion
        if thd >= 10.0 { return "Yüksek Risk — Reaktör Zorunlu" }
        if thd >= 5.0  { return "Orta Risk — Reaktör Önerilir" }
        return "Düşük Risk — Reaktörsüz Çalışılabilir"
    }

    /// Mevcut cosφ değerini gösterge için 0–180 derece açıya çevirir.
    /// cosφ = 0.5 → 0°, cosφ = 1.0 → 180°
    var cosPhiGaugeAngle: Double {
        let phi = isAnimatingGauge ? (result?.achievedCosPhi ?? input.measuredCosPhi) : input.measuredCosPhi
        let clamped = min(max(phi, 0.5), 1.0)
        return (clamped - 0.5) / 0.5 * 180.0
    }

    /// Hedef cosφ değerini gösterge açısına çevirir
    var targetCosPhiGaugeAngle: Double {
        let clamped = min(max(input.targetCosPhi, 0.5), 1.0)
        return (clamped - 0.5) / 0.5 * 180.0
    }

    /// Geri ödeme süresini "15 ay 18 gün" formatında döndürür.
    var paybackText: String {
        guard let res = result, res.paybackMonths > 0 else { return "Hesaplanmadı" }
        let months = Int(res.paybackMonths)
        let remainDays = Int((res.paybackMonths - Double(months)) * 30)
        if remainDays == 0 {
            return "\(months) ay"
        }
        return "\(months) ay \(remainDays) gün"
    }

    /// Yıllık tasarruf tutarını "₺38.400" formatında döndürür.
    var annualSavingsFormatted: String {
        guard let res = result else { return "—" }
        return formatCurrency(res.annualSavingsTL)
    }

    /// Gerekli kondansatör kapasitesini "42,3 kVAr" formatında döndürür.
    var requiredCapacityFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f kVAr", res.requiredCapacityKVAr)
    }

    /// Transformatör kapasite kazanımını "15,2%" formatında döndürür.
    var transformerGainFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f%%", res.transformerCapacityGainPercent)
    }

    /// TEDAŞ ceza uygulanıp uygulanmayacağını belirler (cosφ < 0.90)
    var isTEDASPenaltyRisk: Bool {
        input.measuredCosPhi < 0.90
    }

    // MARK: - Özel Yardımcılar

    /// kVAr değerine göre pano fiyatı tahmini (TL)
    private func calculatePanelPrice(kvar: Double) -> Double {
        switch kvar {
        case ..<50:   return 12_000
        case 50..<100: return 22_000
        case 100..<200: return 38_000
        default:      return 60_000
        }
    }

    /// kVAr değerine göre reaktör fiyatı tahmini (TL)
    private func calculateReactorPrice(kvar: Double) -> Double {
        return kvar * 280  // yaklaşık 280 TL/kVAr
    }

    /// TL formatlaması
    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "₺0"
    }
}
