// MaintenanceChecklist.swift
// VoltAsist
//
// Kompanzasyon panosu bakım ziyareti ve kontrol listesi modeli.

import Foundation

// MARK: - Kontrol Kalemi Durumu

enum ChecklistItemStatus: String, Codable, CaseIterable {
    case unchecked = "unchecked"
    case ok        = "ok"
    case warning   = "warning"
    case failure   = "failure"

    var label: String {
        switch self {
        case .unchecked: return "Kontrol Et"
        case .ok:        return "Tamam"
        case .warning:   return "Dikkat"
        case .failure:   return "Arıza"
        }
    }

    var systemIcon: String {
        switch self {
        case .unchecked: return "circle"
        case .ok:        return "checkmark.circle.fill"
        case .warning:   return "exclamationmark.triangle.fill"
        case .failure:   return "xmark.circle.fill"
        }
    }

    var shortEmoji: String {
        switch self {
        case .unchecked: return "○"
        case .ok:        return "✅"
        case .warning:   return "⚠️"
        case .failure:   return "❌"
        }
    }
}

// MARK: - Kontrol Listesi Madde Türü

/// Standart kontrol listesi maddelerinin kararlı tanımlayıcısı.
/// Başlık metni değişse dahi bu enum sayesinde madde eşleştirmesi güvenli kalır.
/// Raw value String ve Codable — eski kayıtlarda kind yoksa nil decode edilir (Optional).
enum ChecklistItemKind: String, Codable, CaseIterable {
    case terminalCheck       = "terminal_check"
    case corrosionCheck      = "corrosion_check"
    case capacitorVisual     = "capacitor_visual"
    case contactorTest       = "contactor_test"
    case regulatorCheck      = "regulator_check"
    case temperatureCheck    = "temperature_check"
    case capacityMeasurement = "capacity_measurement"
    case harmonicMeasurement = "harmonic_measurement"
    case groundingCheck      = "grounding_check"
    case ventilationCheck    = "ventilation_check"
}

// MARK: - Kontrol Listesi Kalemi

struct ChecklistItem: Identifiable, Codable {
    var id: UUID                      = UUID()
    var title: String
    var status: ChecklistItemStatus   = .unchecked
    var notes: String                 = ""
    /// Kararlı eşleştirme anahtarı — nil ise eski kayıt veya özel madde
    var kind: ChecklistItemKind?      = nil

    var isChecked: Bool { status != .unchecked }
}

// MARK: - Bakım Ziyareti

struct MaintenanceVisit: Identifiable, Codable {
    var id: UUID              = UUID()
    var date: Date            = Date()
    var technician: String    = ""
    var overallNotes: String  = ""
    var items: [ChecklistItem]
    var photoIDs: [UUID]      = []

    var completedCount: Int { items.filter { $0.status != .unchecked }.count }
    var failureCount: Int   { items.filter { $0.status == .failure }.count }
    var warningCount: Int   { items.filter { $0.status == .warning }.count }
    var okCount: Int        { items.filter { $0.status == .ok }.count }
    var isComplete: Bool    { completedCount == items.count }

    var failureItems: [ChecklistItem] { items.filter { $0.status == .failure } }
    var warningItems: [ChecklistItem] { items.filter { $0.status == .warning } }

    static var standardItems: [ChecklistItem] {
        [
            ChecklistItem(title: "Terminal sıkılığı ve vida kontrolleri",            kind: .terminalCheck),
            ChecklistItem(title: "Korozyon ve nem kontrolü",                         kind: .corrosionCheck),
            ChecklistItem(title: "Kondansatör görsel incelemesi (şişlik, sızıntı)",  kind: .capacitorVisual),
            ChecklistItem(title: "Kontaktör çalışma testi",                          kind: .contactorTest),
            ChecklistItem(title: "Regülatör ekran ve göstergeler kontrolü",          kind: .regulatorCheck),
            ChecklistItem(title: "Pano iç sıcaklık ölçümü",                         kind: .temperatureCheck),
            ChecklistItem(title: "Kapasite ölçümü (nominal değerin %80 altı kritik)", kind: .capacityMeasurement),
            ChecklistItem(title: "Harmonik ölçümü (THD değeri)",                    kind: .harmonicMeasurement),
            ChecklistItem(title: "Topraklama bağlantısı kontrolü",                   kind: .groundingCheck),
            ChecklistItem(title: "Havalandırma deliği temizliği",                    kind: .ventilationCheck),
        ]
    }

    static func standard() -> MaintenanceVisit {
        MaintenanceVisit(items: standardItems)
    }
}

