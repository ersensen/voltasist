// LightingEngine.swift
// VoltAsist
//
// Aydınlatma tasarımı hesaplama motoru.
// EN 12464-1 standardı, lümen metodu, LED/floresan karşılaştırması.

import Foundation

// MARK: - Aydınlatma Hesaplama Motoru

/// EN 12464-1 standardına uygun aydınlatma boyutlandırma motoru
struct LightingEngine {

    // MARK: Sabitler

    /// Varsayılan LED panel — 18W / 2000 lm
    static let defaultLEDWatt: Double = 18.0
    static let defaultLEDLumens: Double = 2000.0

    /// LED ışık verimliliği (lm/W) — güncel market ortalaması
    static let ledEfficacy: Double = 111.0   // 2000 lm / 18 W ≈ 111 lm/W

    /// Floresan ışık verimliliği (lm/W) — T8 tüp referans
    static let fluorescentEfficacy: Double = 60.0

    /// Yıllık çalışma saati varsayılanı (saat/yıl)
    static let defaultAnnualHours: Double = 4000.0  // ≈ 11 saat/gün × 365

    /// Elektrik birim fiyatı varsayılanı (TL/kWh) — hesap içi kullanım
    static let defaultElectricityPrice: Double = 4.50

    // MARK: Ana Hesaplama

    /// Aydınlatma hesapla
    /// - Parameter input: Giriş parametreleri
    /// - Returns: Hesaplama sonuçları
    static func calculate(input: LightingCalculationInput) -> LightingCalculationResult {

        // --- 1. Gerekli Aydınlık Düzeyi ---
        let requiredLux = input.usageType.requiredLux

        // --- 2. Kullanım Katsayısı (CU — Coefficient of Utilization) ---
        // Mekan indeksine göre CU — basitleştirilmiş tablo (IEC/CIE yöntemi)
        let cu = utilisationCoefficient(for: input.roomIndex)

        // --- 3. Gerekli Toplam Işık Akısı ---
        // Lümen Metodu: Φ_toplam = E × A / (LLF × CU)
        // LLF: Light Loss Factor = Bakım Faktörü
        let llf = input.maintenanceFactor
        let requiredLumens = (requiredLux * input.areaM2) / (llf * cu)

        // --- 4. Armatür Adedi ---
        // N = Φ_toplam / Φ_armatür
        let fixtureWatt = input.fixtureWatt
        let fixtureLumens = input.fixtureLumens
        let fixtureCountRaw = requiredLumens / fixtureLumens
        let fixtureCount = Int(ceil(fixtureCountRaw))  // Yukarı yuvarlama

        // --- 5. Kurulu Güç ---
        let totalWatt = Double(fixtureCount) * fixtureWatt

        // --- 6. Işık Verimliliği ---
        let efficacy = fixtureLumens / fixtureWatt

        // --- 7. Gerekli Güç ---
        let requiredWatts = requiredLumens / efficacy

        // --- 8. Fiili Aydınlık Düzeyi Doğrulama ---
        // E_gerçek = N × Φ_armatür × LLF × CU / A
        let actualLux = (Double(fixtureCount) * fixtureLumens * llf * cu) / input.areaM2

        // --- 9. Enerji Sınıflandırması ---
        // W/m² değerine göre EU enerji etiketi (yaklaşık)
        let powerDensity = totalWatt / input.areaM2   // W/m²
        let energyClass = energyClassification(for: powerDensity, usageType: input.usageType)

        // --- 10. LED vs Floresan Tasarrufu ---
        // Floresan eşdeğer watt hesabı (aynı lümen çıkışı için)
        let floresanWatt = requiredLumens / fluorescentEfficacy
        let ledSaving = ((floresanWatt - totalWatt) / floresanWatt) * 100.0
        let ledVsFloresanSaving = max(0, ledSaving)

        // --- 11. Yıllık Enerji Maliyeti ---
        let annualKWh = (totalWatt / 1000.0) * defaultAnnualHours
        let annualCost = annualKWh * defaultElectricityPrice

        return LightingCalculationResult(
            requiredLux: requiredLux,
            requiredLumens: requiredLumens,
            luminousEfficacy: efficacy,
            requiredWatts: requiredWatts,
            fixtureCount: fixtureCount,
            fixtureWatt: fixtureWatt,
            totalWatt: totalWatt,
            energyClassification: energyClass,
            ledVsFloresanSaving: ledVsFloresanSaving,
            annualEnergyCostTL: annualCost,
            utilisationCoefficient: cu,
            maintenanceFactor: llf,
            roomIndex: input.roomIndex,
            actualLux: actualLux
        )
    }

