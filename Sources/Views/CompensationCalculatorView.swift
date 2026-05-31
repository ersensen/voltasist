// CompensationCalculatorView.swift
// VoltAsist
//
// 7 sekmeli reaktif güç kompanzasyonu hesaplama ekranı.
// Mevcut durum, kondansatör, AKP, harmonik, transformatör, ekonomi ve rapor sekmeleri.

import SwiftUI
import Charts

// MARK: - Kompanzasyon Sekmeleri

enum CompTab: Int, CaseIterable {
    case current      = 0
    case capacitor    = 1
    case akp          = 2
    case harmonic     = 3
    case transformer  = 4
    case economy      = 5
    case report       = 6

    var title: String {
        switch self {
        case .current:     return "Durum"
        case .capacitor:   return "Kondansatör"
        case .akp:         return "AKP"
        case .harmonic:    return "Harmonik"
        case .transformer: return "Trafo"
        case .economy:     return "Ekonomi"
        case .report:      return "Rapor"
        }
    }

    var icon: String {
        switch self {
        case .current:     return "gauge.medium"
        case .capacitor:   return "cylinder.split.1x2.fill"
        case .akp:         return "square.grid.2x2.fill"
        case .harmonic:    return "waveform.path.ecg"
        case .transformer: return "arrow.triangle.2.circlepath"
        case .economy:     return "chart.line.uptrend.xyaxis"
        case .report:      return "doc.text.fill"
        }
    }
}

// MARK: - CompensationCalculatorView

/// Kompanzasyon hesap ekranı — 7 sekme
struct CompensationCalculatorView: View {

    // MARK: State — Sekme
    @State private var selectedTab: CompTab = .current

    // MARK: State — Ortak Parametreler
    @State private var activePowerKW: String     = "100"
    @State private var apparentPowerKVA: String  = "140"
    @State private var targetCosPhi: Double      = 0.95
    @State private var systemVoltage: String     = "400"
    @State private var frequency: Double         = 50.0

    // MARK: State — Ekonomi
    @State private var investmentCost: String    = "25000"
    @State private var penaltyRate: Double       = 0.40    // TL/kVAr

    // MARK: State — Harmonik
    @State private var thdPercent: Double        = 10.0

    // MARK: State — Transformatör
    @State private var transformerKVA: String    = "250"

    // MARK: State — Hesaplanan (paylaşılan)
    @State private var currentCosPhi: Double     = 0.0
    @State private var requiredQcKVAr: Double    = 0.0
    @State private var monthlySaving: Double     = 0.0

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            // Tab seçici
            compTabSelector

