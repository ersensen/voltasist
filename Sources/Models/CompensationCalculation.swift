// CompensationCalculation.swift
// VoltAsist
//
// Reaktif güç kompanzasyonu hesaplama modeli.
// TEDAŞ ceza hesabı, kondansatör seçimi, harmonik analizi ve ROI hesabı.

import Foundation

// MARK: - Harmonik Risk Seviyesi

/// THD değerine ve sisteme göre harmonik risk sınıflandırması
enum HarmonicRisk: String, Codable, CaseIterable {
    case low    = "Düşük"
    case medium = "Orta - İzleme Gerekli"
    case high   = "Yüksek - Filtreli Reaktör Zorunlu"

    /// Risk seviyesine göre SF Symbols ikon
    var systemIcon: String {
        switch self {
        case .low:    return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high:   return "xmark.octagon.fill"
        }
    }

    /// Renk adı (Asset Catalog)
    var colorName: String {
        switch self {
        case .low:    return "RiskLow"
        case .medium: return "RiskMedium"
        case .high:   return "RiskHigh"
        }
    }
}

// MARK: - Kondansatör Kademesi

/// AKP'de kullanılan her kondansatör kademesi
struct CapacitorStep: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Kademe gücü (kVAr)
    var ratingKVAr: Double

    /// Bu gücünden kaç adet kullanılacak
    var quantity: Int

    /// Toplam kurulu güç (kVAr)
    var totalKVAr: Double { ratingKVAr * Double(quantity) }

    init(id: UUID = UUID(), ratingKVAr: Double, quantity: Int) {
        self.id = id
        self.ratingKVAr = ratingKVAr
        self.quantity = quantity
    }
}

// MARK: - Hesaplama Girişi

/// Kompanzasyon hesaplama için gerekli giriş parametreleri
struct CompensationInput: Codable {
    /// Aktif güç (kW) — güç analizörü ölçümü
    var activePowerKW: Double

    /// Görünür güç (kVA) — güç analizörü ölçümü
    var apparentPowerKVA: Double

    /// Ölçülen güç faktörü (cos φ₁)
    var measuredCosPhi: Double

    /// Hedef güç faktörü (cos φ₂) — TEDAŞ min. 0.95
    var targetCosPhi: Double

    /// Sistem gerilimi (V) — genellikle 3 faz 400V
    var systemVoltageV: Double

    /// Besleme transformatörü gücü (kVA) — varsa harmonik rezonans hesabı için
    var transformerKVA: Double?

    /// Toplam Harmonik Bozulma oranı (THD, %) — 0–50
    var totalHarmonicDistortion: Double

    /// TEDAŞ reaktif enerji ceza tarifesi (TL/kVArh)
    var electricityTariff: Double

    /// Planlanan kondansatör sistemi yatırım maliyeti (TL)
    var investmentCostTL: Double

    /// NBD ve İVK hesabı için iskonto oranı — varsayılan %15 (0.15)
    var discountRate: Double

    init(
        activePowerKW: Double = 500.0,
        apparentPowerKVA: Double = 625.0,
        measuredCosPhi: Double = 0.80,
        targetCosPhi: Double = 0.95,
        systemVoltageV: Double = 400.0,
        transformerKVA: Double? = 1000.0,
        totalHarmonicDistortion: Double = 5.0,
        electricityTariff: Double = 0.90,
        investmentCostTL: Double = 50000.0,
        discountRate: Double = 0.15
    ) {
        self.activePowerKW = activePowerKW
        self.apparentPowerKVA = apparentPowerKVA
        self.measuredCosPhi = measuredCosPhi
        self.targetCosPhi = targetCosPhi
        self.systemVoltageV = systemVoltageV
        self.transformerKVA = transformerKVA
        self.totalHarmonicDistortion = totalHarmonicDistortion
        self.electricityTariff = electricityTariff
        self.investmentCostTL = investmentCostTL
        self.discountRate = discountRate
    }

    var isValid: Bool {
        return activePowerKW > 0
            && apparentPowerKVA >= activePowerKW
            && measuredCosPhi > 0 && measuredCosPhi <= 1.0
            && targetCosPhi > measuredCosPhi && targetCosPhi <= 1.0
            && systemVoltageV > 0
            && totalHarmonicDistortion >= 0 && totalHarmonicDistortion <= 50
            && electricityTariff > 0
            && investmentCostTL > 0
    }
}

