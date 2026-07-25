// MaintenanceRecord.swift
// VoltAsist
//
// Reaktif güç kompanzasyon panosu periyodik bakım takip modeli.

import Foundation

// MARK: - Bakım Takip Kaydı

struct MaintenanceRecord: Identifiable, Codable {
    var id: UUID             = UUID()
    var customerName: String = ""
    var locationAddress: String = ""
    var panelBrand: String   = ""
    var panelModel: String   = ""
    var installationDate: Date = Date()
    var totalKVAr: Double    = 100.0
    var checkPeriodMonths: Int = 3
    var readings: [MaintenanceReading] = []
    var visits: [MaintenanceVisit] = []
    /// Panodaki toplam kademe (kondansatör) sayısı — opsiyonel
    var stepCount: Int?          = nil
    /// Arızalı/devre dışı kademe sayısı — opsiyonel
    var failedStepCount: Int?    = nil
    /// Tahmini panel ömrü (yıl) — opsiyonel; nil ise 15 yıl varsayılır
    /// Optional yapı eski Codable kayıtlarında KeyNotFound decode hatasını önler
    var expectedLifeYears: Int?  = nil

    /// Tahmini kondansatör yenileme tarihi (kurulum tarihi + expectedLifeYears ?? 15)
    var estimatedReplacementDate: Date {
        Calendar.current.date(byAdding: .year, value: expectedLifeYears ?? 15, to: installationDate) ?? installationDate
    }

    var nextCheckDate: Date {
        let base: Date
        if let last = visits.sorted(by: { $0.date > $1.date }).first?.date {
            base = last
        } else if let last = readings.sorted(by: { $0.date > $1.date }).first?.date {
            base = last
        } else {
            base = installationDate
        }
        return Calendar.current.date(byAdding: .month, value: checkPeriodMonths, to: base) ?? base
    }

    var isOverdue: Bool {
        nextCheckDate < Date()
    }

    var isDueSoon: Bool {
        guard !isOverdue else { return false }
        let threshold = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return nextCheckDate <= threshold
    }

    var lastCosPhi: Double? {
        readings.sorted(by: { $0.date > $1.date }).first?.cosPhi
    }

    var lastStatus: MaintenanceStatus {
        guard let cp = lastCosPhi else { return .unknown }
        if cp >= 0.95 { return .good }
        if cp >= 0.90 { return .warning }
        return .critical
    }
}

// MARK: - Sayaç Okuma

struct MaintenanceReading: Identifiable, Codable {
    var id: UUID               = UUID()
    var date: Date             = Date()
    var periodLabel: String    = ""
    var activeKWh: Double      = 0
    var inductiveKVArh: Double = 0
    var capacitiveKVArh: Double = 0
    var invoiceAmount: Double  = 0
    var tariff: Double         = 0.40
    var notes: String          = ""
    var photoIDs: [UUID]       = []
    /// Sahada ölçülen anlık kondansatör kapasitesi (kVAr) — opsiyonel
    var measuredKVAr: Double?  = nil
    /// Harmonik toplam bozulma oranı (%) — sahada ölçülen — opsiyonel
    var thdPercent: Double?    = nil

    // cos φ = kWh / √(kWh² + (endüktif − kapasitif)²)
    var cosPhi: Double {
        guard activeKWh > 0 else { return 1.0 }
        let netQ = inductiveKVArh - capacitiveKVArh
        let s = sqrt(activeKWh * activeKWh + netQ * netQ)
        guard s > 0 else { return 1.0 }
        return min(1.0, activeKWh / s)
    }

    // Kapasitif > %20 aktif → aşırı kompanzasyon
    var isOvercompensated: Bool {
        activeKWh > 0 && capacitiveKVArh > activeKWh * 0.20
    }

    // TEDAŞ endüktif ceza eşiği: aktif × 0.33
    var penaltyKVArh: Double {
        guard activeKWh > 0 else { return 0 }
        return max(0, inductiveKVArh - activeKWh * 0.33)
    }

    var estimatedPenalty: Double { penaltyKVArh * tariff }

    var capacitivePenaltyKVArh: Double {
        guard activeKWh > 0 else { return 0 }
        return max(0, capacitiveKVArh - activeKWh * 0.20)
    }

    var estimatedCapacitivePenalty: Double { capacitivePenaltyKVArh * tariff }
}

// MARK: - Durum

enum MaintenanceStatus {
    case good, warning, critical, unknown

    var label: String {
        switch self {
        case .good:    return "Cezasız"
        case .warning: return "Risk"
        case .critical: return "Cezalı"
        case .unknown: return "Bilinmiyor"
        }
    }

    var icon: String {
        switch self {
        case .good:    return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