            // İçerik
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    tabContent
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 100)
                }
            }
        }
        .background(bgColor.ignoresSafeArea())
        .onAppear { recalculate() }
        .onChange(of: activePowerKW)    { _, _ in recalculate() }
        .onChange(of: apparentPowerKVA) { _, _ in recalculate() }
        .onChange(of: targetCosPhi)     { _, _ in recalculate() }
    }

    // MARK: - Sekme Seçici

    private var compTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CompTab.allCases, id: \.rawValue) { tab in
                    compTabButton(tab)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
    }

    @ViewBuilder
    private func compTabButton(_ tab: CompTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedTab = tab
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.gray.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.purple : Color(red: 0.15, green: 0.15, blue: 0.18))
                    .shadow(color: isSelected ? Color.purple.opacity(0.4) : .clear, radius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab İçeriği

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .current:     currentStatusTab
        case .capacitor:   capacitorTab
        case .akp:         akpTab
        case .harmonic:    harmonicTab
        case .transformer: transformerTab
        case .economy:     economyTab
        case .report:      reportTab
        }
    }

    // MARK: ── SEKME 1: Mevcut Durum ──

    private var currentStatusTab: some View {
        VStack(spacing: 16) {
            // Güç girişleri
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(amber)
                    Text("Mevcut Yük Durumu")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                .padding(.bottom, 4)

                inputFieldRow(label: "Aktif Güç (kW)", binding: $activePowerKW, keyboard: .numberPad)
                Divider().background(amber.opacity(0.15))
                inputFieldRow(label: "Görünür Güç (kVA)", binding: $apparentPowerKVA, keyboard: .numberPad)
            }
            .padding(18)
            .glassCard(borderColor: amber.opacity(0.3))

            // cos φ gauge animasyonu
            cosPhiGauge

            // TEDAŞ ceza kartı
            penaltyCard

            // Hedef cos φ
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🎯 Hedef cos φ")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(String(format: "%.2f", targetCosPhi))
                        .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.green)
                }
                Slider(value: $targetCosPhi, in: 0.90...1.0, step: 0.01)
                    .tint(Color.green)
            }
            .padding(18)
            .glassCard(borderColor: Color.green.opacity(0.3))
        }
    }

    private var cosPhiGauge: some View {
        let cosPhi = currentCosPhi
        let isGood = cosPhi >= 0.95
        let isMedium = cosPhi >= 0.85

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "gauge.medium").foregroundStyle(amber)
                Text("Mevcut cos φ").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            ZStack {
                // Arka plan arc
                Arc(startAngle: .degrees(180), endAngle: .degrees(360))
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))

                // Dolu arc
                Arc(startAngle: .degrees(180), endAngle: .degrees(180 + cosPhi * 180))
                    .stroke(
                        isGood ? Color.green : isMedium ? Color.orange : Color.red,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .shadow(color: (isGood ? Color.green : isMedium ? Color.orange : Color.red).opacity(0.5), radius: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cosPhi)

                VStack(spacing: 4) {
                    Text(String(format: "%.3f", cosPhi))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(isGood ? Color.green : isMedium ? Color.orange : Color.red)
                        .shadow(color: (isGood ? Color.green : isMedium ? Color.orange : Color.red).opacity(0.4), radius: 8)
                    Text(isGood ? "✅ İyi" : isMedium ? "⚠️ Orta" : "❌ Yetersiz")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isGood ? Color.green : isMedium ? Color.orange : Color.red)
                }
                .offset(y: 20)
            }
            .frame(height: 140)
            .padding(.vertical, 8)
        }
        .padding(18)
        .glassCard(borderColor: (isGood ? Color.green : Color.red).opacity(0.35))
    }

    private var penaltyCard: some View {
        let monthly = requiredQcKVAr > 0 ? requiredQcKVAr * penaltyRate * 30 : 0
        let yearly  = monthly * 12

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("TEDAŞ Reaktif Enerji Cezası")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                penaltyCellView(label: "Aylık Ceza", value: monthly.currencyFormatted, color: .red)
                Divider().background(Color.red.opacity(0.3)).frame(height: 50)
                penaltyCellView(label: "Yıllık Ceza", value: yearly.currencyFormatted, color: Color(red: 1, green: 0.3, blue: 0.3))
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.red.opacity(0.35))
    }

    private func penaltyCellView(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: ── SEKME 2: Kondansatör ──

    private var capacitorTab: some View {
        VStack(spacing: 16) {
            // Gerekli Qc
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "cylinder.split.1x2.fill").foregroundStyle(Color.purple)
                    Text("Gerekli Kondansatör Gücü")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Text(String(format: "%.1f kVAr", requiredQcKVAr))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                    .shadow(color: Color.orange.opacity(0.5), radius: 10)
                Text("Qc = P × (tan φ₁ - tan φ₂)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.55))
            }
            .padding(18)
            .glassCard(borderColor: Color.orange.opacity(0.4))

            // Standart basamaklar
            standardStepsCard

            // Kapasitans hesabı
            capacitanceCard

            // Tip önerisi
            compensationTypeCard
        }
    }

    private var standardStepsCard: some View {
        let steps: [Double] = [5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60]
        let selectedSteps = nearestSteps(total: requiredQcKVAr, options: steps)

        return VStack(spacing: 12) {
            HStack {
                Text("📋 Standart Kademeler")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            ForEach(selectedSteps, id: \.self) { step in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                    Text("\(Int(step)) kVAr kondansatör")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("C = \(String(format: "%.1f", capacitance(kvar: step))) μF")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.cyan)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
                )
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.green.opacity(0.3))
    }

    private var capacitanceCard: some View {
        let c = capacitance(kvar: requiredQcKVAr)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kapasitans").font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(String(format: "%.1f μF", c))
                    .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color.cyan)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Formül").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                Text("C = Qc / (2πfU²)")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.cyan.opacity(0.3))
    }

    private var compensationTypeCard: some View {
        let isAuto = requiredQcKVAr > 50
        return HStack(spacing: 14) {
            Image(systemName: isAuto ? "cpu.fill" : "minus.plus.batteryblock.fill")
                .font(.system(size: 28))
                .foregroundStyle(isAuto ? Color.purple : amber)
                .shadow(color: (isAuto ? Color.purple : amber).opacity(0.5), radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tip Önerisi")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(isAuto ? "Otomatik Kompanzasyon (AKP)" : "Sabit Kondansatör Grubu")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(isAuto ? "Değişken yük için idealdir" : "Sabit yük için uygun")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
            Spacer()
            Text(isAuto ? "OTOMATİK" : "SABİT")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(isAuto ? Color.purple : amber))
        }
        .padding(18)
        .glassCard(borderColor: (isAuto ? Color.purple : amber).opacity(0.35))
    }

    // MARK: ── SEKME 3: AKP Boyutlandırma ──

    private var akpTab: some View {
        let stepSize: Double = 5.0
        let stepCount = max(1, Int(ceil(requiredQcKVAr / stepSize)))
        let contactorA = (stepSize * 1000.0) / (sqrt(3.0) * 400.0)
        let needsReactor = thdPercent > 8.0

        return VStack(spacing: 16) {
            // Kademe bilgisi
            HStack(spacing: 0) {
                akpCell(label: "Kademe Sayısı", value: "\(stepCount)", unit: "kademe", color: Color.purple)
                Divider().background(Color.purple.opacity(0.3)).frame(height: 60)
                akpCell(label: "Adım Büyüklüğü", value: String(format: "%.0f", stepSize), unit: "kVAr", color: amber)
                Divider().background(Color.purple.opacity(0.3)).frame(height: 60)
                akpCell(label: "Kontaktör Akımı", value: String(format: "%.1f", contactorA), unit: "A", color: Color.cyan)
            }
            .padding(18)
            .glassCard(borderColor: Color.purple.opacity(0.35))

            // Reaktör gereksinimi
            reactorRequirementCard(needsReactor: needsReactor)

            // Pano boyutu
            panoBoyutuCard(stepCount: stepCount)
        }
    }

    private func akpCell(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(unit).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func reactorRequirementCard(needsReactor: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: needsReactor ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(needsReactor ? Color.orange : Color.green)
                .shadow(color: (needsReactor ? Color.orange : Color.green).opacity(0.5), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text("Reaktör Gereksinimi")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(needsReactor ? "THD > %8 — Detuned reaktör zorunlu!" : "THD < %8 — Reaktör şart değil")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(needsReactor ? Color.orange : Color.green)
                if needsReactor {
                    Text("Önerilen: %7 detuned (189 Hz rezonans koruması)")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(18)
        .glassCard(borderColor: (needsReactor ? Color.orange : Color.green).opacity(0.4))
    }

    private func panoBoyutuCard(stepCount: Int) -> some View {
        let width = min(2400, 400 + stepCount * 200)
        return VStack(spacing: 10) {
            HStack {
                Text("🗄️ Pano Boyutu Tahmini")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 20) {
                dimensionCell(label: "Genişlik", value: "\(width) mm")
                dimensionCell(label: "Yükseklik", value: "2000 mm")
                dimensionCell(label: "Derinlik", value: "600 mm")
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.3))
    }

    private func dimensionCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(amber)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: ── SEKME 4: Harmonik Analiz ──

    private var harmonicTab: some View {
        let resonanceHz = frequency * sqrt(requiredQcKVAr / max(1, Double(activePowerKW) ?? 100))
        let riskLevel: Int  // 0=yeşil, 1=turuncu, 2=kırmızı
        if thdPercent < 5        { riskLevel = 0 }
        else if thdPercent < 15  { riskLevel = 1 }
        else                      { riskLevel = 2 }

        let riskColor: Color = riskLevel == 0 ? .green : riskLevel == 1 ? .orange : .red
        let riskText = riskLevel == 0 ? "Düşük Risk" : riskLevel == 1 ? "Orta Risk" : "Yüksek Risk"

        return VStack(spacing: 16) {
            // THD kaydırıcı
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "waveform.path.ecg").foregroundStyle(Color.purple)
                    Text("Toplam Harmonik Distorsiyon (THD)")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "%%%.0f", thdPercent))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(riskColor)
                }
                Slider(value: $thdPercent, in: 0...40, step: 0.5)
                    .tint(riskColor)
                HStack {
                    Text("Temiz").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                    Spacer()
                    Text("Kritik").font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
                }
            }
            .padding(18)
            .glassCard(borderColor: riskColor.opacity(0.4))

            // Rezonans frekansı
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(Color.cyan)
                    Text("Rezonans Frekansı")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Text(String(format: "%.1f Hz", resonanceHz))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 10)
                Text("fr = f₀ × √(Scc / Qc)")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.55))
            }
            .padding(18)
            .glassCard(borderColor: Color.cyan.opacity(0.35))

            // Risk göstergesi (animasyonlu)
            riskIndicator(color: riskColor, text: riskText, thd: thdPercent)

            // Filtre önerisi (varsa)
            if riskLevel > 0 { filterRecommendationCard(riskLevel: riskLevel) }
        }
    }

    private func riskIndicator(color: Color, text: String, thd: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: thd)
                Image(systemName: color == .green ? "checkmark.circle.fill" : color == .orange ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk Seviyesi")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
                Text(text)
                    .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text("IEC 61000-3-12 standardı")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.5))
            }
            Spacer()
        }
        .padding(18)
        .glassCard(borderColor: color.opacity(0.4))
    }

    private func filterRecommendationCard(riskLevel: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3").foregroundStyle(Color.orange)
                Text("Filtre Önerisi").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            // Pasif vs Aktif karşılaştırma
            HStack(spacing: 10) {
                filterCompCell(
                    title: "Pasif Filtre",
                    subtitle: "Detuned Reaktör",
                    cost: "12.000 – 35.000 ₺",
                    pro: "Basit, güvenilir",
                    con: "Frekans bağımlı",
                    color: Color.orange
                )
                filterCompCell(
                    title: "Aktif Filtre",
                    subtitle: "IGBT Tabanlı",
                    cost: "45.000 – 120.000 ₺",
                    pro: "Tüm harmonikler",
                    con: "Yüksek maliyet",
                    color: Color.purple
                )
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.orange.opacity(0.3))
    }

    private func filterCompCell(title: String, subtitle: String, cost: String, pro: String, con: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(subtitle).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(cost).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            HStack(spacing: 3) {
                Image(systemName: "checkmark").font(.system(size: 10)).foregroundStyle(Color.green)
                Text(pro).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
            }
            HStack(spacing: 3) {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(Color.red)
                Text(con).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: ── SEKME 5: Transformatör ──

    private var transformerTab: some View {
        let kva = Double(transformerKVA) ?? 250
        let currentLoad = (Double(apparentPowerKVA) ?? 140) / kva
        let afterLoad  = ((Double(apparentPowerKVA) ?? 140) - requiredQcKVAr) / kva
        let capacityGain = requiredQcKVAr
        let copperLossReduction = (1 - afterLoad * afterLoad / max(0.01, currentLoad * currentLoad)) * 100

        return VStack(spacing: 16) {
            // Transformatör gücü
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(amber)
                    Text("Transformatör Gücü (kVA)")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                TextField("250", text: $transformerKVA)
                    .keyboardType(.numberPad)
                    .styledInput()
            }
            .padding(18)
            .glassCard(borderColor: amber.opacity(0.3))

            // Yük faktörü: Önce vs Sonra
            VStack(spacing: 12) {
                HStack {
                    Text("📊 Trafo Yük Faktörü")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                loadFactorBar(label: "Kompanzasyon Öncesi", value: min(1.0, currentLoad), color: Color.red)
                loadFactorBar(label: "Kompanzasyon Sonrası", value: min(1.0, max(0, afterLoad)), color: Color.green)
            }
            .padding(18)
            .glassCard(borderColor: amber.opacity(0.25))

            // Kazanımlar
            HStack(spacing: 0) {
                trafoGainCell(label: "Kapasite Kazanımı", value: String(format: "%.0f kVA", capacityGain), color: Color.green)
                Divider().background(amber.opacity(0.2)).frame(height: 55)
                trafoGainCell(label: "Bakır Kaybı Azalması", value: String(format: "%%.0f%%", max(0, copperLossReduction)), color: amber)
            }
            .padding(18)
            .glassCard(borderColor: Color.green.opacity(0.3))
        }
    }

    private func loadFactorBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray.opacity(0.7))
                Spacer()
                Text(String(format: "%%%.0f", value * 100))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * value, height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
                }
            }
            .frame(height: 12)
        }
    }

    private func trafoGainCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: ── SEKME 6: Ekonomik Analiz ──

    private var economyTab: some View {
        let investment = Double(investmentCost) ?? 25000
        let monthly    = monthlySaving
        let payback    = monthly > 0 ? investment / monthly : 999
        let tenYearData = (1...10).map { year in
            (year: year, saving: monthly * 12 * Double(year) - investment)
        }

        return VStack(spacing: 16) {
            // Yatırım
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "building.2.fill").foregroundStyle(amber)
                    Text("Yatırım Maliyeti")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                TextField("25000", text: $investmentCost)
                    .keyboardType(.numberPad)
                    .styledInput()
            }
            .padding(18)
            .glassCard(borderColor: amber.opacity(0.3))

            // KPI kartları
            HStack(spacing: 0) {
                economyKPI(label: "Aylık Tasarruf", value: monthly.currencyFormatted, color: Color.green)
                Divider().background(amber.opacity(0.2)).frame(height: 55)
                economyKPI(label: "Geri Ödeme", value: String(format: "%.1f yıl", payback), color: amber)
                Divider().background(amber.opacity(0.2)).frame(height: 55)
                economyKPI(label: "10Y Tasarruf", value: (monthly * 120 - investment).currencyFormatted, color: Color.cyan)
            }
            .padding(18)
            .glassCard(borderColor: Color.green.opacity(0.3))

            // 10 yıllık kümülatif grafik
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Color.green)
                    Text("10 Yıllık Kümülatif Tasarruf")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                Chart(tenYearData, id: \.year) { point in
                    LineMark(
                        x: .value("Yıl", point.year),
                        y: .value("Tasarruf", point.saving)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    AreaMark(
                        x: .value("Yıl", point.year),
                        y: .value("Tasarruf", point.saving)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    PointMark(
                        x: .value("Yıl", point.year),
                        y: .value("Tasarruf", point.saving)
                    )
                    .foregroundStyle(point.saving >= 0 ? Color.green : Color.red)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { v in
                        AxisValueLabel { Text("Y\(v.as(Int.self) ?? 0)").font(.system(size: 10)).foregroundStyle(.gray.opacity(0.6)) }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.white.opacity(0.08))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(.gray.opacity(0.6))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.white.opacity(0.08))
                    }
                }

                // NBD ve İVO değerleri
                HStack(spacing: 20) {
                    financialMetric(label: "NBD (10Y, %8)", value: nbv(cashFlow: monthly*12, rate: 0.08, years: 10, investment: investment).currencyFormatted, color: Color.cyan)
                    financialMetric(label: "İç Verim Oranı", value: payback < 10 ? "~\(String(format: "%.0f", 100.0/payback))%" : "<%10", color: amber)
                }
            }
            .padding(18)
            .glassCard(borderColor: Color.green.opacity(0.3))
        }
    }

    private func economyKPI(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }

    private func financialMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.65))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Net Bugünkü Değer hesabı
    private func nbv(cashFlow: Double, rate: Double, years: Int, investment: Double) -> Double {
        var pv = 0.0
        for y in 1...years { pv += cashFlow / pow(1 + rate, Double(y)) }
        return pv - investment
    }

    // MARK: ── SEKME 7: Rapor ──

    private var reportTab: some View {
        let kva = Double(transformerKVA) ?? 250
        let isAuto = requiredQcKVAr > 50
        let needsReactor = thdPercent > 8.0

        return VStack(spacing: 16) {
            // Özet kart
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill").foregroundStyle(amber)
                    Text("Kompanzasyon Özeti")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                summaryRow(label: "Gerekli Kondansatör", value: String(format: "%.1f kVAr", requiredQcKVAr), color: Color.orange)
                summaryRow(label: "AKP Tipi", value: isAuto ? "Otomatik (AKP)" : "Sabit", color: Color.purple)
                summaryRow(label: "Reaktör Gereksinimi", value: needsReactor ? "Detuned Reaktör" : "Reaktör Gerekmez", color: needsReactor ? Color.orange : Color.green)
                summaryRow(label: "Transformatör Kapasitesi", value: "\(Int(kva)) kVA", color: amber)
                summaryRow(label: "Beklenen Geri Ödeme", value: monthlySaving > 0 ? String(format: "%.1f yıl", (Double(investmentCost) ?? 25000) / monthlySaving / 12) : "–", color: Color.cyan)
            }
            .padding(18)
            .glassCard(borderColor: amber.opacity(0.35))

            // Standart uyumluluk
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.green)
                    Text("Standart Uyumluluk")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                }
                standardBadge(standard: "IEC 61921", desc: "Power factor correction capacitors")
                standardBadge(standard: "EN 60831", desc: "Shunt power capacitors of the self-healing type")
                standardBadge(standard: "IEC 61000-3-2", desc: "Harmonics — Class A limits")
                standardBadge(standard: "TS EN 50160", desc: "Şebeke gerilim karakteristikleri")
            }
            .padding(18)
            .glassCard(borderColor: Color.green.opacity(0.3))

            // Aksiyon butonları
            VStack(spacing: 12) {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Teklif'e Ekle", systemImage: "doc.badge.plus")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).fill(amber).shadow(color: amber.opacity(0.4), radius: 8, y: 4))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("PDF Önizleme", systemImage: "doc.richtext.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.orange.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
    }

    private func standardBadge(standard: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Color.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(standard).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(desc).font(.system(size: 11, design: .rounded)).foregroundStyle(.gray.opacity(0.6))
            }
            Spacer()
        }
    }

    // MARK: - Hesaplamalar

    private func recalculate() {
        let p  = Double(activePowerKW) ?? 0
        let s  = Double(apparentPowerKVA) ?? 0
        guard s > 0 else { currentCosPhi = 0; return }

        let cosPhi1 = p / s
        currentCosPhi = cosPhi1

        let phi1 = acos(cosPhi1)
        let phi2 = acos(targetCosPhi)
        let qc = p * (tan(phi1) - tan(phi2))
        requiredQcKVAr = max(0, qc)

        // Aylık tasarruf: TEDAŞ ceza kaçınımı + bakır kaybı azalması
        monthlySaving = requiredQcKVAr * penaltyRate * 30
    }

    // MARK: - Yardımcı Fonksiyonlar

    private func capacitance(kvar: Double) -> Double {
        let v = 400.0
        return (kvar * 1000.0) / (2 * Double.pi * frequency * v * v) * 1_000_000
    }

    private func nearestSteps(total: Double, options: [Double]) -> [Double] {
        var remaining = total
        var result: [Double] = []
        for step in options.sorted(by: >) {
            while remaining >= step {
                result.append(step)
                remaining -= step
            }
        }
        return result.prefix(6).sorted(by: >)
    }

    private func inputFieldRow(label: String, binding: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            TextField("0", text: binding)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .styledInput()
        }
    }
}

// MARK: - Arc Shape

/// Daire yayı — cos φ gauge için
struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle   = .degrees(newValue.second)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CompensationCalculatorView()
    }
    .preferredColorScheme(.dark)
}
