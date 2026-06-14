// AdvancedCalculatorViews.swift
// VoltAsist
//
// Kısa Devre, Trafo Boyutlandırma, Topraklama ve Motor Başlatma hesap ekranları.

import SwiftUI

// MARK: - Shared Helpers

private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
private let darkBG  = Color(red: 0.051, green: 0.055, blue: 0.071)
private let cardBG  = Color(red: 0.086, green: 0.090, blue: 0.114)
private let cardBorder = Color(red: 0.133, green: 0.137, blue: 0.161)

private func calcCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(16)
        .background(cardBG)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
}

private func usageBanner(color: Color, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "info.circle.fill").foregroundStyle(color).font(.system(size: 16)).padding(.top, 1)
        VStack(alignment: .leading, spacing: 3) {
            Text("Nasıl Kullanılır?").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(text).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.22), lineWidth: 1)))
}

private func hapBilgi(icon: String, title: String, body: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            .frame(width: 32, height: 32)
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(body).font(.system(size: 12, design: .rounded)).foregroundStyle(.gray).fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(14)
    .background(color.opacity(0.07))
    .cornerRadius(12)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
}

private func resultRow(_ label: String, _ value: String, color: Color = .white) -> some View {
    HStack {
        Text(label).font(.system(size: 13)).foregroundStyle(.gray)
        Spacer()
        Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(color)
    }
}

private func calcButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            Image(systemName: "function").font(.system(size: 15, weight: .bold))
            Text(label).font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .leading, endPoint: .trailing)).shadow(color: color.opacity(0.4), radius: 8, y: 3))
    }
    .buttonStyle(.plain)
}

// MARK: - Kısa Devre Hesabı

struct ShortCircuitCalculatorView: View {

    private let color = Color.red

    // Girdiler
    @State private var selectedTrafoKVA: Double = 250
    @State private var ukPercent: String = "6"
    @State private var systemVoltage: String = "400"

    // Sonuç
    @State private var iccKA: Double? = nil
    @State private var sccMVA: Double? = nil

    private let standardTrafoKVA: [Double] = [100, 160, 250, 400, 630, 1000, 1600, 2000]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kısa Devre Akımı Hesabı")
                        .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Trafo beslemeli sistemlerde Icc hesabı")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                usageBanner(color: color, text: "Trafo gücünü ve kısa devre empedansını (%Uk) girin. Sistem nominal gerilimiyle kısa devre görünen gücü (Scc) ve kısa devre akımı (Icc) hesaplanır. Sonucu sigorta, kesici ve kablo boyutlandırmasında kullanın.")

