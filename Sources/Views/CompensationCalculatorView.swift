// CompensationCalculatorView.swift
// VoltAsist — Saha elektrikçisi için reaktif güç kompanzasyonu hesaplama ekranı.

import SwiftUI
import Charts

// MARK: - Yardımcı Enumlar

enum InputMode: CaseIterable, Hashable {
    case instant, invoice
    var label: String { self == .instant ? "Anlık Ölçüm" : "Fatura/Sayaç" }
    var icon:  String { self == .instant ? "gauge.medium"  : "doc.text.fill" }
}

enum FacilityType: CaseIterable, Hashable {
    case office, industrial, mixed
    var label: String {
        switch self { case .office: return "Ofis/Ticari"; case .industrial: return "Sanayi"; case .mixed: return "Karma" }
    }
    var icon: String {
        switch self { case .office: return "building.2.fill"; case .industrial: return "gear.badge.fill"; case .mixed: return "building.columns.fill" }
    }
    var defaultMethod: CompMethod {
        switch self { case .office: return .central; case .industrial: return .group; case .mixed: return .central }
    }
    var defaultStepCount: Int {
        switch self { case .office: return 6; case .industrial: return 12; case .mixed: return 8 }
    }
    var note: String {
        switch self {
        case .office:      return "Sabit veya yavaş değişen yük. Merkezi AKP genellikle yeterli."
        case .industrial:  return "Değişken/darbeli yükler. Grup veya münferit kompanzasyon önerilir."
        case .mixed:       return "Karma yük profili. Merkezi AKP + kritik noktalara sabit kondansatör."
        }
    }
}

enum CompMethod: CaseIterable, Hashable {
    case central, group, individual
    var label: String {
        switch self { case .central: return "Merkezi"; case .group: return "Grup"; case .individual: return "Münferit" }
    }
    var icon: String {
        switch self { case .central: return "square.fill"; case .group: return "square.grid.2x2.fill"; case .individual: return "cpu.fill" }
    }
    var description: String {
        switch self {
        case .central:    return "Trafo çıkışında tek AKP. Trafoyu korur, hat kayıplarını azaltmaz."
        case .group:      return "MCC/dağıtım tablolarında. Hat kayıplarını önemli ölçüde azaltır."
        case .individual: return "Her yükün başında sabit kondansatör. En etkili, maliyetçe yüksek."
        }
    }
}

enum LoadProfile: CaseIterable, Hashable {
    case stable, variable, pulsed
    var label: String {
        switch self { case .stable: return "Sabit"; case .variable: return "Değişken"; case .pulsed: return "Darbeli" }
    }
    var icon: String {
        switch self { case .stable: return "minus.circle.fill"; case .variable: return "waveform"; case .pulsed: return "bolt.fill" }
    }
    var note: String {
        switch self {
        case .stable:   return "Sabit yük: az kademe yeterli, minimum adım esnek."
        case .variable: return "Değişken yük: küçük ve çok sayıda kademe önerilir."
        case .pulsed:   return "Darbeli yük (kaynak/vinç): hızlı kontaktör + reaktör zorunlu."
        }
    }
    var suggestedMinSteps: Int {
        switch self { case .stable: return 4; case .variable: return 8; case .pulsed: return 12 }
    }
    var forceReactor: Bool { self == .pulsed }
}

// MARK: - Sekme

enum CompTab: Int, CaseIterable {
    case input = 0, steps, field, harmonic, economy, report
    var title: String {
        switch self {
        case .input:    return "Giriş"
        case .steps:    return "Kademe"
        case .field:    return "Saha"
        case .harmonic: return "Harmonik"
        case .economy:  return "Ekonomi"
        case .report:   return "Rapor"
        }
    }
    var icon: String {
        switch self {
        case .input:    return "slider.horizontal.3"
        case .steps:    return "square.grid.2x2.fill"
        case .field:    return "antenna.radiowaves.left.and.right"
        case .harmonic: return "waveform.path.ecg"
        case .economy:  return "chart.line.uptrend.xyaxis"
        case .report:   return "doc.text.fill"
        }
    }
}

// MARK: - Ana View

struct CompensationCalculatorView: View {

    @EnvironmentObject private var persistence: PersistenceService

    // Sekme
    @State private var selectedTab: CompTab = .input

    // Giriş modu
    @State private var inputMode:    InputMode    = .instant
    @State private var facilityType: FacilityType = .industrial
    @State private var compMethod:   CompMethod   = .group
    @State private var loadProfile:  LoadProfile  = .variable

    // Anlık ölçüm
    @State private var activePowerKW:   String = "100"
    @State private var apparentPowerKVA: String = "140"
    @State private var useDirectCosPhi: Bool   = false
    @State private var directCosPhiStr: String = "0.714"

    // Fatura / Sayaç
    @State private var monthlyKWh:      String = "72000"
    @State private var monthlyKVArhInd: String = "35000"
    @State private var monthlyKVArhCap: String = "0"

    // Pik / ortalama
    @State private var usePeakMode:      Bool   = false
    @State private var peakActivePowerKW: String = "150"
    @State private var peakApparentKVA:  String = "210"

    // Sistem
    @State private var targetCosPhi:  Double = 0.97
    @State private var systemVoltage: String = "400"
    @State private var frequency:     Double = 50.0
    @State private var transformerKVA: String = "250"
    @State private var penaltyRate:   Double = 0.40

    // Harmonik
    @State private var thdPercent: Double = 10.0
    @State private var thdText:    String = "10.0"

    // Kademe
    @State private var stepCountOption: Int = 8
    @State private var editableSteps: [Double] = []

    // Yatırım kalemleri
    @State private var capCostStr:       String = ""
    @State private var contactorCostStr: String = ""
    @State private var reactorCostStr:   String = ""
    @State private var panelCostStr:     String = ""
    @State private var laborCostStr:     String = ""

    // Yardım kartı görünürlüğü
    @AppStorage("hideCompFieldGuide") private var hideFieldGuide: Bool = false

    // Quote
    @State private var showQuoteAdded:   Bool = false
    @State private var pendingQuoteItems: [QuoteItem] = []
    @State private var showCustomerPicker: Bool = false
    @State private var showNoCompensationAlert: Bool = false

    // Hesaplanan
    @State private var computedCosPhi:        Double  = 100.0 / 140.0
    @State private var computedQcKVAr:        Double  = 0.0
    @State private var computedMonthlySaving: Double  = 0.0
    @State private var engineOversizingWarning: String? = nil

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body

    private var bodyBase: some View {
        VStack(spacing: 0) {
            compTabSelector
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    tabContent
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 28)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(bgColor.ignoresSafeArea())
        .onAppear { recalculate() }
        .onChange(of: activePowerKW)    { _, _ in recalculate() }
        .onChange(of: apparentPowerKVA) { _, _ in recalculate() }
        .onChange(of: targetCosPhi)     { _, _ in recalculate() }
        .onChange(of: penaltyRate)      { _, _ in recalculate() }
        .onChange(of: systemVoltage)    { _, _ in recalculate() }
        .onChange(of: thdPercent)       { _, _ in recalculate() }
        .onChange(of: transformerKVA)   { _, _ in recalculate() }
    }

