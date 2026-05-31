// LoadCalculation.swift
// VoltAsist
//
// Yük listesi ve güç talebi hesaplama modeli.
// Toplam bağlı güç, talep gücü, enerji tüketimi ve elektrik faturası tahmini.

import Foundation

// MARK: - Yük Kalemi

/// Tek bir elektrik yükü (cihaz/devre)
struct LoadItem: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Yük adı (örn: "Klima", "Motor", "Aydınlatma")
    var name: String

    /// Birim güç (W — watt)
    var powerW: Double

    /// Adet (aynı türden kaç tane)
    var quantity: Int

    /// Günlük çalışma süresi (saat/gün)
    var hoursPerDay: Double

    /// Talep faktörü — bu yük için özel (0.0–1.0, nil ise genel kullanılır)
    var localDemandFactor: Double?

    /// Kategorisi (aydınlatma, motor, ısıtma, vb.)
    var category: LoadCategory

    // MARK: Hesaplanan Değerler

    /// Toplam bağlı güç (W) = güç × adet
    var totalConnectedW: Double {
        return powerW * Double(quantity)
    }

    /// Günlük enerji tüketimi (kWh/gün)
    var dailyKWh: Double {
        return (totalConnectedW / 1000.0) * hoursPerDay
    }

    init(
        id: UUID = UUID(),
        name: String,
        powerW: Double,
        quantity: Int = 1,
        hoursPerDay: Double = 8.0,
        localDemandFactor: Double? = nil,
        category: LoadCategory = .other
    ) {
        self.id = id
        self.name = name
        self.powerW = powerW
        self.quantity = quantity
        self.hoursPerDay = hoursPerDay
        self.localDemandFactor = localDemandFactor
        self.category = category
    }
}

// MARK: - Yük Kategorisi

/// Yük kategorileri — talep faktörü referansı için
enum LoadCategory: String, Codable, CaseIterable, Identifiable {
    case lighting    = "Aydınlatma"
    case motor       = "Motor / Pompa"
    case heating     = "Isıtma / Soğutma"
    case office      = "Ofis Cihazları"
    case kitchen     = "Mutfak Cihazları"
    case other       = "Diğer"

    var id: String { rawValue }

    /// Kategori için tipik talep faktörü (NFPA 70 ve IEC referanslı)
    var typicalDemandFactor: Double {
        switch self {
        case .lighting: return 0.90
        case .motor:    return 0.80
        case .heating:  return 0.75
        case .office:   return 0.70
        case .kitchen:  return 0.65
        case .other:    return 0.80
        }
    }

    var systemIcon: String {
        switch self {
        case .lighting: return "lightbulb.fill"
        case .motor:    return "gearshape.fill"
        case .heating:  return "thermometer.sun.fill"
        case .office:   return "desktopcomputer"
        case .kitchen:  return "fork.knife"
        case .other:    return "bolt.fill"
        }
    }
}

// MARK: - Hesaplama Girişi

/// Yük listesi hesaplama için gerekli giriş parametreleri
struct LoadCalculationInput: Codable {
    /// Yük listesi
    var loads: [LoadItem]

    /// Genel talep faktörü (0.5–1.0) — varsayılan 0.80
    var demandFactor: Double

    /// Ortalama güç faktörü (cos φ) — varsayılan 0.85
    var cosPhi: Double

    /// Elektrik birim fiyatı (TL/kWh) — EPDK tarifesine göre
    var electricityUnitPrice: Double

    /// Aylık kullanım saati (saat/ay) = günlük saat × 30
    var monthlyUsageHours: Double

    init(
        loads: [LoadItem] = [],
        demandFactor: Double = 0.80,
        cosPhi: Double = 0.85,
        electricityUnitPrice: Double = 4.50,
        monthlyUsageHours: Double = 240.0
    ) {
        self.loads = loads
        self.demandFactor = demandFactor
        self.cosPhi = cosPhi
        self.electricityUnitPrice = electricityUnitPrice
        self.monthlyUsageHours = monthlyUsageHours
    }

    /// Girişin geçerli olup olmadığını kontrol et
    var isValid: Bool {
        return !loads.isEmpty
            && demandFactor > 0 && demandFactor <= 1.0
            && cosPhi > 0 && cosPhi <= 1.0
            && electricityUnitPrice > 0
    }
}

// MARK: - Hesaplama Sonucu

/// Yük listesi hesaplama sonuçları
struct LoadCalculationResult: Codable {
    /// Toplam bağlı güç (kW) — talep faktörü uygulanmamış
    var totalConnectedKW: Double

    /// Talep gücü (kW) = toplam bağlı × talep faktörü
    var demandKW: Double

    /// Görünür güç (kVA) = talep kW / cos φ
    var apparentKVA: Double

    /// Reaktif güç (kVAr) = √(S² - P²)
    var reactiveKVAr: Double

    /// Hat akımı (A) — 3 faz 400V için: I = S / (√3 × V)
    var currentA: Double

    /// Aylık enerji tüketimi (kWh/ay)
    var monthlyKWh: Double

    /// Aylık elektrik faturası tahmini (TL)
    var monthlyBillTL: Double

    /// Yıllık elektrik faturası tahmini (TL)
    var yearlyBillTL: Double

    /// Yıllık CO₂ emisyonu (kg/yıl) — EPDK katsayısı 0.42 kgCO₂/kWh
    var co2KgPerYear: Double

    /// Önerilen ana sigorta değeri (A)
    var recommendedMainFuseA: Int

    /// Yük kategorilerine göre dağılım sözlüğü (kategori adı → kW)
    var categoryBreakdown: [String: Double]

    /// En büyük tek yük (adı ve gücü)
    var largestLoadName: String
    var largestLoadKW: Double
}
