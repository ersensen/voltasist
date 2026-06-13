// CableCalculatorView.swift
// VoltAsist
//
// Kablo kesit analiz ekranı. Otomatik/Manuel mod, damar yapısı, 2x2 grid parametreleri,
// tesis limitleri, iletken ve izolasyon sınıfı seçimi ile premium arayüz.

import SwiftUI

// MARK: - Limit Tipi
enum CableLimitType: String, CaseIterable, Identifiable {
    case mainFeed = "Ana Dağıtım / Ana Besleme Hattı"
    case outlet   = "Son Devre — Priz Kuvvetli Akım Hattı"
    case lighting = "Son Devre — Aydınlatma Linye Hattı"

    var id: String { rawValue }

    var limit: Double {
        switch self {
        case .mainFeed: return 2.0
        case .outlet:   return 3.0
        case .lighting: return 1.5
        }
    }
}

// MARK: - İzolasyon Sınıfı
enum CableInsulationClass: String, CaseIterable, Identifiable {
    case nym      = "NYM Antigron"
    case ttr      = "H05VV-F TTR"
    case nyy      = "NYY YVV"
    case n2xh     = "N2XH (Halojensiz)"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nym:  return "NYM Antigron (Sıva Üstü / Nemli Yer)"
        case .ttr:  return "H05VV-F TTR (Esnek Kordon)"
        case .nyy:  return "NYY YVV (Yeraltı / Güç Kablosu)"
        case .n2xh: return "N2XH (Halojensiz / Yangına Güvenli)"
        }
    }
}

// MARK: - CableCalculatorView
struct CableCalculatorView: View {

    // MARK: - State Parametreleri
    @State private var isAuto = true
    @State private var isThreePhase = true // true = Trifaze (380V), false = Monofaze (220V)
    @State private var coreCount = 4 // 3, 4, 5
    
    // Girdiler
    @State private var powerKW = ""
    @State private var lengthM = ""
    @State private var cosPhi = "0.90"
    @State private var groupCount = "1"
    
    // Limit ve İletken
    @State private var selectedLimit: CableLimitType = .mainFeed
    @State private var isCopper = true // true = Bakır (Cu), false = Alüminyum (Al)
    @State private var selectedInsulation: CableInsulationClass = .nym
    
    // Manuel Mod İçin Seçilen Kesit
    @State private var selectedManualSection: Double = 2.5

    // Hesaplama Sonucu State
    @State private var result: CableCalculationResult? = nil
    @State private var resultVisible = false
    @State private var isCalculating = false
    @State private var showAddToQuote = false
    @State private var warningShake = false

