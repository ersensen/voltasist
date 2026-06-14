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

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if persistence.maintenanceRecords.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        summaryHeader
                        ForEach(persistence.maintenanceRecords.sorted { a, b in
                            if a.isOverdue != b.isOverdue { return a.isOverdue }
                            if a.isDueSoon != b.isDueSoon { return a.isDueSoon }
                            return a.nextCheckDate < b.nextCheckDate
                        }) { record in
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
                scheduleNotification(for: newRecord)
            }
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
                            .foregroundStyle(cp >= 0.95 ? .green : cp >= 0.90 ? .orange : .red)
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

    private func scheduleNotification(for record: MaintenanceRecord) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            let center = UNUserNotificationCenter.current()
            let id = record.id.uuidString
            center.removePendingNotificationRequests(withIdentifiers: [id + "_warn", id + "_due"])
            let name = record.customerName.isEmpty ? "Kompanzasyon Panosu" : record.customerName
            let nextCheck = record.nextCheckDate

            if let warnDate = Calendar.current.date(byAdding: .day, value: -7, to: nextCheck), warnDate > Date() {
                let c = UNMutableNotificationContent()
                c.title = "Bakım Kontrolü Yaklaşıyor ⚠️"
                c.body  = "\(name) — kontrol tarihi 7 gün sonra."
                c.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: warnDate)
                center.add(UNNotificationRequest(identifier: id + "_warn",
                                                  content: c,
                                                  trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }

            if nextCheck > Date() {
                let c = UNMutableNotificationContent()
                c.title = "Bakım Kontrolü Zamanı 🔧"
                c.body  = "\(name) — bugün periyodik bakım kontrol günü!"
                c.sound = .default
                c.badge = 1
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: nextCheck)
                center.add(UNNotificationRequest(identifier: id + "_due",
                                                  content: c,
                                                  trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }
}

// MARK: - Kayıt Detay Ekranı

struct MaintenanceRecordDetailView: View {

    @EnvironmentObject private var persistence: PersistenceService
    let record: MaintenanceRecord

    @State private var localRecord: MaintenanceRecord
    @State private var showAddReading  = false
    @State private var showEditRecord  = false
    @State private var showAddVisit    = false
    @State private var showDetails     = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    init(record: MaintenanceRecord) {
        self.record = record
        self._localRecord = State(initialValue: record)
    }

    private var sortedReadings: [MaintenanceReading] {
        localRecord.readings.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Üst: risk skoru + 3 kritik metrik
                facilityRiskCard
                criticalMetricsCard

                // Detaylar accordion (varsayılan kapalı)
                detailsToggleButton
                if showDetails {
                    recordInfoCard
                    if let latest = sortedReadings.first { currentStatusCard(latest) }
                    if localRecord.readings.count >= 2 { trendChartCard }
                    if localRecord.readings.count >= 4 { cosPhiTrendInsightCard }
                    if !localRecord.readings.isEmpty { annualSummaryCard }
                    capacitorHealthCard
                    recommendationsCard
                }

                // Her zaman görünür: ölçüm ve ziyaret geçmişi
                readingListCard
                visitHistoryCard
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
                        persistence.deleteMaintenanceRecord(id: localRecord.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(amber)
                }
            }
        }
        .sheet(isPresented: $showAddReading) {
            MaintenanceReadingFormView(defaultTariff: 0.40) { r in
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
        .sheet(isPresented: $showAddVisit) {
            MaintenanceVisitFormView { visit in
                localRecord.visits.append(visit)
                persistence.saveMaintenanceRecord(localRecord)
            }
        }
        .onAppear {
            if let fresh = persistence.maintenanceRecords.first(where: { $0.id == record.id }) {
                localRecord = fresh
            }
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
        let sc: Color = cp >= 0.95 ? .green : cp >= 0.90 ? .orange : .red
        let label = cp >= 0.95 ? "✅ Cezasız" : cp >= 0.90 ? "⚠️ Risk" : "❌ Cezalı"

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
        let data = localRecord.readings.sorted { $0.date < $1.date }.suffix(12)

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(amber)
                Text("cos φ Trendi (Son \(data.count) Ölçüm)")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            Chart {
                ForEach(Array(data)) { point in
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
            .chartYScale(domain: 0.70...1.0)
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
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1)))
    }

    // MARK: Annual Summary

    private var annualSummaryCard: some View {
        let last12 = Array(localRecord.readings.sorted { $0.date > $1.date }.prefix(12))
        let totalPenalty = last12.reduce(0.0) { $0 + $1.estimatedPenalty }
        let avgCos = last12.isEmpty ? 0.0 : last12.reduce(0.0) { $0 + $1.cosPhi } / Double(last12.count)
        let worst = last12.min(by: { $0.cosPhi < $1.cosPhi })

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundStyle(Color.purple)
                Text("Son 12 Ay Özeti")
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
        let cpColor: Color = cp.map { $0 >= 0.95 ? .green : $0 >= 0.90 ? .orange : .red } ?? .gray
        let last12 = Array(localRecord.readings.sorted { $0.date > $1.date }.prefix(12))
        let totalPenalty = last12.reduce(0.0) { $0 + $1.estimatedPenalty }

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
                label: "Yıllık Ceza",
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

    private var riskInfo: (color: Color, label: String, detail: String) {
        let recent = Array(sortedReadings.prefix(3))
        let avgCos = recent.isEmpty ? nil : recent.reduce(0.0) { $0 + $1.cosPhi } / Double(recent.count)
        let lastVisit = localRecord.visits.sorted { $0.date > $1.date }.first
        var red = 0; var yellow = 0
        if let cos = avgCos { if cos < 0.90 { red += 2 } else if cos < 0.95 { yellow += 1 } }
        if localRecord.isOverdue { red += 1 } else if localRecord.isDueSoon { yellow += 1 }
        if let v = lastVisit { red += v.failureCount; yellow += v.warningCount / 2 }
        if red >= 2 { return (.red, "Yüksek Risk", "Acil müdahale gerektirir") }
        if red >= 1 || yellow >= 2 { return (.orange, "Orta Risk", "Yakın zamanda incelenmeli") }
        return (.green, "Düşük Risk", "Normal çalışma durumu")
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

    // MARK: Kondansatör Sağlık (Task 5)

    private var capacitorHealthCard: some View {
        let lastVisit = localRecord.visits.sorted { $0.date > $1.date }.first
        let capItems = lastVisit?.items.filter { $0.title.contains("Kondansatör") || $0.title.contains("Kapasite") } ?? []
        let hasFailure = capItems.contains { $0.status == .failure }
        let hasWarning = capItems.contains { $0.status == .warning }
        let recentCos = sortedReadings.prefix(3).reduce(0.0) { $0 + $1.cosPhi } / max(1, Double(min(3, sortedReadings.count)))

        let (health, healthColor, healthDetail): (String, Color, String)
        if lastVisit == nil {
            (health, healthColor, healthDetail) = ("Bilinmiyor", .gray, "Bakım ziyareti kaydı yok")
        } else if hasFailure {
            (health, healthColor, healthDetail) = ("Kritik", .red, "Son ziyarette arıza tespit edildi")
        } else if hasWarning {
            (health, healthColor, healthDetail) = ("Dikkat", .orange, "Son ziyarette dikkat gerektiriyor")
        } else if recentCos < 0.90 && !sortedReadings.isEmpty {
            (health, healthColor, healthDetail) = ("Şüpheli", .orange, "Düşük cos φ kondansatör sorunu olabilir")
        } else {
            (health, healthColor, healthDetail) = ("İyi", .green, "Son bakımda sorun tespit edilmedi")
        }

        return HStack(spacing: 14) {
            Image(systemName: "cylinder.split.1x2.fill").font(.system(size: 28)).foregroundStyle(healthColor)
                .shadow(color: healthColor.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("Kondansatör Sağlığı").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(health).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(healthColor)
                Text(healthDetail).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
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
        }
        if let lastVisit = localRecord.visits.sorted(by: { $0.date > $1.date }).first {
            if lastVisit.failureCount > 0 { recs.append("Önceki arızaların takibi (\(lastVisit.failureCount) arıza)") }
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
                    NavigationLink(destination: MaintenanceVisitDetailView(visit: visit)) {
                        visitRow(visit)
                    }
                    .buttonStyle(.plain)
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
        let sc: Color = hasFailure ? .red : hasWarning ? .orange : .green
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(sc.opacity(0.13)).frame(width: 40, height: 40)
                Image(systemName: hasFailure ? "xmark.circle.fill" : hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
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
                    if visit.failureCount > 0 {
                        Label("\(visit.failureCount)", systemImage: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.red)
                    }
                    if visit.warningCount > 0 {
                        Label("\(visit.warningCount)", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    }
                }
                Text("\(visit.completedCount)/\(visit.items.count) kontrol")
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

    private func readingRow(_ reading: MaintenanceReading) -> some View {
        let cp = reading.cosPhi
        let cpColor: Color = cp >= 0.95 ? .green : cp >= 0.90 ? .orange : .red

        return HStack(spacing: 12) {
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
                if reading.estimatedPenalty > 0 {
                    Text("-\(reading.estimatedPenalty.currencyFormatted)")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.red)
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
    @State private var technicianText: String = ""
    @State private var overallNotes: String = ""
    @State private var expandedItem: UUID? = nil

    private let amber = Color(red: 1.0, green: 0.78, blue: 0.25)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ziyaret Tarihi").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                                DatePicker("", selection: $visit.date, displayedComponents: .date)
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

                        Button {
                            visit.technician = technicianText
                            visit.overallNotes = overallNotes
                            onSave(visit)
                            dismiss()
                        } label: {
                            Text("Kaydet")
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
        }
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

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    summaryBanner
                    itemsList
                    if !visit.overallNotes.isEmpty {
                        notesCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(visit.date.formatted(.dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
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

    @State private var customerName: String    = ""
    @State private var locationAddress: String = ""
    @State private var panelBrand: String      = ""
    @State private var panelModel: String      = ""
    @State private var installationDate: Date  = Date()
    @State private var totalKVArStr: String    = "100"
    @State private var checkPeriodMonths: Int  = 3

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    init(record: MaintenanceRecord?, onSave: @escaping (MaintenanceRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        if let r = record {
            _customerName     = State(initialValue: r.customerName)
            _locationAddress  = State(initialValue: r.locationAddress)
            _panelBrand       = State(initialValue: r.panelBrand)
            _panelModel       = State(initialValue: r.panelModel)
            _installationDate = State(initialValue: r.installationDate)
            _totalKVArStr     = State(initialValue: String(format: "%.0f", r.totalKVAr))
            _checkPeriodMonths = State(initialValue: r.checkPeriodMonths)
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
                        Divider().background(amber.opacity(0.15))
                        DatePicker("Kurulum Tarihi", selection: $installationDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white)
                            .colorScheme(.dark)
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
                        var r = record ?? MaintenanceRecord()
                        r.customerName      = customerName
                        r.locationAddress   = locationAddress
                        r.panelBrand        = panelBrand
                        r.panelModel        = panelModel
                        r.installationDate  = installationDate
                        r.totalKVAr         = Double(totalKVArStr) ?? 100
                        r.checkPeriodMonths = checkPeriodMonths
                        onSave(r)
                        dismiss()
                    }
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
    let onSave: (MaintenanceReading) -> Void

    @State private var periodLabel: String   = ""
    @State private var activeKWhStr: String  = ""
    @State private var inductiveStr: String  = ""
    @State private var capacitiveStr: String = ""
    @State private var invoiceStr: String    = ""
    @State private var tariffStr: String     = "0.40"
    @State private var notes: String         = ""
    @State private var date: Date            = Date()

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    private var activeKWh: Double  { Double(activeKWhStr.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var inductive: Double  { Double(inductiveStr.replacingOccurrences(of: ",", with: "."))  ?? 0 }
    private var capacitive: Double { Double(capacitiveStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var computedCosPhi: Double {
        guard activeKWh > 0 else { return 1.0 }
        let netQ = inductive - capacitive
        let s = sqrt(activeKWh * activeKWh + netQ * netQ)
        guard s > 0 else { return 1.0 }
        return min(1.0, activeKWh / s)
    }

    private var cpColor: Color { computedCosPhi >= 0.95 ? .green : computedCosPhi >= 0.90 ? .orange : .red }
    private var isOvercompensated: Bool { activeKWh > 0 && capacitive > activeKWh * 0.20 }
    private var penaltyKVArh: Double { activeKWh > 0 ? max(0, inductive - activeKWh * 0.33) : 0 }
    private var estimatedPenalty: Double { penaltyKVArh * (Double(tariffStr) ?? 0.40) }

    init(defaultTariff: Double, onSave: @escaping (MaintenanceReading) -> Void) {
        self.defaultTariff = defaultTariff
        self.onSave = onSave
        _tariffStr = State(initialValue: String(format: "%.2f", defaultTariff))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if activeKWh > 0 { liveStatusCard }

                    formSection("Dönem Bilgisi") {
                        HStack {
                            Text("Dönem").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            TextField("Ocak 2026", text: $periodLabel)
                                .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider().background(amber.opacity(0.15))
                        DatePicker("Tarih", selection: $date, displayedComponents: .date)
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

                    formSection("Notlar") {
                        TextField("Saha notu, gözlem...", text: $notes, axis: .vertical)
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
                            .lineLimit(3...6)
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
                        var r = MaintenanceReading()
                        r.date            = date
                        r.periodLabel     = periodLabel
                        r.activeKWh       = activeKWh
                        r.inductiveKVArh  = inductive
                        r.capacitiveKVArh = capacitive
                        r.invoiceAmount   = Double(invoiceStr) ?? 0
                        r.tariff          = Double(tariffStr) ?? 0.40
                        r.notes           = notes
                        onSave(r)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(amber)
                    .disabled(activeKWh <= 0)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var liveStatusCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(String(format: "%.3f", computedCosPhi))
                    .font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(cpColor)
                Text("cos φ").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            }
            VStack(alignment: .leading, spacing: 5) {
                let status = computedCosPhi >= 0.95 ? "✅ Cezasız" : computedCosPhi >= 0.90 ? "⚠️ Risk" : "❌ Cezalı"
                Text(status).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(cpColor)
                if isOvercompensated {
                    Label("Aşırı Kompanzasyon!", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                }
                if estimatedPenalty > 0 {
                    Text("Tahmini ceza: \(estimatedPenalty.currencyFormatted)")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.red)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        MaintenanceTrackingView()
    }
    .environmentObject(PersistenceService.shared)
    .preferredColorScheme(.dark)
}
