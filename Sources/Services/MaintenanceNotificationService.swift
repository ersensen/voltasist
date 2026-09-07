import Foundation
import UserNotifications

/// Serializes updates so a delayed permission callback cannot resurrect a deleted reminder.
final class MaintenanceNotificationService {
    static let shared = MaintenanceNotificationService()
    private let queue = DispatchQueue(label: "VoltAsist.maintenance.notifications")
    private var revisions: [UUID: UUID] = [:]
    private let center = UNUserNotificationCenter.current()

    static func identifiers(for id: UUID) -> [String] {
        [id.uuidString + "_warn", id.uuidString + "_due"]
    }

    static func dates(for record: MaintenanceRecord, now: Date = Date(), calendar: Calendar = .current) -> [(String, Date)] {
        let day = calendar.startOfDay(for: record.nextCheckDate)
        guard let due = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
              let warning = calendar.date(byAdding: .day, value: -7, to: due) else { return [] }
        return [("_warn", warning), ("_due", due)].filter { $0.1 > now }
    }

    func cancel(id: UUID) {
        queue.async {
            self.revisions[id] = UUID()
            let ids = Self.identifiers(for: id)
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            self.center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func schedule(_ record: MaintenanceRecord) {
        queue.async {
            let revision = UUID()
            self.revisions[record.id] = revision
            let ids = Self.identifiers(for: record.id)
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            self.center.removeDeliveredNotifications(withIdentifiers: ids)
            self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                self.queue.async {
                    guard granted, self.revisions[record.id] == revision else { return }
                    if let error { print("Maintenance notification permission: \(error)") }
                    for (suffix, date) in Self.dates(for: record) {
                        let content = UNMutableNotificationContent()
                        content.title = suffix == "_warn" ? "Bakım kontrolü yaklaşıyor" : "Bakım kontrolü zamanı"
                        content.body = "\(record.customerName) — \(suffix == "_warn" ? "kontrol tarihi 7 gün sonra." : "bugün bakım günü.")"
                        content.sound = .default
                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                        self.center.add(UNNotificationRequest(identifier: record.id.uuidString + suffix,
                            content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))) { error in
                            if let error { print("Maintenance notification: \(error)") }
                        }
                    }
                }
            }
        }
    }
}