    // MARK: Kullanım Katsayısı (CU)

    /// Mekan indeksine (k) göre Kullanım Katsayısı
    /// Tavan: beyaz (0.7), Duvar: açık (0.5), Zemin: orta (0.2) kabul
    /// IEC/CIBSE lümen metodu tablolarından basitleştirilmiş
    /// - Parameter roomIndex: k = (L×W) / (h×(L+W))
    /// - Returns: CU değeri (0.40–0.75)
    static func utilisationCoefficient(for roomIndex: Double) -> Double {
        switch roomIndex {
        case ..<0.5:   return 0.40
        case 0.5..<0.7: return 0.46
        case 0.7..<1.0: return 0.52
        case 1.0..<1.25: return 0.57
        case 1.25..<1.5: return 0.61
        case 1.5..<2.0: return 0.65
        case 2.0..<2.5: return 0.68
        case 2.5..<3.0: return 0.71
        case 3.0..<4.0: return 0.73
        default:         return 0.75
        }
    }

    // MARK: Enerji Sınıflandırması

    /// Kurulu güç yoğunluğuna göre enerji sınıfı belirle (W/m²)
    /// AB Enerji Verimliliği Direktifi 2010/30/EU + Türkiye BEP yönetmeliği referanslı
    private static func energyClassification(for powerDensity: Double, usageType: RoomUsageType) -> String {
        // Referans güç yoğunluğu: ofis ~10 W/m², konut ~6 W/m²
        let referenceWm2: Double
        switch usageType {
        case .office, .classroom, .store: referenceWm2 = 10.0
        case .workshop, .warehouse:       referenceWm2 = 8.0
        case .kitchen, .bathroom:         referenceWm2 = 7.0
        default:                          referenceWm2 = 6.0
        }

        // Enerji yoğunluğu oranı
        let ratio = powerDensity / referenceWm2
        switch ratio {
        case ..<0.50: return "A++"
        case 0.50..<0.75: return "A+"
        case 0.75..<1.00: return "A"
        case 1.00..<1.25: return "B"
        case 1.25..<1.50: return "C"
        case 1.50..<2.00: return "D"
        default:          return "E"
        }
    }

    // MARK: Mekan Endeksi Hesabı

    /// Mekan endeksini (k) hesapla
    /// k = (Uzunluk × Genişlik) / (Çalışma yüzeyi yüksekliği × (Uzunluk + Genişlik))
    /// - Parameters:
    ///   - length: Oda uzunluğu (m)
    ///   - width: Oda genişliği (m)
    ///   - ceilingHeight: Tavan yüksekliği (m)
    ///   - workingPlaneHeight: Çalışma yüzeyi yüksekliği (m), varsayılan 0.80 m
    /// - Returns: Mekan endeksi (k)
    static func roomIndex(length: Double, width: Double,
                           ceilingHeight: Double, workingPlaneHeight: Double = 0.80) -> Double {
        let h = max(ceilingHeight - workingPlaneHeight, 0.1)
        return (length * width) / (h * (length + width))
    }

    // MARK: Armatür Düzeni Önerisi

    /// Önerilen armatür yerleşimi için satır ve sütun sayısı
    /// - Parameter fixtureCount: Hesaplanan toplam armatür adedi
    /// - Returns: (satır, sütun) çifti
    static func suggestedLayout(for fixtureCount: Int) -> (rows: Int, columns: Int) {
        if fixtureCount <= 1 { return (1, 1) }
        // Kareye en yakın düzeni bul
        let sqrt = Foundation.sqrt(Double(fixtureCount))
        let cols = Int(ceil(sqrt))
        let rows = Int(ceil(Double(fixtureCount) / Double(cols)))
        return (rows, cols)
    }
}
