// SolarEngine.swift
// VoltAsist
//
// Güneş enerjisi sistemi boyutlandırma motoru.
// Panel, batarya, inverter, ekonomi ve 25 yıllık üretim projeksiyonu.

import Foundation

// MARK: - Solar Hesaplama Motoru

/// Güneş enerjisi sistemi boyutlandırma motoru
struct SolarEngine {

    // MARK: Sabitler

    /// Panel modülü varsayılan gücü (Wp)
    static let defaultPanelWp: Double = 400.0

    /// Panel modülü başına çatı alanı (m²) — 400 Wp panel ≈ 2.0 m²
    static let areaPer400WpPanel: Double = 2.0

    /// Sistem verimi (η_system) — panel × inverter × kablo kayıpları
    /// η = ηpanel(0.95) × ηinverter(0.97) × ηkablo(0.98) ≈ 0.90
    static let systemEfficiency: Double = 0.90

    /// Yıllık panel degredasyonu (%) — premium polikristal/monokristal
    static let annualDegradationRate: Double = 0.005   // %0.5/yıl

    /// CO₂ emisyon faktörü (kg CO₂/kWh) — EPDK 2023 Türkiye
    static let co2FactorKgPerKWh: Double = 0.42

    /// Proje ömrü (yıl) — bankacılık sektörü ve YEKA standartları
    static let projectLifeYears: Int = 25

    /// Referans batarya kapasitesi (Ah @ 12V) — hesap birimi
    static let referenceBatteryAh: Double = 100.0
    static let referenceBatteryV: Double  = 12.0

    // MARK: Ana Hesaplama

