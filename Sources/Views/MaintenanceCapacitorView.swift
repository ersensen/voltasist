import SwiftUI

struct MaintenanceCapacitorSummary: View {
    let capacitor: MaintenanceCapacitor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(capacitor.label + " · " + capacitor.status.label, systemImage: capacitor.status.systemIcon)
                .font(.subheadline.bold())
                .foregroundStyle(capacitor.status == .failure ? Color.red : capacitor.status == .warning ? Color.orange : Color.primary)
            Text(capacitor.connection.label).font(.caption)
            Text("Nominal: \(capacitor.nominalKVAr.formatted()) kVAr")
                .font(.caption)
            if let measured = capacitor.measuredKVAr {
                Text("Ölçülen: \(measured.formatted()) kVAr")
                    .font(.caption)
            } else {
                Text("Ölçüm yapılmadı").font(.caption).foregroundStyle(.secondary)
            }
            if !capacitor.notes.isEmpty { Text(capacitor.notes).font(.caption) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MaintenanceCapacitorEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capacitor: MaintenanceCapacitor
    @State private var nominal: String
    @State private var measured: String
    let onSave: (MaintenanceCapacitor) -> Void

    init(capacitor: MaintenanceCapacitor, onSave: @escaping (MaintenanceCapacitor) -> Void) {
        _capacitor = State(initialValue: capacitor)
        _nominal = State(initialValue: capacitor.nominalKVAr > 0 ? String(capacitor.nominalKVAr) : "")
        _measured = State(initialValue: capacitor.measuredKVAr.map { String($0) } ?? "")
        self.onSave = onSave
    }

    private var validated: MaintenanceCapacitor? {
        guard let nominalValue = MaintenanceNumber.parse(nominal), nominalValue > 0 else { return nil }
        let isEmpty = measured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let measuredValue = MaintenanceNumber.parse(measured)
        guard isEmpty || measuredValue != nil else { return nil }
        var result = capacitor
        result.nominalKVAr = nominalValue
        result.measuredKVAr = measuredValue
        return result.isValid ? result : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kondansatör") {
                    TextField("Etiket (örn. K1-C1)", text: $capacitor.label)
                    Picker("Bağlantı", selection: $capacitor.connection) {
                        ForEach(CapacitorConnection.allCases, id: \.self) { connection in
                            Text(connection.label).tag(connection)
                        }
                    }
                    TextField("Nominal kVAr", text: $nominal).keyboardType(.decimalPad)
                    TextField("Ölçülen kVAr (isteğe bağlı)", text: $measured).keyboardType(.decimalPad)
                }
                Section("Saha kontrolü") {
                    Picker("Durum", selection: $capacitor.status) {
                        ForEach(ChecklistItemStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    TextField("Arıza, değişen malzeme veya ölçüm notu", text: $capacitor.notes, axis: .vertical)
                    Text("Ölçülen değer bu kondansatöre ait olmalıdır. Ölçülmediyse boş bırakın; 0 devre dışı veya sıfır ölçüm anlamına gelir.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if validated == nil {
                    Text("Etiket ve pozitif nominal kapasite gerekli. Ölçüm negatif olamaz.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .navigationTitle("Kademe / Kondansatör")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        guard let result = validated else { return }
                        onSave(result)
                        dismiss()
                    }.disabled(validated == nil)
                }
            }
        }
    }
}