    private var bodyWithInputChanges: some View {
        bodyBase
            .onChange(of: inputMode)        { _, _ in recalculate() }
            .onChange(of: monthlyKWh)       { _, _ in recalculate() }
            .onChange(of: monthlyKVArhInd)  { _, _ in recalculate() }
            .onChange(of: monthlyKVArhCap)  { _, _ in recalculate() }
            .onChange(of: useDirectCosPhi)  { _, _ in recalculate() }
            .onChange(of: directCosPhiStr)  { _, _ in recalculate() }
    }

    var body: some View {
        bodyWithInputChanges
            .onChange(of: facilityType) { _, nv in
                compMethod      = nv.defaultMethod
                stepCountOption = nv.defaultStepCount
                recalculate()
            }
            .onChange(of: stepCountOption) { _, _ in rebuildEditableSteps() }
            .alert("Teklif'e Eklendi", isPresented: $showQuoteAdded) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Müşteri teklifine eklendi.")
            }
            .sheet(isPresented: $showCustomerPicker) {
                CustomerPickerView { customer in
                    persistence.addItemsToQuote(pendingQuoteItems, forCustomer: customer)
                    showCustomerPicker = false
                    showQuoteAdded = true
                }
                .environmentObject(persistence)
            }
    }

    // MARK: - Sekme Seçici

    private var compTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CompTab.allCases, id: \.rawValue) { tab in
                    compTabButton(tab)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
    }

    private func compTabButton(_ tab: CompTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { selectedTab = tab }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon).font(.system(size: 11, weight: .semibold))
                Text(tab.title).font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.gray.opacity(0.65))
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(Capsule()
                .fill(isSelected ? Color.purple : Color(red: 0.15, green: 0.15, blue: 0.18))
                .shadow(color: isSelected ? Color.purple.opacity(0.4) : .clear, radius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .input:    inputTab
        case .steps:    stepsTab
        case .field:    fieldTab
        case .harmonic: harmonicTab
        case .economy:  economyTab
        case .report:   reportTab
        }
    }

    // MARK: ── TAB 1: GİRİŞ ──

    private var inputTab: some View {
        VStack(spacing: 16) {
            inputModeCard
            facilityTypeCard
            compMethodCard
            loadProfileCard
            if inputMode == .instant { instantMeasurementCard } else { invoiceMeasurementCard }
            systemParametersCard
            cosPhiResultCard
            penaltyResultCard
        }
    }

    private var inputModeCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "slider.horizontal.3").foregroundStyle(amber)
                Text("Giriş Modu").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Button { withAnimation { inputMode = mode } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon).font(.system(size: 13))
                            Text(mode.label).font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(inputMode == mode ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(inputMode == mode ? amber : Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16).glassCard(borderColor: amber.opacity(0.3))
    }

    private var facilityTypeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill").foregroundStyle(Color.cyan)
                Text("Tesis Türü").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(FacilityType.allCases, id: \.self) { ft in
                    Button { withAnimation { facilityType = ft } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: ft.icon).font(.system(size: 18))
                            Text(ft.label).font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(facilityType == ft ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(facilityType == ft ? Color.cyan : Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(Color.cyan.opacity(0.7))
                Text(facilityType.note).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
            }
        }
        .padding(16).glassCard(borderColor: Color.cyan.opacity(0.25))
    }

    private var compMethodCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.purple)
                Text("Kompanzasyon Yöntemi").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("Önerilen: \(facilityType.defaultMethod.label)")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(Color.purple.opacity(0.7))
            }
            HStack(spacing: 6) {
                ForEach(CompMethod.allCases, id: \.self) { m in
                    Button { withAnimation { compMethod = m } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: m.icon).font(.system(size: 16))
                            Text(m.label).font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(compMethod == m ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(compMethod == m ? Color.purple : Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(compMethod.description).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).glassCard(borderColor: Color.purple.opacity(0.25))
    }

    private var loadProfileCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform").foregroundStyle(Color.orange)
                Text("Yük Profili").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(LoadProfile.allCases, id: \.self) { lp in
                    Button { withAnimation { loadProfile = lp } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: lp.icon).font(.system(size: 16))
                            Text(lp.label).font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(loadProfile == lp ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(loadProfile == lp ? Color.orange : Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: loadProfile == .pulsed ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(loadProfile == .pulsed ? Color.orange : Color.gray.opacity(0.6))
                Text(loadProfile.note).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
            }
        }
        .padding(16).glassCard(borderColor: Color.orange.opacity(0.25))
    }

    private var instantMeasurementCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "gauge.medium").foregroundStyle(amber)
                Text("Anlık Ölçüm Değerleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            inputFieldRow(label: "Aktif Güç (kW)", binding: $activePowerKW, keyboard: .numberPad)
            Divider().background(amber.opacity(0.15))
            inputFieldRow(label: "Görünür Güç (kVA)", binding: $apparentPowerKVA, keyboard: .numberPad)
            Divider().background(amber.opacity(0.15))
            Toggle(isOn: $useDirectCosPhi) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analizörden cos φ gir").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white)
                    Text("Ölçülen değeri doğrudan kullan").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
            }.tint(amber)
            if useDirectCosPhi {
                inputFieldRow(label: "cos φ (analizör)", binding: $directCosPhiStr, keyboard: .decimalPad)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16).glassCard(borderColor: amber.opacity(0.3))
    }

    private var invoiceMeasurementCard: some View {
        let (pD, sD, cosD) = invoiceDerivedValues
        return VStack(spacing: 14) {
            HStack {
                Image(systemName: "doc.text.fill").foregroundStyle(Color.cyan)
                Text("Fatura / Sayaç (Aylık)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            Text("OSOS veya faturadan aylık değerleri girin. cos φ ve güç otomatik hesaplanır.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            inputFieldRow(label: "Aktif Enerji (kWh/ay)", binding: $monthlyKWh, keyboard: .numberPad)
            Divider().background(Color.cyan.opacity(0.15))
            inputFieldRow(label: "Endüktif Reaktif (kVArh/ay)", binding: $monthlyKVArhInd, keyboard: .numberPad)
            Divider().background(Color.cyan.opacity(0.15))
            inputFieldRow(label: "Kapasitif Reaktif (kVArh/ay)", binding: $monthlyKVArhCap, keyboard: .numberPad)
            Divider().background(Color.cyan.opacity(0.15))
            HStack(spacing: 0) {
                miniMetric("P ort.", String(format: "%.1f kW", pD), .green)
                miniMetric("S ort.", String(format: "%.1f kVA", sD), amber)
                miniMetric("cos φ", String(format: "%.3f", cosD), cosD >= 0.95 ? .green : .red)
            }
        }
        .padding(16).glassCard(borderColor: Color.cyan.opacity(0.3))
    }

    private func miniMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
        }.frame(maxWidth: .infinity)
    }

    private var systemParametersCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "gearshape.fill").foregroundStyle(.gray)
                Text("Sistem Parametreleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            inputFieldRow(label: "Sistem Gerilimi (V)", binding: $systemVoltage, keyboard: .numberPad)
            Divider().background(Color.white.opacity(0.07))
            inputFieldRow(label: "Trafo Gücü (kVA)", binding: $transformerKVA, keyboard: .numberPad)
            Divider().background(Color.white.opacity(0.07))
            HStack {
                Text("Hedef cos φ").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.2f", targetCosPhi)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.green)
            }
            Slider(value: $targetCosPhi, in: 0.95...1.0, step: 0.01).tint(.green)
            if targetCosPhi <= 0.96 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("cos φ = \(String(format: "%.2f", targetCosPhi)) seçildi. TEDAŞ ceza sınırına yakın — en az 0.97 önerilir.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 2)
            }
            HStack {
                Text("Tarife (₺/kVArh)").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.2f ₺", penaltyRate)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.red)
            }
            Slider(value: $penaltyRate, in: 0.20...1.50, step: 0.05).tint(.red)
        }
        .padding(16).glassCard(borderColor: Color.white.opacity(0.1))
    }

    private var cosPhiResultCard: some View {
        let cp = computedCosPhi
        let gc: Color = cp >= 0.95 ? .green : cp >= 0.85 ? .orange : .red
        return VStack(spacing: 0) {
            HStack {
                Image(systemName: "gauge.medium").foregroundStyle(amber)
                Text("Mevcut cos φ").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 12)
            ZStack {
                Circle().trim(from: 0.5, to: 1.0)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                Circle().trim(from: 0.5, to: 0.5 + cp * 0.5)
                    .stroke(gc, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .shadow(color: gc.opacity(0.5), radius: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cp)
                VStack(spacing: 4) {
                    Text(String(format: "%.3f", cp))
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(gc)
                        .shadow(color: gc.opacity(0.4), radius: 8)
                    Text(cp >= 0.95 ? "✅ Cezasız" : cp >= 0.85 ? "⚠️ Risk" : "❌ Cezalı")
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(gc)
                    Text(String(format: "Gerekli Qc: %.1f kVAr", computedQcKVAr))
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                }
                .offset(y: 40)
            }
            .frame(height: 160)
        }
        .padding(18).glassCard(borderColor: gc.opacity(0.35))
    }

    private var penaltyResultCard: some View {
        let monthly = computedMonthlySaving
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("TEDAŞ Reaktif Enerji Cezası").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 0) {
                miniMetric("Aylık Ceza", monthly.currencyFormatted, .red)
                Divider().background(Color.red.opacity(0.3)).frame(height: 50)
                miniMetric("Yıllık Ceza", (monthly * 12).currencyFormatted, Color(red: 1, green: 0.35, blue: 0.35))
            }
        }
        .padding(18).glassCard(borderColor: Color.red.opacity(0.35))
    }

    // MARK: ── TAB 2: KADEME TASARIMI ──

    private var stepsTab: some View {
        VStack(spacing: 16) {
            requiredQcBanner
            stepCountPickerCard
            if computedQcKVAr > 0 { stepTableCard }
            mixedStepsCard
            reactorSelectionCard
            physicalSpaceCard
        }
    }

    private var requiredQcBanner: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gerekli Kompanzasyon").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                Text(String(format: "%.1f kVAr", computedQcKVAr))
                    .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    .shadow(color: Color.orange.opacity(0.5), radius: 10)
                Text("Qc = P × (tan φ₁ − tan φ₂)").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.55))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("şu an").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray)
                    Text(String(format: "%.3f", computedCosPhi)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.red)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("hedef").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray)
                    Text(String(format: "%.2f", targetCosPhi)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.green)
                }
            }
        }
        .padding(18).glassCard(borderColor: Color.orange.opacity(0.4))
    }

    private var stepCountPickerCard: some View {
        let perStep  = computedQcKVAr / Double(max(1, stepCountOption))
        let std      = nearestStandard(perStep)
        let total    = std * Double(stepCountOption)
        let excess   = total - computedQcKVAr
        let minStep  = computedQcKVAr * 0.05
        let tooSmall = std < minStep && computedQcKVAr > 0

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.purple)
                Text("Kademe Sayısı").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("Önerilen: \(loadProfile.suggestedMinSteps)+")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.purple.opacity(0.75))
            }
            HStack(spacing: 6) {
                ForEach([4, 6, 8, 12, 16], id: \.self) { cnt in
                    Button { withAnimation { stepCountOption = cnt } } label: {
                        VStack(spacing: 2) {
                            Text("\(cnt)").font(.system(size: 16, weight: .black, design: .rounded))
                            Text("kd.").font(.system(size: 9, design: .rounded))
                        }
                        .foregroundStyle(stepCountOption == cnt ? .black : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(stepCountOption == cnt ? Color.purple : Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            if computedQcKVAr > 0 {
                VStack(spacing: 6) {
                    HStack {
                        Text("Kademe başı kVAr:").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                        Spacer()
                        Text(String(format: "%.1f → standart %.0f kVAr", perStep, std))
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    HStack {
                        Text("Kurulacak toplam:").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                        Spacer()
                        Text(String(format: "%.0f kVAr", total))
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(excess < 1 ? .green : .orange)
                    }
                    if excess > 0.5 {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.orange)
                            Text(String(format: "+%.0f kVAr fazla — standart değer yuvarlandı", excess))
                                .font(.system(size: 11, design: .rounded)).foregroundStyle(.orange.opacity(0.85))
                        }
                    }
                    if tooSmall {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.red)
                            Text(String(format: "Kademe (%.0f kVAr) Qc'nin %%5'inden (%.0f kVAr) küçük — AKP hassas ayar yapamaz", std, minStep))
                                .font(.system(size: 11, design: .rounded)).foregroundStyle(.red.opacity(0.9))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.2), lineWidth: 1)))
            }
        }
        .padding(16).glassCard(borderColor: Color.purple.opacity(0.3))
    }

    private func stepMenuLabel(kvar: Double) -> some View {
        let fillColor: Color   = Color.purple.opacity(0.15)
        let strokeColor: Color = Color.purple.opacity(0.3)
        return HStack(spacing: 4) {
            Text(String(format: "%.0f kVAr", kvar))
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(Color.purple)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(fillColor)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(strokeColor, lineWidth: 1)))
    }

    private func stepRow(index i: Int) -> some View {
        let amps: Double        = contactorAmps(forKVAr: editableSteps[i])
        let rowOpacity: Double  = i % 2 == 0 ? 0.04 : 0.0
        let rowFillColor: Color = Color.purple.opacity(rowOpacity)
        return HStack {
            Text("\(i + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.purple).frame(width: 28)

            Menu {
                ForEach(Self.standardStepValues, id: \.self) { val in
                    Button(String(format: "%.0f kVAr", val)) { editableSteps[i] = val }
                }
            } label: {
                stepMenuLabel(kvar: editableSteps[i])
            }
            .frame(maxWidth: .infinity)

            Text(String(format: "%.1f A", amps))
                .font(.system(size: 12, design: .rounded)).foregroundStyle(Color.cyan)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                withAnimation { editableSteps.remove(at: i) }
            } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain).frame(width: 32)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(rowFillColor))
    }

    private var stepTableCard: some View {
        let total     = editableStepsTotal
        let shortfall = computedQcKVAr - total
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "list.number").foregroundStyle(Color.purple)
                Text("Kademe Detayı").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("\(editableSteps.count) kd. · \(String(format: "%.0f kVAr", total))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(shortfall > 0.5 ? .orange : .green)
            }

            // Kapasite karşılaştırma
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gerekli: \(String(format: "%.1f kVAr", computedQcKVAr))")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                    Text("Kurulacak: \(String(format: "%.1f kVAr", total))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(shortfall > 0.5 ? .orange : .green)
                }
                Spacer()
                if shortfall > 0.5 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.orange)
                        Text("Eksik \(String(format: "%.0f kVAr", shortfall))")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    }
                }
            }
            .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))

            // Aşırı kurulum uyarısı (yalnızca engine min. kademe nedeniyle oluşuyorsa)
            if let warning = engineOversizingWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                )
            }

            // Sütun başlıkları
            HStack {
                Text("Kd.").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(width: 28)
                Text("kVAr (Seç)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .center)
                Text("Kontaktör").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .trailing)
                Spacer().frame(width: 32)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.04)).cornerRadius(6)

            ForEach(editableSteps.indices, id: \.self) { i in
                stepRow(index: i)
            }

            Button {
                withAnimation {
                    let newVal = nearestStandard(computedQcKVAr / Double(max(1, editableSteps.count + 1)))
                    editableSteps.append(newVal)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.purple)
                    Text("Kademe Ekle").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.purple)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.25), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(16).glassCard(borderColor: Color.purple.opacity(0.25))
    }

    private var mixedStepsCard: some View {
        let mixedRaw = nearestSteps(total: computedQcKVAr, options: [12.5, 25, 50, 75, 100])
        var counts: [Double: Int] = [:]
        for s in mixedRaw { counts[s, default: 0] += 1 }
        let grouped    = counts.sorted { $0.key > $1.key }
        let mixedTotal = grouped.reduce(0.0) { $0 + $1.key * Double($1.value) }
        let mixedCount = grouped.reduce(0) { $0 + $1.value }

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "puzzlepiece.fill").foregroundStyle(Color.teal)
                Text("Karma Kademe (Alternatif)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                if !grouped.isEmpty && computedQcKVAr > 0 {
                    Text("\(mixedCount) kd. · \(String(format: "%.0f", mixedTotal)) kVAr")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.teal)
                }
            }
            Text("Fazlalık olmadan tam Qc karşılar. Büyük + küçük kondansatör karışımı.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            if grouped.isEmpty || computedQcKVAr < 1 {
                Text("Kompanzasyon gerekmez.").font(.system(size: 13, design: .rounded)).foregroundStyle(.gray)
            } else {
                ForEach(grouped, id: \.key) { pair in
                    mixedKademeRow(kvar: pair.key, count: pair.value)
                }
                Text("Karma gruplama tam ihtiyacı karşılar — sıfır fazlalık")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.teal.opacity(0.8))
                Button {
                    withAnimation { editableSteps = mixedRaw }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.teal)
                        Text("Bu Öneriyi Kullan").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.teal)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.teal.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.teal.opacity(0.25), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).glassCard(borderColor: Color.teal.opacity(0.3))
    }

    private func mixedKademeRow(kvar: Double, count: Int) -> some View {
        let fillColor: Color   = Color.teal.opacity(0.06)
        let strokeColor: Color = Color.teal.opacity(0.2)
        let labelColor: Color  = Color.teal.opacity(0.85)
        return HStack(spacing: 12) {
            Text("\(count) adet").font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black).padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.teal))
            Text("×").font(.system(size: 13)).foregroundStyle(.gray.opacity(0.5))
            Text(String(format: "%.0f kVAr", kvar))
                .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Text(String(format: "= %.0f kVAr", kvar * Double(count)))
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(labelColor)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(fillColor)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(strokeColor, lineWidth: 1)))
    }

    private var reactorSelectionCard: some View {
        let (rlabel, rfactor, rcolor, rreason) = reactorInfo
        let showForceWarning = loadProfile.forceReactor && thdPercent < 8
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3").foregroundStyle(rcolor)
                Text("Reaktör Seçimi").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text(String(format: "THD: %.1f%%", thdPercent))
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(rcolor)
            }
            HStack(spacing: 14) {
                Image(systemName: thdPercent < 5 && !showForceWarning ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(rcolor).shadow(color: rcolor.opacity(0.4), radius: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rlabel).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(rcolor)
                    Text(rreason).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                    if rfactor != "—" {
                        Text("Detuning faktörü: \(rfactor)")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(rcolor.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(rcolor.opacity(0.25), lineWidth: 1)))
            if showForceWarning {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(.orange)
                    Text("Darbeli yük profili — düşük THD'de bile reaktör önerilir")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.orange.opacity(0.9))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }
        }
        .padding(16).glassCard(borderColor: rcolor.opacity(0.3))
    }

    private var physicalSpaceCard: some View {
        let stepCnt  = editableSteps.isEmpty ? stepCountOption : editableSteps.count
        let cabinets = stepCnt > 12 ? 2 : 1
        let width    = min(400 + stepCnt * 200, 2400)
        let cc: Color = cabinets > 1 ? .orange : .green
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.3.layers.3d").foregroundStyle(amber)
                Text("Fiziksel Yer Tahmini").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 0) {
                miniMetric("Genişlik",  "\(width) mm", amber)
                miniMetric("Yükseklik", "2000 mm", .gray)
                miniMetric("Derinlik",  "600 mm", .gray)
                miniMetric("Dolap",     "\(cabinets) adet", cc)
            }
            if cabinets > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(.orange)
                    Text("\(stepCnt) kademe → 2 dolap gerekir. Kurulum alanı planlanmalı.")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.orange.opacity(0.9))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }
        }
        .padding(16).glassCard(borderColor: amber.opacity(0.3))
    }

    // MARK: ── TAB 3: SAHA ÖLÇÜM REHBERİ ──

    private var fieldTab: some View {
        VStack(spacing: 16) {
            peakAverageCard

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "map.fill").foregroundStyle(Color.cyan)
                    Text("Saha Ölçüm Rehberi")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            hideFieldGuide.toggle()
                        }
                    } label: {
                        Image(systemName: hideFieldGuide ? "chevron.down.circle" : "xmark.circle.fill")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }

                if !hideFieldGuide {
                    fieldGuideCard(icon: "number.circle.fill", color: .cyan, title: "1. OSOS / Sayaç Okuma",
                        steps: ["Dağıtım tablosundaki OSOS cihazına veya akıllı sayaca erişin.",
                                "Aktif enerji (kWh), endüktif reaktif (kVArh) ve kapasitif reaktif (kVArh) değerlerini not alın.",
                                "Aylık faturadaki 'Reaktif Bedel' satırı TEDAŞ'ın hesapladığı cezayı gösterir.",
                                "TEDAŞ online sistemi veya OSOS web arayüzünden aylık Excel raporu indirilebilir."])
                    fieldGuideCard(icon: "antenna.radiowaves.left.and.right", color: .purple, title: "2. Güç Analizörü Bağlantısı",
                        steps: ["Akım problarını faz iletkenlerine (R–S–T) takın — ok yönüne dikkat edin.",
                                "Gerilim problarını MCC giriş baralarına veya pano çıkışına bağlayın.",
                                "Cihaz otomatik olarak cos φ, THD%, kW, kVA, kVAr hesaplar.",
                                "En az 15 dakika ölçüm yapın; pik/vadi değerlerini ayrı kaydedin.",
                                "Önerilen: Fluke 435-II, Hioki PW3360, Chauvin Arnoux CA 8335"])
                    fieldGuideCard(icon: "mappin.circle.fill", color: .orange, title: "3. Ölçüm Noktası",
                        steps: ["Ana tablo (MCC) giriş barası — tesisin toplam yükünü gösterir.",
                                "Transformatör sekonder çıkışı — kompanzasyon öncesi referans noktası.",
                                "Grup kompanzasyon: her MCC veya dağıtım tablosunda ayrı ölçüm gerekir.",
                                "Münferit kompanzasyon: kritik motorların her birinde ayrı cos φ ölçümü."])
                    fieldGuideCard(icon: "clock.fill", color: .green, title: "4. Ölçüm Zamanlaması",
                        steps: ["Tam yük saatinde ölçüm yapın — genellikle mesai başlangıcı 08:00–10:00.",
                                "Gece 22:00–06:00 arası reaktif enerji 2 kat fiyatlandırılır; bu saati de kaydedin.",
                                "Sanayi: Pazartesi sabahı soğuk çalışma ile perşembe öğleden sonra tam yükü karşılaştırın.",
                                "Mevsimsel değişken tesisler için yaz/kış ayrı ölçüm gerekebilir."])
                }
            }
            .padding(16).glassCard(borderColor: Color.cyan.opacity(0.2))
        }
    }

    private var peakModeContent: some View {
        let pkW   = Double(peakActivePowerKW) ?? 0
        let pkVA  = max(1, Double(peakApparentKVA) ?? 1)
        let pkCos = pkW / pkVA
        let pkQc  = pkCos < targetCosPhi && pkW > 0
            ? pkW * (tan(acos(max(0.001, pkCos))) - tan(acos(targetCosPhi))) : 0.0
        let sizing = String(format: "Boyutlandırma: max(%.0f, %.0f) = %.0f kVAr kullanın",
                            pkQc, computedQcKVAr, max(pkQc, computedQcKVAr))
        let bgFillColor: Color = Color.red.opacity(0.07)
        return VStack(spacing: 10) {
            Text("Pik ölçüm en kötü senaryoyu belirler — AKP boyutlandırması buna göre yapılır.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            HStack {
                Text("PIK (Tam Yük)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.red)
                Spacer()
            }
            inputFieldRow(label: "Aktif Güç (kW)",    binding: $peakActivePowerKW, keyboard: .numberPad)
            inputFieldRow(label: "Görünür Güç (kVA)", binding: $peakApparentKVA,   keyboard: .numberPad)
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 0) {
                miniMetric("Pik cos φ", String(format: "%.3f", pkCos), pkCos >= 0.95 ? .green : .red)
                miniMetric("Pik Qc",    String(format: "%.0f kVAr", pkQc), .orange)
                miniMetric("Ort. Qc",   String(format: "%.0f kVAr", computedQcKVAr), amber)
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 12)).foregroundStyle(.red)
                Text(sizing).font(.system(size: 11, design: .rounded)).foregroundStyle(.red.opacity(0.9))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(bgFillColor))
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var peakAverageCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.xaxis").foregroundStyle(Color.orange)
                Text("Pik / Ortalama Yük Karşılaştırması").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: $usePeakMode).tint(Color.orange).labelsHidden()
            }
            if usePeakMode {
                peakModeContent
            } else {
                Text("Etkinleştirin: Pik ve ortalama yük ayrı ölçülerek en kötü durum AKP boyutu belirlenir.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
            }
        }
        .padding(16).glassCard(borderColor: Color.orange.opacity(0.3))
    }

    private func fieldGuideCard(icon: String, color: Color, title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            ForEach(Array(steps.enumerated()), id: \.0) { _, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("·").font(.system(size: 14, weight: .bold)).foregroundStyle(color).frame(width: 10)
                    Text(step).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(16).glassCard(borderColor: color.opacity(0.25))
    }

    // MARK: ── TAB 4: HARMONİK ──

    private var harmonicTab: some View {
        let trafoKVA   = Double(transformerKVA) ?? 250.0
        let sccKVA     = trafoKVA / 0.06
        let resonanceHz = computedQcKVAr > 0 ? frequency * sqrt(sccKVA / computedQcKVAr) : 0.0
        let rc: Color  = thdPercent < 5 ? .green : thdPercent < 15 ? .orange : .red
        let rtxt        = thdPercent < 5 ? "Düşük Risk" : thdPercent < 15 ? "Orta Risk" : "Yüksek Risk"

        return VStack(spacing: 16) {
            harmonicInfoCard(icon: "waveform.path",          color: .purple, title: "THD Nedir?",
                body: "THD (Toplam Harmonik Distorsiyon), şebeke geriliminin saf sinüs dalgasından ne kadar saptığını gösteren yüzdedir. THD arttıkça kondansatörler ısınır, trafolar erken yıpranır, sigortalar gereksiz atar.")
            harmonicInfoCard(icon: "platter.2.filled.iphone", color: .cyan,   title: "Sahada Nasıl Ölçülür?",
                body: "Power quality analizörü kullanın. Akım problarını faz iletkenlerine, gerilim problarını şebeke bağlantı noktasına bağlayın. Cihaz THD% değerini doğrudan gösterir. İnvertör, VFD ve kaynak makinesi bulunan tesislerde düzenli ölçüm yapın.")
            harmonicInfoCard(icon: "exclamationmark.triangle", color: .orange, title: "Ne Zaman Sorun Olur?",
                body: "IEC 61000-3-12 / EN 50160: %5 altı normal · %5–8 dikkat · %8 üzeri reaktörsüz kondansatör kurmak tehlikelidir. Özellikle kompanzasyon devreye girince rezonans riski artar.")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "waveform.path.ecg").foregroundStyle(Color.purple)
                    Text("THD (%)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("0", text: $thdText)
                            .keyboardType(.decimalPad).frame(width: 50)
                            .multilineTextAlignment(.trailing).styledInput()
                            .onChange(of: thdText) { _, v in
                                let c = v.replacingOccurrences(of: ",", with: ".")
                                if let d = Double(c), d >= 0, d <= 40 { thdPercent = d }
                            }
                        Text("%").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(rc)
                    }
                }
                Slider(value: $thdPercent, in: 0...40, step: 0.5).tint(rc)
                    .onChange(of: thdPercent) { _, v in thdText = String(format: "%.1f", v) }
                HStack {
                    Text("Temiz").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                    Spacer()
                    Text("Kritik").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                }
            }
            .padding(18).glassCard(borderColor: rc.opacity(0.4))

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(Color.cyan)
                    Text("Rezonans Frekansı").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Text(String(format: "%.1f Hz", resonanceHz))
                    .font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 10)
                Text("fr = f₀ × √(Scc / Qc)").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.55))
            }
            .padding(18).glassCard(borderColor: Color.cyan.opacity(0.35))

            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(rc.opacity(0.15)).frame(width: 64, height: 64)
                    Circle().fill(rc.opacity(0.3)).frame(width: 44, height: 44)
                    Image(systemName: rc == .green ? "checkmark.circle.fill" : rc == .orange ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 28)).foregroundStyle(rc)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Risk Seviyesi").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                    Text(rtxt).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(rc)
                    Text("IEC 61000-3-12 standardı").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                }
                Spacer()
            }
            .padding(18).glassCard(borderColor: rc.opacity(0.4))

            reactorTableCard
        }
    }

    private var reactorTableCard: some View {
        let rows: [(thd: String, reactor: String, hz: String, color: Color)] = [
            ("< %5",  "Reaktör Gerekmez",      "—",      .green),
            ("%5–8",  "%5.67 Detuned",          "210 Hz", .orange),
            ("%8–20", "%7 Detuned",              "189 Hz", Color(red:1,green:0.5,blue:0)),
            ("> %20", "%14 / Aktif Filtre",     "134 Hz", .red),
        ]
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(amber)
                Text("Reaktör Seçim Tablosu").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack {
                Text("THD").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(width: 55, alignment: .leading)
                Text("Reaktör").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)
                Text("Rezonans Hz").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(width: 75, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.white.opacity(0.04)).cornerRadius(6)

            ForEach(Array(rows.enumerated()), id: \.0) { i, row in
                reactorTableRow(row, active: reactorRowActive(index: i))
            }
        }
        .padding(16).glassCard(borderColor: amber.opacity(0.25))
    }

    private func reactorRowActive(index: Int) -> Bool {
        switch index {
        case 0: return thdPercent < 5
        case 1: return thdPercent >= 5  && thdPercent < 8
        case 2: return thdPercent >= 8  && thdPercent < 20
        default: return thdPercent >= 20
        }
    }

    private func reactorTableRow(_ row: (thd: String, reactor: String, hz: String, color: Color), active: Bool) -> some View {
        let fillColor: Color   = row.color.opacity(0.1)
        let strokeColor: Color = row.color.opacity(0.3)
        return HStack {
            Text(row.thd).font(.system(size: 11, weight: active ? .bold : .regular, design: .rounded))
                .foregroundStyle(active ? row.color : .gray).frame(width: 55, alignment: .leading)
            Text(row.reactor).font(.system(size: 11, weight: active ? .bold : .regular, design: .rounded))
                .foregroundStyle(active ? .white : .gray.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading)
            Text(row.hz).font(.system(size: 11, weight: active ? .bold : .regular, design: .rounded))
                .foregroundStyle(active ? row.color : .gray.opacity(0.6)).frame(width: 75, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(active
            ? RoundedRectangle(cornerRadius: 8).fill(fillColor)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(strokeColor, lineWidth: 1))
            : nil)
    }

    private func harmonicInfoCard(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(body).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).background(color.opacity(0.07)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: ── TAB 5: EKONOMİK ANALİZ ──

    private var economyTab: some View {
        VStack(spacing: 16) {
            investmentBreakdownCard
            savingsBreakdownCard
            projectionTableCard
            roiSummaryCard
            scenarioComparisonCard
        }
    }

    private var investmentBreakdownCard: some View {
        let (defCap, defCon, defReactor, defPanel, defLabor) = defaultCosts
        let total = totalInvestment
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "banknote.fill").foregroundStyle(amber)
                Text("Yatırım Kalemleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text(total.currencyFormatted).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(amber)
            }
            Text("Tahmini değerler. Düzenlemek için üzerine yazın.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            costRow("Kondansatör",                   binding: $capCostStr,       placeholder: defCap,    icon: "cylinder.split.1x2.fill", color: .cyan)
            costRow("Kontaktörler (\(stepCountOption) adet)", binding: $contactorCostStr, placeholder: defCon,    icon: "switch.2",               color: .purple)
            costRow("Reaktör\(thdPercent >= 5 ? "" : " (gerekmez)")", binding: $reactorCostStr, placeholder: defReactor, icon: "slider.horizontal.3",    color: thdPercent >= 5 ? .orange : .gray)
            costRow("Pano / Montaj Malzeme",          binding: $panelCostStr,     placeholder: defPanel,  icon: "square.3.layers.3d",      color: amber)
            costRow("İşçilik",                        binding: $laborCostStr,     placeholder: defLabor,  icon: "person.fill",             color: .green)
            Divider().background(amber.opacity(0.3))
            HStack {
                Text("TOPLAM YATIRIM").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.gray)
                Spacer()
                Text(total.currencyFormatted).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(amber)
            }
        }
        .padding(16).glassCard(borderColor: amber.opacity(0.3))
    }

    private func costRow(_ label: String, binding: Binding<String>, placeholder: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 20)
            Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading)
            TextField(String(Int(placeholder)), text: binding)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(color)
                .frame(width: 90).styledInput()
            Text("₺").font(.system(size: 12)).foregroundStyle(.gray)
        }
    }

    private var savingsBreakdownCard: some View {
        let (penalty, copper, total) = monthlySavingsBreakdown
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis").foregroundStyle(Color.green)
                Text("Aylık Tasarruf Kalemleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text(total.currencyFormatted).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.green)
            }
            savingBar("TEDAŞ Ceza Kaçınımı",    value: penalty, total: total, color: .red)
            savingBar("Bakır Kaybı Azalması",    value: copper,  total: total, color: .orange)
            Divider().background(Color.green.opacity(0.3))
            HStack {
                Text("TOPLAM AYLIK TASARRUF").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.gray)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(total.currencyFormatted).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.green)
                    Text("Yıllık: \((total * 12).currencyFormatted)").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                }
            }
        }
        .padding(16).glassCard(borderColor: Color.green.opacity(0.3))
    }

    private func savingBar(_ label: String, value: Double, total: Double, color: Color) -> some View {
        let pct = total > 0 ? value / total : 0
        return VStack(spacing: 5) {
            HStack {
                Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(value.currencyFormatted).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * pct, height: 6)
                        .animation(.spring(response: 0.6), value: pct)
                }
            }.frame(height: 6)
        }
    }

    private var projectionTableCard: some View {
        let (_, _, totalMonthly) = monthlySavingsBreakdown
        let inv = totalInvestment
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundStyle(Color.cyan)
                Text("Projeksiyon Tablosu").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack {
                Text("Yıl").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(width: 28)
                Text("Kümülatif Tasarruf").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .trailing)
                Text("Net (−Yatırım)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.vertical, 5).background(Color.white.opacity(0.04)).cornerRadius(6)

            ForEach([1, 3, 5, 10], id: \.self) { yr in
                let cum = totalMonthly * 12 * Double(yr)
                let net = cum - inv
                HStack {
                    Text("\(yr)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(width: 28)
                    Text(cum.currencyFormatted).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.cyan).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(net.currencyFormatted).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(net >= 0 ? .green : .red).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(net >= 0 ? Color.green.opacity(0.06) : Color.red.opacity(0.04)))
            }
        }
        .padding(16).glassCard(borderColor: Color.cyan.opacity(0.25))
    }

    private var roiSummaryCard: some View {
        let (_, _, totalMonthly) = monthlySavingsBreakdown
        let inv = totalInvestment
        let payback = totalMonthly > 0 ? inv / totalMonthly : 999
        return HStack(spacing: 0) {
            miniMetric("Geri Ödeme",   String(format: "%.1f ay", payback), .green)
            Divider().background(amber.opacity(0.2)).frame(height: 55)
            miniMetric("Aylık Tasarruf", totalMonthly.currencyFormatted, .cyan)
            Divider().background(amber.opacity(0.2)).frame(height: 55)
            miniMetric("10Y Net", (totalMonthly * 120 - inv).currencyFormatted, amber)
        }
        .padding(16).glassCard(borderColor: Color.green.opacity(0.3))
    }

    private var scenarioComparisonCard: some View {
        let (_, _, totalMonthly) = monthlySavingsBreakdown
        let centralInv = totalInvestment
        let groupInv   = centralInv * 1.30
        let groupSave  = totalMonthly * 1.20
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill").foregroundStyle(Color.purple)
                Text("Senaryo Karşılaştırması").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 10) {
                scenarioCell("Merkezi AKP",  investment: centralInv, monthly: totalMonthly, color: .purple, note: "Trafo çıkışı — basit")
                scenarioCell("Grup Komp.",   investment: groupInv,   monthly: groupSave,    color: .teal,   note: "MCC bazlı, hat kaybı azalır")
            }
        }
        .padding(16).glassCard(borderColor: Color.purple.opacity(0.25))
    }

    private func scenarioCell(_ title: String, investment: Double, monthly: Double, color: Color, note: String) -> some View {
        let pb = monthly > 0 ? investment / monthly : 999
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(note).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
            Divider().background(color.opacity(0.2))
            HStack { Text("Yatırım:").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray); Spacer(); Text(investment.currencyFormatted).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white) }
            HStack { Text("Aylık:").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray); Spacer(); Text(monthly.currencyFormatted).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.green) }
            HStack { Text("Geri ödeme:").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray); Spacer(); Text(String(format: "%.1f ay", pb)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(color) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1)))
    }

    // MARK: ── TAB 6: RAPOR VE TEKLİF ──

    private var reportTab: some View {
        VStack(spacing: 16) {
            customerSummaryCard
            technicalSummaryCard
            standardsCard
            actionButtonsView
        }
    }

    private var customerSummaryCard: some View {
        let (_, _, totalMonthly) = monthlySavingsBreakdown
        let inv = totalInvestment
        let pb  = totalMonthly > 0 ? inv / totalMonthly : 999
        let pbStr = pb < 120
            ? String(format: "%.0f ay (%.1f yıl)", pb, pb / 12)
            : "> 10 yıl"
        let stepCnt = editableSteps.isEmpty ? stepCountOption : editableSteps.count
        let stepTotal = editableSteps.isEmpty ? nearestStandard(computedQcKVAr / Double(max(1, stepCountOption))) * Double(stepCountOption) : editableStepsTotal
        return VStack(spacing: 14) {
            HStack {
                Image(systemName: "person.fill.checkmark").foregroundStyle(.green)
                Text("Müşteri Özeti").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("Sade Anlatım").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 10) {
                summaryLine("📌", "Mevcut cos φ: \(String(format: "%.3f", computedCosPhi)) — Hedef: \(String(format: "%.2f", targetCosPhi))")
                summaryLine("⚡", "Şu an aylık tahmini \(computedMonthlySaving.currencyFormatted) reaktif enerji cezası ödüyorsunuz.")
                summaryLine("🔧", "Gerekli kondansatör: \(String(format: "%.1f kVAr", computedQcKVAr)) — \(stepCnt) kademe · kurulacak: \(String(format: "%.0f kVAr", stepTotal))")
                summaryLine("💰", "Tahmini toplam yatırım: \(inv.currencyFormatted)")
                summaryLine("📅", "Yatırım geri ödeme: \(pbStr)")
                summaryLine("✅", "Kompanzasyon sonrası TEDAŞ cezası sıfıra iner, trafo kapasitesi artar.")
            }
        }
        .padding(18).glassCard(borderColor: Color.green.opacity(0.35))
    }

    private func summaryLine(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji).font(.system(size: 14))
            Text(text).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.85))
        }
    }

    private var technicalSummaryCard: some View {
        let stepCntT = editableSteps.isEmpty ? stepCountOption : editableSteps.count
        let stepTotalT = editableSteps.isEmpty ? nearestStandard(computedQcKVAr / Double(max(1, stepCountOption))) * Double(stepCountOption) : editableStepsTotal
        let (rlabel, _, _, _) = reactorInfo
        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "doc.text.fill").foregroundStyle(amber)
                Text("Teknik Özet").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            rptRow("Kompanzasyon Gücü",    String(format: "%.1f kVAr", computedQcKVAr), .orange)
            rptRow("Kademe",               "\(stepCntT) kd. · \(String(format: "%.0f kVAr", stepTotalT)) kurulu", .purple)
            rptRow("Pano Tipi",            computedQcKVAr > 50 ? "Otomatik (AKP)" : "Sabit Kondansatör", .white)
            rptRow("Reaktör",              rlabel, thdPercent >= 5 ? .orange : .green)
            rptRow("Yöntem",               compMethod.label, .cyan)
            rptRow("Tesis",                facilityType.label, .white)
            rptRow("Gerilim",              "\(systemVoltage) V", .white)
            rptRow("THD",                  String(format: "%.1f%%", thdPercent), thdPercent < 5 ? .green : thdPercent < 8 ? .orange : .red)
        }
        .padding(18).glassCard(borderColor: amber.opacity(0.35))
    }

    private func rptRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
    }

    private var standardsCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Standart Uyumluluk").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            stdBadge("IEC 61921",      "Power factor correction capacitors")
            stdBadge("EN 60831",       "Shunt power capacitors — self-healing type")
            stdBadge("IEC 61000-3-12", "Harmonics — Industrial systems >16A")
            stdBadge("TS EN 50160",    "Şebeke gerilim karakteristikleri")
            stdBadge("IEC 60947-4-1",  "Kontaktör seçimi — inrush × 1.43")
        }
        .padding(18).glassCard(borderColor: Color.green.opacity(0.3))
    }

    private func stdBadge(_ std: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(std).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(desc).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
            Spacer()
        }
    }

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button {
                guard computedCosPhi > 0 else { return }
                guard computedCosPhi < targetCosPhi else {
                    showNoCompensationAlert = true
                    return
                }
                let pKW = effectiveActivePowerKW
                let sKVA = effectiveApparentPowerKVA
                let input = CompensationInput(
                    activePowerKW: pKW,
                    apparentPowerKVA: sKVA,
                    measuredCosPhi: max(0.001, min(computedCosPhi, targetCosPhi - 0.001)),
                    targetCosPhi: targetCosPhi,
                    systemVoltageV: Double(systemVoltage) ?? 400,
                    transformerKVA: Double(transformerKVA),
                    totalHarmonicDistortion: thdPercent,
                    electricityTariff: penaltyRate,
                    investmentCostTL: totalInvestment
                )
                if var result = try? CompensationEngine.calculate(input: input) {
                    // Kullanıcının elle düzenlediği kademeleri engine sonucuna yansıt
                    if !editableSteps.isEmpty {
                        result.selectedSteps     = stepsAsCapacitorSteps()
                        result.totalInstalledKVAr = editableStepsTotal
                        result.stepCount         = editableSteps.count
                        let maxKVAr              = editableSteps.max() ?? result.stepSizeKVAr
                        result.contactorCurrentA = contactorAmps(forKVAr: maxKVAr)
                        let cabinets = editableSteps.count > 12 ? 2 : 1
                        let width    = min(400 + editableSteps.count * 200, 2400)
                        result.panelSizeDescription = "\(width) mm genişlik · \(cabinets) dolap"
                    }
                    pendingQuoteItems = QuoteEngine.itemsFromCompensation(result)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showCustomerPicker = true
                }
            } label: {
                Label("Teklif'e Ekle", systemImage: "doc.badge.plus")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(amber).shadow(color: amber.opacity(0.4), radius: 8, y: 4))
            }
            .buttonStyle(.plain)
            .alert("Kompanzasyon Gerekmiyor", isPresented: $showNoCompensationAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Mevcut cos φ (\(String(format: "%.3f", computedCosPhi))) hedefi (\(String(format: "%.3f", targetCosPhi))) zaten karşılıyor — reaktif güç kompanzasyonuna gerek yok.")
            }

            Button {
                let pdfData = PDFService.generateCompensationReportPDF(
                    activePowerKW:    effectiveActivePowerKW,
                    apparentPowerKVA: effectiveApparentPowerKVA,
                    currentCosPhi:    computedCosPhi,
                    targetCosPhi:     targetCosPhi,
                    requiredQcKVAr:   computedQcKVAr,
                    thdPercent:       thdPercent,
                    penaltyRate:      penaltyRate,
                    monthlySaving:    computedMonthlySaving,
                    investmentCost:   totalInvestment,
                    transformerKVA:   Double(transformerKVA) ?? 250,
                    settings:         persistence.settings
                )
                ShareService.sharePDF(data: pdfData, filename: "Kompanzasyon-Raporu")
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("PDF Raporu", systemImage: "doc.richtext.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hesaplamalar

    private var invoiceDerivedValues: (p: Double, s: Double, cosPhi: Double) {
        let kwh = Double(monthlyKWh) ?? 0
        let qi  = Double(monthlyKVArhInd) ?? 0
        let qc  = Double(monthlyKVArhCap) ?? 0
        guard kwh > 0 else { return (0, 0, 1.0) }
        let netQ  = qi - qc
        let sKVAh = sqrt(kwh * kwh + netQ * netQ)
        let cos   = sKVAh > 0 ? min(1.0, kwh / sKVAh) : 1.0
        return (kwh / 720.0, sKVAh / 720.0, cos)
    }

    private var effectiveActivePowerKW: Double {
        switch inputMode {
        case .instant: return Double(activePowerKW) ?? 0
        case .invoice: return invoiceDerivedValues.p
        }
    }

    private var effectiveApparentPowerKVA: Double {
        switch inputMode {
        case .instant: return Double(apparentPowerKVA) ?? 0
        case .invoice: return invoiceDerivedValues.s
        }
    }

    private func recalculate() {
        let p = effectiveActivePowerKW
        let s = effectiveApparentPowerKVA
        guard s > 0 else { computedCosPhi = 0; return }

        let cos: Double
        if inputMode == .instant && useDirectCosPhi {
            cos = max(0.001, min(Double(directCosPhiStr) ?? (p / s), 0.9999))
        } else {
            cos = p / s
        }
        computedCosPhi = cos

        let phi1 = acos(max(0.001, min(cos, 0.9999)))
        let phi2 = acos(targetCosPhi)
        computedQcKVAr = max(0, p * (tan(phi1) - tan(phi2)))

        let qReactive     = sqrt(max(0, s * s - p * p))
        let penaltyQ      = max(0, qReactive - p * 0.33)
        computedMonthlySaving = penaltyQ * 720 * penaltyRate

        // Aşırı kurulum uyarısı — engine kademeleri üzerinden kontrol
        if computedQcKVAr > 0 {
            let eSteps = CompensationEngine.selectCapacitorSteps(totalQcKVAr: computedQcKVAr)
            let eTotal = eSteps.reduce(0.0) { $0 + $1.totalKVAr }
            let ratio  = (eTotal - computedQcKVAr) / computedQcKVAr
            engineOversizingWarning = ratio > 0.5
                ? String(format: "Kurulan kapasite ihtiyacın %%%.0f üzerinde — minimum standart kademe (2.5 kVAr) küçük yükler için orantısız büyük kalıyor, sabit kondansatörlü özel çözüm değerlendirilebilir.", ratio * 100)
                : nil
        } else {
            engineOversizingWarning = nil
        }

        rebuildEditableSteps()
    }

    // MARK: - Computed Helpers

    private var reactorInfo: (label: String, factor: String, color: Color, reason: String) {
        if thdPercent < 5 {
            return ("Reaktör Gerekmez", "—", .green, "THD < %5 — şebeke temiz")
        } else if thdPercent < 8 {
            return ("%5.67 Detuned Reaktör", "p = 0.0567", .orange, "250 Hz koruma — 5. harmonik")
        } else if thdPercent < 20 {
            return ("%7 Detuned Reaktör", "p = 0.07", Color(red:1,green:0.5,blue:0), "189 Hz rezonans — 7. harmonik")
        } else {
            return ("%14 / Aktif Filtre", "p = 0.14", .red, "3. harmonik koruması — aktif filtre değerlendirin")
        }
    }

    private var defaultCosts: (cap: Double, con: Double, reactor: Double, panel: Double, labor: Double) {
        let cnt      = editableSteps.isEmpty ? stepCountOption : editableSteps.count
        let total    = editableSteps.isEmpty ? nearestStandard(computedQcKVAr / Double(max(1, stepCountOption))) * Double(stepCountOption) : editableStepsTotal
        let cap      = total * 150
        let con      = Double(cnt) * 800
        let reactor  = thdPercent >= 5 ? total * 200 : 0
        let panel: Double = cnt > 12 ? 18000 : cnt > 6 ? 12000 : 6000
        let labor    = (cap + con + reactor + panel) * 0.18
        return (cap, con, reactor, panel, labor)
    }

    private var totalInvestment: Double {
        let (dc, dn, dr, dp, dl) = defaultCosts
        let cap     = Double(capCostStr)       ?? dc
        let con     = Double(contactorCostStr)  ?? dn
        let reactor = Double(reactorCostStr)   ?? dr
        let panel   = Double(panelCostStr)     ?? dp
        let labor   = Double(laborCostStr)     ?? dl
        return cap + con + reactor + panel + labor
    }

    private var monthlySavingsBreakdown: (penalty: Double, copper: Double, total: Double) {
        let penalty = computedMonthlySaving
        let trafoKVA = Double(transformerKVA) ?? 250
        let sKVA = effectiveApparentPowerKVA
        let pKW  = effectiveActivePowerKW
        let newQ = max(0, sqrt(max(0, sKVA * sKVA - pKW * pKW)) - computedQcKVAr)
        let newS = sqrt(pKW * pKW + newQ * newQ)
        let lossRed = (pow(sKVA / max(1, trafoKVA), 2) - pow(newS / max(1, trafoKVA), 2)) * 100
        let copper  = max(0, (trafoKVA * 0.015) * (lossRed / 100) * 720 * penaltyRate)
        return (penalty, copper, penalty + copper)
    }

    // MARK: - Yardımcı Fonksiyonlar

    private func nearestStandard(_ kvar: Double) -> Double {
        let s: [Double] = [2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60, 75, 100]
        return s.min(by: { abs($0 - kvar) < abs($1 - kvar) }) ?? 25
    }

    private static let standardStepValues: [Double] = [2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60, 75, 100]

    private var editableStepsTotal: Double { editableSteps.reduce(0, +) }

    private func rebuildEditableSteps() {
        guard computedQcKVAr > 0, stepCountOption > 0 else { editableSteps = []; return }
        let std = nearestStandard(computedQcKVAr / Double(stepCountOption))
        editableSteps = Array(repeating: std, count: stepCountOption)
    }

    private func contactorAmps(forKVAr kvar: Double) -> Double {
        let v = Double(systemVoltage) ?? 400
        return (kvar * 1000.0) / (sqrt(3.0) * v) * 1.43
    }

    private func stepsAsCapacitorSteps() -> [CapacitorStep] {
        var counts: [Double: Int] = [:]
        for s in editableSteps { counts[s, default: 0] += 1 }
        return counts.sorted { $0.key > $1.key }.map { CapacitorStep(ratingKVAr: $0.key, quantity: $0.value) }
    }


    private func nearestSteps(total: Double, options: [Double]) -> [Double] {
        var rem = total; var res: [Double] = []
        for s in options.sorted(by: >) { while rem >= s { res.append(s); rem -= s } }
        return res.sorted(by: >)
    }

    private func inputFieldRow(label: String, binding: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            TextField("0", text: binding).keyboardType(keyboard)
                .multilineTextAlignment(.trailing).frame(width: 110).styledInput()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { CompensationCalculatorView() }
        .preferredColorScheme(.dark)
}
