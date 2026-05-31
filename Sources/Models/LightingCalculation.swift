// LightingCalculation.swift
// VoltAsist
//
// Aydınlatma tasarımı ve lümen hesaplama modeli.
// EN 12464-1 standardına uygun mekan kullanım türleri ve aydınlık düzeyleri.

import Foundation

// MARK: - Mekan Kullanım Tipi

/// EN 12464-1: Çalışma ortamları için aydınlatma standardı
/// Her mekan tipi için gerekli aydınlık düzeyi (lüx) tanımlanmıştır.
enum RoomUsageType: String, Codable, CaseIterable, Identifiable {
    case livingRoom = "Oturma Odası"
    case bedroom    = "Yatak Odası"
    case kitchen    = "Mutfak"
    case bathroom   = "Banyo"
    case office     = "Ofis"
    case corridor   = "Koridor"
    case workshop   = "Atölye / Fabrika"
    case warehouse  = "Depo"
    case classroom  = "Sınıf / Okul"
    case store      = "Mağaza"

    var id: String { rawValue }

    /// EN 12464-1'e göre gerekli aydınlık düzeyi (lüx)
    var requiredLux: Double {
        switch self {
        case .livingRoom: return 100.0   // EN 12464-1 §5.2
        case .bedroom:    return 100.0   // EN 12464-1 §5.2
        case .kitchen:    return 300.0   // EN 12464-1 §5.3 — yüzey çalışma
        case .bathroom:   return 200.0   // EN 12464-1 §5.4
        case .office:     return 500.0   // EN 12464-1 §5.3.1 — genel ofis
        case .corridor:   return 100.0   // EN 12464-1 §5.8
        case .workshop:   return 500.0   // EN 12464-1 §6.1 — hassas iş
        case .warehouse:  return 200.0   // EN 12464-1 §6.5
        case .classroom:  return 300.0   // EN 12464-1 §7.1
        case .store:      return 300.0   // EN 12464-1 §5.6
        }
    }

    /// Renk render indeksi (CRI / Ra) gereksinimi
    var minCRI: Int {
        switch self {
        case .livingRoom, .bedroom: return 80
        case .kitchen, .bathroom:   return 90
        case .office, .classroom:   return 80
        case .corridor:             return 60
        case .workshop:             return 80
        case .warehouse:            return 60
        case .store:                return 90
        }
    }

    /// Renk sıcaklığı önerisi (K)
    var colorTemperatureK: Int {
        switch self {
        case .livingRoom, .bedroom: return 2700
        case .kitchen, .bathroom:   return 4000
        case .office, .classroom:   return 4000
        case .corridor:             return 4000
        case .workshop:             return 5000
        case .warehouse:            return 5000
        case .store:                return 3000
        }
    }

    var systemIcon: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .bedroom:    return "bed.double.fill"
        case .kitchen:    return "fork.knife"
        case .bathroom:   return "shower.fill"
        case .office:     return "desktopcomputer"
        case .corridor:   return "arrow.right.to.line"
        case .workshop:   return "wrench.and.screwdriver.fill"
        case .warehouse:  return "archivebox.fill"
        case .classroom:  return "book.fill"
        case .store:      return "bag.fill"
        }
    }
}

// MARK: - Hesaplama Girişi

/// Aydınlatma hesaplama için gerekli giriş parametreleri
struct LightingCalculationInput: Codable {
    /// Mekan alanı (m²)
    var areaM2: Double

    /// Tavan yüksekliği (m)
    var ceilingHeightM: Double

    /// Mekan kullanım tipi — EN 12464-1 sınıflandırması
    var usageType: RoomUsageType

    /// Bakım faktörü (LLF — Light Loss Factor) — 0.7–0.9
    /// 0.8: standart ofis, 0.7: kirli ortam, 0.9: temiz mekan
    var maintenanceFactor: Double

    /// Mekan endeksi (k) — LightingEngine tarafından alanEn ve genişlik bilgisiyle hesaplanır
    /// k = (Uzunluk × Genişlik) / (Çalışma düzlemi yüksekliği × (Uzunluk + Genişlik))
    var roomIndex: Double

    /// Oda uzunluğu (m) — roomIndex hesabı için
    var lengthM: Double

    /// Oda genişliği (m) — roomIndex hesabı için
    var widthM: Double

    /// Armatür gücü (W) — varsayılan 18W LED panel
    var fixtureWatt: Double

    /// Armatür ışık akısı (lm) — varsayılan 18W LED = 2000 lm
    var fixtureLumens: Double

    init(
        areaM2: Double = 20.0,
        ceilingHeightM: Double = 2.70,
        usageType: RoomUsageType = .office,
        maintenanceFactor: Double = 0.80,
        lengthM: Double = 5.0,
        widthM: Double = 4.0,
        fixtureWatt: Double = 18.0,
        fixtureLumens: Double = 2000.0
    ) {
        self.areaM2 = areaM2
        self.ceilingHeightM = ceilingHeightM
        self.usageType = usageType
        self.maintenanceFactor = maintenanceFactor
        self.lengthM = lengthM
        self.widthM = widthM
        self.fixtureWatt = fixtureWatt
        self.fixtureLumens = fixtureLumens

        // Çalışma düzlemi yüksekliği: masa yüksekliği 0.8 m varsayılan
        let hRoom = max(ceilingHeightM - 0.80, 0.1)
        let L = lengthM
        let W = widthM
        self.roomIndex = (L * W) / (hRoom * (L + W))
    }

    var isValid: Bool {
        return areaM2 > 0
            && ceilingHeightM > 0
            && maintenanceFactor >= 0.5 && maintenanceFactor <= 1.0
            && fixtureWatt > 0
            && fixtureLumens > 0
    }
}

// MARK: - Hesaplama Sonucu

/// Aydınlatma hesaplama sonuçları
struct LightingCalculationResult: Codable {
    /// Gerekli aydınlık düzeyi (lüx) — EN 12464-1
    var requiredLux: Double

    /// Gerekli toplam ışık akısı (lümen)
    /// Φ = E × A / (LLF × CU)
    var requiredLumens: Double

    /// Işık verimliliği (lm/W) — LED için tipik 100–140 lm/W
    var luminousEfficacy: Double

    /// Gerekli toplam güç (W)
    var requiredWatts: Double

    /// Hesaplanan armatür adedi (tavan)
    var fixtureCount: Int

    /// Armatür birimi gücü (W)
    var fixtureWatt: Double

    /// Kurulu toplam güç (W) = fixtureCount × fixtureWatt
    var totalWatt: Double

    /// Enerji verimliliği sınıfı — AB Enerji Etiketi referanslı
    var energyClassification: String

    /// LED ile floresan arasındaki tasarruf (%)
    var ledVsFloresanSaving: Double

    /// Yıllık enerji maliyeti (TL) — 4000 saat/yıl ve 4.5 TL/kWh varsayılan
    var annualEnergyCostTL: Double

    /// Kullanım katsayısı (CU — Coefficient of Utilization) hesaplamada kullanılan
    var utilisationCoefficient: Double

    /// Bakım faktörü hesaplamada kullanılan
    var maintenanceFactor: Double

    /// Mekan endeksi (k)
    var roomIndex: Double

    /// Fiili aydınlık düzeyi (lüx) — seçilen armatür adet ve lümeniyle
    var actualLux: Double
}
