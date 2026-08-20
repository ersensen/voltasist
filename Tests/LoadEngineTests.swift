// LoadEngineTests.swift
// VoltAsist — Birim Testleri
//
// LoadEngine yük analizi, talep gücü, fatura tahmini ve CO₂ emisyonu hesaplamalarını doğrular.
// Her test Given / When / Then yapısıyla yazılmıştır.

import XCTest
@testable import VoltAsist

// MARK: - LoadEngineTests

/// LoadEngine'in talep gücü, kVA/kVAr, akım, fatura ve CO₂ hesaplarını doğrulayan test sınıfı.
final class LoadEngineTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: 5 Yük Kalemi — Talep Gücü, kVA/kVAr ve Akım Doğrulaması

    /// 5 yük kalemi / kendi talep faktörleri / cosφ=0.90 → doğru talep gücü, kVA, kVAr,
    /// hat akımı ve önerilen sigorta hesabı.
    ///
    /// Elle hesap:
    ///   P_toplam = 1000×3 + 2200 + 1500 + 300×5 + 1000 = 9200 W → 9.2 kW
    ///   P_talep  = 3000×0.8 + 2200×0.9 + 1500×0.9 + 1500×1.0 + 1000×0.7
    ///            = 2400 + 1980 + 1350 + 1500 + 700 = 7930 W → 7.93 kW
    ///   S = P_talep / cosφ = 7.93 / 0.90 = 8.81111 kVA
    ///   Q = √(S² - P²) = √(77.63568 - 62.8849) = √14.75078 ≈ 3.84067 kVAr
    ///   I = S×1000 / (√3 × 400) = 8811.11 / 692.8203 ≈ 12.718 A
    ///   En büyük bağlı yük: "Aydınlatma" (3000 W bağlı güç, en büyük) → 3000×0.8/1000 = 2.4 kW talep
    func test_fiveLoads_ownDemandFactors_cosPhi090_shouldReturnCorrectDemandKVAandCurrent() {
        // Given
        let loads = [
            LoadItem(name: "Aydınlatma", powerW: 1000, quantity: 3, hoursPerDay: 5.0, localDemandFactor: 0.8, category: .lighting),
            LoadItem(name: "Motor 1",    powerW: 2200, quantity: 1, hoursPerDay: 8.0, localDemandFactor: 0.9, category: .motor),
            LoadItem(name: "Motor 2",    powerW: 1500, quantity: 1, hoursPerDay: 8.0, localDemandFactor: 0.9, category: .motor),
            LoadItem(name: "Bilgisayar", powerW: 300,  quantity: 5, hoursPerDay: 8.0, localDemandFactor: 1.0, category: .office),
            LoadItem(name: "Klima",      powerW: 1000, quantity: 1, hoursPerDay: 6.0, localDemandFactor: 0.7, category: .heating)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 0.8,   // yüklerin tümünde localDemandFactor set, bu değer kullanılmaz
            cosPhi: 0.90,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 240.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.totalConnectedKW, 9.2, accuracy: 0.01,
            "Toplam bağlı güç 9.2 kW olmalıdır.")
        XCTAssertEqual(result.demandKW, 7.93, accuracy: 0.01,
            "Talep gücü, her yükün kendi talep faktörüyle 7.93 kW olmalıdır.")
        XCTAssertEqual(result.apparentKVA, 8.8111, accuracy: 0.01,
            "Görünür güç S = P/cosφ formülüyle 8.8111 kVA olmalıdır.")
        XCTAssertEqual(result.reactiveKVAr, 3.8407, accuracy: 0.01,
            "Reaktif güç Q = √(S²-P²) formülüyle 3.8407 kVAr olmalıdır.")
        XCTAssertGreaterThan(result.apparentKVA, result.demandKW,
            "Görünür güç (kVA), talep gücünden (kW) büyük olmalıdır (cosφ < 1).")
        XCTAssertEqual(result.currentA, 12.718, accuracy: 0.05,
            "Hat akımı I = S/(√3×400) formülüyle ≈12.718 A olmalıdır.")
        XCTAssertEqual(result.recommendedMainFuseA, 16,
            "12.718 A akım için standart seride bir üst değer olan 16 A sigorta önerilmelidir.")
        XCTAssertEqual(result.largestLoadName, "Aydınlatma",
            "En büyük bağlı güce sahip yük (3000 W) 'Aydınlatma' olmalıdır.")
        XCTAssertEqual(result.largestLoadKW, 2.4, accuracy: 0.01,
            "En büyük yükün kendi talep faktörüyle (0.8) talep gücü 2.4 kW olmalıdır.")
    }

    // MARK: - Test 2: Fatura Hesabı Doğruluk Testi

    /// 10 kW yük / demandFactor=1.0 / günde 24 saat × 30 gün = 720 saat/ay / 4.5 TL/kWh tarife
    /// → 7200 kWh/ay, 32.400 TL/ay, 388.800 TL/yıl fatura beklenir.
    ///
    /// Elle hesap: kWh/ay = P(kW) × saat/gün × 30 = 10 × 24 × 30 = 7200 kWh
    ///             TL/ay  = 7200 × 4.5 = 32.400 TL
    ///             TL/yıl = 32.400 × 12 = 388.800 TL
    func test_energyCost_10kW_720hoursPerMonth_4p5tariff_shouldReturn32400TLMonthly() {
        // Given
        let loads = [
            LoadItem(name: "Test Yükü", powerW: 10_000, quantity: 1, hoursPerDay: 24.0, localDemandFactor: nil, category: .other)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 1.0,
            cosPhi: 0.90,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 720.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        let expectedMonthlyKWh: Double = 7200.0
        let expectedMonthlyCost: Double = 32_400.0
        let expectedYearlyCost: Double = 388_800.0

        XCTAssertEqual(result.monthlyKWh, expectedMonthlyKWh, accuracy: 0.5,
            "Aylık enerji tüketimi 7200 kWh olmalıdır.")
        XCTAssertEqual(result.monthlyBillTL, expectedMonthlyCost, accuracy: 5.0,
            "Aylık fatura 32.400 TL olmalıdır.")
        XCTAssertEqual(result.yearlyBillTL, expectedYearlyCost, accuracy: 50.0,
            "Yıllık fatura, aylık faturanın 12 katı olan 388.800 TL olmalıdır.")
    }

    // MARK: - Test 3: CO₂ Emisyon Katsayısı Testi

    /// 2 kW yük / demandFactor=1.0 / günde 10 saat çalışma →
    /// aylık 600 kWh, yıllık 7200 kWh × 0.42 kgCO₂/kWh = 3024 kg/yıl beklenir.
    ///
    /// Elle hesap: kWh/ay = 2 × 10 × 30 = 600 kWh → kWh/yıl = 600 × 12 = 7200 kWh
    ///             CO₂ (kg/yıl) = 7200 × 0.42 = 3024 kg
    func test_co2Emission_2kW_10hoursPerDay_shouldReturn3024kgPerYear() {
        // Given
        let loads = [
            LoadItem(name: "Referans Yük", powerW: 2000, quantity: 1, hoursPerDay: 10.0, localDemandFactor: nil, category: .other)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 1.0,
            cosPhi: 1.0,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 300.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        let expectedMonthlyKWh: Double = 600.0
        let expectedCO2KgPerYear: Double = expectedMonthlyKWh * 12.0 * LoadEngine.co2FactorKgPerKWh // 3024 kg

        XCTAssertEqual(result.monthlyKWh, expectedMonthlyKWh, accuracy: 0.5,
            "Aylık enerji tüketimi 600 kWh olmalıdır.")
        XCTAssertEqual(result.co2KgPerYear, expectedCO2KgPerYear, accuracy: 5.0,
            "Yıllık CO₂ emisyonu 3024 kg (±5 kg) olmalıdır.")
    }

    // MARK: - Test 4: Boş Yük Listesi Edge Case

    /// LoadEngine.calculate throws değildir — boş yük listesi ile çağrıldığında
    /// çökmeden emptyResult() dönmelidir: tüm sayısal alanlar 0, sigorta 6 A,
    /// kategori dağılımı boş, en büyük yük adı "-".
    func test_emptyLoadList_shouldReturnEmptyResultWithoutCrashing() {
        // Given
        let input = LoadCalculationInput(
            loads: [],
            demandFactor: 0.8,
            cosPhi: 0.9,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 240.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.totalConnectedKW, 0.0, accuracy: 0.001,
            "Boş liste için toplam bağlı güç 0 kW olmalıdır.")
        XCTAssertEqual(result.demandKW, 0.0, accuracy: 0.001,
            "Boş liste için talep gücü 0 kW olmalıdır.")
        XCTAssertEqual(result.apparentKVA, 0.0, accuracy: 0.001,
            "Boş liste için görünür güç 0 kVA olmalıdır.")
        XCTAssertEqual(result.monthlyKWh, 0.0, accuracy: 0.001,
            "Boş liste için aylık enerji tüketimi 0 kWh olmalıdır.")
        XCTAssertEqual(result.monthlyBillTL, 0.0, accuracy: 0.001,
            "Boş liste için aylık fatura 0 TL olmalıdır.")
        XCTAssertEqual(result.co2KgPerYear, 0.0, accuracy: 0.001,
            "Boş liste için CO₂ emisyonu 0 kg olmalıdır.")
        XCTAssertEqual(result.recommendedMainFuseA, 6,
            "Boş liste için standart seride en küçük sigorta (6 A) dönmelidir.")
        XCTAssertTrue(result.categoryBreakdown.isEmpty,
            "Boş liste için kategori dağılımı boş olmalıdır.")
        XCTAssertEqual(result.largestLoadName, "-",
            "Boş liste için en büyük yük adı '-' olmalıdır.")
        XCTAssertEqual(result.largestLoadKW, 0.0, accuracy: 0.001,
            "Boş liste için en büyük yük gücü 0 kW olmalıdır.")
    }

    // MARK: - Test 5: Genel Talep Faktörü = 0.5 ile Kısmi Yük Hesabı

    /// 20 kW bağlı yük / localDemandFactor yok → genel demandFactor=0.5 kullanılır
    /// → talep gücü 10 kW, bağlı güç ise değişmeden 20 kW kalmalıdır.
    func test_generalDemandFactor05_shouldHalveDemandPowerButNotConnectedPower() {
        // Given
        let loads = [
            LoadItem(name: "Büyük Yük", powerW: 20_000, quantity: 1, hoursPerDay: 8.0, localDemandFactor: nil, category: .other)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 0.5,
            cosPhi: 0.85,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 240.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.totalConnectedKW, 20.0, accuracy: 0.01,
            "Bağlı güç, talep faktöründen etkilenmeden 20 kW olarak kalmalıdır.")
        XCTAssertEqual(result.demandKW, 10.0, accuracy: 0.01,
            "Genel talep faktörü 0.5 uygulanınca talep gücü 10 kW olmalıdır.")
    }

    // MARK: - Test 6: Kategori Dağılımı Testi

    /// 2 farklı kategori / genel demandFactor=0.75 → kategori kırılımları ayrı ayrı doğru
    /// hesaplanmalı ve toplamları demandKW'ye eşit olmalıdır.
    ///
    /// Elle hesap: Aydınlatma: 500×4×0.75/1000 = 1.5 kW
    ///             Motor / Pompa: 3000×1×0.75/1000 = 2.25 kW
    ///             Toplam talep = 3.75 kW
    func test_categoryBreakdown_twoCategories_shouldSumToDemandKW() {
        // Given
        let loads = [
            LoadItem(name: "Aydınlatma A", powerW: 500,  quantity: 4, hoursPerDay: 5.0, localDemandFactor: nil, category: .lighting),
            LoadItem(name: "Motor A",      powerW: 3000, quantity: 1, hoursPerDay: 8.0, localDemandFactor: nil, category: .motor)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 0.75,
            cosPhi: 0.85,
            electricityUnitPrice: 4.0,
            monthlyUsageHours: 240.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.categoryBreakdown[LoadCategory.lighting.rawValue] ?? -1, 1.5, accuracy: 0.01,
            "Aydınlatma kategorisi talep gücü 1.5 kW olmalıdır.")
        XCTAssertEqual(result.categoryBreakdown[LoadCategory.motor.rawValue] ?? -1, 2.25, accuracy: 0.01,
            "Motor / Pompa kategorisi talep gücü 2.25 kW olmalıdır.")
        let breakdownSum = result.categoryBreakdown.values.reduce(0.0, +)
        XCTAssertEqual(breakdownSum, result.demandKW, accuracy: 0.01,
            "Kategori dağılımlarının toplamı, toplam talep gücüne eşit olmalıdır.")
    }

    // MARK: - Test 7: cosφ = 1.0 Saf Rezistif Yük — Reaktif Güç Sıfır

    /// cosφ = 1.0 (saf rezistif yük) için S = P olmalı ve reaktif güç 0 kVAr olmalıdır.
    func test_cosPhiOne_resistiveLoad_shouldReturnZeroReactivePower() {
        // Given
        let loads = [
            LoadItem(name: "Rezistif Yük", powerW: 5000, quantity: 1, hoursPerDay: 8.0, localDemandFactor: 1.0, category: .other)
        ]
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: 1.0,
            cosPhi: 1.0,
            electricityUnitPrice: 4.5,
            monthlyUsageHours: 240.0
        )

        // When
        let result = LoadEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.demandKW, 5.0, accuracy: 0.01,
            "Talep gücü 5.0 kW olmalıdır.")
        XCTAssertEqual(result.apparentKVA, result.demandKW, accuracy: 0.001,
            "cosφ=1 için görünür güç, talep gücüne eşit olmalıdır (S = P).")
        XCTAssertEqual(result.reactiveKVAr, 0.0, accuracy: 0.001,
            "cosφ=1 (saf rezistif) için reaktif güç 0 kVAr olmalıdır.")
    }
}
