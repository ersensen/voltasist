import SwiftUI

struct MaintenanceHomeView: View {
    @EnvironmentObject private var persistence: PersistenceService

    var body: some View {
        List {
            destination("Kompanzasyon", icon: "bolt.circle.fill")
            destination("Solar", icon: "sun.max.fill")
        }
        .navigationTitle("Bakım Takip")
    }

    private func destination(_ type: String, icon: String) -> some View {
        let records = persistence.maintenanceRecords.filter { $0.maintenanceTypeLabel == type }
        return NavigationLink {
            MaintenanceTrackingView(type: type)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(type) Bakım Takip", systemImage: icon).font(.headline)
                Text("\(records.count) tesis • \(records.filter { $0.isOverdue }.count) geciken • \(records.filter { $0.hasOpenFailures }.count) arızalı")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
}
