// CableEngine.swift
// VoltAsist
//
// IEC 60364 standardına uygun kablo kesiti ve gerilim düşümü hesaplama motoru.
// Bakır/Alüminyum iletken, tek/üç faz, montaj tipi derating katsayıları dahil.

import Foundation

// MARK: - Kablo Hesaplama Motoru

/// IEC 60364-5-52 standardına uygun kablo boyutlandırma motoru
struct CableEngine {

    // MARK: Sabitler

    /// Standart kablo kesit serileri (mm²) — IEC 60228
    static let standardSections: [Double] = [
        1.5, 2.5, 4.0, 6.0, 10.0, 16.0, 25.0,
        35.0, 50.0, 70.0, 95.0, 120.0, 150.0, 185.0, 240.0
    ]

    /// Standart sigorta değerleri (A) — IEC 60898 / EN 60947
    static let standardFuseRatings: [Int] = [
        6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400
    ]

    /// Her standart kesite karşılık gelen akım taşıma kapasitesi (A)
    /// Sıva üstü (B2 montaj yöntemi), tek nükleus NYM, 30°C ortam — IEC 60364-5-52 Tablo B.52.4
    static let currentCapacityTable: [Double: Double] = [
        1.5:  15.5,
        2.5:  21.0,
        4.0:  28.0,
        6.0:  36.0,
        10.0: 50.0,
        16.0: 68.0,
        25.0: 89.0,
        35.0: 110.0,
        50.0: 134.0,
        70.0: 171.0,
        95.0: 207.0,
        120.0: 239.0,
        150.0: 272.0,
        185.0: 310.0,
        240.0: 365.0
    ]

    /// 3 aktif iletken (üç fazlı) için akım taşıma kapasitesi (A)
    /// B2 montaj yöntemi, NYM çok damarlı, PVC, bakır, 30°C — IEC 60364-5-52 Tablo A.52-4
    static let currentCapacityTable3P: [Double: Double] = [
        1.5:   13.0,
        2.5:   17.5,
        4.0:   23.0,
        6.0:   29.5,
        10.0:  40.0,
        16.0:  54.0,
        25.0:  73.0,
        35.0:  89.0,
        50.0:  108.0,
        70.0:  136.0,
        95.0:  164.0,
        120.0: 188.0,
        150.0: 216.0,
        185.0: 245.0,
        240.0: 286.0
    ]

    // MARK: Ana Hesaplama

