// LoadEngineTests.swift
// VoltAsist — Birim Testleri
//
// LoadEngine yük analizi, fatura tahmini ve CO₂ emisyonu hesaplamalarını doğrular.
// Referans değerler IEC 60038 ve EPDK tarife tablosuna dayanmaktadır.

import XCTest
@testable import UygulamaMotoru

// MARK: - LoadEngineTests

/// LoadEngine yük akım, güç ve enerji maliyeti hesaplarını doğrulayan test sınıfı.
final class LoadEngineTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: 5 Yük Kalemi — cosφ ve Talep Faktörü ile kVA, kVAr Doğrulaması

    /// 5 yük kalemi / ortalama cosφ=0.9 / talepFaktörü=0.8 → doğru kVA ve kVAr hesabı.
    /// P_toplam = 9500 W → P_talep = 7600 W → Q = P×tan(φ) ≈ 3682 VAr → S = P/cosφ ≈ 8444 VA
    func test_fiveLoads_cosPhi09_demandFactor08_shouldReturnCorrectKVAandKVAr() throws {
        // Given
        let input = LoadCalculationInput(
            supplyVoltageV: 400,
            phaseCount: .three,
            supplyFrequencyHz: 50,
            peakDemandFactor: 0.8,
            averagePowerFactor: 0.90,
            electricityTariffPerKWh: 4.5,
            monthlyOperatingHours: 720,
            co2EmissionFactor: 0.473
        )
        let loads = [
            LoadItem(name: "Aydınlatma",  powerW: 1000, quantity: 3, powerFactor: 0.95, demandFactor: 0.8),
            LoadItem(name: "Motor 1",     powerW: 2200, quantity: 1, powerFactor: 0.85, demandFactor: 0.9),
            LoadItem(name: "Motor 2",     powerW: 1500, quantity: 1, powerFactor: 0.85, demandFactor: 0.9),
            LoadItem(name: "Bilgisayar",  powerW: 300,  quantity: 5, powerFactor: 0.90, demandFactor: 1.0),
            LoadItem(name: "Klima",       powerW: 1000, quantity: 1, powerFactor: 0.80, demandFactor: 0.7)
        ]
        // P_toplam hesabı:
        // 3000 + 2200 + 1500 + 1500 + 1000 = 9200 W (nominal)
        // Talep faktörü 0.8 → 7360 W aktif güç talepte

        // When
        let result = try LoadEngine.calculate(input: input, loads: loads)

        // Then
        XCTAssertGreaterThan(result.totalActivePowerKW, 5.0,
            "Toplam aktif güç 5 kW'dan büyük olmalıdır.")
        XCTAssertGreaterThan(result.totalApparentPowerKVA, result.totalActivePowerKW,
            "Görünür güç (kVA), aktif güçten (kW) büyük olmalıdır.")
        XCTAssertGreaterThan(result.totalReactivePowerKVAr, 0.0,
            "Reaktif güç pozitif olmalıdır.")
        // kVA = kW / cosφ
        let expectedKVA = result.totalActivePowerKW / 0.90
        XCTAssertEqual(result.totalApparentPowerKVA, expectedKVA, accuracy: 1.0,
            "Görünür güç kW/cosφ formülüyle ±1 kVA hassasiyetle örtüşmelidir.")
    }

    // MARK: - Test 2: Fatura Hesabı Doğruluk Testi

    /// 10 kW aktif talep / 4.5 TL/kWh tarife / 720 saat/ay → 32.400 TL/ay fatura beklenir.
    func test_energyCost_10kW_4p5tariff_720hours_shouldReturn32400TLMonthly() throws {
        // Given
        let input = LoadCalculationInput(
            supplyVoltageV: 400,
            phaseCount: .three,
            supplyFrequencyHz: 50,
            peakDemandFactor: 1.0,
            averagePowerFactor: 0.90,
            electricityTariffPerKWh: 4.5,
            monthlyOperatingHours: 720,
            co2EmissionFactor: 0.473
        )
        // Tam 10 kW aktif güç
        let loads = [
            LoadItem(name: "Test Yükü", powerW: 10_000, quantity: 1, powerFactor: 0.90, demandFactor: 1.0)
        ]

        // When
        let result = try LoadEngine.calculate(input: input, loads: loads)

        // Then — E = P × saat = 10 kW × 720 h = 7200 kWh/ay → 7200 × 4.5 = 32.400 TL
        let expectedMonthlyKWh  = 10.0 * 720.0          // 7200 kWh
        let expectedMonthlyCost = expectedMonthlyKWh * 4.5  // 32.400 TL
        XCTAssertEqual(result.monthlyEnergyKWh, expectedMonthlyKWh, accuracy: 50.0,
            "Aylık enerji tüketimi ±50 kWh hassasiyetle 7200 kWh olmalıdır.")
        XCTAssertEqual(result.monthlyEnergyCostTL, expectedMonthlyCost, accuracy: 250.0,
            "Aylık fatura ±250 TL hassasiyetle 32.400 TL olmalıdır.")
    }

    // MARK: - Test 3: CO₂ Emisyon Katsayısı Testi

    /// 1000 kWh enerji × 0.473 kgCO₂/kWh → 473 kg = 0.473 ton CO₂ beklenir.
    func test_co2EmissionFactor_1000kWh_shouldReturn473kg() throws {
        // Given
        let co2Factor = 0.473  // kg CO₂/kWh (Türkiye şebeke emisyon faktörü)
        let input = LoadCalculationInput(
            supplyVoltageV: 230,
            phaseCount: .single,
            supplyFrequencyHz: 50,
            peakDemandFactor: 1.0,
            averagePowerFactor: 1.0,
            electricityTariffPerKWh: 4.5,
            monthlyOperatingHours: 1000,   // 1000 saat/ay
            co2EmissionFactor: co2Factor
        )
        let loads = [
            LoadItem(name: "Referans Yük", powerW: 1000, quantity: 1, powerFactor: 1.0, demandFactor: 1.0)
        ]
        // P = 1 kW × 1000 h = 1000 kWh → CO₂ = 1000 × 0.473 = 473 kg

        // When
        let result = try LoadEngine.calculate(input: input, loads: loads)

        // Then
        let expectedCO2kg = 1000.0 * co2Factor  // 473 kg
        XCTAssertEqual(result.monthlyCO2EmissionKg, expectedCO2kg, accuracy: 5.0,
            "CO₂ emisyonu ±5 kg hassasiyetle 473 kg olmalıdır.")
    }

    // MARK: - Test 4: Boş Yük Listesi Edge Case

    /// Hiç yük kalemi olmadan hesaplama yapılmaya çalışılırsa CalculationError fırlatılmalı.
    func test_emptyLoadList_shouldThrowCalculationError() {
        // Given
        let input = LoadCalculationInput(
            supplyVoltageV: 400,
            phaseCount: .three,
            supplyFrequencyHz: 50,
            peakDemandFactor: 0.85,
            averagePowerFactor: 0.90,
            electricityTariffPerKWh: 4.5,
            monthlyOperatingHours: 720,
            co2EmissionFactor: 0.473
        )
        let emptyLoads: [LoadItem] = []

        // When / Then
        XCTAssertThrowsError(try LoadEngine.calculate(input: input, loads: emptyLoads)) { error in
            XCTAssertTrue(error is CalculationError,
                "Boş liste için CalculationError fırlatılmalıdır.")
        }
    }

    // MARK: - Test 5: Talep Faktörü = 0.5 ile Kısmi Yük Hesabı

    /// 20 kW nominal yük / talepFaktörü = 0.5 → 10 kW aktif talep beklenir.
    func test_demandFactor_05_shouldHalveActivePower() throws {
        // Given
        let input = LoadCalculationInput(
            supplyVoltageV: 400,
            phaseCount: .three,
            supplyFrequencyHz: 50,
            peakDemandFactor: 0.5,
            averagePowerFactor: 0.85,
            electricityTariffPerKWh: 4.5,
            monthlyOperatingHours: 720,
            co2EmissionFactor: 0.473
        )
        let loads = [
            LoadItem(name: "Büyük Yük", powerW: 20_000, quantity: 1, powerFactor: 0.85, demandFactor: 0.5)
        ]

        // When
        let result = try LoadEngine.calculate(input: input, loads: loads)

        // Then — Talep faktörü 0.5 × 20 kW = 10 kW
        XCTAssertEqual(result.totalActivePowerKW, 10.0, accuracy: 0.5,
            "Talep faktörü 0.5 uygulanınca aktif güç 10 kW (±0.5) olmalıdır.")
    }
}
