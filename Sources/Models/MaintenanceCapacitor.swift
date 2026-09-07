import Foundation

enum CapacitorConnection: String, Codable, CaseIterable {
    case threePhase, l1Neutral, l2Neutral, l3Neutral

    var label: String {
        switch self {
        case .threePhase: return "Trifaze — L1/L2/L3"
        case .l1Neutral: return "Monofaze — L1/N"
        case .l2Neutral: return "Monofaze — L2/N"
        case .l3Neutral: return "Monofaze — L3/N"
        }
    }
}

/// One physical capacitor, identified across visits. Multiple capacitors may share a stage.
struct MaintenanceCapacitor: Identifiable, Codable {
    var id: UUID = UUID()
    var label: String = ""
    var connection: CapacitorConnection = .threePhase
    var nominalKVAr: Double = 0
    var measuredKVAr: Double? = nil
    var status: ChecklistItemStatus = .unchecked
    var notes: String = ""

    var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        nominalKVAr.isFinite && nominalKVAr > 0 &&
        (measuredKVAr.map { $0.isFinite && $0 >= 0 } ?? true)
    }

    var capacityRatio: Double? {
        guard isValid, let measuredKVAr else { return nil }
        return measuredKVAr / nominalKVAr
    }

    var awaitingInspection: MaintenanceCapacitor {
        var next = self
        next.measuredKVAr = nil
        next.status = .unchecked
        next.notes = ""
        return next
    }
}
