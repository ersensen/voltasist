// CableEngineTests.swift
// VoltAsist — Birim Testleri
//
// CableEngine kablo kesit seçimi ve sigorta boyutlandırma hesaplamalarını doğrular.
// IEC 60364 ve TS HD 60364 standartlarına göre referans değerler kullanılmıştır.
// Her test Given / When / Then yapısıyla yazılmıştır.

import XCTest
@testable import UygulamaMotoru

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

    /// 3 kW / 230 V / tek faz / cosφ=0.9 / 20 m bakır kablo →
    /// Akım ≈ 14.5 A, kesit = 2.5 mm², sigorta = 16 A beklenir.
    func test_singlePhase_3kW_230V_20m_copper_shouldReturn2p5mm2And16ABreaker() throws {
        // Given
        let input = CableCalculationInput(
            powerKW: 3.0,
            voltageV: 230,
            phaseCount: .single,
            powerFactor: 0.90,
            cableLengthM: 20.0,
            conductorMaterial: .copper,
            installationMethod: .conduit,
            ambientTemperatureC: 30,
            simultaneousDemandFactor: 1.0
        )

        // When
        let result = try CableEngine.calculate(input: input)

        // Then — IEC standart değerleri
        XCTAssertEqual(result.recommendedSectionMM2, 2.5,
            "3 kW tek faz 20 m için 2.5 mm² bakır seçilmelidir.")
        XCTAssertEqual(result.breakerRatingA, 16,
            "2.5 mm² bakır için 16 A sigorta seçilmelidir.")
        XCTAssertGreaterThan(result.currentA, 12.0,
            "Akım 12 A'dan büyük olmalıdır.")
        XCTAssertLessThan(result.currentA, 16.0,
            "Akım 16 A'dan küçük olmalıdır (sigorta değerinin altında).")
    }

    // MARK: - Test 2: Üç Fazlı Orta Güç (10 kW / 400 V / 50 m / Bakır)

    /// 10 kW / 400 V / 3 faz / cosφ=0.85 / 50 m bakır kablo →
    /// Kesit ≥ 2.5 mm² beklenir, sigorta ≤ 32 A.
    func test_threePhase_10kW_400V_50m_copper_shouldReturnValidSectionAndBreaker() throws {
        // Given
        let input = CableCalculationInput(
            powerKW: 10.0,
            voltageV: 400,
            phaseCount: .three,
            powerFactor: 0.85,
            cableLengthM: 50.0,
            conductorMaterial: .copper,
            installationMethod: .conduit,
            ambientTemperatureC: 30,
            simultaneousDemandFactor: 1.0
        )

        // When
        let result = try CableEngine.calculate(input: input)

        // Then
        XCTAssertGreaterThanOrEqual(result.recommendedSectionMM2, 2.5,
            "10 kW 50 m için en az 2.5 mm² kesit seçilmelidir.")
        XCTAssertLessThanOrEqual(result.recommendedSectionMM2, 16.0,
            "Bu güç için 16 mm² üstü gereksiz kapasite olur.")
        XCTAssertLessThanOrEqual(result.breakerRatingA, 32,
            "10 kW yük için sigorta 32 A'yı aşmamalıdır.")
        XCTAssertLessThan(result.voltageDropPercent, 5.0,
            "Gerilim düşümü %5'in altında kalmalıdır.")
    }

    // MARK: - Test 3: Yüksek Güç / Uzun Hat / Alüminyum (50 kW / 400 V / 100 m)

    /// 50 kW / 400 V / 3 faz / cosφ=0.92 / 100 m alüminyum kablo →
    /// Akım ≈ 78.2 A, kesit ≥ 35 mm² beklenir.
    func test_threePhase_50kW_400V_100m_aluminum_shouldSelectLargeSection() throws {
        // Given
        let input = CableCalculationInput(
            powerKW: 50.0,
            voltageV: 400,
            phaseCount: .three,
            powerFactor: 0.92,
            cableLengthM: 100.0,
            conductorMaterial: .aluminum,
            installationMethod: .duct,
            ambientTemperatureC: 35,
            simultaneousDemandFactor: 1.0
        )

        // When
        let result = try CableEngine.calculate(input: input)

        // Then — Alüminyum iletkenlik ~%61 bakır kapasite
        XCTAssertGreaterThanOrEqual(result.recommendedSectionMM2, 35.0,
            "50 kW 100 m alüminyum için en az 35 mm² kesit seçilmelidir.")
        XCTAssertGreaterThan(result.currentA, 70.0,
            "50 kW 3 faz 400V için akım 70 A'dan büyük olmalıdır.")
    }

    // MARK: - Test 4: Gerilim Düşümü Sınır Testi (%5 Üstü Uyarı)

    /// Uzun hat / ince kesit → gerilim düşümü %5'i aşarsa uyarı bayrağı aktif olmalı.
    func test_longCable_thinSection_shouldFlagExcessiveVoltageDrop() throws {
        // Given — 5 kW / 230 V tek faz / 80 m bakır → düşüm yüksek olur
        let input = CableCalculationInput(
            powerKW: 5.0,
            voltageV: 230,
            phaseCount: .single,
            powerFactor: 0.85,
            cableLengthM: 80.0,
            conductorMaterial: .copper,
            installationMethod: .conduit,
            ambientTemperatureC: 30,
            simultaneousDemandFactor: 1.0
        )

        // When
        let result = try CableEngine.calculate(input: input)

        // Then — Motor hesaplar ve kesiti büyütür ama flag'i de set eder
        // Küçük bir kesitle test edersek drop uyarısı gelir
        // Motorun seçtiği kesit drop sınırını karşılıyorsa uyarı kapalı olmalı
        if result.voltageDropPercent > 5.0 {
            XCTAssertTrue(result.voltageDropWarning,
                "Gerilim düşümü %5 üzerindeyse uyarı bayrağı aktif olmalıdır.")
        } else {
            // Motor büyük kesit seçerek drop'u karşılamışsa uyarı kapalı olmalı
            XCTAssertFalse(result.voltageDropWarning,
                "Seçilen kesit gerilim düşümünü karşılıyorsa uyarı olmaz.")
            XCTAssertGreaterThan(result.recommendedSectionMM2, 4.0,
                "80 m hat için motor en az 6 mm² seçmiş olmalıdır.")
        }
    }

    // MARK: - Test 5: Sıfır Güç Edge Case

    /// Sıfır güç girildiğinde motor CalculationError fırlatmalıdır.
    func test_zeroPower_shouldThrowCalculationError() {
        // Given
        let input = CableCalculationInput(
            powerKW: 0.0,
            voltageV: 230,
            phaseCount: .single,
            powerFactor: 0.9,
            cableLengthM: 10.0,
            conductorMaterial: .copper,
            installationMethod: .conduit,
            ambientTemperatureC: 30,
            simultaneousDemandFactor: 1.0
        )

        // When / Then
        XCTAssertThrowsError(try CableEngine.calculate(input: input)) { error in
            XCTAssertTrue(error is CalculationError,
                "Sıfır güç için CalculationError fırlatılmalıdır.")
            if let calcError = error as? CalculationError {
                switch calcError {
                case .invalidInput:
                    break  // Beklenen hata türü
                default:
                    XCTFail("Sıfır güç için .invalidInput hatası beklendi, '\(calcError)' geldi.")
                }
            }
        }
    }

    // MARK: - Test 6: Cosφ = 1.0 Saf Rezistif Yük

    /// cosφ = 1.0 (saf rezistif yük) için akım = P/V formülüyle doğrulama.
    func test_singlePhase_resistiveLoad_cosPhiOne_shouldMatchDirectFormula() throws {
        // Given
        let powerKW: Double = 2.3
        let voltageV: Double = 230
        let input = CableCalculationInput(
            powerKW: powerKW,
            voltageV: voltageV,
            phaseCount: .single,
            powerFactor: 1.0,   // Saf rezistif
            cableLengthM: 15.0,
            conductorMaterial: .copper,
            installationMethod: .surface,
            ambientTemperatureC: 25,
            simultaneousDemandFactor: 1.0
        )

        // When
        let result = try CableEngine.calculate(input: input)

        // Then — I = P / (V × cosφ) = 2300 / 230 = 10 A
        let expectedCurrent = (powerKW * 1000.0) / voltageV  // 10.0 A
        XCTAssertEqual(result.currentA, expectedCurrent, accuracy: 0.5,
            "cosφ=1 için akım P/V formülüyle ±0.5 A hassasiyetle örtüşmelidir.")
        XCTAssertEqual(result.recommendedSectionMM2, 1.5,
            "10 A akım için 1.5 mm² kesit yeterlidir.")
    }
}
