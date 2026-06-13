// LoadCalculatorView.swift
// VoltAsist
//
// Yük / Güç hesaplama ekranı.
// Cihaz listesi yönetimi, talep gücü, görünür güç, fatura tahmini ve bar chart.

import SwiftUI
import Charts

// MARK: - LoadCalculatorView

/// Yük listesi ve güç hesap ekranı — tam premium UI
struct LoadCalculatorView: View {

    // MARK: State — Yük Listesi
    @State private var loads: [LoadItem]        = []
    @State private var showAddSheet: Bool       = false
    @State private var editingLoad: LoadItem?   = nil

    // MARK: State — Sistem Parametreleri
    @State private var cosPhi: Double           = 0.85
    @State private var demandFactor: Double     = 0.80
    @State private var unitPrice: Double        = 4.50

    // MARK: State — Sonuç
    @State private var result: LoadCalculationResult? = nil
    @State private var resultVisible: Bool      = false

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Sistem parametreleri
                systemParamsCard

                // Yük listesi
                loadListSection

                // Hesapla butonu
                if !loads.isEmpty {
                    calculateButton
                }

                // Sonuç kartları
                if resultVisible, let res = result {
                    resultSection(res)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(bgColor.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddLoadSheet(existingLoad: editingLoad) { load in
                if let existing = editingLoad,
                   let idx = loads.firstIndex(where: { $0.id == existing.id }) {
                    loads[idx] = load
                } else {
                    loads.append(load)
                }
                editingLoad = nil
                autoCalculate()
            }
        }
        .onChange(of: showAddSheet) { _, _ in editingLoad = nil }
    }

    // MARK: - Sistem Parametreleri Kartı

    private var systemParamsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(amber)
                Text("Sistem Parametreleri")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 14)

            VStack(spacing: 12) {
                sliderRow(
                    label: "Güç Faktörü (cos φ)",
                    value: $cosPhi,
                    range: 0.6...1.0,
                    step: 0.01,
                    format: "%.2f",
                    color: amber
                )
                Divider().background(amber.opacity(0.15))
                sliderRow(
                    label: "Talep Faktörü",
                    value: $demandFactor,
                    range: 0.5...1.0,
                    step: 0.05,
                    format: "%.2f",
                    color: Color.orange
                )
                Divider().background(amber.opacity(0.15))
                HStack {
                    Text("⚡ Birim Fiyat")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("4.50", value: $unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .styledInput()
                        Text("₺/kWh")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.3))
    }

    private func sliderRow(
        label: String, value: Binding<Double>,
        range: ClosedRange<Double>, step: Double,
        format: String, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: step)
                .tint(color)
        }
    }

    // MARK: - Yük Listesi Bölümü

    private var loadListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundStyle(amber)
                Text("Yük Listesi")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                // Yük ekle butonu
                Button {
                    showAddSheet = true
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                } label: {
                    Label("Yük Ekle", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(amber)
                }
                .buttonStyle(.plain)
            }

            if loads.isEmpty {
                emptyLoadsView
            } else {
                VStack(spacing: 8) {
                    ForEach(loads) { load in
                        LoadItemRow(load: load) {
                            // Düzenle
                            editingLoad = load
                            showAddSheet = true
                        } onDelete: {
                            withAnimation(.spring()) {
                                loads.removeAll { $0.id == load.id }
                                autoCalculate()
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.25))
    }

    private var emptyLoadsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.rectangle.fill.on.rectangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.gray.opacity(0.35))
            Text("Yük ekleyin")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Hesapla Butonu

    private var calculateButton: some View {
        Button { calculate() } label: {
            Label("Güç Hesapla", systemImage: "bolt.circle.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [amber, .orange], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: amber.opacity(0.45), radius: 10, y: 4)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sonuç Bölümü

    @ViewBuilder
    private func resultSection(_ res: LoadCalculationResult) -> some View {
        VStack(spacing: 16) {
            // Ana güç değerleri
            powerResultCard(res)

            // Fatura tahmini
            billCard(res)

            // Bar chart
            chartCard(res)
        }
    }

    private func powerResultCard(_ res: LoadCalculationResult) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "bolt.circle.fill").foregroundStyle(amber)
                Text("Güç Sonuçları")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                powerValueCell(label: "Bağlı Güç", value: String(format: "%.2f kW", res.totalConnectedKW), color: amber)
                powerValueCell(label: "Talep Gücü", value: String(format: "%.2f kW", res.demandKW), color: .orange)
                powerValueCell(label: "Görünür Güç", value: String(format: "%.2f kVA", res.apparentKVA), color: .cyan)
                powerValueCell(label: "Reaktif Güç", value: String(format: "%.2f kVAr", res.reactiveKVAr), color: .purple)
            }

            Divider().background(amber.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hat Akımı")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.gray)
                    Text(String(format: "%.1f A", res.currentA))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(amber)
                        .shadow(color: amber.opacity(0.4), radius: 6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Önerilen Sigorta")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.gray)
                    Text("\(res.recommendedMainFuseA) A")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.3))
    }

    private func powerValueCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gray.opacity(0.7))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func billCard(_ res: LoadCalculationResult) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "turkishlirasign.circle.fill").foregroundStyle(Color.green)
                Text("Fatura Tahmini")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                billValue(label: "Aylık kWh", value: String(format: "%.0f kWh", res.monthlyKWh), color: amber)
                Divider().background(amber.opacity(0.2)).frame(height: 55)
                billValue(label: "Aylık Fatura", value: res.monthlyBillTL.currencyFormatted, color: .orange)
                Divider().background(amber.opacity(0.2)).frame(height: 55)
                billValue(label: "Yıllık Fatura", value: res.yearlyBillTL.currencyFormatted, color: .cyan)
            }

            // CO2 badge
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text(String(format: "Yıllık CO₂: %.2f ton/yıl", res.co2KgPerYear / 1000.0))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.12))
                    .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
            )
        }
        .padding(18)
        .glassCard(borderColor: Color.green.opacity(0.3))
    }

    private func billValue(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gray.opacity(0.65))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func chartCard(_ res: LoadCalculationResult) -> some View {
        let chartData = res.categoryBreakdown.sorted { $0.value > $1.value }

        VStack(spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundStyle(amber)
                Text("Yük Dağılımı (kW)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            Chart(chartData, id: \.key) { item in
                BarMark(
                    x: .value("Kategori", item.key),
                    y: .value("Güç (kW)", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [amber, Color.orange],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.25))
    }

    // MARK: - Hesaplama

    private func autoCalculate() {
        guard !loads.isEmpty else {
            resultVisible = false
            return
        }
        calculate()
    }

    private func calculate() {
        let input = LoadCalculationInput(
            loads: loads,
            demandFactor: demandFactor,
            cosPhi: cosPhi,
            electricityUnitPrice: unitPrice
        )
        let res = LoadEngine.calculate(input: input)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            result = res
            resultVisible = true
        }
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
}

// MARK: - Yük Kalemi Satırı

struct LoadItemRow: View {
    let load: LoadItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: load.category.systemIcon)
                .font(.system(size: 18))
                .foregroundStyle(amber)
                .frame(width: 36, height: 36)
                .background(amber.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(load.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(load.quantity)× \(Int(load.powerW)) W · \(String(format: "%.1f", load.hoursPerDay)) sa/gün")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.65))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.3f kWh", load.dailyKWh))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(amber)
                Text("Günlük")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(amber.opacity(0.15), lineWidth: 1)
                )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Sil", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("Düzenle", systemImage: "pencil.circle.fill")
            }
            .tint(amber)
        }
    }
}

