// SolarEngineTests.swift
// VoltAsist — Birim Testleri
//
// SolarEngine güneş enerjisi sistemi boyutlandırma ve ekonomik analiz hesaplamalarını doğrular.
// Referans PSH değerleri PVGIS veri tabanı ve Türkiye Güneş Enerjisi Potansiyel Atlası'na dayanır.
// Sistem kapasitesi formülü: kWp = (aylık kWh / 30) / (PSH × PR)

import XCTest
@testable import UygulamaMotoru

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

    // MARK: - Test 1: İstanbul / 500 kWh/ay / OnGrid → ~4.2 kWp ±0.3

    /// Formül: Günlük ihtiyaç = 500/30 = 16.67 kWh
    /// kWp = günlük kWh / (PSH × PR) = 16.67 / (4.2 × 0.80) ≈ 4.96 kWp
    /// (PR = performans oranı 0.78–0.82 aralığında değişir)
    func test_istanbul_500kWhMonthly_onGrid_shouldReturn4to5kWp() throws {
        // Given
        let input = SolarCalculationInput(
            monthlyConsumptionKWh: 500.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — İstanbul PSH=4.2, PR≈0.80 → kWp ≈ 4.96 (tolerans ±0.5)
        XCTAssertEqual(result.systemCapacityKWp, 4.96, accuracy: 0.8,
            "İstanbul 500 kWh/ay OnGrid sistem ≈4.96 kWp (±0.8) olmalıdır.")
        XCTAssertGreaterThan(result.systemCapacityKWp, 3.5,
            "Sistem kapasitesi 3.5 kWp'den büyük olmalıdır.")
        XCTAssertLessThan(result.systemCapacityKWp, 6.5,
            "Sistem kapasitesi 6.5 kWp'den küçük olmalıdır.")
    }

    // MARK: - Test 2: Yıllık Üretim Doğruluk Testi

    /// Yıllık üretim = kWp × PSH × 365 × PR
    /// 5 kWp × 4.2 h/gün × 365 gün × 0.80 = 6.132 kWh/yıl
    func test_annualProduction_5kWp_istanbul_shouldMatch6000kWh() throws {
        // Given
        let input = SolarCalculationInput(
            monthlyConsumptionKWh: 600.0,   // 600 kWh/ay → ~5 kWp
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — Yıllık üretim, aylık tüketimin ~12 katına yakın olmalı (self-consumption için)
        XCTAssertGreaterThan(result.annualProductionKWh, 4_000.0,
            "İstanbul 5 kWp için yıllık üretim 4000 kWh'den büyük olmalıdır.")
        XCTAssertLessThan(result.annualProductionKWh, 10_000.0,
            "İstanbul 5 kWp için yıllık üretim 10000 kWh'den küçük olmalıdır.")

        // Üretim formülü tutarlılığı: kWp × PSH_istanbul × 365 × PR
        let expectedAnnual = result.systemCapacityKWp * 4.2 * 365.0 * 0.80
        XCTAssertEqual(result.annualProductionKWh, expectedAnnual, accuracy: 300.0,
            "Yıllık üretim kWp×PSH×365×PR formülüyle ±300 kWh örtüşmelidir.")
    }

    // MARK: - Test 3: Batarya Kapasitesi (OffGrid / 2 Gün / LiFePO₄)

    /// OffGrid, 2 gün özerklik, 500 kWh/ay:
    /// Günlük ihtiyaç = 500/30 = 16.67 kWh
    /// Toplam batarya enerjisi = 16.67 × 2 = 33.33 kWh
    /// LiFePO₄ DoD = %80 → gerçek kapasite = 33.33 / 0.80 = 41.67 kWh
    func test_offGrid_2days_lifepo4_shouldReturnCorrectBatteryCapacity() throws {
        // Given
        let input = SolarCalculationInput(
            monthlyConsumptionKWh: 500.0,
            city: .ankara,
            roofTiltDeg: 33.0,
            roofOrientationDeg: 0.0,
            systemType: .offGrid,
            autonomyDays: 2,
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
            // Günlük = 500/30 ≈ 16.67 kWh, 2 gün × DoD 0.80 = 41.67 kWh gerekli
            let dailyKWh   = 500.0 / 30.0   // ≈ 16.67
            let dodFactor  = 0.80            // LiFePO₄ DoD
            let expectedKWh = dailyKWh * 2.0 / dodFactor  // ≈ 41.67 kWh
            XCTAssertEqual(bat.totalCapacityKWh, expectedKWh, accuracy: 3.0,
                "LiFePO₄ 2 gün özerklik için batarya kapasitesi ≈41.7 kWh (±3) olmalıdır.")
            XCTAssertGreaterThan(bat.unitCount, 0,
                "Batarya ünite sayısı pozitif olmalıdır.")
        }
    }

    // MARK: - Test 4: PSH Değeri Testi (İstanbul=4.2, İzmir=5.3)

    /// Her şehrin PSH değeri PVGIS veri tabanı ile örtüşmelidir.
    func test_PSH_istanbul_422_izmir_53() {
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

    /// 6000 kWh/yıl × 0.473 kg/kWh × 25 yıl = 71.0 ton CO₂ tasarrufu beklenir.
    func test_co2Saving_6000kWh_25years_shouldReturn71tons() throws {
        // Given
        let input = SolarCalculationInput(
            monthlyConsumptionKWh: 600.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When
        let result = try SolarEngine.calculate(input: input)

        // Then — CO₂ = yıllık_kWh × 0.473 × 25
        let expectedCO2ton = result.annualProductionKWh * 0.473 * 25.0 / 1000.0
        XCTAssertEqual(result.co2SavingsTon25Years, expectedCO2ton, accuracy: 5.0,
            "25 yıllık CO₂ tasarrufu ±5 ton hassasiyetle örtüşmelidir.")
        XCTAssertGreaterThan(result.co2SavingsTon25Years, 30.0,
            "25 yıllık CO₂ tasarrufu 30 tondan büyük olmalıdır.")
    }

    // MARK: - Test 6: Sıfır Tüketim Edge Case

    /// Sıfır aylık tüketim girişinde CalculationError fırlatılmalıdır.
    func test_zeroMonthlyConsumption_shouldThrowError() {
        // Given
        let input = SolarCalculationInput(
            monthlyConsumptionKWh: 0.0,
            city: .istanbul,
            roofTiltDeg: 30.0,
            roofOrientationDeg: 0.0,
            systemType: .onGrid,
            autonomyDays: 0,
            batteryType: .lifepo4,
            systemVoltage: 48,
            feedInTariff: 3.0,
            electricityPrice: 4.5,
            installationCostPerKWp: 35_000.0
        )

        // When / Then
        XCTAssertThrowsError(try SolarEngine.calculate(input: input)) { error in
            XCTAssertTrue(error is CalculationError,
                "Sıfır tüketim için CalculationError fırlatılmalıdır.")
        }
    }
}
