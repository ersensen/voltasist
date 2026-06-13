// CableCalculatorView.swift
// VoltAsist
//
// Premium kablo kesit hesaplama ekranı.
// IEC 60364 standardına uygun — akım, kesit, gerilim düşümü ve sigorta hesapları.
// Glassmorphism kart girişleri, amber gradient hesaplama butonu ve animasyonlu sonuçlar.

import SwiftUI

// MARK: - CableCalculatorView

/// Kablo kesiti hesap ekranı — tam premium UI
struct CableCalculatorView: View {

    // MARK: State — Girdi Parametreleri
    @State private var powerKW: String         = "10"
    @State private var voltageSelection: Int   = 1      // 0 = 230V, 1 = 400V
    @State private var phaseCount: Int         = 3      // 1 veya 3
    @State private var lengthM: String         = "50"
    @State private var conductorType: ConductorType     = .copper
    @State private var installationType: InstallationType = .inWall
    @State private var cosPhi: Double          = 0.90
    @State private var targetDrop: Double      = 3.0

    // MARK: State — Sonuç
    @State private var result: CableCalculationResult? = nil
    @State private var resultVisible: Bool     = false
    @State private var isCalculating: Bool     = false
    @State private var showAddToQuote: Bool    = false
    @State private var warningShake: Bool      = false

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBG  = Color(red: 0.11, green: 0.11, blue: 0.14)

    // MARK: Gerilim seçenekleri
    private let voltageOptions: [Double] = [230.0, 400.0]

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Girdi kartı
                inputCard

                // Hesapla butonu
                calculateButton

