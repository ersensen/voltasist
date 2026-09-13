import Foundation

struct SolarMaintenanceSystem: Codable {
    var installedKWp: Double
    var panelCount: Int
    var inverterInfo: String
}

/// Blank measurements remain absent; zero is a valid observed value.
struct SolarMaintenanceMeasurements: Codable {
    var dailyProductionKWh: Double?
    var inverterPowerKW: Double?
    var dcVoltageV: Double?
    var dcCurrentA: Double?
    var groundingOhms: Double?

    var isValid: Bool {
        [dailyProductionKWh, inverterPowerKW, dcVoltageV, dcCurrentA, groundingOhms]
            .allSatisfy { $0.map { $0.isFinite && $0 >= 0 } ?? true }
    }

    var rows: [(String, String)] {
        [("Günlük üretim", dailyProductionKWh, "kWh"),
         ("İnverter AC gücü", inverterPowerKW, "kW"),
         ("DC gerilim", dcVoltageV, "V"),
         ("DC akım", dcCurrentA, "A"),
         ("Topraklama direnci", groundingOhms, "Ω")].map { label, value, unit in
            (label, value.map { String(format: "%.2f %@", $0, unit) } ?? "Ölçülmedi")
        }
    }
}

extension MaintenanceVisit {
    static func solarVisit() -> MaintenanceVisit {
        MaintenanceVisit(items: [
            ChecklistItem(title: "Panel temizliği ve cam/yüzey hasarı", kind: .solarPanels),
            ChecklistItem(title: "Gölgelenme ve çevre kontrolü", kind: .solarShading),
            ChecklistItem(title: "DC/AC kablo ve bağlantıların durumu", kind: .solarCables),
            ChecklistItem(title: "Konstrüksiyon, bağlantı ve korozyon", kind: .solarStructure),
            ChecklistItem(title: "İnverter hata kayıtları ve havalandırma", kind: .solarInverter),
            ChecklistItem(title: "Koruma elemanları ve parafudr göstergeleri", kind: .solarProtection),
            ChecklistItem(title: "Topraklama ve eşpotansiyel bağlantılar", kind: .solarGrounding),
            ChecklistItem(title: "Üretim kayıtları ve olağandışı değişimler", kind: .solarProduction)
        ])
    }
}