    /// Kablo kesiti ve gerilim düşümü hesapla
    /// - Parameters:
    ///   - input: Hesaplama girdi parametreleri
    ///   - manualSection: Kullanıcı tarafından manuel seçilen kesit değeri (opsiyonel)
    /// - Returns: Hesaplama sonuçları
    static func calculate(input: CableCalculationInput, manualSection: Double? = nil) -> CableCalculationResult {

        // --- 1. Akım Hesabı ---
        // Tek faz: I = P / (V × cos φ)
        // Üç faz: I = P / (√3 × V × cos φ)
        let powerW = input.powerKW * 1000.0
        let current: Double
        if input.phaseCount == 1 {
            current = powerW / (input.voltageV * input.cosPhi)
        } else {
            current = powerW / (sqrt(3.0) * input.voltageV * input.cosPhi)
        }

        // --- 2. Termal Kesit (Akım Kapasitesi) ---
        // Derating katsayısı ve gruplama katsayısı (Cg) uygulanmış gerekli kapasite
        let deratingFactor = input.installationType.derating * CableEngine.groupingFactor(cableCount: input.groupCount)
        let requiredCapacity = current / deratingFactor

        // Faz sayısına göre IEC 60364-5-52 Tablo A.52-4 sütunu seç
        // Tek faz → 2 aktif iletken; üç faz → 3 aktif iletken (%13-15 daha düşük kapasite)
        let capacityTable = input.phaseCount == 1
            ? CableEngine.currentCapacityTable
            : CableEngine.currentCapacityTable3P

        // Akım kapasitesinden minimum kesit
        let sectionByCapacity = minimumSectionForCurrent(requiredCapacity, table: capacityTable)

        // --- 3. Gerilim Düşümü Kesiti ---
        // Gerilim düşümü formülü:
        //   Tek faz: ΔU% = (2 × ρ × L × I × 100) / (A × V)
        //   Üç faz: ΔU% = (√3 × ρ × L × I × 100) / (A × V)
        // A = (2 × ρ × L × I × 100) / (ΔU% × V)  — tek faz için
        let resistivity = 1.0 / input.conductorType.conductivity  // Ω·mm²/m
        let maxDropVolts = input.voltageV * input.targetVoltageDrop / 100.0

        let sectionByVoltageDrop: Double
        if input.phaseCount == 1 {
            // A = (2 × ρ × L × I) / ΔUmax(V)
            sectionByVoltageDrop = (2.0 * resistivity * input.lengthM * current) / maxDropVolts
        } else {
            // A = (√3 × ρ × L × I) / ΔUmax(V)
            sectionByVoltageDrop = (sqrt(3.0) * resistivity * input.lengthM * current) / maxDropVolts
        }

        // --- 4. Gerekli Minimum Kesit (İki Kriter Maksimumu) ---
        let requiredSection = max(sectionByCapacity, sectionByVoltageDrop)

        // --- 5. Standart Kesit Seçimi (Yukarı Yuvarlama veya Manuel) ---
        let recommendedSection: Double
        if let manual = manualSection {
            recommendedSection = manual
        } else {
            recommendedSection = nextStandardSection(for: requiredSection)
        }

        // --- 6. Seçilen Kesitle Gerilim Düşümü Doğrulaması ---
        let actualVoltageDrop: Double
        if input.phaseCount == 1 {
            actualVoltageDrop = (2.0 * resistivity * input.lengthM * current) / recommendedSection
        } else {
            actualVoltageDrop = (sqrt(3.0) * resistivity * input.lengthM * current) / recommendedSection
        }
        let actualVoltageDropPercent = (actualVoltageDrop / input.voltageV) * 100.0
        let isVoltageDropOK = actualVoltageDropPercent <= input.targetVoltageDrop

        // --- 7. Sigorta Seçimi ---
        // IEC 60364-4-43 md.433.1: Ib ≤ In ≤ Iz — sigorta yük akımından küçük olmaz
        // (1.25 çarpanı standartta yok; In > Iz ise aşırı yük koruması sağlanamaz)
        let selectedFuse = nextStandardFuse(for: current)

        // --- 8. Seçilen Kesitin Akım Kapasitesi ---
        let cableCapacity = (capacityTable[recommendedSection] ?? 0.0) * deratingFactor

        // --- 9. Uyarı Mesajı ---
        var warning: String?

        if actualVoltageDropPercent > 5.0 {
            warning = "⚠️ Gerilim düşümü %\(String(format: "%.1f", actualVoltageDropPercent)) — IEC sınırının üzerinde. Hat uzunluğunu veya kesiti gözden geçirin."
        } else if actualVoltageDropPercent > input.targetVoltageDrop {
            warning = "⚠️ Gerilim düşümü %\(String(format: "%.1f", actualVoltageDropPercent)) — hedef değerin üzerinde."
        }

        if input.conductorType == .aluminum && recommendedSection < 16.0 {
            let aluminumWarning = "⚡ Alüminyum iletken için minimum kesit 16 mm² önerilir (IEC korozyona karşı)."
            warning = warning != nil ? "\(warning!) \(aluminumWarning)" : aluminumWarning
        }

        if cableCapacity < current * 1.0 {
            let overloadWarning = "🔥 Seçilen kesit akım kapasitesi yetersiz — bir üst kesiti tercih edin."
            warning = warning != nil ? "\(warning!) \(overloadWarning)" : overloadWarning
        }

        return CableCalculationResult(
            currentA: current,
            requiredSectionMM2: requiredSection,
            recommendedSectionMM2: recommendedSection,
            voltageDrop: actualVoltageDropPercent,
            voltageDropV: actualVoltageDrop,
            recommendedFuseA: selectedFuse,
            isVoltagDropOK: isVoltageDropOK,
            warningMessage: warning,
            currentCapacityA: cableCapacity
        )
    }

