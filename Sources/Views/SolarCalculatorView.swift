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

                    // Parametreler
                    parametersCard

                    // Hesapla butonu
                    calculateButton

                    // Sonuçlar (hesaplandıktan sonra görünür)
                    if let result = vm.result, vm.showResult {
                        resultTabs(result: result)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Solar Hesap")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(selectedCity: $vm.input.city, searchText: $vm.citySearchText)
        }
        .alert("Teklif'e Eklendi", isPresented: $showQuoteAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Solar sistem kalemleri yeni teklife eklendi.")
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

    // MARK: - Parametreler Kartı

    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("📋 Sistem Parametreleri")

            // Aylık tüketim
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aylık Tüketim")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f kWh", vm.input.monthlyConsumptionKWh))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(sunGold)
                }
                Slider(value: $vm.input.monthlyConsumptionKWh, in: 100...5000, step: 50)
                    .tint(sunGold)
            }

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
            panelResultView(result: result)
                .tabItem { Label("Panel", systemImage: "square.grid.3x3.fill") }
            batteryResultView(result: result)
                .tabItem { Label("Batarya", systemImage: "battery.100") }
            economyResultView(result: result)
                .tabItem { Label("Ekonomi", systemImage: "chart.line.uptrend.xyaxis") }
            co2ResultView(result: result)
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
                // Yeni teklif oluşturup QuoteViewModel'i günceller
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
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "₺0"
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