    /// Solar sistem boyutlandırmasını gerçekleştir
    /// - Parameter input: Giriş parametreleri
    /// - Returns: Hesaplama sonuçları
    /// - Throws: CalculationError giriş geçersizse
    static func calculate(input: SolarCalculationInput) throws -> SolarCalculationResult {
        guard input.isValid else {
            throw CalculationError.invalidInput("Solar hesaplama giriş parametreleri geçersiz.")
        }

        // --- 1. Günlük Tüketim ---
        let dailyConsumptionKWh = input.monthlyConsumptionKWh / 30.0

        // --- 2. PSH Değeri (Tepe Güneş Saati) ---
        // Çatı yönü ve eğiminden düzeltme katsayısı
        let orientFactor = orientationFactor(
            tiltDeg: input.roofTiltDeg,
            orientationDeg: input.roofOrientationDeg
        )
        let effectivePSH = input.city.peakSunHours * orientFactor

        // --- 3. Gerekli Panel Kapasitesi ---
        // kWp = (kWh/gün) / (PSH × η_sistem)
        let requiredKWp = dailyConsumptionKWh / (effectivePSH * systemEfficiency)

        // Standart panel adedi — yukarı yuvarlama
        let panelWp = defaultPanelWp / 1000.0  // kWp
        let panelCount = Int(ceil(requiredKWp / panelWp))
        let installedKWp = Double(panelCount) * panelWp

        // Çatı alanı (m²)
        let roofAreaM2 = Double(panelCount) * areaPer400WpPanel

        // --- 4. Yıllık Üretim ---
        // kWh/yıl = kWp × PSH_efektif × 365 × η_sistem
        let annualProductionKWh = installedKWp * effectivePSH * 365.0 * systemEfficiency

        // Özgül verim (kWh/kWp/yıl)
        let specificYield = effectivePSH * 365.0 * systemEfficiency

        // --- 5. Batarya Sistemi (Off-Grid / Hybrid için) ---
        let batteryCapacityKWh: Double
        let batteryCapacityAh: Double
        let batteryCount: Int
        let chargeCurrentA: Double

        if input.systemType == .onGrid {
            // On-grid sistemde batarya yok
            batteryCapacityKWh = 0
            batteryCapacityAh  = 0
            batteryCount       = 0
            chargeCurrentA     = 0
        } else {
            // Gerekli depolama: kWh = (kWh/gün × özerklik günü) / DoD
            let rawCapacityKWh = (dailyConsumptionKWh * input.autonomyDays) / input.batteryType.dod
            // Batarya verimliliği düzeltmesi
            batteryCapacityKWh = rawCapacityKWh / input.batteryType.efficiency

            // Ah kapasitesi: Ah = kWh × 1000 / sistem gerilimi
            let rawAh = (batteryCapacityKWh * 1000.0) / Double(input.systemVoltage)
            batteryCapacityAh = rawAh

            // 100 Ah @ 12V biriminden seri/paralel hesabı
            // Seri: gerilim eşleşmesi, Paralel: kapasite eşleşmesi
            let batteryVoltage = 12.0  // 12V referans batarya
            let seriesCount = input.systemVoltage / 12   // Seri bağlı batarya sayısı
            let parallelCount = Int(ceil(rawAh / referenceBatteryAh))
            batteryCount = seriesCount * parallelCount

            // Şarj akımı: I = kWp × 1000 / sistem gerilimi (C/10 önerilir)
            chargeCurrentA = (installedKWp * 1000.0) / Double(input.systemVoltage)

            // Kullanılmayan ama derleme için tutulan değer
            _ = batteryVoltage
        }

        // --- 6. Ekonomik Analiz ---
        // Batarya maliyeti
        let batteryCostTL: Double
        if input.systemType != .onGrid && batteryCapacityKWh > 0 {
            batteryCostTL = batteryCapacityKWh * input.batteryType.pricePerKWh
        } else {
            batteryCostTL = 0.0
        }

        // Toplam yatırım = panel+inverter (kWp×birim fiyat) + batarya
        let totalInvestmentTL = installedKWp * input.installationCostPerKWp + batteryCostTL

        // Yıllık tasarruf — öz tüketim kısmı (şebekeden çekilmeyen enerji)
        let annualConsumptionKWh = input.monthlyConsumptionKWh * 12.0
        let selfConsumedKWh: Double
        let gridFeedInKWh: Double

        if annualProductionKWh <= annualConsumptionKWh {
            // Üretim < Tüketim — tamamı öz tüketim
            selfConsumedKWh = annualProductionKWh
            gridFeedInKWh   = 0.0
        } else {
            // Üretim > Tüketim — fazlası şebekeye
            selfConsumedKWh = annualConsumptionKWh
            gridFeedInKWh   = annualProductionKWh - annualConsumptionKWh
        }

        let annualSavingTL  = selfConsumedKWh * input.electricityPrice
        let annualGridIncomeTL: Double
        if input.systemType == .offGrid {
            annualGridIncomeTL = 0.0  // Off-grid: şebeke bağlantısı yok
        } else {
            annualGridIncomeTL = gridFeedInKWh * input.feedInTariff
        }
        let totalAnnualBenefit = annualSavingTL + annualGridIncomeTL

        // Geri ödeme (yıl)
        let paybackYears = totalAnnualBenefit > 0
            ? totalInvestmentTL / totalAnnualBenefit
            : Double.infinity

        // --- 7. CO₂ Tasarrufu ---
        let co2SavingTon = (annualProductionKWh * co2FactorKgPerKWh) / 1000.0

        // --- 8. 25 Yıllık Üretim (Degredasyonlu) ---
        var yearlyProduction: [Double] = []
        for year in 0..<projectLifeYears {
            let degradationFactor = pow(1.0 - annualDegradationRate, Double(year))
            yearlyProduction.append(annualProductionKWh * degradationFactor)
        }

        // --- 9. 25 Yıllık NBD ---
        let discountRate = 0.15  // %15 iskonto oranı (YEKA standartları)
        var npc = -totalInvestmentTL
        for (year, production) in yearlyProduction.enumerated() {
            let selfConsume = min(production, annualConsumptionKWh)
            let feedIn = max(0.0, production - annualConsumptionKWh)
            let yearBenefit: Double
            if input.systemType == .offGrid {
                yearBenefit = selfConsume * input.electricityPrice
            } else {
                yearBenefit = selfConsume * input.electricityPrice + feedIn * input.feedInTariff
            }
            // Yılda bir kez bakım maliyeti düş (~₺500/yıl)
            let maintenanceCost = 500.0 * pow(1.05, Double(year))  // %5 enflasyon
            npc += (yearBenefit - maintenanceCost) / pow(1.0 + discountRate, Double(year + 1))
        }

        // --- 10. İnverter Boyutu ---
        // DC/AC oranı 1.2 önerilir (oversizing)
        let inverterKW = installedKWp * 1.0  // On-grid için eşit boyutlandırma
        let dcAcRatio  = installedKWp / max(inverterKW, 0.001)

        return SolarCalculationResult(
            requiredCapacityKWp: installedKWp,
            panelCount: panelCount,
            roofAreaM2: roofAreaM2,
            annualProductionKWh: annualProductionKWh,
            specificYield: specificYield,
            batteryCapacityKWh: batteryCapacityKWh,
            batteryCapacityAh: batteryCapacityAh,
            batteryCount: batteryCount,
            chargeCurrentA: chargeCurrentA,
            totalInvestmentTL: totalInvestmentTL,
            annualSavingTL: annualSavingTL,
            annualGridIncomeTL: annualGridIncomeTL,
            paybackYears: paybackYears,
            co2SavingTonPerYear: co2SavingTon,
            npcTL: npc,
            yearlyProduction: yearlyProduction,
            inverterKW: inverterKW,
            dcAcRatio: dcAcRatio,
            orientationFactor: orientFactor
        )
    }

