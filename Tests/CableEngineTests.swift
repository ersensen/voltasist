// CableEngineTests.swift
// VoltAsist — Birim Testleri
//
// CableEngine kablo kesit seçimi ve sigorta boyutlandırma hesaplamalarını doğrular.
// IEC 60364-5-52 standardına göre referans değerler kullanılmıştır.
// Her test Given / When / Then yapısıyla yazılmıştır.

import XCTest
@testable import VoltAsist

// MARK: - CableEngineTests

/// CableEngine'in kablo seçimi, akım ve gerilim düşümü hesaplarını doğrulayan test sınıfı.
final class CableEngineTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: Tek Fazlı Temel Hesaplama (3 kW / 230 V / 20 m / Bakır)

    /// 3 kW / 230 V / tek faz / cosφ=0.9 / 20 m bakır kablo, yüzey montaj →
    /// Akım ≈ 14.49 A, kesit = 2.5 mm², sigorta = 16 A beklenir.
    func test_singlePhase_3kW_230V_20m_copper_shouldReturn2p5mm2And16ABreaker() {
        // Given
        let input = CableCalculationInput(
            powerKW: 3.0,
            voltageV: 230,
            phaseCount: 1,
            lengthM: 20.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 0.90,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When
        let result = CableEngine.calculate(input: input)

        // Then — IEC standart değerleri
        XCTAssertEqual(result.recommendedSectionMM2, 2.5,
            "3 kW tek faz 20 m için 2.5 mm² bakır seçilmelidir.")
        XCTAssertEqual(result.recommendedFuseA, 16,
            "2.5 mm² bakır için 16 A sigorta seçilmelidir.")
        XCTAssertGreaterThan(result.currentA, 12.0,
            "Akım 12 A'dan büyük olmalıdır.")
        XCTAssertLessThan(result.currentA, 16.0,
            "Akım 16 A'dan küçük olmalıdır (sigorta değerinin altında).")
        XCTAssertTrue(result.isVoltageDropWithinLimit,
            "Bu senaryoda gerilim düşümü hedef sınırın içinde kalmalıdır.")
    }

    // MARK: - Test 2: Üç Fazlı Orta Güç (10 kW / 400 V / 50 m / Bakır)

    /// 10 kW / 400 V / 3 faz / cosφ=0.85 / 50 m bakır kablo →
    /// Kesit ≥ 2.5 mm² beklenir, gerilim düşümü %5'in altında kalmalıdır.
    func test_threePhase_10kW_400V_50m_copper_shouldReturnValidSectionAndBreaker() {
        // Given
        let input = CableCalculationInput(
            powerKW: 10.0,
            voltageV: 400,
            phaseCount: 3,
            lengthM: 50.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 0.85,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When
        let result = CableEngine.calculate(input: input)

        // Then
        XCTAssertGreaterThanOrEqual(result.recommendedSectionMM2, 2.5,
            "10 kW 50 m için en az 2.5 mm² kesit seçilmelidir.")
        XCTAssertLessThanOrEqual(result.recommendedSectionMM2, 16.0,
            "Bu güç için 16 mm² üstü gereksiz kapasite olur.")
        XCTAssertLessThanOrEqual(result.recommendedFuseA, 32,
            "10 kW yük için sigorta 32 A'yı aşmamalıdır.")
        XCTAssertLessThan(result.voltageDrop, 5.0,
            "Gerilim düşümü %5'in altında kalmalıdır.")
    }

    // MARK: - Test 3: Yüksek Güç / Uzun Hat / Alüminyum (50 kW / 400 V / 100 m)

    /// 50 kW / 400 V / 3 faz / cosφ=0.92 / 100 m alüminyum kablo →
    /// Akım ≈ 78.2 A, kesit ≥ 35 mm² beklenir.
    func test_threePhase_50kW_400V_100m_aluminum_shouldSelectLargeSection() {
        // Given
        let input = CableCalculationInput(
            powerKW: 50.0,
            voltageV: 400,
            phaseCount: 3,
            lengthM: 100.0,
            conductorType: .aluminum,
            installationType: .cableTray,
            cosPhi: 0.92,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 35
        )

        // When
        let result = CableEngine.calculate(input: input)

        // Then — Alüminyum iletkenlik ~%61 bakır kapasite
        XCTAssertGreaterThanOrEqual(result.recommendedSectionMM2, 35.0,
            "50 kW 100 m alüminyum için en az 35 mm² kesit seçilmelidir.")
        XCTAssertGreaterThan(result.currentA, 70.0,
            "50 kW 3 faz 400V için akım 70 A'dan büyük olmalıdır.")
    }

    // MARK: - Test 4: Manuel Küçük Kesit → Gerilim Düşümü Sınırı Aşılmalı

    /// 5 kW / 230 V tek faz / 80 m bakır, manuel olarak 1.5 mm² seçilirse
    /// gerilim düşümü hedef sınırı (%3) aşmalı ve uyarı mesajı "aşıldı" içermelidir.
    func test_manualSection_tooSmall_shouldExceedVoltageDropLimit() {
        // Given
        let input = CableCalculationInput(
            powerKW: 5.0,
            voltageV: 230,
            phaseCount: 1,
            lengthM: 80.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 0.85,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When
        let result = CableEngine.calculate(input: input, manualSection: 1.5)

        // Then
        XCTAssertFalse(result.isVoltageDropWithinLimit,
            "1.5 mm² ile 80 m hat için gerilim düşümü hedef sınırı aşmalıdır.")
        XCTAssertNotNil(result.warningMessage)
        XCTAssertTrue(result.warningMessage?.contains("aşıldı") ?? false,
            "Uyarı mesajı sınırın aşıldığını belirtmelidir.")
    }

    // MARK: - Test 5: Manuel Yeterli Kesit → Gerilim Düşümü Sınırı İçinde Kalmalı

    /// Aynı senaryoda manuel olarak yeterince büyük (25 mm²) kesit seçilirse
    /// gerilim düşümü hedef sınırın içinde kalmalı ve uyarı mesajı "içinde kalıyor" içermelidir.
    func test_manualSection_adequate_shouldStayWithinVoltageDropLimit() {
        // Given
        let input = CableCalculationInput(
            powerKW: 5.0,
            voltageV: 230,
            phaseCount: 1,
            lengthM: 80.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 0.85,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When
        let result = CableEngine.calculate(input: input, manualSection: 25.0)

        // Then
        XCTAssertTrue(result.isVoltageDropWithinLimit,
            "25 mm² ile 80 m hat için gerilim düşümü hedef sınırı içinde kalmalıdır.")
        XCTAssertNotNil(result.warningMessage)
        XCTAssertTrue(result.warningMessage?.contains("içinde kalıyor") ?? false,
            "Uyarı mesajı sınırın içinde kalındığını belirtmelidir.")
    }

    // MARK: - Test 6: Sıfır Güç Edge Case

    /// CableEngine.calculate throws değildir — sıfır güç girildiğinde çökmeden
    /// akım 0 A, kesit standart minimum (1.5 mm²) ve sigorta minimum (6 A) dönmelidir.
    func test_zeroPower_shouldReturnMinimumSectionWithoutCrashing() {
        // Given
        let input = CableCalculationInput(
            powerKW: 0.0,
            voltageV: 230,
            phaseCount: 1,
            lengthM: 10.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 0.9,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When
        let result = CableEngine.calculate(input: input)

        // Then
        XCTAssertEqual(result.currentA, 0.0, accuracy: 0.001,
            "Sıfır güç için akım 0 A olmalıdır.")
        XCTAssertEqual(result.recommendedSectionMM2, 1.5,
            "Sıfır güç için standart serinin en küçük kesiti (1.5 mm²) seçilmelidir.")
        XCTAssertEqual(result.recommendedFuseA, 6,
            "Sıfır güç için standart serinin en küçük sigortası (6 A) seçilmelidir.")
        XCTAssertTrue(result.isVoltageDropWithinLimit,
            "Sıfır akımda gerilim düşümü olmayacağından sınır içinde kalmalıdır.")
    }

    // MARK: - Test 7: Cosφ = 1.0 Saf Rezistif Yük

    /// cosφ = 1.0 (saf rezistif yük) için akım = P/V formülüyle doğrulama.
    func test_singlePhase_resistiveLoad_cosPhiOne_shouldMatchDirectFormula() {
        // Given
        let powerKW: Double = 2.3
        let voltageV: Double = 230
        let input = CableCalculationInput(
            powerKW: powerKW,
            voltageV: voltageV,
            phaseCount: 1,
            lengthM: 15.0,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: 1.0,   // Saf rezistif
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 25
        )

        // When
        let result = CableEngine.calculate(input: input)

        // Then — I = P / (V × cosφ) = 2300 / 230 = 10 A
        let expectedCurrent = (powerKW * 1000.0) / voltageV  // 10.0 A
        XCTAssertEqual(result.currentA, expectedCurrent, accuracy: 0.5,
            "cosφ=1 için akım P/V formülüyle ±0.5 A hassasiyetle örtüşmelidir.")
        XCTAssertEqual(result.recommendedSectionMM2, 1.5,
            "10 A akım için 1.5 mm² kesit yeterlidir.")
    }

    // MARK: - Test 8: IEC 60364-5-52 Ek G Gerilim Düşümü Formülü — Elle Hesaplanmış Referans

    /// Bilinen senaryo: 3 faz, 400 V, 50 m, I=35 A, cosφ=0.8 (→ sinφ=0.6), bakır, kesit manuel 10 mm².
    ///
    /// Elle hesap (IEC 60364-5-52 Ek G):
    ///   ΔU = b × I × L × (ρ1/A × cosφ + λ × sinφ)
    ///   b = √3, ρ1(bakır) = 0.0225 Ω·mm²/m, λ = 0.00008 Ω/m
    ///   ρ1/A × cosφ = (0.0225/10) × 0.8 = 0.0018
    ///   λ × sinφ    = 0.00008 × 0.6     = 0.000048
    ///   ΔU = 1.7320508 × 35 × 50 × 0.001848 ≈ 5.6015 V
    ///   ΔU% = 5.6015 / 400 × 100 ≈ 1.4004 %
    func test_threePhase_400V_50m_35A_cosPhi08_copper10mm2_shouldMatchIECAnnexGFormula() {
        // Given — I = P / (√3 × V × cosφ) = 35 A olacak şekilde güç türetilir (temel akım formülü,
        // test edilen gerilim düşümü Ek G formülünden bağımsızdır).
        let targetCurrent = 35.0
        let voltageV = 400.0
        let cosPhi = 0.8
        let lengthM = 50.0
        let powerKW = (sqrt(3.0) * voltageV * cosPhi * targetCurrent) / 1000.0

        let input = CableCalculationInput(
            powerKW: powerKW,
            voltageV: voltageV,
            phaseCount: 3,
            lengthM: lengthM,
            conductorType: .copper,
            installationType: .surface,
            cosPhi: cosPhi,
            targetVoltageDrop: 3.0,
            groupCount: 1,
            ambientTemperature: 30
        )

        // When — kesit 10 mm² olarak sabitleniyor (Annex G formülünün kendisini izole test etmek için)
        let result = CableEngine.calculate(input: input, manualSection: 10.0)

        // Then
        XCTAssertEqual(result.currentA, targetCurrent, accuracy: 0.01,
            "Türetilen güç ile akım tam olarak 35 A olmalıdır.")
        XCTAssertEqual(result.recommendedSectionMM2, 10.0,
            "Manuel seçilen kesit 10 mm² olarak korunmalıdır.")

        let expectedDropV = 5.601452
        let expectedDropPercent = 1.400363

        XCTAssertEqual(result.voltageDropV, expectedDropV, accuracy: 0.001,
            "Ek G formülüyle elle hesaplanan gerilim düşümü ±0.001 V hassasiyetle örtüşmelidir.")
        XCTAssertEqual(result.voltageDrop, expectedDropPercent, accuracy: 0.001,
            "Ek G formülüyle elle hesaplanan gerilim düşümü yüzdesi ±0.001 hassasiyetle örtüşmelidir.")
        XCTAssertTrue(result.isVoltageDropWithinLimit,
            "%1.40 düşüm, %3 hedef sınırın içinde kalmalıdır.")
    }
}
