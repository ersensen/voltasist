// DashboardView.swift
// VoltAsist
//
// Premium ana ekran — istatistik kartları, hızlı erişim ve son teklifler.
// Amber glow efektleri, spring animasyonlar ve glassmorphism kartlar.

import SwiftUI

// MARK: - DashboardView

/// Ana dashboard — istatistikler, hızlı hesap kısayolları ve son teklifler
struct DashboardView: View {

    // MARK: Environment
    @EnvironmentObject private var persistence: PersistenceService

    // MARK: State
    /// İstatistik kartı animasyon tamamlandı mı?
    @State private var statsAppeared = false
    /// Hızlı hesap buton basma efekti
    @State private var pressedButton: String? = nil
    /// Acil arama butonu görünürlüğü
    @State private var showEmergencyCall = false

    // MARK: Tasarım Sabitleri
    private let amber    = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor  = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBG   = Color(red: 0.12, green: 0.12, blue: 0.15)

    // MARK: Body
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Logo başlık
                    headerSection

                    // İstatistik kartları 2×2
                    statsGrid

                    // Hızlı hesap butonları
                    quickAccessSection

                    // Son teklifler
                    recentQuotesSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Acil arama FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    emergencyCallButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                statsAppeared = true
            }
        }
    }

    // MARK: - Başlık Bölümü

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Amber glow ikonu
                    ZStack {
                        Circle()
                            .fill(amber.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .shadow(color: amber.opacity(0.6), radius: 10, x: 0, y: 0)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(amber)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("VoltAsist")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [amber, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: amber.opacity(0.5), radius: 6, x: 0, y: 0)

                        Text(greetingText)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.gray.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Bildirim butonu
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(amber.opacity(0.25), lineWidth: 1)
                        )

                    // Bildirim noktası
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .padding(.top, 12)
    }

    /// Günün saatine göre selamlama metni
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:  return "Günaydın! ☀️"
        case 12..<17: return "İyi günler! 💪"
        case 17..<21: return "İyi akşamlar! 🌆"
        default:      return "İyi geceler! 🌙"
        }
    }

    // MARK: - İstatistik Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Toplam Ciro",
                value: persistence.totalRevenueTL.currencyFormatted,
                icon: "turkishlirasign.circle.fill",
                color: Color.green,
                index: 0,
                appeared: statsAppeared
            )
            StatCard(
                title: "Onaylanan",
                value: "\(persistence.approvedQuoteCount) Teklif",
                icon: "checkmark.seal.fill",
                color: amber,
                index: 1,
                appeared: statsAppeared
            )
            StatCard(
                title: "Bekleyen",
                value: "\(persistence.pendingQuoteCount) Teklif",
                icon: "clock.fill",
                color: Color.orange,
                index: 2,
                appeared: statsAppeared
            )
            StatCard(
                title: "Müşteriler",
                value: "\(persistence.customerCount)",
                icon: "person.2.fill",
                color: Color.cyan,
                index: 3,
                appeared: statsAppeared
            )
        }
    }

    // MARK: - Hızlı Hesap Bölümü

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("⚡ Hızlı Hesap")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 4),
                spacing: 12
            ) {
                QuickAccessButton(
                    title: "Kablo",
                    icon: "cable.connector",
                    color: Color.yellow,
                    key: "cable",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Yük",
                    icon: "bolt.fill",
                    color: Color.orange,
                    key: "load",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Aydınlatma",
                    icon: "lightbulb.fill",
                    color: Color.cyan,
                    key: "lighting",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Kompanz.",
                    icon: "waveform.path.ecg",
                    color: Color.purple,
                    key: "comp",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Solar",
                    icon: "sun.max.fill",
                    color: Color.green,
                    key: "solar",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Teklif",
                    icon: "doc.text.fill",
                    color: amber,
                    key: "quote",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Müşteri",
                    icon: "person.fill",
                    color: Color.pink,
                    key: "customer",
                    pressed: $pressedButton
                )
                QuickAccessButton(
                    title: "Ayarlar",
                    icon: "gearshape.fill",
                    color: Color.gray,
                    key: "settings",
                    pressed: $pressedButton
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(amber.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Son Teklifler

    private var recentQuotesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("📋 Son Teklifler")
                Spacer()
                NavigationLink("Tümü →") {
                    QuoteBuilderView()
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(amber)
            }

            if persistence.quotes.isEmpty {
                emptyQuotesView
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(persistence.quotes.suffix(5).reversed())) { quote in
                        QuoteRowCard(quote: quote)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(amber.opacity(0.25), lineWidth: 1)
                )
        )
    }

    /// Teklif yoksa boş durum görseli
    private var emptyQuotesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.gray.opacity(0.4))
            Text("Henüz teklif yok")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.5))
            Text("İlk teklifinizi oluşturun!")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Acil Arama Butonu

    private var emergencyCallButton: some View {
        Button {
            let phone = persistence.settings.emergencyPhone
            guard !phone.isEmpty,
                  let url = URL(string: "tel://\(phone.filter { $0.isNumber })") else { return }
            UIApplication.shared.open(url)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.warning)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Acil Ara")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.red.opacity(0.5), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(showEmergencyCall ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showEmergencyCall)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showEmergencyCall = true
            }
        }
    }

    // MARK: - Yardımcı

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.9))
    }
}

// MARK: - İstatistik Kartı

/// Dashboard istatistik kartı — animasyonlu giriş
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let index: Int
    let appeared: Bool

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 0)
                Spacer()
            }

            Spacer()

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.gray.opacity(0.65))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.4), amber.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 4)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.08),
            value: appeared
        )
    }
}

// MARK: - Hızlı Erişim Butonu

/// Hızlı hesap grid butonu
struct QuickAccessButton: View {
    let title: String
    let icon: String
    let color: Color
    let key: String
    @Binding var pressed: String?

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var isPressed: Bool { pressed == key }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                pressed = key
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                pressed = nil
            }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(isPressed ? 0.5 : 0.2), radius: isPressed ? 10 : 4)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .scaleEffect(isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Teklif Satır Kartı

/// Son teklifler listesindeki satır
struct QuoteRowCard: View {
    let quote: Quote

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 12) {
            // Durum rengi şeridi
            RoundedRectangle(cornerRadius: 3)
                .fill(quote.status.color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(quote.customerName.isEmpty ? "İsimsiz Müşteri" : quote.customerName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(quote.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(quote.grandTotal.currencyFormatted)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(amber)

                // Durum badge
                Text(quote.status.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(quote.status.color)
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(amber.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Double Extension

extension Double {
    /// TL para formatı
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "₺\(Int(self))"
    }
}

// MARK: - QuoteStatus Extension (renk & isim)

extension QuoteStatus {
    var color: Color {
        switch self {
        case .draft:    return Color.gray
        case .sent:     return Color.orange
        case .approved: return Color.green
        case .rejected: return Color.red
        }
    }
    var displayName: String {
        switch self {
        case .draft:    return "Taslak"
        case .sent:     return "Gönderildi"
        case .approved: return "Onaylandı"
        case .rejected: return "Reddedildi"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environmentObject(PersistenceService.shared)
    .preferredColorScheme(.dark)
}