    // MARK: Yardımcı Fonksiyonlar

    /// Verilen akım kapasitesi için minimum standart kesiti döndürür
    /// - Parameter requiredCurrentA: Gerekli akım taşıma kapasitesi (A)
    /// - Returns: Minimum standart kesit (mm²)
    private static func minimumSectionForCurrent(_ requiredCurrentA: Double, table: [Double: Double]) -> Double {
        for section in standardSections {
            if let capacity = table[section], capacity >= requiredCurrentA {
                return section
            }
        }
        // Tablonun üzerindeyse en büyük kesiti döndür
        return standardSections.last ?? 240.0
    }

    /// Hesaplanan kesit için bir üstteki standart kesiti seçer
    /// - Parameter section: Hesaplanan minimum kesit (mm²)
    /// - Returns: Seçilen standart kesit (mm²)
    private static func nextStandardSection(for section: Double) -> Double {
        for std in standardSections {
            if std >= section {
                return std
            }
        }
        return standardSections.last ?? 240.0
    }

    /// Verilen minimum akım için uygun standart sigorta değerini seçer
    /// - Parameter minCurrentA: Minimum sigorta akımı (A)
    /// - Returns: Seçilen standart sigorta değeri (A)
    private static func nextStandardFuse(for minCurrentA: Double) -> Int {
        for fuse in standardFuseRatings {
            if Double(fuse) >= minCurrentA {
                return fuse
            }
        }
        return standardFuseRatings.last ?? 400
    }

    // MARK: İletkenlik Düzeltmesi (Sıcaklık)

    /// Ortam sıcaklığına göre akım kapasitesi düzeltme katsayısı — IEC 60364-5-52 Tablo B.52.14
    /// - Parameters:
    ///   - ambientTemp:    Ortam sıcaklığı (°C)
    ///   - insulationType: İzolasyon tipi — "PVC" (maks 70°C) veya "XLPE" (maks 90°C)
    ///   - underground:    Toprak döşemesi ise true — referans sıcaklık 20°C; hava montajı: 30°C
    /// - Returns: Düzeltme katsayısı (0.5–1.0)
    static func temperatureCorrectionFactor(
        ambientTemp: Double,
        insulationType: String = "PVC",
        underground: Bool = false
    ) -> Double {
        // IEC 60364-5-52 Tablo B.52.14: hava döşemesi 30°C, toprak döşemesi 20°C referans
        let referenceTemp: Double = underground ? 20.0 : 30.0
        let maxTemp: Double = insulationType == "XLPE" ? 90.0 : 70.0

        // Ct = √((Tp − Ta) / (Tp − T0))
        let factor = sqrt((maxTemp - ambientTemp) / (maxTemp - referenceTemp))
        return max(0.5, min(factor, 1.0))
    }

    // MARK: Çoklu Kablo Derating

    /// Aynı kanalda döşeli kablo sayısına göre derating katsayısı
    /// IEC 60364-5-52 Tablo B.52.20
    /// - Parameter cableCount: Aynı kanalda döşeli kablo sayısı
    /// - Returns: Gruplama derating katsayısı
    static func groupingFactor(cableCount: Int) -> Double {
        switch cableCount {
        case 1:       return 1.00
        case 2:       return 0.80
        case 3:       return 0.70
        case 4:       return 0.65
        case 5...9:   return 0.60  // IEC 60364-5-52 Tablo B.52.17: 5 devre için 0.60 (önce 0.65 idi, hatalıydı)
        case 10...14: return 0.55
        case 15...19: return 0.50
        default:      return 0.45
        }
    }
}
