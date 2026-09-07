// MaintenanceTrackingView.swift
// VoltAsist
//
// Kompanzasyon panosu periyodik bakım takip ekranı.
// TEDAŞ sayaç okuma girişi, cos φ hesabı, ceza tahmini ve trend grafiği.

import SwiftUI
import Charts
import UserNotifications
import UIKit

// MARK: - MaintenanceTrackingView

struct MaintenanceTrackingView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var showAddRecord = false
    @State private var selectedQueue: MaintenanceQueue = .all

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    init(initialQueue: MaintenanceQueue = .all) {
        _selectedQueue = State(initialValue: initialQueue)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if persistence.maintenanceRecords.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        summaryHeader
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(MaintenanceQueue.allCases, id: \.self) { queue in
                                    Button {
                                        selectedQueue = queue
                                    } label: {
                                        Text("\(queue.rawValue) (\(persistence.maintenanceRecords.filter { queue.includes($0) }.count))")
                                            .font(.caption.weight(.semibold))
                                            .padding(10)
                                            .background(selectedQueue == queue ? amber.opacity(0.3) : Color.white.opacity(0.06))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if visibleRecords.isEmpty {
                            Text("Bu listede pano yok.").foregroundStyle(.gray).padding()
                        }
                        ForEach(visibleRecords) { record in
                            NavigationLink(destination: MaintenanceRecordDetailView(record: record)) {
                                recordCell(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            for record in persistence.maintenanceRecords {
                MaintenanceNotificationService.shared.schedule(record)
            }
        }
        .navigationTitle("Bakım Takip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddRecord = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(amber)
                        .font(.system(size: 22))
                }
            }
        }
        .sheet(isPresented: $showAddRecord) {
            MaintenanceRecordFormView(record: nil) { newRecord in
                persistence.saveMaintenanceRecord(newRecord)

            }
        }
    }

    private var visibleRecords: [MaintenanceRecord] {
        persistence.maintenanceRecords.filter { selectedQueue.includes($0) }.sorted {
            if $0.hasOpenFailures != $1.hasOpenFailures { return $0.hasOpenFailures }
            return $0.nextCheckDate < $1.nextCheckDate
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        HStack(spacing: 10) {
            summaryCell("\(persistence.overdueMaintenanceCount)", label: "Gecikmiş", color: .red)
            summaryCell("\(persistence.dueSoonMaintenanceCount)", label: "7 Günde Yaklaşan", color: .yellow)
            summaryCell("\(persistence.maintenanceRecords.count)", label: "Toplam Pano", color: amber)
        }
    }

    private func summaryCell(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: Record Cell

    private func recordCell(_ record: MaintenanceRecord) -> some View {
        let sc = statusColor(for: record)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(sc.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: record.isOverdue ? "exclamationmark.circle.fill" :
                                      record.isDueSoon ? "clock.badge.fill" : "checkmark.circle.fill")
                        .font(.system(size: 22)).foregroundStyle(sc)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.customerName.isEmpty ? "İsimsiz Müşteri" : record.customerName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).lineLimit(1)
                    if !record.locationAddress.isEmpty {
                        Text(record.locationAddress)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.gray).lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.0f kVAr", record.totalKVAr))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(amber)
                    if let cp = record.lastCosPhi {
                        Text(String(format: "cos φ %.3f", cp))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(record.lastStatus.color)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Her \(record.checkPeriodMonths) ayda bir")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.gray)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                Spacer()
                if record.isOverdue {
                    Text("GECİKMİŞ")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                } else if record.isDueSoon {
                    Text("7 GÜN İÇİNDE")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.yellow))
                } else {
                    Text("Sonraki: " + record.nextCheckDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    sc.opacity(record.isOverdue || record.isDueSoon ? 0.5 : 0.15), lineWidth: 1))
        )
    }

    private func statusColor(for record: MaintenanceRecord) -> Color {
        if record.isOverdue { return .red }
        if record.isDueSoon { return .yellow }
        return .green
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 56))
                .foregroundStyle(amber.opacity(0.35))
            Text("Bakım Kaydı Yok")
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Kompanzasyon panolarınızı takip etmek için\nyeni bir kayıt ekleyin.")
                .font(.system(size: 14, design: .rounded)).foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button { showAddRecord = true } label: {
                Label("Kayıt Ekle", systemImage: "plus")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(amber))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Notification


}

// MARK: - Kayıt Detay Ekranı