    // Tasarım Renkleri
    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.05, green: 0.05, blue: 0.07)
    private let cardBG = Color(red: 0.09, green: 0.09, blue: 0.12)
    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96) // #3B82F6

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Header (Ekran görüntüsündeki gibi)
                headerSection

                // Üst Seçim: Otomatik Kesit Önerisi / Manuel Deneme-Yanılma
                modeSelector

                // 1. Şebeke ve Kablo Damar Yapısı
                coreStructureCard

                // 2. Girdiler Kartı (2x2 Grid)
                inputsGridCard

                // 3. Tesis Bölümü Sınır Limiti
                limitsCard

                // 4. İletken Metali
                conductorCard

                // 5. Piyasa İzolasyon Sınıfı
                insulationCard

                // Manuel Mod için Kesit Seçici
                if !isAuto {
                    manualSectionCard
                }

                // Hesapla Butonu
                calculateButton

                // Sonuç Kartı
                if resultVisible, let res = result {
                    resultCard(res)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(darkBG.ignoresSafeArea())
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kablo Kesit Analizi & Canlı Simülasyon")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Deneme-Yanılma Seçenekli Vektörel Gerilim Düşümü Motoru")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Mod Seçici (Otomatik / Manuel)
    private var modeSelector: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isAuto = true
                    resultVisible = false
                }
            } label: {
                Text("? Otomatik Kesit Önerisi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isAuto ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isAuto ? Color.white.opacity(0.12) : Color.clear)
                    .cornerRadius(10)
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isAuto = false
                    resultVisible = false
                }
            } label: {
                Text("⚙️ Manuel Deneme-Yanılma")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(!isAuto ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(!isAuto ? Color.white.opacity(0.12) : Color.clear)
                    .cornerRadius(10)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 1. Şebeke ve Kablo Damar Yapısı
    private var coreStructureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Şebeke ve Kablo Damar Yapısı", systemImage: "bolt.horizontal.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(amber)

            // Gerilim Tipi
            VStack(alignment: .leading, spacing: 6) {
                Text("Gerilim Tipi")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    segmentButton(title: "Monofaze (220V)", selected: !isThreePhase) {
                        isThreePhase = false
                    }
                    segmentButton(title: "Trifaze (380V)", selected: isThreePhase) {
                        isThreePhase = true
                    }
                }
            }

            // Damar Sayısı
            VStack(alignment: .leading, spacing: 6) {
                Text("Kablo Damar (İletken) Sayısı")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    ForEach([3, 4, 5], id: \.self) { count in
                        segmentButton(title: "\(count)x", selected: coreCount == count) {
                            coreCount = count
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 2. Girdiler Kartı (2x2 Grid)
    private var inputsGridCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            gridInputField(label: "Aktif Yük Gücü (kW)", placeholder: "Örn: 15", text: $powerKW)
            gridInputField(label: "Hat Metrajı (Metre)", placeholder: "Örn: 60", text: $lengthM)
            gridInputField(label: "Güç Faktörü (Cos Phi)", placeholder: "0.90", text: $cosPhi)
            gridInputField(label: "Demet Devre Sayısı (Cg)", placeholder: "1", text: $groupCount)
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 3. Tesis Bölümü Sınır Limiti
    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tesis Bölümü Sınır Limiti", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(amber)
                .padding(.bottom, 4)

            ForEach(CableLimitType.allCases) { item in
                let isSelected = selectedLimit == item
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selectedLimit = item
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .gray)
                            Text(isSelected ? "Hesap limitine göre doğrulanacak" : "Seçmek için dokunun")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .gray.opacity(0.5))
                        }
                        Spacer()
                        Text(String(format: "Max %%.1f", item.limit).replacingOccurrences(of: "%%", with: "%"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? .black : amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? amber : amber.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .padding(12)
                    .background(isSelected ? accentBlue.opacity(0.25) : Color.white.opacity(0.03))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? accentBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 4. İletken Metali
    private var conductorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İletken Metali")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(amber)
            HStack(spacing: 8) {
                segmentButton(title: "Bakır (Cu)", selected: isCopper) {
                    isCopper = true
                }
                segmentButton(title: "Alüminyum (Al)", selected: !isCopper) {
                    isCopper = false
                }
            }
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 5. Piyasa İzolasyon Sınıfı
    private var insulationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Piyasa İzolasyon Sınıfı")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(amber)

            Picker("İzolasyon Sınıfı", selection: $selectedInsulation) {
                ForEach(CableInsulationClass.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .accentColor(amber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

            Text(selectedInsulation.displayName)
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Manuel Mod Kesit Kartı
    private var manualSectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manuel Kesit Seçimi (mm²)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(amber)

            Picker("Kesit Değeri", selection: $selectedManualSection) {
                ForEach(CableEngine.standardSections, id: \.self) { section in
                    Text(String(format: "%.1f mm²", section)).tag(section)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .clipped()
        }
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Hesapla Butonu
    private var calculateButton: some View {
        Button {
            calculate()
        } label: {
            HStack(spacing: 10) {
                if isCalculating {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(isCalculating ? "Hesaplanıyor..." : "Hesapla")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [amber, .orange], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: amber.opacity(0.4), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sonuç Kartı
    @ViewBuilder
    private func resultCard(_ res: CableCalculationResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Simülasyon Sonuçları")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 16)

            HStack(spacing: 0) {
                bigResultCell(label: "Yük Akımı", value: String(format: "%.1f A", res.currentA), color: amber)
                Divider().background(amber.opacity(0.2)).frame(height: 50)
                bigResultCell(
                    label: isAuto ? "Önerilen Kesit" : "Seçilen Kesit",
                    value: String(format: "%.1f mm²", res.recommendedSectionMM2),
                    color: .orange
                )
            }
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.1)).padding(.bottom, 16)

            // Detaylar
            VStack(spacing: 12) {
                let dropLimit = selectedLimit.limit
                let dropOK = res.voltageDrop <= dropLimit

                resultDetailRow(
                    label: "Gerilim Düşümü",
                    value: String(format: "%.2f%%", res.voltageDrop),
                    statusText: dropOK ? "UYGUN" : "UYGUN DEĞİL",
                    isGood: dropOK
                )
                resultDetailRow(
                    label: "Gerilim Düşümü (V)",
                    value: String(format: "%.2f V", res.voltageDropV),
                    statusText: nil,
                    isGood: dropOK
                )
                resultDetailRow(
                    label: "Kapasite Kullanımı",
                    value: String(format: "%.1f%%", res.loadPercent),
                    statusText: res.loadPercent < 100.0 ? "GÜVENLİ" : "AŞIRI YÜK",
                    isGood: res.loadPercent < 100.0
                )
                resultDetailRow(
                    label: "Akım Kapasitesi",
                    value: String(format: "%.1f A", res.currentCapacityA),
                    statusText: nil,
                    isGood: true
                )
                resultDetailRow(
                    label: "Önerilen Sigorta",
                    value: "\(res.recommendedFuseA) A",
                    statusText: nil,
                    isGood: true
                )
            }

            if let warning = res.warningMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.9))
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .padding(.top, 16)
                .shake(trigger: warningShake)
            }

            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 16)

            Button {
                showAddToQuote = true
            } label: {
                Label("Teklife Ekle", systemImage: "doc.badge.plus")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(amber)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBG)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(res.voltageDrop <= selectedLimit.limit ? Color.green.opacity(0.35) : Color.red.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Yardımcı Alt UI Bileşenleri

    private func segmentButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? accentBlue : Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? accentBlue.opacity(0.8) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func gridInputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .lineLimit(1)
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(text.wrappedValue.isEmpty ? Color.white.opacity(0.06) : amber.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private func bigResultCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultDetailRow(label: String, value: String, statusText: String?, isGood: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            if let status = statusText {
                Text(status)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isGood ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isGood ? Color.green : Color.red).opacity(0.12))
                    .cornerRadius(4)
                    .padding(.trailing, 4)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isGood ? .white : .red)
        }
    }

    // MARK: - Hesaplama Tetikleyicisi
    private func calculate() {
        guard let power = Double(powerKW.replacingOccurrences(of: ",", with: ".")),
              let length = Double(lengthM.replacingOccurrences(of: ",", with: ".")),
              power > 0, length > 0 else {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            return
        }

        let cosVal = Double(cosPhi.replacingOccurrences(of: ",", with: ".")) ?? 0.90
        let groupVal = Int(groupCount) ?? 1

        isCalculating = true
        resultVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let input = CableCalculationInput(
                powerKW: power,
                voltageV: isThreePhase ? 400.0 : 230.0,
                phaseCount: isThreePhase ? 3 : 1,
                lengthM: length,
                conductorType: isCopper ? .copper : .aluminum,
                installationType: selectedInsulation == .nym ? .surface : .inConduit,
                cosPhi: cosVal,
                targetVoltageDrop: selectedLimit.limit,
                groupCount: groupVal
            )

            let res = CableEngine.calculate(input: input, manualSection: isAuto ? nil : selectedManualSection)

            isCalculating = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                result = res
                resultVisible = true
            }

            if res.warningMessage != nil {
                warningShake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    warningShake = false
                }
            }

            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }
    }
}

// MARK: - Shake Animasyonu Modifier
extension View {
    func shake(trigger: Bool) -> some View {
        self.modifier(ShakeAnimationModifier(trigger: trigger))
    }
}

struct ShakeAnimationModifier: GeometryEffect {
    var trigger: Bool
    var animatableData: CGFloat {
        get { trigger ? 1.0 : 0.0 }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = trigger ? 5.0 * sin(animatableData * .pi * 5) : 0
        return ProjectionTransform(CGAffineTransform(translationX: CGFloat(translation), y: 0))
    }
}

// MARK: - Preview
#Preview {
    CableCalculatorView()
        .preferredColorScheme(.dark)
}