                // Girdiler
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: "square.3.layers.3d.fill").foregroundStyle(color); Text("Trafo Gücü").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white) }
                    Picker("Trafo kVA", selection: $selectedTrafoKVA) {
                        ForEach(standardTrafoKVA, id: \.self) { kva in
                            Text(String(format: "%.0f kVA", kva)).tag(kva)
                        }
                    }
                    .pickerStyle(.wheel).frame(height: 90).clipped()

                    Divider().background(cardBorder)

                    HStack(spacing: 12) {
                        inputField(label: "Kısa Devre Empedansı (%Uk)", placeholder: "6", text: $ukPercent, unit: "%")
                        inputField(label: "Sistem Gerilimi", placeholder: "400", text: $systemVoltage, unit: "V")
                    }
                }
                .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))

                calcButton(label: "Hesapla", color: color) { calculate() }

                if let icc = iccKA, let scc = sccMVA {
                    resultCard(icc: icc, scc: scc)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                infoCards
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
        }
        .background(darkBG.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: iccKA)
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
            HStack {
                TextField(placeholder, text: text).keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(unit).font(.system(size: 12)).foregroundStyle(.gray)
            }
            .padding(10).background(Color.white.opacity(0.06)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func resultCard(icc: Double, scc: Double) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "bolt.badge.xmark.fill").foregroundStyle(color)
                Text("Kısa Devre Sonuçları").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(String(format: "%.2f", icc)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(color)
                    Text("kA (Icc)").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                Divider().background(color.opacity(0.3)).frame(height: 50)
                VStack(spacing: 3) {
                    Text(String(format: "%.1f", scc)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.orange)
                    Text("MVA (Scc)").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().background(Color.white.opacity(0.1))

            let uk = Double(ukPercent.replacingOccurrences(of: ",", with: ".")) ?? 6
            resultRow("Trafo kVA", String(format: "%.0f kVA", selectedTrafoKVA))
            resultRow("%Uk Empedansı", String(format: "%.1f%%", uk))
            resultRow("Sistem Gerilimi", "\(systemVoltage) V")

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 13))
                Text("Gerçek değer kablo ve ağ empedanslarına göre daha düşük olabilir. Saha ölçümü ile doğrulayın.")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.orange.opacity(0.85))
            }
            .padding(10).background(Color.orange.opacity(0.08)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        }
        .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1))
    }

    private var infoCards: some View {
        VStack(spacing: 10) {
            hapBilgi(icon: "bolt.shield.fill", title: "Formül: Icc = Scc / (√3 × Un)", body: "Scc = S_trafo / (%Uk/100). Kısa devre görünen gücü trafo kapasitesini kısa devre empedansına böler.", color: color)
            hapBilgi(icon: "chart.bar.fill", title: "Tipik %Uk Değerleri", body: "100–630 kVA trafo: %4–6 · 1 MVA ve üzeri: %5–8 · Katalog değerini kullanın.", color: .orange)
            hapBilgi(icon: "checkmark.shield.fill", title: "TS EN 60909 Standardı", body: "Kısa devre akımı hesabında uluslararası referans standarttır. Kesici kırma kapasitesi bu değer üzerinde olmalıdır.", color: .green)
        }
    }

    private func calculate() {
        let uk = Double(ukPercent.replacingOccurrences(of: ",", with: ".")) ?? 6
        let un = Double(systemVoltage.replacingOccurrences(of: ",", with: ".")) ?? 400
        guard uk > 0, un > 0 else { return }
        let sccKVA = selectedTrafoKVA / (uk / 100.0)
        let sccMVAVal = sccKVA / 1000.0
        let iccKAVal = (sccKVA * 1000.0) / (sqrt(3.0) * un) / 1000.0
        withAnimation { sccMVA = sccMVAVal; iccKA = iccKAVal }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Trafo Boyutlandırma

struct TransformerSizingCalculatorView: View {

    private let color = Color.teal

    @State private var loadKW: String   = ""
    @State private var cosPhiStr: String = "0.85"
    @State private var reservePercent: Double = 20

    // Sonuç
    @State private var requiredKVA: Double? = nil
    @State private var suggestedKVA: Double? = nil

    private let standardSizes: [Double] = [100, 160, 250, 400, 630, 1000, 1600, 2000]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trafo Boyutlandırma")
                        .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Toplam yük kVA ve rezerv payıyla standart trafo seçimi")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                usageBanner(color: color, text: "Toplam aktif yükü (kW) ve güç faktörünü girin. Rezerv oranıyla birlikte gerekli kVA kapasitesi hesaplanır ve TS/IEC standart trafo güçleri arasından en uygun seçim önerilir.")

                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: "square.3.layers.3d.fill").foregroundStyle(color); Text("Yük Bilgileri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white) }

                    inputField2(label: "Toplam Aktif Yük (kW)", placeholder: "Örn: 180", text: $loadKW)
                    inputField2(label: "Ortalama Güç Faktörü (cos φ)", placeholder: "0.85", text: $cosPhiStr)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Kapasite Rezervi").font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
                            Spacer()
                            Text(String(format: "%%%.0f", reservePercent)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
                        }
                        Slider(value: $reservePercent, in: 10...50, step: 5).tint(color)
                    }
                }
                .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))

                calcButton(label: "Trafo Boyutla", color: color) { calculate() }

                if let req = requiredKVA, let sug = suggestedKVA {
                    resultCard(required: req, suggested: sug)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                infoCards
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
        }
        .background(darkBG.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: requiredKVA)
        .scrollDismissesKeyboard(.immediately)
    }

    private func inputField2(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
            TextField(placeholder, text: text).keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .padding(10).background(Color.white.opacity(0.06)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func resultCard(required: Double, suggested: Double) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Trafo Seçim Sonucu").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(String(format: "%.0f", required)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(color)
                    Text("Gerekli kVA").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                Divider().background(color.opacity(0.3)).frame(height: 50)
                VStack(spacing: 3) {
                    Text(String(format: "%.0f", suggested)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.green)
                    Text("Önerilen kVA").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().background(Color.white.opacity(0.1))

            // Standart seçenekler
            Text("Diğer Standart Seçenekler").font(.system(size: 12, weight: .semibold)).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            let alternatives = standardSizes.filter { $0 >= required && $0 != suggested }.prefix(3)
            HStack(spacing: 8) {
                ForEach(Array(alternatives), id: \.self) { kva in
                    Text(String(format: "%.0f kVA", kva))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.08)).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
                }
            }

            let load = Double(loadKW.replacingOccurrences(of: ",", with: ".")) ?? 0
            let cosf = Double(cosPhiStr.replacingOccurrences(of: ",", with: ".")) ?? 0.85
            resultRow("Aktif Yük", String(format: "%.1f kW", load))
            resultRow("cos φ", String(format: "%.2f", cosf))
            resultRow("Rezerv Oranı", String(format: "%%%.0f", reservePercent))
            resultRow("Yükleme Oranı", String(format: "%%.1f%%", (required / suggested) * 100), color: .orange)
        }
        .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(.green.opacity(0.35), lineWidth: 1))
    }

    private var infoCards: some View {
        VStack(spacing: 10) {
            hapBilgi(icon: "square.3.layers.3d.fill", title: "Formül: S = P / cos φ × (1 + rezerv)", body: "Apparent power (görünen güç) aktif yükü güç faktörüne bölerek bulunur, rezerv payı ile büyütülür.", color: color)
            hapBilgi(icon: "percent", title: "Kapasite Yükleme Önerisi", body: "Trafolar %70–80 yükte çalışırken en verimlidir. %85 üzerinde sürekli yükleme ömrü kısaltır. Minimum %20 rezerv bırakın.", color: .orange)
            hapBilgi(icon: "thermometer.medium", title: "Sıcaklık Etkisi", body: "Her 10°C artışta trafo ömrü %50 kısalır (Arrhenius kuralı). Sıcak ortamlarda %20 ek rezerv ekleyin.", color: .red)
            hapBilgi(icon: "chart.line.uptrend.xyaxis", title: "Harmonik Yük", body: "VFD, UPS, kaynak makinesi gibi harmonik üreten yükler varsa K-faktörlü trafo veya %15 ek kapasite tercih edin.", color: .purple)
        }
    }

    private func calculate() {
        let load = Double(loadKW.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cosf = Double(cosPhiStr.replacingOccurrences(of: ",", with: ".")) ?? 0.85
        guard load > 0, cosf > 0 else { return }
        let apparentKVA = (load / cosf) * (1.0 + reservePercent / 100.0)
        let suggested = standardSizes.first(where: { $0 >= apparentKVA }) ?? standardSizes.last!
        withAnimation { requiredKVA = apparentKVA; suggestedKVA = suggested }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Topraklama Hesabı

struct EarthingCalculatorView: View {

    private let color = Color(red: 0.3, green: 0.85, blue: 0.5)

    @State private var raStr: String  = ""   // Toprak direnci Ω
    @State private var iaStr: String  = ""   // Koruma akımı A
    @State private var limitV: Double = 50   // İzin verilen dokunma gerilimi (50V)

    @State private var result: EarthingResult? = nil

    struct EarthingResult {
        let touchVoltage: Double
        let maxRA: Double
        let isCompliant: Bool
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Topraklama Kontrolü")
                        .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("RA × Ia ≤ UL koşulu — IEC 60364 / TN-TT sistem")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                usageBanner(color: color, text: "Toprak elektrot direncini (RA) ve koruma akımını (Ia) girin. IEC 60364 gereği RA × Ia ≤ 50 V koşulunun sağlanıp sağlanmadığını kontrol eder, izin verilen maksimum toprak direncini hesaplar.")

                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: "arrow.down.to.line.compact").foregroundStyle(color); Text("Topraklama Parametreleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white) }

                    HStack(spacing: 12) {
                        earthField("Toprak Direnci (RA)", placeholder: "Örn: 10", text: $raStr, unit: "Ω")
                        earthField("Koruma Akımı (Ia)", placeholder: "Örn: 30", text: $iaStr, unit: "A")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("İzin Verilen Dokunma Gerilimi").font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
                            Spacer()
                            Text(String(format: "%.0f V", limitV)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
                        }
                        HStack(spacing: 8) {
                            limitButton("25 V", 25)
                            limitButton("50 V", 50)
                        }
                    }
                }
                .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))

                calcButton(label: "Topraklama Kontrol Et", color: color) { calculate() }

                if let res = result {
                    resultCard(res)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                infoCards
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
        }
        .background(darkBG.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: result?.isCompliant)
        .scrollDismissesKeyboard(.immediately)
    }

    private func earthField(_ label: String, placeholder: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
            HStack {
                TextField(placeholder, text: text).keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(unit).font(.system(size: 12)).foregroundStyle(.gray)
            }
            .padding(10).background(Color.white.opacity(0.06)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func limitButton(_ label: String, _ value: Double) -> some View {
        Button { limitV = value } label: {
            Text(label)
                .font(.system(size: 13, weight: limitV == value ? .bold : .medium, design: .rounded))
                .foregroundStyle(limitV == value ? .black : color.opacity(0.8))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(limitV == value ? color : Color.white.opacity(0.06))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func resultCard(_ res: EarthingResult) -> some View {
        let sc: Color = res.isCompliant ? .green : .red
        return VStack(spacing: 14) {
            HStack {
                Image(systemName: res.isCompliant ? "checkmark.shield.fill" : "xmark.shield.fill").foregroundStyle(sc)
                Text(res.isCompliant ? "Topraklama UYGUN" : "Topraklama UYGUN DEĞİL")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(sc)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(String(format: "%.1f", res.touchVoltage)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(sc)
                    Text("V Dokunma").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                Divider().background(sc.opacity(0.3)).frame(height: 50)
                VStack(spacing: 3) {
                    Text(String(format: "%.1f", res.maxRA)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(color)
                    Text("Ω Max RA").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().background(Color.white.opacity(0.1))

            let ra = Double(raStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            let ia = Double(iaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            resultRow("RA × Ia", String(format: "%.1f V", ra * ia), color: sc)
            resultRow("Limit", String(format: "%.0f V", limitV))
            resultRow("İzin Verilen Maks RA", String(format: "%.2f Ω", res.maxRA), color: color)

            if !res.isCompliant {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.system(size: 13))
                    Text("Toprak direncini \(String(format: "%.2f Ω", res.maxRA)) altına düşürün veya daha düşük eşikli bir koruma rölesi kullanın.")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.red.opacity(0.9))
                }
                .padding(10).background(Color.red.opacity(0.08)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.25), lineWidth: 1))
            }
        }
        .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(sc.opacity(0.35), lineWidth: 1))
    }

    private var infoCards: some View {
        VStack(spacing: 10) {
            hapBilgi(icon: "arrow.down.to.line.compact", title: "RA × Ia ≤ UL Koşulu", body: "RA: toprak elektrot direnci (Ω) · Ia: koruma akımı eşiği (A) · UL: izin verilen temas gerilimi (50 V kuru / 25 V ıslak ortam)", color: color)
            hapBilgi(icon: "bolt.shield", title: "Sistem Tipleri", body: "TN-C-S: PEN iletkeni · TT: bağımsız topraklama, RCD gerekli · IT: yalıtılmış, 2. arıza tehlikelidir", color: .blue)
            hapBilgi(icon: "doc.badge.checkmark", title: "IEC 60364 / TS HD 60364", body: "Alçak gerilim elektrik tesisleri için güvenlik gereksinimleri. Koruma iletkenlerinin seçimi ve boyutlandırması.", color: .teal)
        }
    }

    private func calculate() {
        let ra = Double(raStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let ia = Double(iaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard ra > 0, ia > 0 else { return }
        let touchV = ra * ia
        let maxRA  = limitV / ia
        withAnimation { result = EarthingResult(touchVoltage: touchV, maxRA: maxRA, isCompliant: touchV <= limitV) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Motor Başlatma Hesabı

struct MotorStartingCalculatorView: View {

    private let color = Color.indigo

    @State private var powerKW:    String = ""
    @State private var voltageStr: String = "400"
    @State private var efficiencyStr: String = "92"
    @State private var cosPhiStr:  String = "0.85"
    @State private var startMode: StartMode = .starDelta

    @State private var result: MotorResult? = nil

    enum StartMode: String, CaseIterable {
        case directOnLine = "Direkt (DOL)"
        case starDelta    = "Yıldız-Üçgen (Y-Δ)"
    }

    struct MotorResult {
        let nominalA: Double
        let startingA: Double
        let suggestedFuseA: Int
        let suggestedSectionMM2: Double
    }

    private let standardFuses = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200]
    private let standardSections: [Double] = [1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Motor Başlatma Hesabı")
                        .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Yıldız-üçgen / DOL başlatma akımı, sigorta ve kablo seçimi")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                usageBanner(color: color, text: "Motor gücü, gerilim, verim ve güç faktörünü girin. Nominal akım, başlatma akımı (DOL veya Y-Δ) otomatik hesaplanır. Önerilen sigorta ve kablo kesiti gösterilir.")

                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: "fan.fill").foregroundStyle(color); Text("Motor Parametreleri").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white) }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        motorField("Motor Gücü (kW)", placeholder: "Örn: 22", text: $powerKW)
                        motorField("Gerilim (V)", placeholder: "400", text: $voltageStr)
                        motorField("Verim η (%)", placeholder: "92", text: $efficiencyStr)
                        motorField("cos φ", placeholder: "0.85", text: $cosPhiStr)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Başlatma Yöntemi").font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
                        HStack(spacing: 8) {
                            ForEach(StartMode.allCases, id: \.self) { mode in
                                Button {
                                    withAnimation(.spring(response: 0.25)) { startMode = mode }
                                } label: {
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: startMode == mode ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(startMode == mode ? .black : color.opacity(0.8))
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(startMode == mode ? color : Color.white.opacity(0.06))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))

                calcButton(label: "Hesapla", color: color) { calculate() }

                if let res = result {
                    resultCard(res)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                infoCards
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
        }
        .background(darkBG.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: result?.nominalA)
        .scrollDismissesKeyboard(.immediately)
    }

    private func motorField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray).lineLimit(1)
            TextField(placeholder, text: text).keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .padding(10).background(Color.white.opacity(0.06)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func resultCard(_ res: MotorResult) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Motor Başlatma Sonuçları").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(String(format: "%.1f", res.nominalA)).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(amber)
                    Text("A Nominal").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                Divider().background(color.opacity(0.3)).frame(height: 50)
                VStack(spacing: 3) {
                    Text(String(format: "%.1f", res.startingA)).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.orange)
                    Text("A Başlatma").font(.system(size: 11)).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().background(Color.white.opacity(0.1))

            resultRow("Başlatma Yöntemi", startMode.rawValue, color: color)
            resultRow("Başlatma Akımı Katsayısı", startMode == .starDelta ? "× 2 (Y-Δ)" : "× 6–7 (DOL)", color: .orange)
            resultRow("Önerilen Sigorta (gG)", "\(res.suggestedFuseA) A", color: .yellow)
            resultRow("Önerilen Kablo Kesiti", String(format: "%.1f mm²", res.suggestedSectionMM2), color: amber)

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(color).font(.system(size: 13))
                Text(startMode == .starDelta
                     ? "Y-Δ başlatmada motor sargıları önce yıldız, sonra üçgen bağlı çalışır. Başlatma süresi 5–15 sn; yük altında start etmez."
                     : "DOL başlatmada tam gerilim uygulanır. Şebeke gerilimi düşmelerine dikkat edin. Büyük motorlarda (>7,5 kW) tavsiye edilmez.")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(color.opacity(0.85))
            }
            .padding(10).background(color.opacity(0.08)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 1))
        }
        .padding(16).background(cardBG).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1))
    }

    private var infoCards: some View {
        VStack(spacing: 10) {
            hapBilgi(icon: "bolt.circle.fill", title: "Nominal Akım Formülü", body: "In = P / (√3 × U × η × cos φ)\nη ve cos φ ondalık olarak girilir (örn: 92% → 0.92)", color: color)
            hapBilgi(icon: "arrow.triangle.2.circlepath", title: "Yıldız-Üçgen Avantajı", body: "Başlatma akımını DOL'un 1/3'üne indirir. 5–30 sn sonra üçgen geçişte geçici akım artışı oluşur.", color: .teal)
            hapBilgi(icon: "shield.fill", title: "Sigorta Seçimi", body: "Motor sigortaları: In × 1.25 kuralı, motor koruma şalteri (MKŞ) ile birlikte kullanılır. gG tipi sigorta tercih edin.", color: .orange)
            hapBilgi(icon: "cable.connector", title: "Kablo Boyutlandırma", body: "IEC 60364-5-52 tablosuna göre nominal akım baz alınır. Uzun mesafelerde gerilim düşümü kontrolü yapın.", color: .green)
        }
    }

    private func calculate() {
        let p   = Double(powerKW.replacingOccurrences(of: ",", with: ".")) ?? 0
        let u   = Double(voltageStr.replacingOccurrences(of: ",", with: ".")) ?? 400
        let eta = (Double(efficiencyStr.replacingOccurrences(of: ",", with: ".")) ?? 92) / 100.0
        let pf  = Double(cosPhiStr.replacingOccurrences(of: ",", with: ".")) ?? 0.85
        guard p > 0, u > 0, eta > 0, pf > 0 else { return }

        let nominalA = (p * 1000.0) / (sqrt(3.0) * u * eta * pf)
        let startingA: Double = startMode == .starDelta ? nominalA * 2.0 : nominalA * 6.5

        // Sigorta önerisi: In × 1.25, yukarıya yuvarla
        let fuseMin = nominalA * 1.25
        let fuseA = standardFuses.first(where: { Double($0) >= fuseMin }) ?? standardFuses.last!

        // Kablo kesiti: nominal akıma göre basit tablo
        let sectionMM2: Double
        switch nominalA {
        case ..<10:  sectionMM2 = 1.5
        case ..<16:  sectionMM2 = 2.5
        case ..<22:  sectionMM2 = 4.0
        case ..<30:  sectionMM2 = 6.0
        case ..<40:  sectionMM2 = 10.0
        case ..<55:  sectionMM2 = 16.0
        case ..<75:  sectionMM2 = 25.0
        case ..<100: sectionMM2 = 35.0
        case ..<130: sectionMM2 = 50.0
        default:     sectionMM2 = 70.0
        }

        withAnimation {
            result = MotorResult(
                nominalA: nominalA,
                startingA: startingA,
                suggestedFuseA: fuseA,
                suggestedSectionMM2: sectionMM2
            )
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
