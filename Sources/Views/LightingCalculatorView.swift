// LightingCalculatorView.swift
// VoltAsist
//
// Aydınlatma tasarımı ve lümen hesaplama ekranı.
// EN 12464-1 standardı — gerekli lüx, armatür adedi, LED vs Floresan karşılaştırma.

import SwiftUI

// MARK: - LightingCalculatorView

/// Aydınlatma hesap ekranı — tam premium UI
struct LightingCalculatorView: View {

    // MARK: State — Girdi
    @State private var areaM2: String           = "20"
    @State private var ceilingHeightM: String   = "2.7"
    @State private var lengthM: String          = "5"
    @State private var widthM: String           = "4"
    @State private var usageType: RoomUsageType = .office
    @State private var maintenanceFactor: Double = 0.80
    @State private var fixtureWatt: String      = "18"
    @State private var fixtureLumens: String    = "2000"

    // MARK: State — Sonuç
    @State private var result: LightingCalculationResult? = nil
    @State private var resultVisible: Bool       = false
    @State private var bulbRotation: Double      = 0

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Girdi kartı
                inputCard

                // Hesapla
                calculateButton

                // Sonuçlar
                if resultVisible, let res = result {
                    resultSection(res)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 60)
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
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.6), radius: 6)
                Text("Mekan Bilgileri")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 16)

            VStack(spacing: 14) {
                // Boyutlar
                HStack(spacing: 10) {
                    dimField(label: "Uzunluk (m)", binding: $lengthM)
                    dimField(label: "Genişlik (m)", binding: $widthM)
                }

                // Otomatik alan hesabı
                if let l = Double(lengthM), let w = Double(widthM), l > 0, w > 0 {
                    HStack {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray.opacity(0.6))
                        Text("Alan: \(String(format: "%.1f", l * w)) m²")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.65))
                        Spacer()
                    }
                }

                Divider().background(amber.opacity(0.15))

                // Tavan yüksekliği
                HStack {
                    Text("🏠 Tavan Yüksekliği")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    TextField("2.7", text: $ceilingHeightM)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .styledInput()
                    Text("m")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.gray.opacity(0.6))
                }

                Divider().background(amber.opacity(0.15))

                // Kullanım tipi
                VStack(alignment: .leading, spacing: 8) {
                    Text("💼 Mekan Kullanım Tipi")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RoomUsageType.allCases) { type in
                                roomTypeChip(type: type)
                            }
                        }
                    }

                    // Seçilen tipin lüx gereksinimi
                    HStack(spacing: 6) {
                        Image(systemName: "sun.min.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(amber)
                        Text("Gerekli Aydınlık: \(Int(usageType.requiredLux)) lüx")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(amber)
                        Spacer()
                        Text("CRI ≥ \(usageType.minCRI) · \(usageType.colorTemperatureK)K")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }

                Divider().background(amber.opacity(0.15))

                // Bakım faktörü
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("🔧 Bakım Faktörü (LLF)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(String(format: "%.2f", maintenanceFactor))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(amber)
                    }
                    Slider(value: $maintenanceFactor, in: 0.6...0.95, step: 0.05)
                        .tint(amber)
                    HStack {
                        Text("Kirli ortam")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.5))
                        Spacer()
                        Text("Temiz mekan")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }

                Divider().background(amber.opacity(0.15))

                // Armatür parametreleri
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Armatür Gücü")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.65))
                        HStack {
                            TextField("18", text: $fixtureWatt)
                                .keyboardType(.decimalPad)
                                .styledInput()
                            Text("W")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.gray.opacity(0.6))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Işık Akısı")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.65))
                        HStack {
                            TextField("2000", text: $fixtureLumens)
                                .keyboardType(.decimalPad)
                                .styledInput()
                            Text("lm")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.gray.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.cyan.opacity(0.3))
    }

    @ViewBuilder
    private func dimField(label: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gray.opacity(0.65))
            TextField(label, text: binding)
                .keyboardType(.decimalPad)
                .styledInput()
        }
    }

    @ViewBuilder
    private func roomTypeChip(type: RoomUsageType) -> some View {
        let isSelected = usageType == type
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                usageType = type
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.systemIcon)
                    .font(.system(size: 11))
                Text(type.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.gray.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.cyan : Color(red: 0.14, green: 0.14, blue: 0.17))
                    .shadow(color: isSelected ? Color.cyan.opacity(0.4) : .clear, radius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hesapla Butonu

    private var calculateButton: some View {
        Button { calculate() } label: {
            Label("Aydınlatma Hesapla", systemImage: "lightbulb.circle.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.cyan, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: Color.cyan.opacity(0.4), radius: 10, y: 4)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sonuç Bölümü

    @ViewBuilder
    private func resultSection(_ res: LightingCalculationResult) -> some View {
        VStack(spacing: 16) {
            // Ana sonuç kartı
            mainResultCard(res)

            // LED vs Floresan karşılaştırması
            ledVsFloresanCard(res)

            // Yıllık maliyet kartı
            annualCostCard(res)
        }
    }

    private func mainResultCard(_ res: LightingCalculationResult) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                Text("Hesap Sonuçları")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                // Animasyonlu ampul
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(amber)
                    .shadow(color: amber.opacity(0.7), radius: 8)
                    .rotationEffect(.degrees(bulbRotation))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatCount(3, autoreverses: true)) {
                            bulbRotation = 15
                        }
                    }
            }

            // Büyük değerler grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                luxCell(
                    label: "Gerekli Aydınlık",
                    value: "\(Int(res.requiredLux)) lüx",
                    color: amber,
                    icon: "sun.max.fill"
                )
                luxCell(
                    label: "Gerçekleşen",
                    value: "\(Int(res.actualLux)) lüx",
                    color: res.actualLux >= res.requiredLux ? Color.green : Color.red,
                    icon: "checkmark.circle.fill"
                )
                luxCell(
                    label: "Armatür Adedi",
                    value: "\(res.fixtureCount) adet",
                    color: Color.cyan,
                    icon: "lightbulb.2.fill"
                )
                luxCell(
                    label: "Toplam Güç",
                    value: "\(Int(res.totalWatt)) W",
                    color: Color.orange,
                    icon: "bolt.fill"
                )
            }

            Divider().background(amber.opacity(0.15))

            // Detay değerler
            VStack(spacing: 8) {
                detailRow(label: "Gerekli Lümen", value: String(format: "%.0f lm", res.requiredLumens))
                detailRow(label: "Kullanım Katsayısı (CU)", value: String(format: "%.2f", res.utilisationCoefficient))
                detailRow(label: "Bakım Faktörü (LLF)", value: String(format: "%.2f", res.maintenanceFactor))
                detailRow(label: "Mekan Endeksi (k)", value: String(format: "%.2f", res.roomIndex))
                detailRow(label: "Enerji Verimliliği", value: String(format: "%.0f lm/W", res.luminousEfficacy))
                detailRow(label: "Enerji Sınıfı", value: res.energyClassification)
            }
        }
        .padding(18)
        .glassCard(borderColor: Color.cyan.opacity(0.3))
    }

    private func luxCell(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 6)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gray.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func ledVsFloresanCard(_ res: LightingCalculationResult) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(amber)
                Text("LED vs Floresan")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                // LED sütunu
                VStack(spacing: 8) {
                    Text("💡 LED")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                    Text("\(res.fixtureCount) adet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(Int(res.totalWatt)) W")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.green)
                }
                .frame(maxWidth: .infinity)

                // Karşılaştırma ortası
                VStack(spacing: 4) {
                    Text("TASARRUF")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.gray.opacity(0.6))
                    Text(String(format: "%%%.0f", res.ledVsFloresanSaving))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(amber)
                        .shadow(color: amber.opacity(0.5), radius: 6)
                }
                .frame(width: 70)

                // Floresan sütunu
                VStack(spacing: 8) {
                    Text("🔆 Floresan")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gray.opacity(0.7))
                    Text("\(res.fixtureCount) adet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "%.0f W", res.totalWatt / (1.0 - res.ledVsFloresanSaving / 100.0)))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.orange)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .padding(18)
        .glassCard(borderColor: amber.opacity(0.3))
    }

    private func annualCostCard(_ res: LightingCalculationResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "turkishlirasign.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.green)
                .shadow(color: Color.green.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Yıllık Enerji Maliyeti")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.7))
                Text(res.annualEnergyCostTL.currencyFormatted)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.green)
                    .shadow(color: Color.green.opacity(0.35), radius: 6)
                Text("4000 saat/yıl · 4.50 ₺/kWh baz alınmıştır")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.5))
            }

            Spacer()
        }
        .padding(18)
        .glassCard(borderColor: Color.green.opacity(0.3))
    }

    // MARK: - Hesaplama Mantığı

    private func calculate() {
        guard let len = Double(lengthM.replacingOccurrences(of: ",", with: ".")),
              let wid = Double(widthM.replacingOccurrences(of: ",", with: ".")),
              let height = Double(ceilingHeightM.replacingOccurrences(of: ",", with: ".")),
              let fWatt = Double(fixtureWatt.replacingOccurrences(of: ",", with: ".")),
              let fLumen = Double(fixtureLumens.replacingOccurrences(of: ",", with: ".")),
              len > 0, wid > 0, height > 0, fWatt > 0, fLumen > 0 else {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            return
        }

        let input = LightingCalculationInput(
            areaM2: len * wid,
            ceilingHeightM: height,
            usageType: usageType,
            maintenanceFactor: maintenanceFactor,
            lengthM: len,
            widthM: wid,
            fixtureWatt: fWatt,
            fixtureLumens: fLumen
        )

        let res = LightingEngine.calculate(input: input)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            result = res
            resultVisible = true
        }
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LightingCalculatorView()
    }
    .preferredColorScheme(.dark)
}
