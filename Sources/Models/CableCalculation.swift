// CableCalculation.swift
// VoltAsist
//
// Kablo kesiti ve gerilim düşümü hesaplama modeli.
// IEC 60364 standardına uygun giriş/çıkış veri yapıları.

import Foundation

// MARK: - İletken Tipi

/// Kablo iletken malzemesi
enum ConductorType: String, Codable, CaseIterable, Identifiable {
    case copper   = "Bakır"
    case aluminum = "Alüminyum"

    var id: String { rawValue }

    /// İletkenlik katsayısı (m / Ω·mm²)
    /// Bakır: 56, Alüminyum: 35
    var conductivity: Double {
        switch self {
        case .copper:   return 56.0
        case .aluminum: return 35.0
        }
    }

    /// Özdirenç (Ω·mm²/m)
    var resistivity: Double {
        return 1.0 / conductivity
    }
}

// MARK: - Montaj Tipi

/// Kablo döşeme/montaj yöntemi (IEC 60364-5-52)
enum InstallationType: String, Codable, CaseIterable, Identifiable {
    case inWall    = "Sıva Altı (Boru İçi)"
    case surface   = "Sıva Üstü"
    case inConduit = "Açık Boru İçi"
    case cableTray = "Kablo Kanalı"

    var id: String { rawValue }

    /// Montaj tipi derating (düşürme) katsayısı
    /// IEC 60364-5-52 Tablo B.52.3 referanslı
    var derating: Double {
        switch self {
        case .inWall:    return 0.70   // Isı birikimi nedeniyle %30 düşürme
        case .surface:   return 1.00   // Referans değer
        case .inConduit: return 0.80   // Açık boru — ılımlı havalandırma
        case .cableTray: return 0.95   // Kablo taşıyıcı — iyi havalandırma
        }
    }

    /// SF Symbols ikon adı
    var systemIcon: String {
        switch self {
        case .inWall:    return "arrow.down.to.line.compact"
        case .surface:   return "line.horizontal.3"
        case .inConduit: return "circle.dotted"
        case .cableTray: return "tray.fill"
        }
    }
}

// MARK: - Hesaplama Girişi

/// Kablo kesiti hesaplama için gerekli girdi parametreleri
struct CableCalculationInput: Codable {
    /// Aktif güç (kW)
    var powerKW: Double

    /// Şebeke gerilimi (V) — tek faz 230V, üç faz 400V
    var voltageV: Double

    /// Faz sayısı — 1 (tek faz) veya 3 (üç faz)
    var phaseCount: Int

    /// Kablo uzunluğu (m) — tek yön
    var lengthM: Double

    /// İletken tipi — Bakır veya Alüminyum
    var conductorType: ConductorType

    /// Montaj tipi — derating hesabı için
    var installationType: InstallationType

    /// Güç faktörü (cos φ) — varsayılan 0.90
    var cosPhi: Double

    /// İzin verilen maksimum gerilim düşümü (%) — IEC önerisi %3
    var targetVoltageDrop: Double

    /// Demet devre sayısı (Cg) — varsayılan 1
    var groupCount: Int

    // MARK: Varsayılan Değerler

    init(
        powerKW: Double = 10.0,
        voltageV: Double = 400.0,
        phaseCount: Int = 3,
        lengthM: Double = 50.0,
        conductorType: ConductorType = .copper,
        installationType: InstallationType = .inWall,
        cosPhi: Double = 0.90,
        targetVoltageDrop: Double = 3.0,
        groupCount: Int = 1
    ) {
        self.powerKW = powerKW
        self.voltageV = voltageV
        self.phaseCount = phaseCount
        self.lengthM = lengthM
        self.conductorType = conductorType
        self.installationType = installationType
        self.cosPhi = cosPhi
        self.targetVoltageDrop = targetVoltageDrop
        self.groupCount = groupCount
    }

    /// Güç faktörünün geçerliliğini kontrol et
    var isValid: Bool {
        return powerKW > 0
            && (voltageV == 230 || voltageV == 400)
            && (phaseCount == 1 || phaseCount == 3)
            && lengthM > 0
            && cosPhi > 0 && cosPhi <= 1.0
            && targetVoltageDrop > 0 && targetVoltageDrop <= 10
            && groupCount > 0
    }
}

// MARK: - Hesaplama Sonucu

/// Kablo kesiti hesaplama sonuçları
struct CableCalculationResult: Codable {
    /// Yük akımı (A) — termal boyutlandırma için
    var currentA: Double

    /// Akım ve gerilim düşümünden hesaplanan minimum kesit (mm²)
    var requiredSectionMM2: Double

    /// Standart seriden seçilen önerilen kesit (mm²)
    var recommendedSectionMM2: Double

    /// Seçilen kesitle gerçekleşen gerilim düşümü (%)
    var voltageDrop: Double

    /// Seçilen kesitle gerçekleşen gerilim düşümü (V — volt cinsinden)
    var voltageDropV: Double

    /// Önerilen sigorta değeri (A) — standart değerlerden
    var recommendedFuseA: Int

    /// Gerilim düşümü IEC sınırı içinde mi?
    var isVoltagDropOK: Bool

    /// Varsa uyarı mesajı (aşırı yük, uzun hat vb.)
    var warningMessage: String?

    /// Akım taşıma kapasitesi (A) — seçilen kesite göre
    var currentCapacityA: Double

    /// Kullanılan akım yükü (%) — currentA / currentCapacityA × 100
    var loadPercent: Double {
        guard currentCapacityA > 0 else { return 0 }
        return (currentA / currentCapacityA) * 100.0
    }
}
