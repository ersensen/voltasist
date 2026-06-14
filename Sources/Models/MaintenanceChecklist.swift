// MaintenanceChecklist.swift
// VoltAsist
//
// Kompanzasyon panosu periyodik bakım kontrol listesi modeli.

import Foundation

// MARK: - Kontrol Listesi Kalemi

struct ChecklistItem: Identifiable, Codable {
    var id: UUID        = UUID()
    var title: String
    var isChecked: Bool = false
    var notes: String   = ""
}

// MARK: - Bakım Kontrol Listesi

struct MaintenanceChecklist: Identifiable, Codable {
    var id: UUID       = UUID()
    var recordID: UUID
    var readingID: UUID?
    var date: Date     = Date()
    var items: [ChecklistItem]

    var completedCount: Int { items.filter(\.isChecked).count }
    var totalCount: Int { items.count }
    var isComplete: Bool { completedCount == totalCount }

    static func standard(for recordID: UUID) -> MaintenanceChecklist {
        MaintenanceChecklist(recordID: recordID, items: [
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
        ])
    }
}