    // MARK: Yön ve Eğim Düzeltme Katsayısı

    /// Çatı yönü ve eğim açısına göre üretim düzeltme katsayısı
    /// Güneye bakan 30° eğim = optimum (1.0)
    /// Hesaplama: PVGIS/SolarGIS yıllık ortalama veri ile kalibre edilmiştir
    /// - Parameters:
    ///   - tiltDeg: Eğim açısı (0–90 derece)
    ///   - orientationDeg: Yön açısı (0=Güney, 90=Batı, -90=Doğu, 180=Kuzey)
    /// - Returns: Düzeltme katsayısı (0.60–1.00)
    static func orientationFactor(tiltDeg: Double, orientationDeg: Double) -> Double {
        // Yön kaybı — Güneyden sapma başına yaklaşık kayıp
        let absOrientation = abs(orientationDeg)
        let orientationLoss: Double
        switch absOrientation {
        case 0..<15:   orientationLoss = 0.00   // Güney — kayıp yok
        case 15..<30:  orientationLoss = 0.02
        case 30..<45:  orientationLoss = 0.05
        case 45..<60:  orientationLoss = 0.09
        case 60..<90:  orientationLoss = 0.15
        case 90..<120: orientationLoss = 0.22
        case 120..<150:orientationLoss = 0.30
        default:       orientationLoss = 0.40   // Kuzey
        }

        // Eğim kaybı — 30° optimumdan sapma
        let tiltLoss: Double
        let tiltDeviation = abs(tiltDeg - 30.0)
        switch tiltDeviation {
        case 0..<5:   tiltLoss = 0.00
        case 5..<10:  tiltLoss = 0.01
        case 10..<20: tiltLoss = 0.03
        case 20..<30: tiltLoss = 0.06
        case 30..<45: tiltLoss = 0.10
        default:       tiltLoss = 0.15
        }

        let factor = 1.0 - orientationLoss - tiltLoss
        return max(0.60, min(factor, 1.00))
    }

    // MARK: Hızlı Tahmin

    /// Fatura miktarına göre hızlı panel kapasitesi tahmini
    /// - Parameters:
    ///   - monthlyBillTL: Aylık elektrik faturası (TL)
    ///   - electricityPrice: Birim fiyat (TL/kWh)
    ///   - city: İl (PSH için)
    /// - Returns: Tahmini gerekli kapasite (kWp)
    static func quickEstimate(monthlyBillTL: Double, electricityPrice: Double, city: TurkishCity) -> Double {
        guard electricityPrice > 0 else { return 0 }
        let monthlyKWh = monthlyBillTL / electricityPrice
        let dailyKWh = monthlyKWh / 30.0
        return dailyKWh / (city.peakSunHours * systemEfficiency)
    }
}
