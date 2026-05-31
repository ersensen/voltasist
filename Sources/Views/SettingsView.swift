// SettingsView.swift
// VoltAsist
//
// Firma bilgileri, fiyatlandırma parametreleri ve uygulama tercihleri ayar ekranı.

import SwiftUI

// MARK: - SettingsView

/// Firma bilgileri, işçilik ücreti, KDV, elektrik tarife ve teklif ayarlarını yöneten ekran.
struct SettingsView: View {

    @StateObject private var vm: SettingsViewModel
    @EnvironmentObject private var persistence: PersistenceService
    @State private var showResetAlert = false
    @State private var showSavedToast = false

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.07, green: 0.07, blue: 0.09)

    init() {
        _vm = StateObject(wrappedValue: SettingsViewModel(persistence: PersistenceService.shared))
    }

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    companySection
                    pricingSection
                    solarSection
                    compensationSection
                    quoteSection
                    dangerZone
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Kaydet toast bildirimi
            if showSavedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Ayarlar kaydedildi")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: showSavedToast)
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: saveSettings) {
                    Text("Kaydet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(amber)
                }
            }
        }
        .alert("Varsayılanlara Dön?", isPresented: $showResetAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sıfırla", role: .destructive) {
                vm.resetToDefaults(in: persistence)
            }
        } message: {
            Text("Tüm ayarlar fabrika değerlerine sıfırlanacak. Bu işlem geri alınamaz.")
        }
    }

    // MARK: - Firma Bilgileri

    private var companySection: some View {
        settingsCard(title: "🏢 Firma Bilgileri", icon: "building.2.fill") {
            settingsField(label: "Firma Adı", placeholder: "VoltAsist Elektrik", text: $vm.settings.companyName)
            settingsField(label: "Yetkili Adı", placeholder: "Ad Soyad", text: $vm.settings.ownerName)
            settingsField(label: "Telefon", placeholder: "0532 123 45 67", text: $vm.settings.phone)
                .keyboardType(.phonePad)
            settingsField(label: "E-posta", placeholder: "info@voltasist.com", text: $vm.settings.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            settingsField(label: "Adres", placeholder: "İl, İlçe, Mahalle...", text: $vm.settings.address)
            settingsField(label: "Vergi No", placeholder: "1234567890 (opsiyonel)",
                          text: Binding(get: { vm.settings.taxNumber ?? "" },
                                        set: { vm.settings.taxNumber = $0.isEmpty ? nil : $0 }))
                .keyboardType(.numberPad)
        }
    }

    // MARK: - Fiyatlandırma

    private var pricingSection: some View {
        settingsCard(title: "💰 Fiyatlandırma", icon: "turkishlirasign.circle.fill") {
            numericField(label: "İşçilik Ücreti", suffix: "₺/saat", value: $vm.settings.laborRatePerHour)
            numericField(label: "Elektrik Birim Fiyatı", suffix: "₺/kWh", value: $vm.settings.electricityUnitPrice)
            numericField(label: "TEDAŞ Ceza Tarifesi", suffix: "₺/kVArh", value: $vm.settings.tedasPenaltyTariff)

            VStack(alignment: .leading, spacing: 6) {
                Text("Varsayılan KDV Oranı")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Picker("", selection: $vm.settings.defaultVatRate) {
                    Text("%0").tag(0.0)
                    Text("%10").tag(10.0)
                    Text("%20").tag(20.0)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Solar

    private var solarSection: some View {
        settingsCard(title: "☀️ Solar Parametreleri", icon: "sun.max.fill") {
            numericField(label: "Net Metering Tarife", suffix: "₺/kWh", value: $vm.settings.feedInTariff)
            numericField(label: "Kurulum Maliyeti", suffix: "₺/kWp", value: $vm.settings.installationCostPerKWp)
        }
    }

    // MARK: - Kompanzasyon

    private var compensationSection: some View {
        settingsCard(title: "⚡ Kompanzasyon Parametreleri", icon: "bolt.circle.fill") {
            numericField(label: "Hedef cos φ", suffix: "", value: $vm.settings.defaultTargetCosPhi)
                .keyboardType(.decimalPad)
            HStack {
                Text("Hedef cos φ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Slider(value: $vm.settings.defaultTargetCosPhi, in: 0.85...1.0, step: 0.01)
                    .tint(amber)
                    .frame(width: 140)
                Text(String(format: "%.2f", vm.settings.defaultTargetCosPhi))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                    .frame(width: 40)
            }
        }
    }

    // MARK: - Teklif Ayarları

    private var quoteSection: some View {
        settingsCard(title: "📋 Teklif Ayarları", icon: "doc.text.fill") {
            HStack {
                Text("Geçerlilik Süresi")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Stepper("\(vm.settings.quoteValidityDays) gün",
                        value: $vm.settings.quoteValidityDays,
                        in: 7...90, step: 7)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack {
                Text("Sonraki Teklif No")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text(QuoteEngine.generateQuoteNumber(sequence: vm.settings.nextQuoteNumber))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(amber)
            }
        }
    }

    // MARK: - Tehlike Bölgesi

    private var dangerZone: some View {
        VStack(spacing: 10) {
            Button(action: { showResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Varsayılan Ayarlara Dön")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.08))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }

            Text("Versiyon 1.0.0 • VoltAsist\nIEC 60364 • IEC 61921 • TS EN 60831")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Yardımcı Bileşenler

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.85))

            Divider().background(Color.white.opacity(0.08))

            content()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.12), lineWidth: 1))
    }

    private func settingsField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
        }
    }

    private func numericField(label: String, suffix: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            Spacer()
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }

    private func saveSettings() {
        vm.save(to: persistence)
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PersistenceService.shared)
    }
}