// MARK: - Yük Ekle Sheet

struct AddLoadSheet: View {
    let existingLoad: LoadItem?
    let onSave: (LoadItem) -> Void

    @State private var name: String         = ""
    @State private var powerW: String       = "100"
    @State private var quantity: String     = "1"
    @State private var hoursPerDay: String  = "8"
    @State private var category: LoadCategory = .other

    @Environment(\.dismiss) private var dismiss

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // İsim
                        formField(label: "Yük Adı") {
                            TextField("Örn: Klima, Motor...", text: $name)
                                .styledInput()
                        }

                        // Güç
                        formField(label: "Güç (W)") {
                            TextField("100", text: $powerW)
                                .keyboardType(.numberPad)
                                .styledInput()
                        }

                        // Adet
                        formField(label: "Adet") {
                            TextField("1", text: $quantity)
                                .keyboardType(.numberPad)
                                .styledInput()
                        }

                        // Günlük saat
                        formField(label: "Günlük Çalışma (saat)") {
                            TextField("8", text: $hoursPerDay)
                                .keyboardType(.decimalPad)
                                .styledInput()
                        }

                        // Kategori
                        formField(label: "Kategori") {
                            Picker("Kategori", selection: $category) {
                                ForEach(LoadCategory.allCases) { c in
                                    Label(c.rawValue, systemImage: c.systemIcon).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(amber)
                        }

                        // Kaydet
                        Button {
                            saveLoad()
                        } label: {
                            Text("Ekle")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(amber)
                                        .shadow(color: amber.opacity(0.4), radius: 8, y: 4)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty)
                        .opacity(name.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existingLoad == nil ? "Yük Ekle" : "Yükü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(amber)
                }
            }
        }
        .onAppear { prefill() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.7))
            content()
        }
    }

    private func prefill() {
        guard let load = existingLoad else { return }
        name = load.name
        powerW = String(Int(load.powerW))
        quantity = String(load.quantity)
        hoursPerDay = String(format: "%.1f", load.hoursPerDay)
        category = load.category
    }

    private func saveLoad() {
        guard !name.isEmpty else { return }
        let load = LoadItem(
            id: existingLoad?.id ?? UUID(),
            name: name,
            powerW: Double(powerW) ?? 100,
            quantity: Int(quantity) ?? 1,
            hoursPerDay: Double(hoursPerDay.replacingOccurrences(of: ",", with: ".")) ?? 8,
            category: category
        )
        onSave(load)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LoadCalculatorView()
    }
    .preferredColorScheme(.dark)
}