                // Sonuç kartı (animasyonlu)
                if resultVisible, let res = result {
                    resultCard(res)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .opacity
                            )
                        )
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(bgColor.ignoresSafeArea())
    }

    // MARK: - Girdi Kartı

    private var inputCard: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(amber)
                Text("Hesap Parametreleri")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
            }
            .padding(.bottom, 16)

            VStack(spacing: 14) {
                // Güç
                inputRow(label: "⚡ Güç (kW)", systemIcon: "bolt.fill") {
                    TextField("Güç (kW)", text: $powerKW)
                        .keyboardType(.decimalPad)
                        .styledInput()
                }

                Divider().background(amber.opacity(0.15))

                // Gerilim
                inputRow(label: "🔌 Gerilim", systemIcon: "powerplug.fill") {
                    Picker("Gerilim", selection: $voltageSelection) {
                        Text("230 V (Tek Faz)").tag(0)
                        Text("400 V (Üç Faz)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: voltageSelection) { _, val in
                        phaseCount = val == 0 ? 1 : 3
                    }
                }

                Divider().background(amber.opacity(0.15))

                // Uzunluk
                inputRow(label: "📏 Uzunluk (m)", systemIcon: "ruler.fill") {
                    TextField("Uzunluk (m)", text: $lengthM)
                        .keyboardType(.decimalPad)
                        .styledInput()
                }

                Divider().background(amber.opacity(0.15))

                // İletken tipi
                inputRow(label: "🧲 İletken", systemIcon: "cable.connector") {
                    Picker("İletken", selection: $conductorType) {
                        ForEach(ConductorType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().background(amber.opacity(0.15))

                // Montaj tipi
                inputRow(label: "🏗️ Montaj Tipi", systemIcon: "square.stack.3d.up.fill") {
                    Picker("Montaj", selection: $installationType) {
                        ForEach(InstallationType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(amber)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Divider().background(amber.opacity(0.15))

                // cos φ slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 13))
                            .foregroundStyle(amber)
                        Text("Güç Faktörü (cos φ)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.8))
                        Spacer()
                        Text(String(format: "%.2f", cosPhi))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(amber)
                    }
                    Slider(value: $cosPhi, in: 0.6...1.0, step: 0.01)
                        .tint(amber)
                }

                Divider().background(amber.opacity(0.15))

                // Hedef gerilim düşümü slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.right.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.orange)
                        Text("Hedef Gerilim Düşümü")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.8))
                        Spacer()
                        Text(String(format: "%.1f%%", targetDrop))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(targetDrop <= 3.0 ? Color.green : Color.orange)
                    }
                    Slider(value: $targetDrop, in: 1.0...10.0, step: 0.5)
                        .tint(targetDrop <= 3.0 ? Color.green : Color.orange)
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.3))
    }

    // MARK: - Girdi Satırı

    @ViewBuilder
    private func inputRow<Content: View>(label: String, systemIcon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(minWidth: 130, alignment: .leading)
            content()
        }
    }

    // MARK: - Hesapla Butonu

    private var calculateButton: some View {
        Button {
            calculate()
        } label: {
            HStack(spacing: 10) {
                if isCalculating {
                    ProgressView()
                        .tint(Color.black)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "equal.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                }
                Text(isCalculating ? "Hesaplanıyor..." : "Hesapla")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [amber, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: amber.opacity(0.5), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isCalculating ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isCalculating)
    }

    // MARK: - Sonuç Kartı

    @ViewBuilder
    private func resultCard(_ res: CableCalculationResult) -> some View {
        VStack(spacing: 0) {
            // Başlık
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                Text("Hesap Sonuçları")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
            }
            .padding(.bottom, 16)

            // Ana değerler — büyük
            HStack(spacing: 0) {
                bigResultValue(
                    label: "Hat Akımı",
                    value: String(format: "%.1f", res.currentA),
                    unit: "A",
                    color: amber
                )
                Divider()
                    .background(amber.opacity(0.25))
                    .frame(height: 60)
                bigResultValue(
                    label: "Önerilen Kesit",
                    value: String(format: "%.0f", res.recommendedSectionMM2),
                    unit: "mm²",
                    color: Color.orange
                )
            }
            .padding(.bottom, 16)

            Divider().background(amber.opacity(0.15)).padding(.bottom, 16)

            // Detay değerler
            VStack(spacing: 10) {
                resultRow(
                    label: "Gerilim Düşümü",
                    value: String(format: "%.2f%%", res.voltageDrop),
                    isGood: res.isVoltagDropOK,
                    icon: "arrow.down.right"
                )
                resultRow(
                    label: "Gerilim Düşümü (V)",
                    value: String(format: "%.1f V", res.voltageDropV),
                    isGood: res.isVoltagDropOK,
                    icon: "bolt"
                )
                resultRow(
                    label: "Önerilen Sigorta",
                    value: "\(res.recommendedFuseA) A",
                    isGood: true,
                    icon: "shield.fill"
                )
                resultRow(
                    label: "Kapasite Kullanımı",
                    value: String(format: "%.0f%%", res.loadPercent),
                    isGood: res.loadPercent < 80,
                    icon: "gauge.medium"
                )
                resultRow(
                    label: "Akım Kapasitesi",
                    value: String(format: "%.0f A", res.currentCapacityA),
                    isGood: true,
                    icon: "cable.connector"
                )
            }

            // Uyarı mesajı
            if let warning = res.warningMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text(warning)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.orange.opacity(0.9))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.top, 12)
                .offset(x: warningShake ? -4 : 0)
                .animation(
                    .easeInOut(duration: 0.08).repeatCount(5, autoreverses: true),
                    value: warningShake
                )
            }

            Divider().background(amber.opacity(0.15)).padding(.vertical, 16)

            // Teklif'e Ekle butonu
            Button {
                showAddToQuote = true
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
            } label: {
                Label("Teklif'e Ekle", systemImage: "doc.badge.plus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(amber)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassCard(borderColor: Color.green.opacity(0.35))
    }

    // MARK: - Büyük Sonuç Değeri

    private func bigResultValue(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.65))
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.4), radius: 6)
                Text(unit)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sonuç Satırı

    private func resultRow(label: String, value: String, isGood: Bool, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.gray.opacity(0.55))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isGood ? Color.green : Color.red)
        }
    }

    // MARK: - Hesaplama Mantığı

    private func calculate() {
        guard let power = Double(powerKW.replacingOccurrences(of: ",", with: ".")),
              let length = Double(lengthM.replacingOccurrences(of: ",", with: ".")),
              power > 0, length > 0 else {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            return
        }

        isCalculating = true
        resultVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let voltage = voltageOptions[voltageSelection]
            let input = CableCalculationInput(
                powerKW: power,
                voltageV: voltage,
                phaseCount: phaseCount,
                lengthM: length,
                conductorType: conductorType,
                installationType: installationType,
                cosPhi: cosPhi,
                targetVoltageDrop: targetDrop
            )
            let res = CableEngine.calculate(input: input)
            isCalculating = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                result = res
                resultVisible = true
            }
            if res.warningMessage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    warningShake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        warningShake = false
                    }
                }
            }
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }
    }
}

// MARK: - Görünüm Yardımcıları

extension View {
    /// Glassmorphism kart stili — amber kenarlık
    func glassCard(borderColor: Color = Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.3)) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.14).opacity(0.6))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

    /// Text field stili — amber kenarlık
    func styledInput() -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        CableCalculatorView()
    }
    .preferredColorScheme(.dark)
}
