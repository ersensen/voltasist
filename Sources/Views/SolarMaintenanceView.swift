import SwiftUI

struct SolarMeasurementFields: View {
    @Binding var measurements: SolarMaintenanceMeasurements

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Solar Ölçümleri (opsiyonel)").font(.headline)
            measurement("Günlük üretim (kWh)", value: $measurements.dailyProductionKWh)
            measurement("İnverter AC gücü (kW)", value: $measurements.inverterPowerKW)
            measurement("DC gerilim (V)", value: $measurements.dcVoltageV)
            measurement("DC akım (A)", value: $measurements.dcCurrentA)
            measurement("Topraklama direnci (Ω)", value: $measurements.groundingOhms)
            Text("Ölçülmeyen alanları boş bırakın. Ölçüm noktası, saat, hava koşulları ve inverter hata kodlarını genel notlara yazın.")
                .font(.caption).foregroundStyle(.secondary)
            if !measurements.isValid {
                Text("Ölçümler sıfır veya pozitif olmalıdır; geçersiz ölçümle kayıt yapılamaz.")
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14).background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func measurement(_ title: String, value: Binding<Double?>) -> some View {
        SolarMeasurementInput(title: title, value: value)
    }
}

private struct SolarMeasurementInput: View {
    let title: String
    @Binding var value: Double?
    @State private var text: String

    init(title: String, value: Binding<Double?>) {
        self.title = title
        _value = value
        _text = State(initialValue: value.wrappedValue.map { String($0) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline)
            TextField("Ölçülmedi", text: $text)
                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    // Invalid drafts are rejected by the parent before persistence.
                    value = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil : (MaintenanceNumber.parse(newValue) ?? -1)
                }
        }
    }
}

struct SolarMaintenanceDetailView: View {
    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss
    @State private var record: MaintenanceRecord
    @State private var showVisit = false
    @State private var showEdit = false
    @State private var editingVisit: MaintenanceVisit?
    @State private var showDelete = false

    init(record: MaintenanceRecord) {
        _record = State(initialValue: record)
    }

    var body: some View {
        List {
            Section("Solar Tesis") {
                LabeledContent("Müşteri", value: record.customerName)
                LabeledContent("Konum", value: record.locationAddress)
                LabeledContent("Kurulu güç", value: record.capacityLabel)
                LabeledContent("Panel", value: "\(record.panelBrand) \(record.panelModel)")
                LabeledContent("Panel adedi", value: "\(record.solar?.panelCount ?? 0)")
                LabeledContent("İnverter", value: record.solar?.inverterInfo ?? "")
            }
            Section("Bakım Planı") {
                LabeledContent("Periyot", value: "\(record.checkPeriodMonths) ay")
                LabeledContent("Sonraki bakım", value: record.nextCheckDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(record.isOverdue ? Color.red : Color.primary)
                Button { showVisit = true } label: {
                    Label("Solar Bakım Ziyareti Ekle", systemImage: "sun.max.fill")
                }
            }
            Section("Açık Bulgular") {
                if record.openFindings.isEmpty {
                    Text(record.visits.isEmpty ? "Henüz kontrol yapılmadı." : "Kayıtlı açık bulgu yok.")
                        .foregroundStyle(.secondary)
                }
                ForEach(record.openFindings) { item in
                    VStack(alignment: .leading) {
                        Label(item.title, systemImage: item.status.systemIcon)
                        Text(item.status.label).foregroundStyle(item.status == .failure ? Color.red : Color.orange)
                        if !item.notes.isEmpty { Text(item.notes).font(.caption) }
                    }
                }
            }
            Section("Ziyaretler ve Ölçümler") {
                if record.visits.isEmpty { Text("Henüz ziyaret yok.").foregroundStyle(.secondary) }
                ForEach(record.visits.sorted { $0.date > $1.date }) { visit in
                    DisclosureGroup {
                        if let measurements = visit.solarMeasurements {
                            ForEach(measurements.rows, id: \.0) { row in
                                LabeledContent(row.0, value: row.1)
                            }
                        }
                        NavigationLink("Kontroller, Notlar ve Fotoğraflar") {
                            MaintenanceVisitDetailView(visit: visit)
                        }
                        Button("Ziyareti Düzenle") { editingVisit = visit }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(visit.date.formatted(date: .abbreviated, time: .omitted))
                            Text("\(visit.completedCount)/\(visit.items.count) kontrol • \(visit.isComplete ? "Tamamlandı" : "Taslak")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Solar Bakım")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tesisi Düzenle") { showEdit = true }
                    Button("PDF Raporu") {
                        ShareService.sharePDF(data: PDFService.generateSolarMaintenancePDF(record: record, settings: persistence.settings),
                                              filename: "solar_bakim_\(record.id.uuidString)")
                    }
                    Button("Kaydı Sil", role: .destructive) { showDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showVisit) {
            MaintenanceVisitFormView(isSolar: true) { visit in
                record.visits.append(visit)
                persistence.saveMaintenanceRecord(record)
            }
        }
        .sheet(item: $editingVisit) { visit in
            MaintenanceVisitFormView(existingVisit: visit, isSolar: true) { updated in
                if let index = record.visits.firstIndex(where: { $0.id == updated.id }) {
                    record.visits[index] = updated
                    persistence.saveMaintenanceRecord(record)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            MaintenanceRecordFormView(record: record) { updated in
                record = updated
                persistence.saveMaintenanceRecord(updated)
            }
        }
        .confirmationDialog("Solar tesis ve tüm bakım geçmişi silinsin mi?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Kaydı Sil", role: .destructive) {
                persistence.deleteMaintenanceRecord(id: record.id)
                dismiss()
            }
        }
    }
}
