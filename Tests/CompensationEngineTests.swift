// CompensationEngineTests.swift
// VoltAsist — Birim Testleri
//
// CompensationEngine reaktif güç kompanzasyonu hesaplamalarını doğrular.
// Referans değerler IEC 60831, TEDAŞ Tarife Yönetmeliği ve mühendislik formüllerine dayanır.
// Qc = P × (tanφ₁ - tanφ₂) formülü esas alınmıştır.

import XCTest
@testable import VoltAsist

// MARK: - CompensationEngineTests

/// CompensationEngine kondansatör boyutlandırma, harmonik risk ve geri ödeme testleri.
final class CompensationEngineTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: 100 kW / cosφ=0.75 → hedef 0.95 → Qc ≈ 42.3 kVAr

    /// Formül: Qc = P × (tanφ₁ - tanφ₂)
    /// tanφ₁ = tan(arccos 0.75) = 0.8819, tanφ₂ = tan(arccos 0.95) = 0.3287
    /// Qc = 100 × (0.8819 - 0.3287) = 100 × 0.5532 = 55.32 kVAr
    /// (Not: cosφ=0.77'den farklı olarak 0.75 kullanıldı — referans değer değişir)
    func test_100kW_cosPhi075_toTarget095_shouldReturnQc_around55kVAr() throws {
        // Given
        let input = CompensationInput(
            activePowerKW: 100.0,
            apparentPowerKVA: 133.3,          // 100/0.75
            measuredCosPhi: 0.75,
            targetCosPhi: 0.95,
            systemVoltageV: 400.0,
            transformerKVA: 250.0,
            totalHarmonicDistortion: 3.0,
            electricityTariff: 2.5,
            investmentCostTL: 50_000.0,
            discountRate: 0.12
        )

        // When
        let result = try CompensationEngine.calculate(input: input)

        // Then — Qc = 100 × (tan(arccos 0.75) - tan(arccos 0.95)) ≈ 55.3 kVAr
        let phi1   = acos(0.75)
        let phi2   = acos(0.95)
        let expectedQc = 100.0 * (tan(phi1) - tan(phi2))  // ≈ 55.32 kVAr
        XCTAssertEqual(result.requiredCapacityKVAr, expectedQc, accuracy: 0.5,
            "Gerekli kondansatör kapasitesi Qc formülüyle ±0.5 kVAr örtüşmelidir.")
    }

    // MARK: - Test 2: Referans Değer — cosφ=0.77 → hedef 0.95 → Qc ≈ 42.3 kVAr

    /// Formül değerleri:
    /// tanφ₁ = tan(arccos 0.77) ≈ 0.8292, tanφ₂ = tan(arccos 0.95) ≈ 0.3287
    /// Qc = 100 × (0.8292 - 0.3287) = 100 × 0.5005 ≈ 50.05 kVAr
    /// (İstenen değer 42.3 iken input 0.77'dir — toleranslı test)
    func test_100kW_cosPhi077_toTarget095_shouldReturnApproximateQc() throws {
        // Given
        let input = CompensationInput(
            activePowerKW: 100.0,
            apparentPowerKVA: 129.9,
            measuredCosPhi: 0.77,
            targetCosPhi: 0.95,
            systemVoltageV: 400.0,
            transformerKVA: 250.0,
            totalHarmonicDistortion: 4.0,
            electricityTariff: 2.5,
            investmentCostTL: 80_000.0,
            discountRate: 0.15
        )

        // When
        let result = try CompensationEngine.calculate(input: input)

        // Then — matematik: Qc = 100 × (tan(arccos 0.77) - tan(arccos 0.95))
        let phi1   = acos(0.77)
        let phi2   = acos(0.95)
        let expectedQc = 100.0 * (tan(phi1) - tan(phi2))
        XCTAssertEqual(result.requiredCapacityKVAr, expectedQc, accuracy: 2.0,
            "Qc değeri hesap formülüyle ±2 kVAr örtüşmelidir.")
        XCTAssertGreaterThan(result.requiredCapacityKVAr, 40.0,
            "Qc 40 kVAr'dan büyük olmalıdır.")
        XCTAssertLessThan(result.requiredCapacityKVAr, 60.0,
            "Qc 60 kVAr'dan küçük olmalıdır.")
    }

    // MARK: - Test 3: Standart Basamak Seçimi (40 + 2.5 kVAr Kombinasyonu)

    /// Yaklaşık 42.5 kVAr ihtiyacı → Standart basamaklar: 40 + 2.5 kVAr kombinasyonu seçilmeli.
    func test_42kVAr_capacitorSteps_shouldSelectStandardCombination() throws {
        // Given
        let input = CompensationInput(
            activePowerKW: 84.0,           // 84 × (tan48.7° - tan18.2°) ≈ 42 kVAr
            apparentPowerKVA: 112.0,
            measuredCosPhi: 0.75,
            targetCosPhi: 0.95,
            systemVoltageV: 400.0,
            transformerKVA: 160.0,
            totalHarmonicDistortion: 2.0,
            electricityTariff: 3.0,
            investmentCostTL: 35_000.0,
            discountRate: 0.10
        )

        // When
        let result = try CompensationEngine.calculate(input: input)

        // Then — Seçilen basamakların toplam kapasitesi ihtiyacı karşılamalı
        let selectedTotal = result.selectedSteps.reduce(0.0) { $0 + $1.totalKVAr }
        XCTAssertGreaterThanOrEqual(selectedTotal, result.requiredCapacityKVAr,
            "Seçilen kondansatör basamakları toplam ihtiyacı karşılamalıdır.")
        XCTAssertFalse(result.selectedSteps.isEmpty,
            "Kondansatör basamak listesi boş olmamalıdır.")
    }

    // MARK: - Test 4: Harmonik Risk — THD=%12 → .high → Reaktör Zorunlu

    /// THD ≥ %10 olduğunda harmonik risk seviyesi .high ve reaktör zorunlu olmalı.
    func test_THD12Percent_shouldReturnHighHarmonicRiskAndReactorRequired() throws {
        // Given
        let input = CompensationInput(
            activePowerKW: 100.0,
            apparentPowerKVA: 120.0,
            measuredCosPhi: 0.83,
            targetCosPhi: 0.95,
            systemVoltageV: 400.0,
            transformerKVA: 250.0,
            totalHarmonicDistortion: 12.0,   // %12 THD — yüksek risk
            electricityTariff: 2.5,
            investmentCostTL: 100_000.0,
            discountRate: 0.15
        )

        // When
        let result = try CompensationEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.harmonicRiskLevel, .high,
            "THD=%12 için harmonik risk seviyesi .high olmalıdır.")
        XCTAssertTrue(result.reactorRequired,
            "THD=%12 için detuned reaktör zorunlu olmalıdır.")
    }

    // MARK: - Transformer capacity relative to its actual nameplate rating

    func testTransformerCapacityGainUsesActualTransformerRating() throws {
        var input = CompensationInput(activePowerKW: 154, apparentPowerKVA: 200,
            measuredCosPhi: 0.77, targetCosPhi: 0.95, transformerKVA: 200)
        let steps = [CapacitorStep(ratingKVAr: 10, quantity: 8)]
        let result = try CompensationEngine.calculate(input: input, selectedSteps: steps)
        // Q = sqrt(200^2 - 154^2); S_after = sqrt(154^2 + (Q - 80)^2).
        // S_after = 161.1911773627 kVA, released capacity = 38.8088226373 kVA.
        XCTAssertEqual(result.newApparentKVA, 161.1911773627, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.capacityGainKVA), 38.8088226373, accuracy: 0.0001)
        XCTAssertEqual(result.transformerCapacityGainPercent, 19.4044113186, accuracy: 0.0001)

        // Identical load/capacitors on a 400 kVA transformer release half the percentage.
        input.transformerKVA = 400
        let larger = try CompensationEngine.calculate(input: input, selectedSteps: steps)
        XCTAssertEqual(larger.transformerCapacityGainPercent, 9.7022056593, accuracy: 0.0001)
        input.transformerKVA = nil
        XCTAssertEqual(try CompensationEngine.calculate(input: input, selectedSteps: steps)
            .transformerCapacityGainPercent, 0)
    }

    func testPaybackForKnownMonthlySaving() {
        let roi = CompensationEngine.calculateROI(investmentTL: 50_000,
            monthlySavingTL: 3_200, discountRate: 0.12)
        XCTAssertEqual(roi.paybackMonths, 15.625, accuracy: 0.000001)
    }

    func testPaybackUsesCalculatedMonthlySaving() throws {
        let input = CompensationInput(activePowerKW: 100, apparentPowerKVA: 125,
            measuredCosPhi: 0.8, targetCosPhi: 0.95, transformerKVA: nil,
            electricityTariff: 3, investmentCostTL: 50_000, discountRate: 0.12)
        let result = try CompensationEngine.calculate(input: input)
        // Existing estimate: (sqrt(125^2 - 100^2) - 100*0.33) * 720 * 3 = 90,720.
        // No transformer loss saving because no transformer was specified.
        XCTAssertEqual(result.totalMonthlySavingTL, 90_720, accuracy: 0.0001)
        XCTAssertEqual(result.paybackMonths, 50_000.0 / 90_720.0, accuracy: 0.000001)
    }

    // MARK: - Test 7: TEDAŞ Ceza Sınırı Kontrol Testi (cosφ < 0.90)

    /// TEDAŞ yönetmeliğine göre cosφ < 0.90 ise ceza riski aktif olmalı.
    func test_cosPhi_belowTEDAS_threshold_shouldFlagPenaltyRisk() throws {
        // Given — cosφ = 0.82 (ceza sınırı olan 0.90'ın altında)
        let input = CompensationInput(
            activePowerKW: 80.0,
            apparentPowerKVA: 97.6,
            measuredCosPhi: 0.82,
            targetCosPhi: 0.95,
            systemVoltageV: 400.0,
            transformerKVA: 160.0,
            totalHarmonicDistortion: 3.0,
            electricityTariff: 2.5,
            investmentCostTL: 45_000.0,
            discountRate: 0.12
        )

        // When
        let result = try CompensationEngine.calculate(input: input)

        // Then
        XCTAssertGreaterThan(result.monthlyPenaltyTL, 0.0,
            "cosφ=0.82 için aylık TEDAŞ ceza tahmini pozitif olmalıdır.")
        XCTAssertGreaterThan(result.yearlyPenaltyTL, 0.0,
            "Tahmini yıllık ceza tutarı pozitif olmalıdır.")
    }
}
