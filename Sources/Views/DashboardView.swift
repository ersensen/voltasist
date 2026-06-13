// DashboardView.swift
// VoltAsist
//
// Ana dashboard — KPI kartları, hızlı erişim ve son teklifler.

import SwiftUI

struct DashboardView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var appeared = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bg      = Color(red: 0.06, green: 0.06, blue: 0.09)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                kpiRow
                quickAccessSection
                recentQuotesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)  // tab bar boşluğu
        }
        .background(bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(amber)
                    Text("VoltAsist")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [amber, .orange],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                Text("Elektrik Mühendisliği Asistanın")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            // Tarih badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(Date().formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                Text(Date().formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(amber.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(amber.opacity(0.2), lineWidth: 1))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 6..<12:  return "Günaydın! ☀️"
        case 12..<17: return "İyi günler! 💪"
        case 17..<21: return "İyi akşamlar! 🌆"
        default:      return "İyi geceler! 🌙"
        }
    }

    // MARK: KPI

    private var kpiRow: some View {
        HStack(spacing: 10) {
            kpiCard(
                value: persistence.totalRevenueTL.shortFormatted,
                label: "Toplam Ciro",
                icon: "turkishlirasign.circle.fill",
                color: .green,
                index: 0
            )
            kpiCard(
                value: "\(persistence.approvedQuoteCount)",
                label: "Onaylandı",
                icon: "checkmark.seal.fill",
                color: amber,
                index: 1
            )
            kpiCard(
                value: "\(persistence.pendingQuoteCount)",
                label: "Bekleyen",
                icon: "clock.badge.fill",
                color: .orange,
                index: 2
            )
            kpiCard(
                value: "\(persistence.customerCount)",
                label: "Müşteri",
                icon: "person.2.fill",
                color: .cyan,
                index: 3
            )
        }
    }

    private func kpiCard(value: String, label: String, icon: String, color: Color, index: Int) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 6)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(index) * 0.06), value: appeared)
    }

    // MARK: Quick Access

    private let quickItems: [(String, String, Color)] = [
        ("Kablo Kesit", "cable.connector", Color(red: 1, green: 0.75, blue: 0)),
        ("Yük / Güç",   "bolt.circle.fill",   .orange),
        ("Aydınlatma",  "lightbulb.fill",      .cyan),
        ("Kompanz.",    "waveform.path.ecg",   .purple),
        ("Solar",       "sun.max.fill",        .yellow),
        ("Teklif",      "doc.text.fill",       Color(red: 0.2, green: 0.8, blue: 0.5)),
        ("Müşteriler",  "person.badge.plus",   .pink),
        ("Malzeme",     "shippingbox.fill",    .brown),
    ]

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("⚡ Hızlı Hesap")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 12
            ) {
                ForEach(quickItems, id: \.0) { item in
                    quickButton(title: item.0, icon: item.1, color: item.2)
                }
            }
        }
        .padding(16)
        .background(glassBG)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(amber.opacity(0.15), lineWidth: 1))
    }

    private func quickButton(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Recent Quotes

    private var recentQuotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("📋 Son Teklifler")
                Spacer()
                Text("→ Tümü")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(amber)
            }

            if persistence.quotes.isEmpty {
                emptyQuotes
            } else {
                VStack(spacing: 8) {
                    ForEach(persistence.quotes.sorted { $0.createdAt > $1.createdAt }.prefix(4)) { quote in
                        dashboardQuoteRow(quote)
                    }
                }
            }
        }
        .padding(16)
        .background(glassBG)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(amber.opacity(0.15), lineWidth: 1))
    }

    private func dashboardQuoteRow(_ quote: Quote) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(quote.status.color)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(quote.customerName.isEmpty ? "İsimsiz" : quote.customerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(quote.quoteNumber)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(quote.grandTotal.shortFormatted)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                Text(quote.status.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(quote.status.color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }

    private var emptyQuotes: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(amber.opacity(0.3))
            Text("Henüz teklif yok")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: Helpers

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
    }

    private var glassBG: some ShapeStyle {
        .ultraThinMaterial
    }
}

// MARK: - Double Extension

extension Double {
    var shortFormatted: String {
        if self >= 1_000_000 { return String(format: "₺%.1fM", self / 1_000_000) }
        if self >= 1_000     { return String(format: "₺%.0fK", self / 1_000) }
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₺"
        f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "₺\(Int(self))"
    }

    var currencyFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₺"
        f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "₺\(Int(self))"
    }
}

// MARK: - QuoteStatus Extension

extension QuoteStatus {
    var color: Color {
        switch self {
        case .draft:    return .gray
        case .sent:     return .orange
        case .approved: return .green
        case .rejected: return .red
        case .invoiced: return .purple
        }
    }
    var displayName: String { rawValue }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environmentObject(PersistenceService.shared)
    .preferredColorScheme(.dark)
}
