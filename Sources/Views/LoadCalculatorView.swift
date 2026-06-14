// LoadCalculatorView.swift
// VoltAsist
//
// Yük / Güç hesaplama ekranı.
// Cihaz listesi yönetimi, talep gücü, görünür güç, fatura tahmini ve bar chart.

import SwiftUI

// MARK: - Geçmiş Kaydı

private struct LoadHistoryEntry: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let loads: [LoadItem]
    let cosPhi: Double
    let demandFactor: Double
    let unitPrice: Double
}

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
    @State private var showQuoteAdded: Bool     = false
    @State private var showTransferAlert: Bool  = false
    @State private var transferredKW: Double    = 0
    @State private var pendingQuoteItems: [QuoteItem] = []
    @State private var showCustomerPicker      = false

    @AppStorage("pendingCableKW") private var pendingCableKW: Double = 0
    @AppStorage("hideUsageNoteYuk") private var hideUsageNote: Bool = false
    @EnvironmentObject private var persistence: PersistenceService
    @State private var loadHistory: [LoadHistoryEntry] = []
    @State private var showHistory: Bool = false

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Kullanım talimatı (kapatılabilir)
                if !hideUsageNote { loadUsageNote }

                // Son Hesaplar
                if !loadHistory.isEmpty { loadHistoryAccordion }

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
        .alert("Kablo Hesabına Aktarıldı", isPresented: $showTransferAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(String(format: "%.2f kW talep gücü aktarıldı. Kablo Hesabı sekmesine geçin — değer hazır yüklendi.", transferredKW))
        }
        .alert("Teklif'e Eklendi", isPresented: $showQuoteAdded) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Müşteri teklifine eklendi. Teklif sekmesinden görüntüleyebilirsiniz.")
        }
        .sheet(isPresented: $showCustomerPicker) {
            CustomerPickerView { customer in
                persistence.addItemsToQuote(pendingQuoteItems, forCustomer: customer)
                showCustomerPicker = false
                showQuoteAdded = true
            }
            .environmentObject(persistence)
        }
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
        .onAppear { loadLoadHistory() }
    }

    // MARK: - Kullanım Talimatı

    private var loadUsageNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(amber)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text("Nasıl Kullanılır?")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(amber)
                Text("Cihaz veya devre ekleyip güç (W), adet ve günlük çalışma saatini girin. Talep Faktörü, yüklerin aynı anda çalışma oranıdır (tipik 0.75–0.85); tüm yükler eş zamanlı çalışmıyorsa 1.0'dan küçük tutun. Çıktılar: Talep Gücü → fider ve sigorta boyutu, Görünür Güç → trafo seçimi, Hat Akımı → kablo kesiti hesabının girdisi.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                withAnimation { hideUsageNote = true }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.gray.opacity(0.45))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amber.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(amber.opacity(0.22), lineWidth: 1)
                )
        )
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

            // Kablo hesabına aktar
            Button {
                pendingCableKW = res.demandKW
                transferredKW = res.demandKW
                showTransferAlert = true
            } label: {
                Label("Kablo Hesabına Aktar", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.23, green: 0.51, blue: 0.96))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Teklif butonu
            Button {
                pendingQuoteItems = QuoteEngine.itemsFromLoad(res)
                showCustomerPicker = true
            } label: {
                Label("Teklif'e Ekle", systemImage: "doc.badge.plus")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(amber)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                powerValueCell(label: "Bağlı Güç", value: String(format: "%.2f kW", res.totalConnectedKW), color: amber)
                powerValueCell(label: "Talep Gücü", value: String(format: "%.2f kW", res.demandKW), color: .orange)
                powerValueCell(label: "Görünür Güç", value: String(format: "%.2f kVA", res.apparentKVA), color: .cyan)
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
            }
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

    // MARK: - Geçmiş Bölümü

    private var loadHistoryAccordion: some View {
        let cardBG = Color(red: 0.086, green: 0.090, blue: 0.114)
        let cardBorder = Color(red: 0.133, green: 0.137, blue: 0.161)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { showHistory.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(amber)
                    Text("Son Hesaplar")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Text("\(loadHistory.count)")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(amber))
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showHistory {
                Divider().background(Color.white.opacity(0.08))
                VStack(spacing: 0) {
                    ForEach(loadHistory) { entry in
                        Button { restoreLoadHistory(entry) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                                    Text("\(entry.loads.count) cihaz · cos φ \(String(format: "%.2f", entry.cosPhi)) · TF \(String(format: "%.2f", entry.demandFactor))")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "arrow.uturn.left.circle")
                                    .font(.system(size: 16)).foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if entry.id != loadHistory.last?.id {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 14)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBG)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.18), lineWidth: 1))
    }

    private func loadLoadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "loadCalcHistory"),
              let decoded = try? JSONDecoder().decode([LoadHistoryEntry].self, from: data)
        else { return }
        loadHistory = decoded
    }

    private func saveLoadHistory() {
        guard !loads.isEmpty else { return }
        let entry = LoadHistoryEntry(date: Date(), loads: loads,
                                    cosPhi: cosPhi, demandFactor: demandFactor, unitPrice: unitPrice)
        var h = loadHistory
        h.insert(entry, at: 0)
        loadHistory = Array(h.prefix(5))
        if let encoded = try? JSONEncoder().encode(loadHistory) {
            UserDefaults.standard.set(encoded, forKey: "loadCalcHistory")
        }
    }

    private func restoreLoadHistory(_ entry: LoadHistoryEntry) {
        loads = entry.loads
        cosPhi = entry.cosPhi
        demandFactor = entry.demandFactor
        unitPrice = entry.unitPrice
        autoCalculate()
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
        saveLoadHistory()
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
    .environmentObject(PersistenceService.shared)
    .preferredColorScheme(.dark)
}