// MARK: - Hesaplama Sonucu

/// Kompanzasyon hesaplama sonuçları — tüm alt analizler dahil
struct CompensationResult: Codable {

    // MARK: Mevcut Durum

    /// Mevcut reaktif güç (kVAr)
    var reactivePowerKVAr: Double

    /// Ölçülen güç faktörü (giriş ile aynı, doğrulama için)
    var currentCosPhi: Double

    /// TEDAŞ ceza eşiği (kVAr) — aktif gücün %33'ü (endüktif sınır)
    var penaltyThresholdKVAr: Double

    /// Aylık reaktif enerji ceza tahmini (TL)
    var monthlyPenaltyTL: Double

    /// Yıllık reaktif enerji ceza tahmini (TL)
    var yearlyPenaltyTL: Double

    // MARK: Kondansatör Hesabı

    /// Gerekli kompanzasyon gücü (kVAr)
    /// Qc = P × (tan φ₁ − tan φ₂)
    var requiredQcKVAr: Double

    /// Seçilen kondansatör kademeleri
    var selectedSteps: [CapacitorStep]

    /// Toplam kurulu kondansatör gücü (kVAr)
    var totalInstalledKVAr: Double

    /// Kondansatör tipi açıklaması ("Sabit" veya "Otomatik (AKP)")
    var capacitorType: String

    // MARK: AKP Parametreleri

    /// AKP kademe sayısı
    var stepCount: Int

    /// Her kademe gücü (kVAr)
    var stepSizeKVAr: Double

    /// Kontaktör akımı (A) = Qkademe / (√3 × V)
    var contactorCurrentA: Double

    /// Harmonik reaktör gerekli mi?
    var reactorRequired: Bool

    /// Reaktör detuning faktörü (%) — %5.67, %7 veya %14
    var reactorRatingPercent: Double

    /// Pano boyutu açıklaması (örn: "600×600×250 mm")
    var panelSizeDescription: String

    // MARK: Harmonik Analizi

    /// Paralel rezonans frekansı (Hz) = 50 × √(S_trafo / Qc)
    var resonanceFrequencyHz: Double

    /// Harmonik risk seviyesi
    var harmonicRiskLevel: HarmonicRisk

    /// Önerilen reaktör detuning katsayısı (p = fn²/50²)
    var recommendedReactorFactor: Double

    // MARK: Transformatör Etkisi

    /// Kompanzasyon öncesi transformatör yüklenme (%) — opsiyonel
    var transformerLoadBefore: Double?

    /// Kompanzasyon sonrası transformatör yüklenme (%) — opsiyonel
    var transformerLoadAfter: Double?

    /// Serbest kalan transformatör kapasitesi (kVA) — opsiyonel
    var capacityGainKVA: Double?

    /// Bakır kayıp azalması (%) — opsiyonel
    var copperLossReductionPercent: Double?

    // MARK: Ekonomik Analiz

    /// Aylık toplam tasarruf (TL) = ceza + kayıp azalması
    var totalMonthlySavingTL: Double

    /// Geri ödeme süresi (ay)
    var paybackMonths: Double

    /// 10 yıllık Net Bugünkü Değer (TL)
    var npvTL: Double

    /// İç Verimlilik Oranı — % (yıllık)
    var irrPercent: Double

    /// Yıllık kümülatif tasarruf dizisi — 10 yıl
    var cumulativeSavings: [Double]

    /// Kompanzasyon sonrası ulaşılan güç faktörü
    var achievedCosPhi: Double

    /// Kompanzasyon sonrası görünür güç (kVA)
    var newApparentKVA: Double

    // MARK: Uyumluluk Alias'ları

    /// Gerekli kondansatör kapasitesi (kVAr) — requiredQcKVAr ile aynı
    var requiredCapacityKVAr: Double { requiredQcKVAr }

    /// Yıllık toplam tasarruf (TL)
    var annualSavingsTL: Double { totalMonthlySavingTL * 12.0 }

    /// Transformatör kapasite kazanımı (%) — capacityGainKVA / trafo kapasite varsayımı
    var transformerCapacityGainPercent: Double {
        guard let gain = capacityGainKVA, gain > 0 else { return 0 }
        // Trafo kapasitesi bilinmiyorsa 1000 kVA referans al
        return (gain / 1000.0) * 100.0
    }
}
