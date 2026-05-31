// SolarCalculatorViewModel.swift
// VoltAsist
//
// Güneş enerjisi sistemi (GES) hesaplamalarını yöneten ViewModel.
// SolarEngine ile entegre çalışır; OnGrid/OffGrid destekler.
// Türk şehirleri PSH tablosuna dayalı şehir filtreleme içerir.

import Foundation
import Combine
import SwiftUI

// MARK: - SolarCalculatorViewModel

/// Güneş enerji sistemi hesap makinesinin iş mantığını ve görüntüleme verilerini yönetir.
/// Panel kapasitesi, yıllık üretim, batarya boyutlandırma ve geri ödeme hesaplamalarını
/// SolarEngine aracılığıyla gerçekleştirir.
final class SolarCalculatorViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Solar hesaplama girdi parametreleri (gerçekçi varsayılanlar)
    @Published var input = SolarCalculationInput(
        monthlyConsumptionKWh: 500.0,
        city: .istanbul,
        roofTiltDeg: 30.0,
        roofOrientationDeg: 0.0,      // Güney yönü
        systemType: .onGrid,
        autonomyDays: 2,
        batteryType: .lifepo4,
        systemVoltage: 48,
        feedInTariff: 3.0,            // TL/kWh — şebekeye satış
        electricityPrice: 4.5,        // TL/kWh — satın alma tarife
        installationCostPerKWp: 35_000.0
    )

    /// Hesaplama sonucu — nil ise henüz çalıştırılmadı
    @Published var result: SolarCalculationResult? = nil

    /// Hata mesajı
    @Published var errorMessage: String? = nil

    /// Aktif sekme indeksi (0–4: Özet, Panel, Batarya, Ekonomi, CO₂)
    @Published var selectedTab: Int = 0

    /// Şehir arama metin kutusu
    @Published var citySearchText: String = ""

    /// Hesaplama sonrası animasyon tetikleyicisi
    @Published var showResult: Bool = false

    // MARK: - Init

    init() {}

    // MARK: - Hesaplama

    /// SolarEngine'i çağırarak tüm güneş enerjisi hesaplamalarını yapar.
    func calculate() {
        errorMessage = nil
        showResult   = false
        do {
            let res = try SolarEngine.calculate(input: input)
            result = res
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showResult = true
            }
        } catch let error as CalculationError {
            errorMessage = error.localizedDescription
            result       = nil
        } catch {
            errorMessage = "Solar hesaplama hatası: \(error.localizedDescription)"
            result       = nil
        }
    }

    // MARK: - Teklif'e Ekle

    /// Solar sistem bileşenlerinden teklif kalemleri oluşturarak QuoteViewModel'e ekler.
    /// Panel grubu, inverter, montaj ve (varsa) batarya kalemleri eklenir.
    /// - Parameter quoteVM: Kalemlerin ekleneceği teklif ViewModel'i
    func addToQuote(quoteVM: QuoteViewModel) {
        guard let res = result else { return }

        // Panel grubu
        let panelItem = QuoteItem(
            description: "Güneş Paneli Grubu — \(String(format: "%.2f", res.systemCapacityKWp)) kWp",
            unit: "kWp",
            quantity: res.systemCapacityKWp,
            unitPrice: input.installationCostPerKWp * 0.55,   // Toplam maliyetin %55'i panel
            vatRate: 20,
            category: .solar
        )
        quoteVM.addItem(panelItem)

        // İnverter
        let inverterItem = QuoteItem(
            description: "\(input.systemType == .offGrid ? "Off-Grid Şarj Regülatörü ve İnverter" : "On-Grid İnverter") — \(String(format: "%.1f", res.systemCapacityKWp)) kWp",
            unit: "Adet",
            quantity: 1,
            unitPrice: inverterPrice(kwp: res.systemCapacityKWp),
            vatRate: 20,
            category: .solar
        )
        quoteVM.addItem(inverterItem)

        // Batarya (OffGrid veya Hybrid)
        if input.systemType != .onGrid, let bat = res.batteryBank {
            let batItem = QuoteItem(
                description: "\(input.batteryType.displayName) Batarya Grubu — \(String(format: "%.1f", bat.totalCapacityKWh)) kWh / \(input.systemVoltage)V",
                unit: "Adet",
                quantity: 1,
                unitPrice: bat.totalCapacityKWh * batteryUnitPrice(),
                vatRate: 20,
                category: .solar
            )
            quoteVM.addItem(batItem)
        }

        // Montaj ve kurulum
        let mountItem = QuoteItem(
            description: "Çatı Montaj Sistemi, Kablo ve Kurulum İşçiliği",
            unit: "kWp",
            quantity: res.systemCapacityKWp,
            unitPrice: input.installationCostPerKWp * 0.20,   // Toplam maliyetin %20'si işçilik
            vatRate: 20,
            category: .solar
        )
        quoteVM.addItem(mountItem)
    }

    // MARK: - Şehir Filtreleme

    /// Arama metnine göre Türk şehirlerini filtreler.
    /// Arama boşsa tüm şehirleri döndürür.
    var filteredCities: [TurkishCity] {
        let query = citySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return TurkishCity.allCases }
        return TurkishCity.allCases.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.rawValue.lowercased().contains(query)
        }
    }

    // MARK: - Görüntüleme Hesaplamaları

    /// Sistem kapasitesini "4,20 kWp" formatında döndürür.
    var systemCapacityFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.2f kWp", res.systemCapacityKWp)
    }

    /// Yıllık üretimi "7.308 kWh" formatında döndürür.
    var annualProductionFormatted: String {
        guard let res = result else { return "—" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        let str = fmt.string(from: NSNumber(value: res.annualProductionKWh)) ?? "0"
        return "\(str) kWh"
    }

    /// Geri ödeme süresini "7,2 yıl" formatında döndürür.
    var paybackYearsFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f yıl", res.paybackYears)
    }

    /// Yıllık tasarrufu "₺32.850" formatında döndürür.
    var annualSavingsFormatted: String {
        guard let res = result else { return "—" }
        return formatCurrency(res.annualSavingsTL)
    }

    /// 25 yıllık CO₂ tasarrufunu "91,3 ton" formatında döndürür.
    var co2SavingsFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f ton CO₂", res.co2SavingsTon25Years)
    }

    /// Seçili şehrin PSH değerini "4,2 saat/gün" formatında döndürür.
    var pshFormatted: String {
        String(format: "%.1f saat/gün", input.city.peakSunHours)
    }

    /// Sistem türünü Türkçe etiket olarak döndürür.
    var systemTypeLabel: String {
        switch input.systemType {
        case .onGrid:  return "Şebeke Bağlantılı (On-Grid)"
        case .offGrid: return "Bağımsız (Off-Grid)"
        case .hybrid:  return "Hibrit (Hem Şebeke Hem Batarya)"
        }
    }

    // MARK: - Özel Yardımcılar

    /// kWp değerine göre inverter fiyatı (TL)
    private func inverterPrice(kwp: Double) -> Double {
        switch kwp {
        case ..<5:   return 15_000
        case 5..<10: return 25_000
        case 10..<20: return 45_000
        default:     return 80_000
        }
    }

    /// Batarya tipi fiyat katsayısı (TL/kWh)
    private func batteryUnitPrice() -> Double {
        switch input.batteryType {
        case .lifepo4: return 6_500
        case .agm:     return 2_800
        case .gel:     return 3_200
        case .lithiumNMC: return 7_200
        }
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
