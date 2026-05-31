// CustomerDetailView.swift
// VoltAsist
//
// Müşteri profili, teklif geçmişi ve iletişim aksiyonları ekranı.

import SwiftUI

// MARK: - CustomerDetailView

/// Bir müşterinin tüm bilgilerini, teklif geçmişini ve iletişim olanaklarını gösteren ekran.
struct CustomerDetailView: View {

    let customer: Customer
    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss
    @State private var showNewQuote = false
    @State private var showEditSheet = false

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.07, green: 0.07, blue: 0.09)

    private var quotes: [Quote] {
        persistence.quotes
            .filter { $0.customer?.id == customer.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalRevenue: Double {
        persistence.quotes
            .filter { $0.customer?.id == customer.id && $0.status == .approved }
            .reduce(0) { $0 + $1.grandTotal }
    }

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    profileHeader
                    contactButtons
                    statsGrid
                    quoteHistorySection
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(customer.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showNewQuote = true }) {
                    Label("Yeni Teklif", systemImage: "doc.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(amber)
                }
            }
        }
        .sheet(isPresented: $showNewQuote) {
            NavigationStack {
                QuoteBuilderView(existingQuote: Quote(
                    id: UUID(),
                    quoteNumber: QuoteEngine.generateQuoteNumber(sequence: (persistence.quotes.count + 1)),
                    customer: customer,
                    customerName: customer.fullName,
                    customerPhone: customer.phone,
                    customerAddress: customer.address,
                    items: [],
                    notes: nil,
                    validUntil: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                    createdAt: Date(),
                    status: .draft,
                    discountPercent: 0
                ))
                .environmentObject(persistence)
            }
        }
    }

    // MARK: - Profil Başlığı

    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Büyük avatar
            ZStack {
                Circle()
                    .fill(amber.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(amber.opacity(0.3), lineWidth: 1.5))
                Text(customer.initials)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(amber)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(customer.fullName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let company = customer.companyName, !company.isEmpty {
                    Label(company, systemImage: "building.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Label(customer.phone, systemImage: "phone.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                if !customer.email.isEmpty {
                    Label(customer.email, systemImage: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [amber.opacity(0.1), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1))
    }

    // MARK: - İletişim Butonları

    private var contactButtons: some View {
        HStack(spacing: 10) {
            contactBtn(icon: "phone.fill", label: "Ara", color: .green) {
                if let url = URL(string: "tel://\(customer.phone.filter { $0.isNumber })") {
                    UIApplication.shared.open(url)
                }
            }
            contactBtn(icon: "bubble.left.fill", label: "WhatsApp", color: Color(red: 0.07, green: 0.61, blue: 0.21)) {
                let message = "Merhaba \(customer.fullName), VoltAsist üzerinden sizinle iletişime geçiyorum."
                ShareService.openWhatsApp(phone: customer.phone, message: message)
            }
            contactBtn(icon: "envelope.fill", label: "E-posta", color: .blue) {
                if !customer.email.isEmpty,
                   let url = URL(string: "mailto:\(customer.email)") {
                    UIApplication.shared.open(url)
                }
            }
            .opacity(customer.email.isEmpty ? 0.4 : 1.0)
            .disabled(customer.email.isEmpty)
        }
    }

    private func contactBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - İstatistik Grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(value: "\(quotes.count)", label: "Toplam Teklif", accent: amber)
            statCard(value: "\(quotes.filter { $0.status == .approved }.count)", label: "Onaylanan", accent: .green)
            statCard(value: formatTLShort(totalRevenue), label: "Toplam Ciro", accent: .cyan)
        }
    }

    private func statCard(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Teklif Geçmişi

    private var quoteHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Teklif Geçmişi", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showNewQuote = true }) {
                    Label("Yeni", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(amber)
                }
            }

            if quotes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(amber.opacity(0.3))
                        Text("Bu müşteriye ait teklif yok")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(quotes) { quote in
                    NavigationLink(destination: QuotePreviewView(vm: QuoteViewModel(existingQuote: quote, settings: persistence.settings))
                        .environmentObject(persistence)) {
                        quoteRow(quote: quote)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func quoteRow(_ quote: Quote) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.quoteNumber)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(quote.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTL(quote.grandTotal))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                QuoteStatusBadge(status: quote.status)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    // MARK: - Yardımcılar

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencySymbol = "₺"; f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }

    private func formatTLShort(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "₺%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "₺%.0fK", v / 1_000) }
        return String(format: "₺%.0f", v)
    }
}

#Preview {
    NavigationStack {
        CustomerDetailView(customer: Customer(
            id: UUID(), fullName: "Ahmet Yılmaz", phone: "05321234567",
            email: "ahmet@example.com", address: "İstanbul, Kadıköy",
            companyName: "Yılmaz Elektrik Ltd.", notes: nil, createdAt: Date()
        ))
        .environmentObject(PersistenceService.shared)
    }
}
