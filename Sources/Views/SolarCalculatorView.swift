// SolarCalculatorView.swift
// VoltAsist
//
// Güneş enerji sistemi boyutlandırma ve ekonomik analiz ekranı.
// On-Grid, Off-Grid ve Hibrit sistemler için 4 sekmeli premium arayüz.

import SwiftUI
import Charts

// MARK: - SolarCalculatorView

/// Solar enerji hesaplama ana ekranı.
/// Şehir bazlı PSH değerleri, panel/batarya boyutlandırma ve 25 yıllık ekonomik analiz içerir.
struct SolarCalculatorView: View {

    @StateObject private var vm = SolarCalculatorViewModel()
    @EnvironmentObject private var persistence: PersistenceService
    @State private var showCityPicker = false
    @State private var addedToQuote  = false
    @State private var showQuoteAlert = false

    // MARK: State — Panel Gücü (Wp) — malzeme listesi için kullanıcı tarafından değiştirilebilir
    @State private var panelWp          : Double = 400      // varsayılan 400Wp

    // MARK: State — Malzeme Birim Fiyatları (₺, KDV dahil, 2026 piyasası)
    @State private var pricePanel       : Double = 2_200    // 400Wp monokristalin panel
    @State private var priceInverter    : Double = 22_000   // inverter (tam ünite, 5kW ref.)
    @State private var priceBattery     : Double = 10_500   // 100Ah/12V LiFePO4 batarya
    @State private var priceMountRail   : Double = 280      // montaj sacı + alüm. ray (panel/set)
    @State private var priceDCCable     : Double = 32       // DC solar kablo PV1-F 4mm² (₺/m)
    @State private var priceACCable     : Double = 65       // AC kablo NYY 3×4mm² (₺/m)
    @State private var priceFuse        : Double = 160      // DC string sigorta + tutucu (adet)
    @State private var priceGrounding   : Double = 1_800    // topraklama seti (set)
    @State private var priceRoofHook    : Double = 130      // çatı kancası alüm. (adet)
    @State private var priceJunctionBox : Double = 550      // junction box / DC combiner (adet)

    // Amber-Solar renk sistemi
    private let sunGold   = Color(red: 1.0,  green: 0.80, blue: 0.10)
    private let sunOrange = Color(red: 1.0,  green: 0.55, blue: 0.10)
    private let darkBG    = Color(red: 0.07, green: 0.07, blue: 0.09)

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Başlık
                    solarHeader

                    // Kullanım talimatı
                    solarUsageNote

                    // Parametreler
                    parametersCard

                    // Hesapla butonu
                    calculateButton