struct MaintenanceRecordDetailView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss
    let record: MaintenanceRecord

    @State private var localRecord: MaintenanceRecord
    @State private var showAddReading    = false
    @State private var showEditRecord    = false
    @State private var showAddVisit      = false
    @State private var editingVisit: MaintenanceVisit?
    @State private var showDetails       = false
    @State private var showDeleteConfirm = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    init(record: MaintenanceRecord) {
        self.record = record
        self._localRecord = State(initialValue: record)
    }

    private var visitActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localRecord.customerName.isEmpty ? "Kompanzasyon panosu" : localRecord.customerName)
                .font(.title2.bold()).foregroundStyle(.white)
            if !localRecord.locationAddress.isEmpty {
                Label(localRecord.locationAddress, systemImage: "mappin.and.ellipse")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Label("Sonraki bakım: " + localRecord.nextCheckDate.formatted(.dateTime.day().month(.abbreviated).year()), systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(localRecord.isOverdue ? Color.red : Color.secondary)
            Button {
                if let draft = localRecord.visits.filter({ !$0.isComplete }).max(by: { $0.date < $1.date }) {
                    editingVisit = draft
                } else {
                    showAddVisit = true
                }
            } label: {
                Label(localRecord.visits.contains(where: { !$0.isComplete }) ? "Taslak ziyarete devam et" : "Ziyaret başlat", systemImage: "checklist")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(amber).clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
            Button { showAddReading = true } label: {
                Label("Sayaç ölçümü ekle", systemImage: "gauge.medium")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(amber)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain)
        }
        .padding(16).background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sortedReadings: [MaintenanceReading] {
        localRecord.readings.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                visitActionCard
                facilityRiskCard
                openFindingsCard

                // Detaylar accordion (varsayılan kapalı)
                detailsToggleButton
                if showDetails {
                    criticalMetricsCard
                    recordInfoCard
                    if let latest = sortedReadings.first { currentStatusCard(latest) }
                    if localRecord.readings.count >= 2 { trendChartCard }
                    if localRecord.readings.count >= 6 { cosPhiTrendInsightCard }
                    if !localRecord.readings.isEmpty { annualSummaryCard }
                    capacitorHealthCard
                    recommendationsCard
                }

                // Her zaman görünür: ölçüm ve ziyaret geçmişi
                visitHistoryCard
                readingListCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 100)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(localRecord.customerName.isEmpty ? "Bakım Detayı" : localRecord.customerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showAddReading = true } label: { Label("Okuma Ekle", systemImage: "gauge.medium") }
                    Button { showAddVisit = true } label: { Label("Ziyaret Ekle", systemImage: "checklist") }
                    Divider()
                    Button { showEditRecord = true } label: { Label("Kaydı Düzenle", systemImage: "pencil") }
                    Button {
                        let data = PDFService.generateMaintenancePDF(record: localRecord, settings: persistence.settings)
                        let name = "bakim_\(localRecord.customerName.isEmpty ? "rapor" : localRecord.customerName)"
                        ShareService.sharePDF(data: data, filename: name)
                    } label: { Label("PDF Raporu", systemImage: "doc.text.fill") }
                    Divider()
                    Button("Kaydı Sil", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(amber)
                }
            }
        }
        .sheet(isPresented: $showAddReading) {
            MaintenanceReadingFormView(defaultTariff: 0.40, panelTotalKVAr: localRecord.totalKVAr) { r in
                localRecord.readings.append(r)
                persistence.saveMaintenanceRecord(localRecord)

            }
        }
        .sheet(isPresented: $showEditRecord) {
            MaintenanceRecordFormView(record: localRecord) { updated in
                localRecord = updated
                persistence.saveMaintenanceRecord(updated)

            }
        }
        .sheet(item: $editingVisit) { draft in
            MaintenanceVisitFormView(existingVisit: draft) { updated in
                if let index = localRecord.visits.firstIndex(where: { $0.id == updated.id }) {
                    localRecord.visits[index] = updated
                    persistence.saveMaintenanceRecord(localRecord)
                }
            }
        }
        .sheet(isPresented: $showAddVisit) {
            MaintenanceVisitFormView(inventory: localRecord.capacitorInventory) { visit in
                localRecord.visits.append(visit)
                persistence.saveMaintenanceRecord(localRecord)
            }
        }
        .onAppear {
            if let fresh = persistence.maintenanceRecords.first(where: { $0.id == record.id }) {
                localRecord = fresh
            }
        }
        .confirmationDialog(
            "Bu bakım kaydını kalıcı olarak sil",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil — Tüm Geçmiş Silinecek", role: .destructive) {
                persistence.deleteMaintenanceRecord(id: localRecord.id)
                dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tüm ölçümler, ziyaretler ve fotoğraf kayıtları bu panoya bağlı. Bu işlem geri alınamaz.")
        }
    }

    // MARK: Info Card

    private var recordInfoCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "building.2.fill").foregroundStyle(amber)
                Text("Pano Bilgileri")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("Her \(localRecord.checkPeriodMonths) ayda bir")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
            }
            Divider().background(amber.opacity(0.2))
            infoRow("Müşteri",          localRecord.customerName)
            infoRow("Adres",            localRecord.locationAddress)
            infoRow("Marka / Model",    "\(localRecord.panelBrand) \(localRecord.panelModel)")
            infoRow("Kurulum",          localRecord.installationDate.formatted(.dateTime.day().month().year()))
            infoRow("Toplam kVAr",      String(format: "%.0f kVAr", localRecord.totalKVAr))
            infoRow("Sonraki Kontrol",  localRecord.nextCheckDate.formatted(.dateTime.day().month().year()),
                    color: localRecord.isOverdue ? .red : localRecord.isDueSoon ? .yellow : nil)
            infoRow("Tahmini Yenileme", localRecord.estimatedReplacementDate.formatted(.dateTime.day().month().year()),
                    color: localRecord.estimatedReplacementDate < Date() ? .red : nil)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1)))
    }

    private func infoRow(_ label: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color ?? .white)
        }
    }

    // MARK: Current Status

    private func currentStatusCard(_ reading: MaintenanceReading) -> some View {
        let cp = reading.cosPhi
        let sc: Color = reading.status.color
        let label = reading.status.label

        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "gauge.medium").foregroundStyle(amber)
                Text("Son Ölçüm — \(reading.periodLabel.isEmpty ? reading.date.formatted(.dateTime.month().year()) : reading.periodLabel)")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "%.3f", cp))
                        .font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(sc)
                    Text("cos φ").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(sc)
                    if reading.isOvercompensated {
                        Label("Aşırı Kompanzasyon!", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                    }
                    if reading.estimatedPenalty > 0 {
                        Text("Tahmini ceza: \(reading.estimatedPenalty.currencyFormatted)")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(.red)
                    }
                    if reading.estimatedCapacitivePenalty > 0 {
                        Text("Tahmini kapasitif ceza: \(reading.estimatedCapacitivePenalty.currencyFormatted)")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(sc.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(sc.opacity(0.35), lineWidth: 1)))
    }

    // MARK: Trend Chart

    private var trendChartCard: some View {
        let allSorted = Array(localRecord.readings.sorted { $0.date < $1.date })
        let data      = Array(allSorted.suffix(12))
        let thdData   = data.filter { $0.thdPercent  != nil }
        let kvarData  = data.filter { $0.measuredKVAr != nil }

        return VStack(spacing: 12) {
            // cos φ grafiği
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(amber)
                Text("cos φ Trendi (Son \(data.count) Ölçüm)")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            Chart {
                ForEach(data) { point in
                    LineMark(x: .value("Tarih", point.date), y: .value("cos φ", point.cosPhi))
                        .foregroundStyle(Color.cyan).lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Tarih", point.date), y: .value("cos φ", point.cosPhi))
                        .foregroundStyle(point.cosPhi >= 0.95 ? Color.green : point.cosPhi >= 0.90 ? Color.orange : Color.red)
                }
                RuleMark(y: .value("TEDAŞ Sınırı", 0.95))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .annotation(position: .trailing) {
                        Text("0.95").font(.system(size: 9, design: .rounded)).foregroundStyle(.red.opacity(0.7))
                    }
            }
            .frame(height: 180)
            .chartYScale(domain: (max(0.0, (data.map(\.cosPhi).min() ?? 0.70) - 0.05))...1.0)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.gray.opacity(0.6))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.08))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.70, 0.80, 0.90, 0.95, 1.0]) { _ in
                    AxisValueLabel().foregroundStyle(Color.gray.opacity(0.6))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.08))
                }
            }

            // THD grafiği — en az 2 okumada thdPercent doluysa göster
            if thdData.count >= 2 {
                Divider().background(amber.opacity(0.2)).padding(.vertical, 2)
                HStack {
                    Image(systemName: "waveform.path.ecg").foregroundStyle(Color.orange)
                    Text("THD Trendi (Son \(thdData.count) Ölçüm)")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Chart {
                    ForEach(thdData) { point in
                        LineMark(x: .value("Tarih", point.date), y: .value("THD %", point.thdPercent!))
                            .foregroundStyle(Color.orange.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Tarih", point.date), y: .value("THD %", point.thdPercent!))
                            .foregroundStyle(
                                (point.thdPercent ?? 0) > 8 ? Color.red :
                                (point.thdPercent ?? 0) > 5 ? Color.orange : Color.green
                            )
                    }
                    RuleMark(y: .value("Yüksek Risk", 8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(Color.red.opacity(0.55))
                        .annotation(position: .trailing) {
                            Text(">8%").font(.system(size: 9, design: .rounded)).foregroundStyle(.red.opacity(0.55))
                        }
                    RuleMark(y: .value("Orta Risk", 5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(Color.orange.opacity(0.55))
                        .annotation(position: .trailing) {
                            Text("5%").font(.system(size: 9, design: .rounded)).foregroundStyle(.orange.opacity(0.55))
                        }
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.gray.opacity(0.6))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.gray.opacity(0.6))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                    }
                }
            }

            // Kapasite trendi — en az 2 okumada measuredKVAr doluysa göster
            if kvarData.count >= 2 {
                Divider().background(amber.opacity(0.2)).padding(.vertical, 2)
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(Color.cyan)
                    Text("Kapasite Trendi (Son \(kvarData.count) Ölçüm)")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Chart {
                    ForEach(kvarData) { point in
                        LineMark(x: .value("Tarih", point.date), y: .value("kVAr", point.measuredKVAr!))
                            .foregroundStyle(Color.cyan.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Tarih", point.date), y: .value("kVAr", point.measuredKVAr!))
                            .foregroundStyle(
                                (point.measuredKVAr ?? localRecord.totalKVAr) < localRecord.totalKVAr * 0.80 ? Color.red :
                                (point.measuredKVAr ?? localRecord.totalKVAr) < localRecord.totalKVAr * 0.90 ? Color.orange : Color.green
                            )
                    }
                    if localRecord.totalKVAr > 0 {
                        RuleMark(y: .value("Nominal", localRecord.totalKVAr))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(Color.cyan.opacity(0.45))
                            .annotation(position: .trailing) {
                                Text("Nom.").font(.system(size: 9, design: .rounded)).foregroundStyle(.cyan.opacity(0.45))
                            }
                        RuleMark(y: .value("%80 Sınırı", localRecord.totalKVAr * 0.80))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(Color.red.opacity(0.5))
                            .annotation(position: .trailing) {
                                Text("80%").font(.system(size: 9, design: .rounded)).foregroundStyle(.red.opacity(0.5))
                            }
                    }
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.gray.opacity(0.6))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.gray.opacity(0.6))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1)))
    }

    // MARK: Annual Summary

    private var annualSummaryCard: some View {
        let last12 = Array(localRecord.readings.sorted { $0.date > $1.date }.prefix(12))
        let totalPenalty = localRecord.totalEstimatedPenalty
        let avgCos = last12.isEmpty ? 0.0 : last12.reduce(0.0) { $0 + $1.cosPhi } / Double(last12.count)
        let worst = last12.min(by: { $0.cosPhi < $1.cosPhi })

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundStyle(Color.purple)
                Text("Son 12 Ölçüm Özeti")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("\(last12.count) ölçüm")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            }
            HStack(spacing: 0) {
                summaryMetric("Toplam Tahmini Ceza", value: totalPenalty.currencyFormatted, color: .red)
                Divider().background(Color.purple.opacity(0.3)).frame(height: 50)
                summaryMetric("Ortalama cos φ", value: String(format: "%.3f", avgCos),
                              color: avgCos >= 0.95 ? .green : avgCos >= 0.90 ? .orange : .red)
            }
            if let w = worst {
                HStack {
                    Text("En Kötü Dönem:").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                    Text("\(w.periodLabel.isEmpty ? w.date.formatted(.dateTime.month().year()) : w.periodLabel) — cos φ \(String(format: "%.3f", w.cosPhi))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.red)
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.3), lineWidth: 1)))
    }

    // MARK: Kritik Metrik Kartı

    private var criticalMetricsCard: some View {
        let latest = sortedReadings.first
        let cp = latest?.cosPhi
        let cpColor: Color = localRecord.lastStatus.color
        let last12 = Array(localRecord.readings.sorted { $0.date > $1.date }.prefix(12))
        let totalPenalty = localRecord.totalEstimatedPenalty

        return HStack(spacing: 0) {
            criticalCell(
                icon: "calendar.badge.clock",
                label: "Sonraki Bakım",
                value: localRecord.nextCheckDate.formatted(.dateTime.day().month(.abbreviated).year()),
                color: localRecord.isOverdue ? .red : localRecord.isDueSoon ? .yellow : .green
            )
            Divider().background(Color.white.opacity(0.1)).frame(height: 56)
            criticalCell(
                icon: "gauge.medium",
                label: "Son cos φ",
                value: cp.map { String(format: "%.3f", $0) } ?? "—",
                color: cpColor
            )
            Divider().background(Color.white.opacity(0.1)).frame(height: 56)
            criticalCell(
                icon: "turkishlirasign.circle.fill",
                label: "Son 12 Ölçüm Cezası",
                value: totalPenalty > 0 ? totalPenalty.currencyFormatted : "0 ₺",
                color: totalPenalty > 0 ? .red : .green
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1))
        )
    }

    private func criticalCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showDetails.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(showDetails ? "Detayları Gizle" : "Detayları Göster")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.gray.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryMetric(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Tesis Risk Skoru (Task 5)

    @ViewBuilder
    private var openFindingsCard: some View {
        if !localRecord.openFindings.isEmpty || !localRecord.openCapacitorFindings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Açık kontrol bulguları").font(.headline)
                ForEach(localRecord.openFindings) { item in
                    Label(item.title, systemImage: item.status.systemIcon)
                        .foregroundStyle(item.status == .failure ? Color.red : Color.orange)
                    if !item.notes.isEmpty { Text(item.notes).font(.caption) }
                }
                ForEach(localRecord.openCapacitorFindings) { capacitor in
                    MaintenanceCapacitorSummary(capacitor: capacitor)
                }
                Text("Giderilen bulguyu kapatmak için yeni ziyarette aynı kontrolü Tamam olarak işaretleyin.")
                    .font(.caption).foregroundStyle(.gray)
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var riskInfo: (color: Color, label: String, detail: String) {
        if localRecord.hasOpenFailures || localRecord.lastStatus == .critical {
            return (.red, "Yüksek Risk", "Açık arıza veya reaktif sınır aşımı var")
        }
        if !localRecord.openFindings.isEmpty || !localRecord.openCapacitorFindings.isEmpty || localRecord.lastStatus == .warning || localRecord.isOverdue {
            return (.orange, "İnceleme gerekli", "Kontrol bulgularını ve bakım tarihini inceleyin")
        }
        guard localRecord.lastStatus != .unknown,
              localRecord.visits.contains(where: { $0.isComplete }) else {
            return (.gray, "Veri eksik", "Ölçüm ve tamamlanmış bakım gerekli")
        }
        return (.green, "Açık bulgu yok", "Kayıtlı kontrollerde sorun bildirilmedi")
    }

    private var facilityRiskCard: some View {
        let (rc, rl, rd) = riskInfo
        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(rc.opacity(0.15)).frame(width: 56, height: 56)
                Circle().fill(rc.opacity(0.25)).frame(width: 40, height: 40)
                Image(systemName: rc == .green ? "checkmark.circle.fill" : rc == .orange ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(rc)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Tesis Risk Skoru").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(rl).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(rc)
                Text(rd).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(rc.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(rc.opacity(0.4), lineWidth: 1)))
    }

    // MARK: cos φ Trend Analizi (Task 5)

    private var cosPhiTrendInsightCard: some View {
        let sorted = localRecord.readings.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(3))
        let older  = Array(sorted.dropLast(3).suffix(3))
        let recentAvg = recent.isEmpty ? 0.0 : recent.reduce(0.0) { $0 + $1.cosPhi } / Double(recent.count)
        let olderAvg  = older.isEmpty  ? 0.0 : older.reduce(0.0)  { $0 + $1.cosPhi } / Double(older.count)
        let delta = recentAvg - olderAvg
        let (trendIcon, trendLabel, trendColor): (String, String, Color) = delta > 0.01
            ? ("arrow.up.circle.fill", "İyileşiyor", .green)
            : delta < -0.01
            ? ("arrow.down.circle.fill", "Kötüleşiyor", .red)
            : ("minus.circle.fill", "Stabil", .gray)

        return HStack(spacing: 16) {
            Image(systemName: trendIcon).font(.system(size: 32)).foregroundStyle(trendColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("cos φ Trendi").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(trendLabel).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(trendColor)
                Text(String(format: "Son 3 ort: %.3f → Önceki 3 ort: %.3f", recentAvg, olderAvg))
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
            Spacer()
            Text(delta >= 0 ? String(format: "+%.3f", delta) : String(format: "%.3f", delta))
                .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(trendColor)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(trendColor.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(trendColor.opacity(0.3), lineWidth: 1)))
    }

    // MARK: Kondansatör Sağlık

    private var capacitorHealthCard: some View {
        // En son measuredKVAr içeren okumayı bul
        let latestMeasured = sortedReadings.first(where: { $0.measuredKVAr != nil })
        let lastVisit      = localRecord.visits.sorted { $0.date > $1.date }.first

        // Checklist: kind-based eşleştirme (yeni ziyaretler) + legacy string fallback (eski kayıtlar)
        let capItems = localRecord.openFindings.filter {
            $0.kind == .capacitorVisual || $0.kind == .capacityMeasurement ||
            ($0.kind == nil && ($0.title.contains("Kondansatör") || $0.title.contains("Kapasite")))
        }
        let hasChecklistFailure = capItems.contains { $0.status == .failure } || localRecord.openCapacitorFindings.contains { $0.status == .failure }
        let hasChecklistWarning = capItems.contains { $0.status == .warning } || localRecord.openCapacitorFindings.contains { $0.status == .warning }
        let recentCos = sortedReadings.prefix(3).reduce(0.0) { $0 + $1.cosPhi } / max(1, Double(min(3, sortedReadings.count)))

        let health:       String
        let healthColor:  Color
        let healthDetail: String
        let healthSource: String

        if hasChecklistFailure || hasChecklistWarning {
            health = hasChecklistFailure ? "Kritik" : "Dikkat"
            healthColor = hasChecklistFailure ? .red : .orange
            healthDetail = "Giderilmemiş kondansatör kontrol bulgusu var"
            healthSource = "Bakım kontrol listesi"
        } else if let measured = latestMeasured?.measuredKVAr, localRecord.totalKVAr > 0,
                  let measurementDate = latestMeasured?.date,
                  measurementDate >= (lastVisit?.date ?? .distantPast) {
            let ratio = measured / localRecord.totalKVAr
            let pct   = String(format: "%.0f", ratio * 100)
            healthSource = String(format: "Ölçülen: %.0f kVAr / Nominal: %.0f kVAr", measured, localRecord.totalKVAr)
            if ratio < 0.80 {
                health      = "Kritik"
                healthColor = .red
                healthDetail = "Kapasite nominal değerin %80'inin altında (\(pct)%)"
            } else if ratio < 0.90 {
                health      = "İzlenmeli"
                healthColor = .orange
                healthDetail = "Kapasite azalmış — kontrol öneriliyor (\(pct)%)"
            } else {
                health      = "Sağlıklı"
                healthColor = .green
                healthDetail = "Kapasite nominal değer aralığında (\(pct)%)"
            }
        } else {
            // Ölçüm verisi yok — checklist tabanlı tahmin
            healthSource = ""
            let suffix = lastVisit != nil ? " (ölçüm girilmedi — tahmin)" : ""
            if lastVisit == nil || lastVisit?.isComplete != true {
                health      = "Bilinmiyor"
                healthColor = .gray
                healthDetail = "Tamamlanmış güncel kontrol gerekli"
            } else if hasChecklistFailure {
                health      = "Kritik"
                healthColor = .red
                healthDetail = "Son ziyarette arıza tespit edildi\(suffix)"
            } else if hasChecklistWarning {
                health      = "Dikkat"
                healthColor = .orange
                healthDetail = "Son ziyarette dikkat gerektiriyor\(suffix)"
            } else if recentCos < 0.90 && !sortedReadings.isEmpty {
                health      = "Şüpheli"
                healthColor = .orange
                healthDetail = "Düşük cos φ kondansatör sorunu olabilir\(suffix)"
            } else {
                health      = "İyi"
                healthColor = .green
                healthDetail = "Son bakımda sorun tespit edilmedi\(suffix)"
            }
        }

        return HStack(spacing: 14) {
            Image(systemName: "cylinder.split.1x2.fill").font(.system(size: 28)).foregroundStyle(healthColor)
                .shadow(color: healthColor.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("Kondansatör Sağlığı").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(health).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(healthColor)
                Text(healthDetail).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
                if !healthSource.isEmpty {
                    Text(healthSource).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(healthColor.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(healthColor.opacity(0.3), lineWidth: 1)))
    }

    // MARK: Sonraki Bakım Önerileri (Task 5)

    private var recommendationsCard: some View {
        var recs: [String] = []
        if let latest = sortedReadings.first {
            if latest.cosPhi < 0.95 { recs.append("cos φ ölçümü ve kompanzasyon ayarı") }
            if latest.isOvercompensated { recs.append("Aşırı kompanzasyon incelemesi") }
            if let thd = latest.thdPercent {
                if thd > 8 {
                    recs.insert(String(format: "Yüksek THD (%%%.0f) — detuned reaktör değerlendirilmeli", thd), at: 0)
                } else if thd > 5 {
                    recs.append(String(format: "THD %%%.0f — harmonik izleme önerilir", thd))
                }
            }
        }
        if let lastVisit = localRecord.visits.sorted(by: { $0.date > $1.date }).first {
            let failureCount = localRecord.openFindings.filter { $0.status == .failure }.count
            if failureCount > 0 { recs.append("Açık arızaların takibi (\(failureCount) arıza)") }
            let unc = lastVisit.items.filter { $0.status == .unchecked }
            if !unc.isEmpty { recs.append("Tamamlanmamış kontroller: \(unc.count) madde") }
        }
        if localRecord.visits.isEmpty { recs.append("İlk bakım ziyareti ve tam check list") }
        if localRecord.isOverdue { recs.append("Gecikmiş periyodik kontrol — ivediyle yapılmalı") }
        if recs.isEmpty { recs.append("Rutin periyodik kontrol") }

        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundStyle(amber)
                Text("Sonraki Ziyarette Kontrol Et")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            ForEach(recs, id: \.self) { rec in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 13)).foregroundStyle(amber)
                    Text(rec).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(amber.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.25), lineWidth: 1)))
    }

    // MARK: - Ziyaret Geçmişi (Task 3)

    private var visitHistoryCard: some View {
        let sorted = localRecord.visits.sorted { $0.date > $1.date }
        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "checklist").foregroundStyle(Color.teal)
                Text("Bakım Ziyareti Geçmişi")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Button { showAddVisit = true } label: {
                    Label("Ekle", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
            if sorted.isEmpty {
                Text("Henüz bakım ziyareti kaydı yok. Sağ üstten ziyaret ekleyin.")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.gray)
                    .padding(.vertical, 12).frame(maxWidth: .infinity)
            } else {
                ForEach(sorted) { visit in
                    if visit.isComplete {
                        NavigationLink(destination: MaintenanceVisitDetailView(visit: visit)) {
                            visitRow(visit)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { editingVisit = visit } label: { visitRow(visit) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal.opacity(0.3), lineWidth: 1)))
    }

    private func visitRow(_ visit: MaintenanceVisit) -> some View {
        let hasFailure = visit.failureCount > 0
        let hasWarning = visit.warningCount > 0
        let sc: Color = hasFailure ? .red : hasWarning ? .orange : visit.isComplete ? .green : .gray
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(sc.opacity(0.13)).frame(width: 40, height: 40)
                Image(systemName: hasFailure ? "xmark.circle.fill" : hasWarning ? "exclamationmark.triangle.fill" : visit.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 18)).foregroundStyle(sc)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(visit.date.formatted(.dateTime.day().month().year()))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                if !visit.technician.isEmpty {
                    Text(visit.technician).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    if visit.photoIDs.count > 0 {
                        Label("\(visit.photoIDs.count)", systemImage: "camera.fill")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(.teal)
                    }
                    if visit.failureCount > 0 {
                        Label("\(visit.failureCount)", systemImage: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.red)
                    }
                    if visit.warningCount > 0 {
                        Label("\(visit.warningCount)", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    }
                }
                Text("\(visit.completedCount)/\(visit.items.count) kontrol\(visit.isComplete ? "" : " · Taslak")")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(sc.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(sc.opacity(0.2), lineWidth: 1))
    }

    // MARK: Reading List

    private var readingListCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "list.number").foregroundStyle(amber)
                Text("Okuma Geçmişi")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Button { showAddReading = true } label: {
                    Label("Ekle", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(amber)
                }
                .buttonStyle(.plain)
            }

            if sortedReadings.isEmpty {
                Text("Henüz okuma kaydı yok. İlk ölçümü ekleyin.")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.gray)
                    .padding(.vertical, 12).frame(maxWidth: .infinity)
            } else {
                ForEach(sortedReadings) { reading in
                    readingRow(reading)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1)))
    }

    // MARK: Notification



    private func readingRow(_ reading: MaintenanceReading) -> some View {
        let cp = reading.cosPhi
        let cpColor: Color = reading.status.color

        var fieldParts = [String]()
        if let kv  = reading.measuredKVAr { fieldParts.append(String(format: "Ölçülen: %.0f kVAr", kv)) }
        if let thd = reading.thdPercent   { fieldParts.append(String(format: "THD: %.0f%%", thd)) }
        let fieldBadge = fieldParts.isEmpty ? nil : fieldParts.joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.periodLabel.isEmpty ? reading.date.formatted(.dateTime.month(.wide).year()) : reading.periodLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    Text(reading.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "cos φ %.3f", cp))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(cpColor)
                    if reading.totalEstimatedPenalty > 0 {
                        Text("-\(reading.totalEstimatedPenalty.currencyFormatted)")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(.red)
                    }
                    if reading.estimatedCapacitivePenalty > 0 {
                        Text("-\(reading.estimatedCapacitivePenalty.currencyFormatted)")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(.orange)
                    }
                    if reading.photoIDs.count > 0 {
                        Label("\(reading.photoIDs.count)", systemImage: "camera.fill")
                            .font(.system(size: 10, design: .rounded)).foregroundStyle(.teal)
                    }
                }
            }
            if let badge = fieldBadge {
                HStack(spacing: 5) {
                    Image(systemName: "ruler.fill").font(.system(size: 9)).foregroundStyle(.cyan.opacity(0.7))
                    Text(badge).font(.system(size: 10, design: .rounded)).foregroundStyle(.cyan.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Ziyaret Formu (Task 3)

struct MaintenanceVisitFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MaintenanceVisit) -> Void

    @State private var visit: MaintenanceVisit = .standard()
    @State private var editingCapacitor: MaintenanceCapacitor?
    @State private var technicianText: String = ""
    @State private var overallNotes: String = ""
    @State private var expandedItem: UUID? = nil
    @State private var selectedImages: [UIImage] = []
    @State private var photoSaveFailed = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false

    private let amber = Color(red: 1.0, green: 0.78, blue: 0.25)

    init(existingVisit: MaintenanceVisit? = nil, inventory: [MaintenanceCapacitor] = [], onSave: @escaping (MaintenanceVisit) -> Void) {
        var initial = existingVisit ?? .standard()
        if existingVisit == nil { initial.capacitors = inventory.map(\.awaitingInspection) }
        self.onSave = onSave
        _visit = State(initialValue: initial)
        _technicianText = State(initialValue: initial.technician)
        _overallNotes = State(initialValue: initial.overallNotes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ziyaret Tarihi").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                                DatePicker("", selection: $visit.date, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.compact).labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Teknisyen").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                                TextField("Adı Soyadı", text: $technicianText)
                                    .font(.system(size: 15, design: .rounded)).foregroundColor(.white)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Kontrol Listesi")
                                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.gray)
                            ForEach($visit.items) { $item in
                                visitItemRow(item: $item)
                            }
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Genel Notlar").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                            TextEditor(text: $overallNotes)
                                .font(.system(size: 14, design: .rounded)).foregroundColor(.white)
                                .frame(height: 80).scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))

                        capacitorSection
                        visitPhotoSection

                        Button {
                            visit.technician = technicianText
                            visit.overallNotes = overallNotes
                            var photoIDs: [UUID] = []
                            for img in selectedImages {
                                guard let pid = PhotoStorageService.save(image: img, entityID: visit.id) else {
                                    for savedID in photoIDs { PhotoStorageService.delete(photoID: savedID, entityID: visit.id) }
                                    photoSaveFailed = true
                                    return
                                }
                                photoIDs.append(pid)
                            }
                            visit.photoIDs.append(contentsOf: photoIDs)
                            onSave(visit)
                            dismiss()
                        } label: {
                            Text(visit.isComplete ? "Bakımı Tamamla" : "Taslak Kaydet")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(Capsule().fill(amber))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Bakım Ziyareti Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }.foregroundStyle(.gray)
                }
            }
            .alert("Fotoğraf kaydedilemedi", isPresented: $photoSaveFailed) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Kayıt tamamlanmadı. Depolama alanını kontrol edip tekrar deneyin.")
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { images in selectedImages.append(contentsOf: images) }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in selectedImages.append(image) }
            }
        }
    }

    private var capacitorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kademe ve kondansatörler").font(.headline)
            Text("Bir kademede birden fazla kondansatör varsa K1-C1, K1-C2 gibi ayrı kaydedin.")
                .font(.caption).foregroundStyle(.gray)
            ForEach(visit.capacitors ?? []) { capacitor in
                Button { editingCapacitor = capacitor } label: {
                    MaintenanceCapacitorSummary(capacitor: capacitor)
                }.buttonStyle(.plain)
            }
            Button("Kondansatör ekle", systemImage: "plus.circle") {
                editingCapacitor = MaintenanceCapacitor()
            }
        }.padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $editingCapacitor) { capacitor in
            MaintenanceCapacitorEditor(capacitor: capacitor) { updated in
                var entries = visit.capacitors ?? []
                if let index = entries.firstIndex(where: { $0.id == updated.id }) {
                    entries[index] = updated
                } else {
                    entries.append(updated)
                }
                visit.capacitors = entries
            }
        }
    }

    private var visitPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled").foregroundStyle(Color.teal)
                Text("Fotoğraflar")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                Spacer()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Image(systemName: "camera.fill").font(.system(size: 17)).foregroundStyle(Color.teal)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                Button { showPhotoPicker = true } label: {
                    Image(systemName: "photo.fill.on.rectangle.fill").font(.system(size: 17)).foregroundStyle(Color.teal)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            if selectedImages.isEmpty {
                Text("Bakım fotoğrafı eklemek için galeri veya kamera ikonuna basın.")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.0) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 80, height: 80).clipped()
                                    .cornerRadius(8)
                                Button { selectedImages.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.black.opacity(0.4)))
                                }
                                .buttonStyle(.plain).offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    private func visitItemRow(item: Binding<ChecklistItem>) -> some View {
        let statuses: [ChecklistItemStatus] = [.ok, .warning, .failure]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.wrappedValue.title)
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(statuses, id: \.self) { st in
                        Button {
                            if item.wrappedValue.status == st { item.status.wrappedValue = .unchecked }
                            else { item.status.wrappedValue = st }
                        } label: {
                            Text(st.shortEmoji).font(.system(size: 20))
                                .opacity(item.wrappedValue.status == st ? 1.0 : 0.28)
                                .scaleEffect(item.wrappedValue.status == st ? 1.15 : 1.0)
                                .animation(.spring(response: 0.2), value: item.wrappedValue.status)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if item.wrappedValue.status != .unchecked {
                TextField("Not (isteğe bağlı)", text: item.notes)
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.white.opacity(0.8))
                    .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ziyaret Detay (Task 3)

struct MaintenanceVisitDetailView: View {
    let visit: MaintenanceVisit
    private let amber = Color(red: 1.0, green: 0.78, blue: 0.25)

    @State private var photos: [(id: UUID, image: UIImage)] = []
    @State private var fullScreenImage: UIImage? = nil

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    summaryBanner
                    if !photos.isEmpty { photoStrip }
                    itemsList
                    ForEach(visit.capacitors ?? []) { capacitor in
                        MaintenanceCapacitorSummary(capacitor: capacitor)
                    }
                    if !visit.overallNotes.isEmpty {
                        notesCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(visit.date.formatted(.dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            photos = PhotoStorageService.loadAll(photoIDs: visit.photoIDs, entityID: visit.id)
        }
        .sheet(isPresented: .init(
            get: { fullScreenImage != nil },
            set: { if !$0 { fullScreenImage = nil } }
        )) {
            if let img = fullScreenImage { PhotoFullScreenView(image: img) }
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "camera.fill").foregroundStyle(Color.teal)
                Text("Ziyaret Fotoğrafları (\(photos.count))")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos, id: \.id) { entry in
                        Button { fullScreenImage = entry.image } label: {
                            Image(uiImage: entry.image)
                                .resizable().scaledToFill()
                                .frame(width: 90, height: 90).clipped()
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.teal.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.teal.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.teal.opacity(0.25), lineWidth: 1))
        )
    }

    private var summaryBanner: some View {
        HStack(spacing: 20) {
            stat("\(visit.okCount)", label: "Tamam", color: .green)
            Divider().background(.white.opacity(0.1)).frame(height: 36)
            stat("\(visit.warningCount)", label: "Dikkat", color: .orange)
            Divider().background(.white.opacity(0.1)).frame(height: 36)
            stat("\(visit.failureCount)", label: "Arıza", color: .red)
            Divider().background(.white.opacity(0.1)).frame(height: 36)
            stat("\(visit.items.filter { $0.status == .unchecked }.count)", label: "Bekliyor", color: .gray)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private func stat(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray)
        }.frame(maxWidth: .infinity)
    }

    private var itemsList: some View {
        VStack(spacing: 2) {
            ForEach(visit.items) { item in
                HStack(spacing: 12) {
                    Text(item.status.shortEmoji).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                        if !item.notes.isEmpty {
                            Text(item.notes).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(itemBg(item.status))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func itemBg(_ st: ChecklistItemStatus) -> Color {
        switch st {
        case .ok: return .green.opacity(0.07)
        case .warning: return .orange.opacity(0.07)
        case .failure: return .red.opacity(0.09)
        case .unchecked: return .white.opacity(0.04)
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Genel Notlar").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            Text(visit.overallNotes).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Kayıt Formu

struct MaintenanceRecordFormView: View {

    @Environment(\.dismiss) private var dismiss
    let record: MaintenanceRecord?
    let onSave: (MaintenanceRecord) -> Void

    @State private var customerName: String      = ""
    @State private var locationAddress: String   = ""
    @State private var panelBrand: String        = ""
    @State private var panelModel: String        = ""
    @State private var installationDate: Date    = Date()
    @State private var totalKVArStr: String      = "100"
    @State private var checkPeriodMonths: Int    = 3
    @State private var expectedLifeYearsVal: Int = 15

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    private var isKVArInvalid: Bool {
        guard let value = MaintenanceNumber.parse(totalKVArStr) else { return true }
        return value <= 0
    }

    init(record: MaintenanceRecord?, onSave: @escaping (MaintenanceRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        if let r = record {
            _customerName        = State(initialValue: r.customerName)
            _locationAddress     = State(initialValue: r.locationAddress)
            _panelBrand          = State(initialValue: r.panelBrand)
            _panelModel          = State(initialValue: r.panelModel)
            _installationDate    = State(initialValue: r.installationDate)
            _totalKVArStr        = State(initialValue: String(r.totalKVAr))
            _checkPeriodMonths   = State(initialValue: r.checkPeriodMonths)
            _expectedLifeYearsVal = State(initialValue: r.expectedLifeYears ?? 15)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formSection("Müşteri / Lokasyon") {
                        formRow("Müşteri Adı", $customerName, .default)
                        Divider().background(amber.opacity(0.15))
                        formRow("Adres / Lokasyon", $locationAddress, .default)
                    }
                    formSection("Pano Bilgisi") {
                        formRow("Marka", $panelBrand, .default)
                        Divider().background(amber.opacity(0.15))
                        formRow("Model", $panelModel, .default)
                        Divider().background(amber.opacity(0.15))
                        formRow("Toplam kVAr", $totalKVArStr, .numberPad)
                        if isKVArInvalid {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10)).foregroundStyle(.red)
                                Text("Geçersiz değer — kayıt 100 kVAr ile yapılacak")
                                    .font(.system(size: 10, design: .rounded)).foregroundStyle(.red)
                            }
                            .padding(.top, 2)
                        }
                        Divider().background(amber.opacity(0.15))
                        DatePicker("Kurulum Tarihi", selection: $installationDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white)
                            .colorScheme(.dark)
                        Divider().background(amber.opacity(0.15))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tahmini Ömür")
                                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                                Text("Yenileme: \(Calendar.current.date(byAdding: .year, value: expectedLifeYearsVal, to: installationDate)?.formatted(.dateTime.year()) ?? "—")")
                                    .font(.system(size: 10, design: .rounded)).foregroundStyle(.gray)
                            }
                            Spacer()
                            Stepper(value: $expectedLifeYearsVal, in: 5...25) {
                                Text("\(expectedLifeYearsVal) yıl")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    formSection("Kontrol Periyodu") {
                        Picker("Periyot", selection: $checkPeriodMonths) {
                            Text("Aylık").tag(1)
                            Text("2 Aylık").tag(2)
                            Text("3 Aylık").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
            }
            .background(bgColor.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(record == nil ? "Yeni Kayıt" : "Kaydı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }.foregroundStyle(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        guard !isKVArInvalid, !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        var r = record ?? MaintenanceRecord()
                        r.customerName       = customerName
                        r.locationAddress    = locationAddress
                        r.panelBrand         = panelBrand
                        r.panelModel         = panelModel
                        r.installationDate   = installationDate
                        r.totalKVAr          = MaintenanceNumber.parse(totalKVArStr) ?? 0
                        r.checkPeriodMonths  = checkPeriodMonths
                        r.expectedLifeYears  = expectedLifeYearsVal
                        onSave(r)
                        dismiss()
                    }
                    .disabled(isKVArInvalid || customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(amber)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.2), lineWidth: 1)))
        }
    }

    private func formRow(_ label: String, _ binding: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                .frame(minWidth: 100, alignment: .leading)
            TextField("", text: binding)
                .keyboardType(keyboard)
                .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Okuma Formu

struct MaintenanceReadingFormView: View {

    @Environment(\.dismiss) private var dismiss
    let defaultTariff: Double
    let panelTotalKVAr: Double
    let onSave: (MaintenanceReading) -> Void

    @State private var readingID: UUID        = UUID()
    @State private var periodLabel: String   = ""
    @State private var activeKWhStr: String  = ""
    @State private var inductiveStr: String  = ""
    @State private var capacitiveStr: String = ""
    @State private var invoiceStr: String    = ""
    @State private var tariffStr: String     = "0.40"
    @State private var notes: String         = ""
    @State private var date: Date            = Date()
    @State private var selectedImages: [UIImage] = []
    @State private var photoSaveFailed = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var measuredKVArStr: String = ""
    @State private var thdStr: String          = ""

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    private var activeKWh: Double  { MaintenanceNumber.parse(activeKWhStr)  ?? 0 }
    private var inductive: Double  { MaintenanceNumber.parse(inductiveStr)  ?? 0 }
    private var capacitive: Double { MaintenanceNumber.parse(capacitiveStr) ?? 0 }

    private var preview: MaintenanceReading {
        var r = MaintenanceReading()
        r.activeKWh = activeKWh; r.inductiveKVArh = inductive; r.capacitiveKVArh = capacitive
        r.tariff = MaintenanceNumber.parse(tariffStr) ?? 0
        return r
    }
    private var inputIsValid: Bool {
        guard let active = MaintenanceNumber.parse(activeKWhStr), active > 0 else { return false }
        let required = [inductiveStr, capacitiveStr, tariffStr]
        let optional = [invoiceStr, measuredKVArStr, thdStr]
        return required.allSatisfy { MaintenanceNumber.parse($0) != nil } &&
            optional.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MaintenanceNumber.parse($0) != nil }
    }
    private var computedCosPhi: Double { preview.cosPhi }
    private var cpColor: Color { inputIsValid ? preview.status.color : .gray }
    private var isOvercompensated: Bool { preview.isOvercompensated }
    private var estimatedPenalty: Double { preview.estimatedPenalty }
    private var estimatedCapacitivePenalty: Double { preview.estimatedCapacitivePenalty }

    init(defaultTariff: Double, panelTotalKVAr: Double = 0, onSave: @escaping (MaintenanceReading) -> Void) {
        self.defaultTariff = defaultTariff
        self.panelTotalKVAr = panelTotalKVAr
        self.onSave = onSave
        _tariffStr = State(initialValue: String(format: "%.2f", defaultTariff))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !inputIsValid {
                        Text("Aktif tüketim sıfırdan büyük olmalı. Endüktif, kapasitif ve tarife alanlarını doldurun; negatif veya geçersiz sayı kullanmayın.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if activeKWh > 0 {
                        if inductive > 0 || capacitive > 0 {
                            liveStatusCard
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Tüm değerleri girin")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.25), lineWidth: 1))
                            )
                        }
                    }

                    formSection("Dönem Bilgisi") {
                        HStack {
                            Text("Dönem").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            TextField("Ocak 2026", text: $periodLabel)
                                .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider().background(amber.opacity(0.15))
                        DatePicker("Tarih", selection: $date, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 14, design: .rounded)).foregroundStyle(.white).colorScheme(.dark)
                    }

                    formSection("Sayaç Değerleri") {
                        numericRow("Aktif Enerji (kWh)", $activeKWhStr)
                        Divider().background(amber.opacity(0.15))
                        numericRow("Endüktif kVArh", $inductiveStr)
                        Divider().background(amber.opacity(0.15))
                        numericRow("Kapasitif kVArh", $capacitiveStr)
                        Divider().background(amber.opacity(0.15))
                        numericRow("Fatura Tutarı (₺)", $invoiceStr)
                    }

                    formSection("TEDAŞ Reaktif Tarife") {
                        numericRow("Tarife (₺/kVArh)", $tariffStr)
                    }

                    formSection("Saha Ölçümleri") {
                        numericRow("Ölçülen Kapasite (kVAr)", $measuredKVArStr)
                        Divider().background(amber.opacity(0.15))
                        numericRow("THD (%)", $thdStr)
                        let meas = MaintenanceNumber.parse(measuredKVArStr)
                        if let m = meas, panelTotalKVAr > 0, m < panelTotalKVAr * 0.80 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                                Text("Kapasite nominal değerin %80 altında (\(String(format: "%.0f", panelTotalKVAr * 0.80)) kVAr) — kondansatör değişimi önerilir.")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.red)
                            }
                            .padding(.top, 6)
                        }
                    }

                    formSection("Notlar") {
                        TextField("Saha notu, gözlem...", text: $notes, axis: .vertical)
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                            .lineLimit(3...6)
                    }

                    formSection("Sayaç Fotoğrafı") {
                        readingPhotoContent
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
            }
            .background(bgColor.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Okuma Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }.foregroundStyle(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        guard inputIsValid else { return }
                        var r = MaintenanceReading()
                        r.id              = readingID
                        r.date            = date
                        r.periodLabel     = periodLabel
                        r.activeKWh       = activeKWh
                        r.inductiveKVArh  = inductive
                        r.capacitiveKVArh = capacitive
                        r.invoiceAmount   = MaintenanceNumber.parse(invoiceStr) ?? 0
                        r.tariff          = MaintenanceNumber.parse(tariffStr) ?? 0.40
                        r.notes           = notes
                        r.measuredKVAr    = MaintenanceNumber.parse(measuredKVArStr)
                        r.thdPercent      = MaintenanceNumber.parse(thdStr)
                        var photoIDs: [UUID] = []
                        for img in selectedImages {
                            guard let pid = PhotoStorageService.save(image: img, entityID: readingID) else {
                                    for savedID in photoIDs { PhotoStorageService.delete(photoID: savedID, entityID: readingID) }
                                    photoSaveFailed = true
                                    return
                                }
                                photoIDs.append(pid)
                        }
                        r.photoIDs = photoIDs
                        onSave(r)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(amber)
                    .disabled(!inputIsValid)
                }
            }
            .alert("Fotoğraf kaydedilemedi", isPresented: $photoSaveFailed) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Kayıt tamamlanmadı. Depolama alanını kontrol edip tekrar deneyin.")
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { images in selectedImages.append(contentsOf: images) }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in selectedImages.append(image) }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var readingPhotoContent: some View {
        if selectedImages.isEmpty {
            HStack(spacing: 16) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Label("Kamera", systemImage: "camera.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.teal)
                    }
                    .buttonStyle(.plain)
                }
                Button { showPhotoPicker = true } label: {
                    Label("Galeriden Seç", systemImage: "photo.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.teal)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.0) { idx, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 76, height: 76).clipped()
                                .cornerRadius(8)
                            Button { selectedImages.remove(at: idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .buttonStyle(.plain).offset(x: 4, y: -4)
                        }
                    }
                    Button { showPhotoPicker = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(Color.teal)
                            Text("Ekle").font(.system(size: 11)).foregroundStyle(Color.teal)
                        }
                        .frame(width: 76, height: 76)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.teal.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var liveStatusCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(String(format: "%.3f", computedCosPhi))
                    .font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(cpColor)
                Text("cos φ").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            }
            VStack(alignment: .leading, spacing: 5) {
                let status = inputIsValid ? preview.status.label : "Geçerli ölçüm girin"
                Text(status).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(cpColor)
                if isOvercompensated {
                    Label("Aşırı Kompanzasyon!", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                }
                if estimatedPenalty > 0 {
                    Text("Tahmini ceza: \(estimatedPenalty.currencyFormatted)")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.red)
                }
                if estimatedCapacitivePenalty > 0 {
                    Text("Tahmini kapasitif ceza: \(estimatedCapacitivePenalty.currencyFormatted)")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(cpColor.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(cpColor.opacity(0.35), lineWidth: 1)))
        .animation(.spring(response: 0.3), value: computedCosPhi)
    }

    private func numericRow(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            TextField("0", text: binding)
                .keyboardType(.decimalPad).frame(width: 120)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    private func formSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(amber)
                .padding(.horizontal, 4)
            VStack(spacing: 8) { content() }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.2), lineWidth: 1)))
        }
    }
}

// MARK: - MaintenanceStatus Color

private extension MaintenanceStatus {
    var color: Color {
        switch self {
        case .good:     return .green
        case .warning:  return .orange
        case .critical: return .red
        case .unknown:  return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MaintenanceTrackingView()
    }
    .environmentObject(PersistenceService.shared)
    .preferredColorScheme(.dark)
}
