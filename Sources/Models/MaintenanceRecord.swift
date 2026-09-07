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
    /// Şu an UI'da kullanılmıyor — gelecekte kademe bazlı arıza takibi için ayrılmış
    var stepCount: Int?          = nil
    /// Arızalı/devre dışı kademe sayısı — opsiyonel
    /// Şu an UI'da kullanılmıyor — gelecekte kademe bazlı arıza takibi için ayrılmış
    var failedStepCount: Int?    = nil
    /// Tahmini panel ömrü (yıl) — opsiyonel; nil ise 15 yıl varsayılır
    /// Optional yapı eski Codable kayıtlarında KeyNotFound decode hatasını önler
    var expectedLifeYears: Int?  = nil

    /// Tahmini kondansatör yenileme tarihi (kurulum tarihi + expectedLifeYears ?? 15)
    var estimatedReplacementDate: Date {
        Calendar.current.date(byAdding: .year, value: expectedLifeYears ?? 15, to: installationDate) ?? installationDate
    }

    var nextCheckDate: Date {
        let base = visits.filter { $0.isComplete }.map(\.date).max() ?? installationDate
        return Calendar.current.date(byAdding: .month, value: max(1, checkPeriodMonths), to: base) ?? base
    }

    func isOverdue(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: nextCheckDate) < calendar.startOfDay(for: date)
    }
    func isDueToday(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(nextCheckDate, inSameDayAs: date)
    }
    var isOverdue: Bool { isOverdue(on: Date()) }
    var isDueToday: Bool { isDueToday(on: Date()) }
    var isDueSoon: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let threshold = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        return !isOverdue && Calendar.current.startOfDay(for: nextCheckDate) <= threshold
    }
    var lastCosPhi: Double? { readings.max(by: { $0.date < $1.date })?.cosPhi }
    var lastStatus: MaintenanceStatus {
        readings.max(by: { $0.date < $1.date })?.status ?? .unknown
    }

    /// An unchecked item never clears a previous finding. A subsequent explicit OK
    /// for the same kind (or legacy title) is the evidence that closes it.
    var openFindings: [ChecklistItem] {
        var latest: [String: ChecklistItem] = [:]
        for visit in visits.enumerated().sorted(by: { $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date }).map(\.element) {
            for item in visit.items where item.isChecked {
                let key = item.kind?.rawValue ?? MaintenanceVisit.standardItems.first(where: { $0.title == item.title })?.kind?.rawValue ?? item.title
                latest[key] = item
            }
        }
        return latest.values.filter { $0.status == .failure || $0.status == .warning }
            .sorted { $0.title < $1.title }
    }
    var hasOpenFailures: Bool { openFindings.contains { $0.status == .failure } || openCapacitorFindings.contains { $0.status == .failure } }
    private var chronologicalVisits: [MaintenanceVisit] {
        visits.enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date
        }.map(\.element)
    }

    var capacitorInventory: [MaintenanceCapacitor] {
        var inventory: [UUID: MaintenanceCapacitor] = [:]
        for visit in chronologicalVisits {
            for capacitor in visit.capacitors ?? [] { inventory[capacitor.id] = capacitor }
        }
        return inventory.values.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    var openCapacitorFindings: [MaintenanceCapacitor] {
        var checked: [UUID: MaintenanceCapacitor] = [:]
        for visit in chronologicalVisits {
            for capacitor in visit.capacitors ?? [] where capacitor.status != .unchecked {
                checked[capacitor.id] = capacitor
            }
        }
        return checked.values.filter { $0.status == .failure || $0.status == .warning }
            .sorted { $0.label < $1.label }
    }

    var totalEstimatedPenalty: Double {
        readings.sorted { $0.date > $1.date }.prefix(12).reduce(0) { $0 + $1.totalEstimatedPenalty }
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

    var isValid: Bool {
        activeKWh.isFinite && activeKWh > 0 &&
        [inductiveKVArh, capacitiveKVArh, invoiceAmount, tariff].allSatisfy { $0.isFinite && $0 >= 0 } &&
        [measuredKVAr, thdPercent].allSatisfy { value in
            guard let value else { return true }
            return value.isFinite && value >= 0
        }
    }
    var status: MaintenanceStatus {
        guard isValid else { return .unknown }
        let inductiveRatio = inductiveKVArh / activeKWh
        let capacitiveRatio = capacitiveKVArh / activeKWh
        if inductiveRatio > 0.33 || capacitiveRatio > 0.20 { return .critical }
        if inductiveRatio >= 0.297 || capacitiveRatio >= 0.18 { return .warning }
        return .good
    }
    var totalEstimatedPenalty: Double { estimatedPenalty + estimatedCapacitivePenalty }

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
        case .good:    return "Sınırlar içinde"
        case .warning: return "Risk"
        case .critical: return "Sınır aşımı"
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

/// Shared form validation: reject malformed, negative and non-finite measurements.
enum MaintenanceNumber {
    static func parse(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0 else { return nil }
        return value
    }
}

enum MaintenanceQueue: String, CaseIterable {
    case all = "Tümü"
    case today = "Bugünkü işler"
    case overdue = "Geciken bakımlar"
    case failures = "Açık arızalar"

    func includes(_ record: MaintenanceRecord, on date: Date = Date()) -> Bool {
        switch self {
        case .all: return true
        case .today: return record.isDueToday(on: date)
        case .overdue: return record.isOverdue(on: date)
        case .failures: return record.hasOpenFailures
        }
    }
}
