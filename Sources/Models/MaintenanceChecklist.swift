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

// MARK: - Kontrol Listesi Kalemi

struct ChecklistItem: Identifiable, Codable {
    var id: UUID                      = UUID()
    var title: String
    var status: ChecklistItemStatus   = .unchecked
    var notes: String                 = ""

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
            ChecklistItem(title: "Terminal sıkılığı ve vida kontrolleri"),
            ChecklistItem(title: "Korozyon ve nem kontrolü"),
            ChecklistItem(title: "Kondansatör görsel incelemesi (şişlik, sızıntı)"),
            ChecklistItem(title: "Kontaktör çalışma testi"),
            ChecklistItem(title: "Regülatör ekran ve göstergeler kontrolü"),
            ChecklistItem(title: "Pano iç sıcaklık ölçümü"),
            ChecklistItem(title: "Kapasite ölçümü (nominal değerin %80 altı kritik)"),
            ChecklistItem(title: "Harmonik ölçümü (THD değeri)"),
            ChecklistItem(title: "Topraklama bağlantısı kontrolü"),
            ChecklistItem(title: "Havalandırma deliği temizliği"),
        ]
    }

    static func standard() -> MaintenanceVisit {
        MaintenanceVisit(items: standardItems)
    }
}

// MARK: - Legacy (Backward Compat — not persisted)

struct MaintenanceChecklist: Identifiable, Codable {
    var id: UUID        = UUID()
    var recordID: UUID
    var readingID: UUID?
    var date: Date      = Date()
    var items: [ChecklistItem]

    var completedCount: Int { items.filter(\.isChecked).count }
    var totalCount: Int { items.count }
    var isComplete: Bool { completedCount == totalCount }

    static func standard(for recordID: UUID) -> MaintenanceChecklist {
        MaintenanceChecklist(recordID: recordID, items: MaintenanceVisit.standardItems)
    }
}