                    // Sonuçlar (hesaplandıktan sonra görünür)
                    if let result = vm.result, vm.showResult {
                        resultTabs(result: result)
                        solarMaterialListSection(result: result)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(selectedCity: $vm.input.city, searchText: $vm.citySearchText)
        }
        .alert("Teklif'e Eklendi", isPresented: $showQuoteAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Teklif sekmesine eklendi, görmek için Dashboard > Teklifler'e gidin.")
        }
    }

    // MARK: - Header

    private var solarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(sunGold.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 28))
                    .foregroundColor(sunGold)
                    .shadow(color: sunGold.opacity(0.6), radius: 8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Solar Enerji Hesabı")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("On-Grid • Off-Grid • Hibrit")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Kullanım Notu

    private var solarUsageNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(sunGold)
                .font(.system(size: 16))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Nasıl Kullanılır?")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(sunGold)
                Text("Talep gücünüzü (kW) ve günlük kullanım süresini (saat/gün) girin — aylık tüketim otomatik hesaplanır. Şehir ve sistem tipini seçin. Hesapla'ya basın; panel kapasitesi, inverter gücü ve 25 yıllık ekonomik analiz otomatik hesaplanır.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sunGold.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(sunGold.opacity(0.22), lineWidth: 1))
        )
    }

    // MARK: - Parametreler Kartı

    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("📋 Sistem Parametreleri")

            // Talep Gücü + Günlük Kullanım
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Talep Gücü")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("2.0", value: $vm.input.demandKW, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("kW")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Günlük Kullanım")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("8", value: $vm.input.dailyUsageHours, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("saat/gün")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }

            // Türetilmiş aylık tüketim
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(sunGold.opacity(0.6))
                Text("Aylık Tüketim:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Text(String(format: "≈ %.0f kWh/ay", vm.input.monthlyConsumptionKWh))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(sunGold)
                Spacer()
                Text("talep × saat × 30")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.45))
            }
            .padding(.horizontal, 4)

            // Şehir seçimi
            Button(action: { showCityPicker = true }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(sunGold)
                    Text(vm.input.city.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(vm.pshFormatted)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }

            // Sistem tipi
            VStack(alignment: .leading, spacing: 6) {
                Text("Sistem Tipi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                Picker("", selection: $vm.input.systemType) {
                    ForEach(SolarSystemType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.input.systemType) { _, newType in
                    switch newType {
                    case .hybrid:  vm.input.autonomyDays = 1.0
                    case .offGrid: vm.input.autonomyDays = 2.0
                    case .onGrid:  break
                    }
                }
            }

            // Eğim ve Yön (yan yana)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Eğim (°)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("30", value: $vm.input.roofTiltDeg, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("°")
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Yön (°)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("0", value: $vm.input.roofOrientationDeg, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("°")
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }

            // Off-Grid / Hibrit ek parametreler
            if vm.input.systemType != .onGrid {
                Divider().background(Color.white.opacity(0.1))

                sectionLabel("🔋 Batarya Parametreleri")

                // Batarya tipi
                VStack(alignment: .leading, spacing: 6) {
                    Text("Batarya Tipi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    Picker("", selection: $vm.input.batteryType) {
                        ForEach(BatteryType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Sistem gerilimi ve otonom gün
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sistem Gerilimi")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        Picker("", selection: $vm.input.systemVoltage) {
                            Text("12V").tag(12)
                            Text("24V").tag(24)
                            Text("48V").tag(48)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Otonom Gün")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        HStack {
                            TextField("2", value: $vm.input.autonomyDays, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("gün")
                                .foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                if vm.input.systemType == .hybrid {
                    let dailyKWh = vm.input.monthlyConsumptionKWh / 30.0
                    let rawKWh = (dailyKWh * vm.input.autonomyDays) / max(vm.input.batteryType.dod, 0.01)
                    let totalKWh = rawKWh / max(vm.input.batteryType.efficiency, 0.01)
                    HStack(spacing: 6) {
                        Image(systemName: "battery.75")
                            .font(.system(size: 12))
                            .foregroundColor(sunGold.opacity(0.8))
                        Text(String(format: "≈ %.1f kWh hibrit batarya kapasitesi", totalKWh))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(sunGold)
                    }
                    .padding(.horizontal, 4)
                }
            }

            Divider().background(Color.white.opacity(0.1))
            sectionLabel("💰 Fiyat Parametreleri")

            HStack(spacing: 12) {
                currencyField(title: "Elektrik (₺/kWh)", value: $vm.input.electricityPrice)
                currencyField(title: "Kurulum (₺/kWp)", value: $vm.input.installationCostPerKWp)
            }
            if vm.input.systemType != .offGrid {
                currencyField(title: "Net Metering (₺/kWh)", value: $vm.input.feedInTariff)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Hesapla Butonu

    private var calculateButton: some View {
        Button(action: { vm.calculate() }) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Hesapla")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [sunGold, sunOrange], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(14)
            .shadow(color: sunGold.opacity(0.4), radius: 8, y: 4)
        }
    }

    // MARK: - Sonuç Sekmeleri

    @ViewBuilder
    private func resultTabs(result: SolarCalculationResult) -> some View {
        TabView {
            panelResultView(result)
                .tabItem { Label("Panel", systemImage: "square.grid.3x3.fill") }
            if vm.input.systemType != .onGrid {
                batteryResultView(result)
                    .tabItem { Label("Batarya", systemImage: "battery.100") }
            }
            economyResultView(result)
                .tabItem { Label("Ekonomi", systemImage: "chart.line.uptrend.xyaxis") }
            co2ResultView(result)
                .tabItem { Label("Çevre", systemImage: "leaf.fill") }
        }
        .frame(height: 420)
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    // MARK: Panel Sonuçlar

    private func panelResultView(_ result: SolarCalculationResult) -> some View {
        VStack(spacing: 14) {
            sectionLabel("⚡ Panel Sistem Sonuçları")

            HStack(spacing: 12) {
                resultMetric(title: "Sistem Gücü", value: String(format: "%.2f kWp", result.requiredCapacityKWp), accent: sunGold)
                resultMetric(title: "Panel Adedi", value: "\(result.panelCount) adet", accent: sunOrange)
            }
            HStack(spacing: 12) {
                resultMetric(title: "Çatı Alanı", value: String(format: "%.1f m²", result.roofAreaM2), accent: .cyan)
                resultMetric(title: "Yıllık Üretim", value: String(format: "%.0f kWh", result.annualProductionKWh), accent: .green)
            }
            HStack(spacing: 12) {
                resultMetric(title: "Özgül Verim", value: String(format: "%.0f kWh/kWp", result.specificYield), accent: .purple)
                resultMetric(title: "İnverter", value: String(format: "%.1f kW", result.inverterKW), accent: .orange)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 2)
    }

    // MARK: Batarya Sonuçlar

    private func batteryResultView(_ result: SolarCalculationResult) -> some View {
        VStack(spacing: 14) {
            sectionLabel("🔋 Batarya Sistemi")

            if vm.input.systemType == .onGrid {
                Text("On-Grid sistemde batarya kullanılmaz.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    resultMetric(title: "Kapasite (kWh)", value: String(format: "%.1f kWh", result.batteryCapacityKWh), accent: sunGold)
                    resultMetric(title: "Kapasite (Ah)", value: String(format: "%.0f Ah", result.batteryCapacityAh), accent: sunOrange)
                }
                HStack(spacing: 12) {
                    resultMetric(title: "Batarya Adedi", value: "\(result.batteryCount) adet", accent: .cyan)
                    resultMetric(title: "Şarj Akımı", value: String(format: "%.1f A", result.chargeCurrentA), accent: .green)
                }
                HStack(spacing: 12) {
                    resultMetric(title: "Tip", value: vm.input.batteryType.rawValue, accent: .purple)
                    resultMetric(title: "Sistem", value: "\(vm.input.systemVoltage) V DC", accent: .orange)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 2)
    }

    // MARK: Ekonomi Sonuçlar

    private func economyResultView(_ result: SolarCalculationResult) -> some View {
        VStack(spacing: 14) {
            sectionLabel("💰 Ekonomik Analiz")

            HStack(spacing: 12) {
                resultMetric(title: "Toplam Yatırım", value: formatTL(result.totalInvestmentTL), accent: sunGold)
                resultMetric(title: "Yıllık Tasarruf", value: formatTL(result.annualSavingTL), accent: .green)
            }
            HStack(spacing: 12) {
                resultMetric(title: "Geri Ödeme", value: vm.paybackYearsFormatted, accent: sunOrange)
                resultMetric(title: "Şebeke Geliri", value: formatTL(result.annualGridIncomeTL) + "/yıl", accent: .cyan)
            }

            // 25 yıllık üretim grafiği
            if !result.yearlyProduction.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("25 Yıllık Üretim Tahmini")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Chart {
                        ForEach(Array(result.yearlyProduction.enumerated()), id: \.offset) { year, production in
                            AreaMark(
                                x: .value("Yıl", year + 1),
                                y: .value("kWh", production)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [sunGold.opacity(0.7), sunOrange.opacity(0.2)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: [1, 5, 10, 15, 20, 25]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0). yıl").font(.system(size: 9)).foregroundColor(.gray) }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel().foregroundStyle(Color.gray)
                        }
                    }
                    .frame(height: 100)
                }
            }

            // Teklif'e ekle
            Button(action: {
                if let res = vm.result {
                    let items = QuoteEngine.itemsFromSolar(res, input: vm.input)
                    var quote = QuoteEngine.createNewQuote(
                        sequence: persistence.settings.nextQuoteNumber,
                        settings: persistence.settings
                    )
                    quote.items = items
                    persistence.saveQuote(quote)
                    var updatedSettings = persistence.settings
                    updatedSettings.nextQuoteNumber += 1
                    persistence.saveSettings(updatedSettings)
                }
                showQuoteAlert = true
            }) {
                Label("Teklif'e Ekle", systemImage: "doc.badge.plus")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(sunGold)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 2)
    }

    // MARK: CO2 Sonuçlar

    private func co2ResultView(_ result: SolarCalculationResult) -> some View {
        VStack(spacing: 14) {
            sectionLabel("🌿 Çevresel Etki")

            // Büyük CO2 sayısı
            VStack(spacing: 6) {
                Text(String(format: "%.1f", result.co2SavingTonPerYear))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                Text("ton CO₂/yıl tasarruf")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.08))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2), lineWidth: 1))

            HStack(spacing: 12) {
                co2Metric(icon: "car.fill",
                          value: String(format: "%.0f", result.co2SavingTonPerYear * 1000 / 0.170),
                          label: "km'lik araba yolculuğu")
                co2Metric(icon: "tree.fill",
                          value: String(format: "%.0f", result.co2SavingTonPerYear * 45),
                          label: "ağaç dikimi eşdeğeri")
            }

            HStack(spacing: 12) {
                resultMetric(title: "25 Yılda CO₂", value: String(format: "%.0f ton", result.co2SavingTonPerYear * 25), accent: .green)
                resultMetric(title: "Yıllık Üretim", value: vm.annualProductionFormatted, accent: .mint)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 2)
    }

    // MARK: - Malzeme Listesi

    private func solarMaterialListSection(result: SolarCalculationResult) -> some View {
        let effectiveWp    = max(1.0, panelWp)
        let derivedCount   = max(1, Int(ceil(result.requiredCapacityKWp * 1000.0 / effectiveWp)))
        let panelQty  = Double(derivedCount)
        let batQty    = Double(result.batteryCount)
        let dcCableM  = panelQty * 10                    // panel başına ~10m DC kablo
        let hookQty   = panelQty * 4                     // panel başına 4 kanca
        let fuseQty   = Double(max(1, derivedCount / 4))
        let jboxQty   = Double(max(1, Int(ceil(panelQty / 8))))

        let grandTotal = panelQty  * pricePanel
                       + 1         * priceInverter
                       + batQty    * priceBattery
                       + panelQty  * priceMountRail
                       + dcCableM  * priceDCCable
                       + 20        * priceACCable
                       + fuseQty   * priceFuse
                       + 1         * priceGrounding
                       + hookQty   * priceRoofHook
                       + jboxQty   * priceJunctionBox

        return VStack(alignment: .leading, spacing: 0) {
            // Başlık
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard.fill").foregroundColor(sunGold)
                Text("Malzeme Listesi")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                Spacer()
                // Kullanıcı tarafından değiştirilebilir panel gücü
                HStack(spacing: 3) {
                    TextField("400", value: $panelWp, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(sunGold)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(7)
                    Text("Wp")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray.opacity(0.55))
                }
                Label("KDV Dahil", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(sunGold.opacity(0.75))
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.4))
                Text("\(derivedCount) panel · \(String(format: "%.2f", result.requiredCapacityKWp)) kWp ihtiyaç")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.gray.opacity(0.45))
            }
            .padding(.bottom, 10)

            // Kolon başlıkları
            HStack {
                Text("MALZEME")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("BİRİM FİYAT")
                    .frame(width: 90, alignment: .trailing)
                Text("TOPLAM")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.gray.opacity(0.5))
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.1)).padding(.bottom, 6)

            // Malzeme satırları
            materialPriceRow(
                name: "Güneş Paneli (\(Int(panelWp))Wp Monokristalin)",
                qty: panelQty, unit: "adet", price: $pricePanel
            )
            materialPriceRow(
                name: "İnverter (\(String(format: "%.1f", result.inverterKW)) kW)",
                qty: 1, unit: "adet", price: $priceInverter
            )
            if result.batteryCount > 0 {
                materialPriceRow(
                    name: "Batarya 100Ah/12V — \(vm.input.batteryType.rawValue)",
                    qty: batQty, unit: "adet", price: $priceBattery
                )
            }
            materialPriceRow(
                name: "Montaj Sacı + Alüminyum Ray",
                qty: panelQty, unit: "set", price: $priceMountRail
            )
            materialPriceRow(
                name: "DC Solar Kablo (PV1-F 4mm²)",
                qty: dcCableM, unit: "m", price: $priceDCCable
            )
            materialPriceRow(
                name: "AC Kablo (NYY 3×4mm²)",
                qty: 20, unit: "m", price: $priceACCable
            )
            materialPriceRow(
                name: "DC String Sigorta + Tutucu",
                qty: fuseQty, unit: "adet", price: $priceFuse
            )
            materialPriceRow(
                name: "Topraklama Seti",
                qty: 1, unit: "set", price: $priceGrounding
            )
            materialPriceRow(
                name: "Çatı Kancası (Alüminyum)",
                qty: hookQty, unit: "adet", price: $priceRoofHook
            )
            materialPriceRow(
                name: "Junction Box / DC Combiner",
                qty: jboxQty, unit: "adet", price: $priceJunctionBox
            )

            Divider().background(sunGold.opacity(0.35)).padding(.vertical, 8)

            // Genel toplam
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GENEL TOPLAM")
                        .font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text("Malzeme • KDV dahil • İşçilik hariç")
                        .font(.system(size: 10)).foregroundColor(.gray.opacity(0.5))
                }
                Spacer()
                Text(formatTL(grandTotal))
                    .font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(sunGold)
                    .shadow(color: sunGold.opacity(0.5), radius: 6)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(sunGold.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(sunGold.opacity(0.3), lineWidth: 1))
            )
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(sunGold.opacity(0.2), lineWidth: 1))
    }

    private func materialPriceRow(name: String, qty: Double, unit: String, price: Binding<Double>) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(Int(qty)) \(unit)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.gray.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Düzenlenebilir birim fiyat
                VStack(alignment: .trailing, spacing: 2) {
                    TextField("0", value: price, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(sunGold)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .frame(width: 80)
                    Text("₺ / \(unit)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .frame(width: 90, alignment: .trailing)

                // Satır toplamı
                Text(formatTL(qty * price.wrappedValue))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .trailing)
            }
            Divider().background(Color.white.opacity(0.06)).padding(.top, 8)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Yardımcı Bileşenler

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
    }

    private func currencyField(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
        }
    }

    private func resultMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(accent.opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.2), lineWidth: 1))
    }

    private func co2Metric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.green.opacity(0.07))
        .cornerRadius(12)
    }

    private func formatTL(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return (fmt.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)) + " ₺"
    }
}

// MARK: - Şehir Seçici Sheet

struct CityPickerSheet: View {
    @Binding var selectedCity: TurkishCity
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    private let sunGold = Color(red: 1.0, green: 0.80, blue: 0.10)

    var filteredCities: [TurkishCity] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return TurkishCity.allCases }
        return TurkishCity.allCases.filter { $0.rawValue.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filteredCities) { city in
                Button(action: {
                    selectedCity = city
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(city.climateZone)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 12))
                                .foregroundColor(sunGold)
                            Text(String(format: "%.1f saat/gün", city.peakSunHours))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(sunGold)
                        }
                        if city == selectedCity {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Şehir ara...")
            .navigationTitle("Şehir Seçin (81 İl)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SolarCalculatorView()
            .environmentObject(PersistenceService.shared)
    }
}
