// SolarEngineTests.swift
// VoltAsist — Birim Testleri
//
// SolarEngine güneş enerjisi sistemi boyutlandırma ve ekonomik analiz hesaplamalarını doğrular.
// Referans PSH değerleri PVGIS veri tabanı ve Türkiye Güneş Enerjisi Potansiyel Atlası'na dayanır.
// Sistem kapasitesi formülü (SolarEngine.calculate): kWp = (günlük kWh) / (PSH_efektif × η_sistem)
// η_sistem = SolarEngine.systemEfficiency = 0.90 (sabit).
// PSH_efektif = şehir PSH × yön/eğim düzeltme katsayısı (SolarEngine.orientationFactor).
// Güneye bakan (0°), 30° eğimli çatı için düzeltme katsayısı = 1.00 (kayıpsız).

import XCTest
@testable import VoltAsist

// MARK: - SolarEngineTests

/// SolarEngine panel kapasitesi, batarya boyutlandırma, üretim ve CO₂ testleri.
final class SolarEngineTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: İstanbul / 500 kWh/ay / OnGrid → Panel Kapasitesi

    /// SolarCalculationInput'ta monthlyConsumptionKWh salt-okunur bir computed property'dir
    /// (demandKW × dailyUsageHours × 30.0). 500 kWh/ay elde etmek için demandKW = 500/(8×30) ≈ 2.0833 kW,
    /// dailyUsageHours = 8.0 seçilmiştir (2.0833 × 8 × 30 = 500.0 tam).
    ///
    /// Elle hesap (SolarEngine.calculate formülü):
    ///   Günlük tüketim = 500 / 30 = 16.6667 kWh/gün
    ///   Yön/eğim: roofOrientationDeg=0° (Güney), roofTiltDeg=30° (optimum) → düzeltme katsayısı = 1.00
    ///   PSH_efektif = İstanbul PSH(4.20) × 1.00 = 4.20
    ///   Gerekli kWp (yuvarlanmamış) = 16.6667 / (4.20 × 0.90) = 16.6667 / 3.78 ≈ 4.4092 kWp
    ///   Panel adedi = ceil(4.4092 / 0.4) = ceil(11.023) = 12 panel
    ///   Kurulu kapasite = 12 × 0.4 = 4.8 kWp (tam değer — panel yuvarlamasıyla deterministik)
    func test_istanbul_500kWhMonthly_onGrid_shouldReturn4p8kWp() throws {
        // Given
        let demandKW = 500.0 / (8.0 * 30.0)   // ≈ 2.0833 kW
        let input = SolarCalculationInput(
            demandKW: demandKW,
            dailyUsageHours: 8.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0.0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — panel yuvarlaması nedeniyle kurulu kapasite tam olarak 4.8 kWp olmalıdır.
        XCTAssertEqual(input.monthlyConsumptionKWh, 500.0, accuracy: 0.01,
            "demandKW × dailyUsageHours × 30 aylık tüketimi 500 kWh vermelidir.")
        XCTAssertEqual(result.systemCapacityKWp, 4.8, accuracy: 0.01,
            "İstanbul 500 kWh/ay OnGrid sistem, panel yuvarlamasıyla tam 4.8 kWp olmalıdır.")
        XCTAssertEqual(result.panelCount, 12,
            "4.4092 kWp gereksinim, 400 Wp panellerle yukarı yuvarlanarak 12 panel vermelidir.")
        XCTAssertGreaterThan(result.systemCapacityKWp, 3.5,
            "Sistem kapasitesi 3.5 kWp'den büyük olmalıdır.")
        XCTAssertLessThan(result.systemCapacityKWp, 6.5,
            "Sistem kapasitesi 6.5 kWp'den küçük olmalıdır.")
    }

    // MARK: - Test 2: Yıllık Üretim Doğruluk Testi

    /// demandKW = 600/(8×30) = 2.5 kW, dailyUsageHours = 8.0 → aylık tüketim tam 600 kWh.
    ///
    /// Elle hesap:
    ///   Günlük tüketim = 600 / 30 = 20.0 kWh/gün
    ///   PSH_efektif = 4.20 (İstanbul, optimum çatı)
    ///   Gerekli kWp (yuvarlanmamış) = 20.0 / (4.20 × 0.90) = 20.0 / 3.78 ≈ 5.2910 kWp
    ///   Panel adedi = ceil(5.2910 / 0.4) = ceil(13.2275) = 14 panel
    ///   Kurulu kapasite = 14 × 0.4 = 5.6 kWp
    ///   Yıllık üretim = kWp × PSH_efektif × 365 × η_sistem = 5.6 × 4.20 × 365 × 0.90 = 7726.32 kWh/yıl
    ///   Özgül verim = PSH_efektif × 365 × η_sistem = 4.20 × 365 × 0.90 = 1379.7 kWh/kWp/yıl
    func test_annualProduction_600kWhMonthly_istanbul_shouldMatch7726kWh() throws {
        // Given
        let demandKW = 600.0 / (8.0 * 30.0)   // = 2.5 kW
        let input = SolarCalculationInput(
            demandKW: demandKW,
            dailyUsageHours: 8.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0.0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — kurulu kapasite 5.6 kWp ve yıllık üretim 7726.32 kWh olmalıdır (deterministik).
        XCTAssertEqual(result.systemCapacityKWp, 5.6, accuracy: 0.01,
            "600 kWh/ay İstanbul OnGrid sistem 5.6 kWp kurulu kapasiteye yuvarlanmalıdır.")
        XCTAssertEqual(result.specificYield, 1379.7, accuracy: 1.0,
            "Özgül verim PSH×365×η formülüyle ≈1379.7 kWh/kWp/yıl olmalıdır.")
        XCTAssertEqual(result.annualProductionKWh, 7726.32, accuracy: 5.0,
            "Yıllık üretim kWp×PSH×365×η formülüyle ≈7726.32 kWh olmalıdır.")

        // Üretim = kurulu kapasite × özgül verim (motorun kendi iç tutarlılığı)
        XCTAssertEqual(result.annualProductionKWh, result.systemCapacityKWp * result.specificYield,
            accuracy: 0.5, "Yıllık üretim = kWp × özgül verim eşitliği sağlanmalıdır.")

        XCTAssertGreaterThan(result.annualProductionKWh, 4_000.0,
            "Yıllık üretim 4000 kWh'den büyük olmalıdır.")
        XCTAssertLessThan(result.annualProductionKWh, 10_000.0,
            "Yıllık üretim 10000 kWh'den küçük olmalıdır.")
    }

    // MARK: - Test 3: Batarya Kapasitesi (OffGrid / 2 Gün / LiFePO₄)

    /// OffGrid, 2 gün özerklik, 500 kWh/ay (demandKW = 500/(8×30), dailyUsageHours = 8.0), Ankara, LiFePO₄, 48V.
    ///
    /// Elle hesap (SolarEngine.calculate batarya bölümü):
    ///   Günlük tüketim = 500 / 30 ≈ 16.6667 kWh/gün
    ///   Ham kapasite = (16.6667 × 2 gün) / DoD(0.80) = 33.3333 / 0.80 = 41.6667 kWh
    ///   Verimlilik düzeltmesi (LiFePO₄ efficiency=0.97) = 41.6667 / 0.97 ≈ 42.9553 kWh
    ///   Ah kapasitesi = 42.9553 × 1000 / 48V ≈ 894.90 Ah
    ///   Seri sayısı = 48 / 12 = 4
    ///   Paralel sayısı = ceil(894.90 / 100) = 9
    ///   Batarya adedi = 4 × 9 = 36
    func test_offGrid_2days_lifepo4_shouldReturnCorrectBatteryCapacity() throws {
        // Given
        let demandKW = 500.0 / (8.0 * 30.0)
        let input = SolarCalculationInput(
            demandKW: demandKW,
            dailyUsageHours: 8.0,
            city: .ankara,
            roofTiltDeg: 33.0,
            roofOrientationDeg: 0.0,
            systemType: .offGrid,
            autonomyDays: 2.0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 0.0,   // OffGrid — şebekeye satış yok
            electricityPrice: 4.5,
            installationCostPerKWp: 38_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — Batarya grubu var olmalı
        XCTAssertNotNil(result.batteryBank,
            "OffGrid sistem için batarya grubu hesaplanmış olmalıdır.")

        if let bat = result.batteryBank {
            XCTAssertEqual(bat.totalCapacityKWh, 42.9553, accuracy: 0.1,
                "LiFePO₄ 2 gün özerklik için batarya kapasitesi (DoD ve verim düzeltmeli) ≈42.96 kWh olmalıdır.")
            XCTAssertEqual(bat.totalCapacityAh, 894.9, accuracy: 3.0,
                "48V sistemde Ah kapasitesi ≈894.9 Ah olmalıdır.")
            XCTAssertEqual(bat.batteryCount, 36,
                "4 seri × 9 paralel = 36 batarya ünitesi olmalıdır.")
            XCTAssertGreaterThan(bat.batteryCount, 0,
                "Batarya ünite sayısı pozitif olmalıdır.")
        }
    }

    // MARK: - Test 4: PSH Değeri Testi (İstanbul=4.2, İzmir=5.3)

    /// Her şehrin PSH değeri PVGIS veri tabanı ile örtüşmelidir.
    func test_PSH_istanbul_42_izmir_53() {
        // Given / When / Then
        XCTAssertEqual(TurkishCity.istanbul.peakSunHours, 4.2, accuracy: 0.2,
            "İstanbul PSH değeri 4.2 ±0.2 olmalıdır.")
        XCTAssertEqual(TurkishCity.izmir.peakSunHours, 5.3, accuracy: 0.2,
            "İzmir PSH değeri 5.3 ±0.2 olmalıdır.")
        XCTAssertGreaterThan(TurkishCity.konya.peakSunHours, 4.5,
            "Konya PSH değeri 4.5'tan büyük olmalıdır (iç bölge avantajı).")
        XCTAssertLessThan(TurkishCity.rize.peakSunHours, 3.8,
            "Rize PSH değeri 3.8'den küçük olmalıdır (yağışlı bölge).")
    }

    // MARK: - Test 5: CO₂ Tasarrufu Hesabı

    /// Aynı senaryo Test 2 ile aynı girişleri kullanır (annualProductionKWh ≈ 7726.32 kWh/yıl).
    ///
    /// Elle hesap:
    ///   co2SavingTonPerYear = annualProductionKWh × 0.42(co2FactorKgPerKWh) / 1000
    ///                       ≈ 7726.32 × 0.42 / 1000 ≈ 3.245 ton/yıl
    ///   co2SavingsTon25Years (uyumluluk alias'ı) = Σ(25 yıllık, %0.5/yıl degredasyonlu üretim) × 0.42 / 1000
    ///   Degredasyonlu toplam, düz "yıllık × 25" değerinden küçük olmalı (panel bozunması nedeniyle)
    ///   ama yaklaşık 23.5 "etkin yıl" civarında olduğundan 20 katından büyük olmalıdır.
    func test_co2Saving_600kWhMonthly_istanbul() throws {
        // Given
        let demandKW = 600.0 / (8.0 * 30.0)
        let input = SolarCalculationInput(
            demandKW: demandKW,
            dailyUsageHours: 8.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0.0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — Yıllık CO₂ tasarrufu = yıllık üretim × 0.42 / 1000
        let expectedCo2PerYear = result.annualProductionKWh * 0.42 / 1000.0
        XCTAssertEqual(result.co2SavingTonPerYear, expectedCo2PerYear, accuracy: 0.01,
            "Yıllık CO₂ tasarrufu üretim×0.42/1000 formülüyle örtüşmelidir.")

        // 25 yıllık kümülatif (degredasyonlu) — düz 25 katından az, 20 katından fazla olmalıdır.
        XCTAssertLessThan(result.co2SavingsTon25Years, expectedCo2PerYear * 25.0,
            "25 yıllık CO₂ tasarrufu, panel bozunması nedeniyle düz 25 katından az olmalıdır.")
        XCTAssertGreaterThan(result.co2SavingsTon25Years, expectedCo2PerYear * 20.0,
            "25 yıllık CO₂ tasarrufu, yıllık değerin 20 katından fazla olmalıdır.")
        XCTAssertGreaterThan(result.co2SavingsTon25Years, 30.0,
            "25 yıllık CO₂ tasarrufu 30 tondan büyük olmalıdır.")
    }

    // MARK: - Test 6: Sıfır Talep Gücü Edge Case

    /// SolarCalculationInput.isValid, demandKW > 0 şartını arar. demandKW: 0.0 ile giriş geçersiz
    /// hale gelir ve SolarEngine.calculate CalculationError.invalidInput fırlatır.
    func test_zeroDemandKW_shouldThrowError() {
        // Given
        let input = SolarCalculationInput(
            demandKW: 0.0,
            dailyUsageHours: 8.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0.0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When / Then
        XCTAssertThrowsError(try SolarEngine.calculate(input: input)) { error in
            XCTAssertTrue(error is CalculationError,
                "Sıfır demandKW için CalculationError fırlatılmalıdır.")
        }
    }
}
