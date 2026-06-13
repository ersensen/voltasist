// EngineeringPanelView.swift
// VoltAsist
//
// Mühendislik & Teklif Paneli — tüm tekliflerin, müşterilerin ve KPI'ların
// merkezi yönetim ekranı. Kıdemli elektrik mühendisi için tasarlandı.

import SwiftUI

// MARK: - EngineeringPanelView

/// Merkezi mühendislik paneli:
/// - Finansal KPI'lar (ciro, onay oranı, bekleyen)
/// - Tüm tekliflerin durum bazlı listelenmesi ve yönetimi
/// - Müşteri erişimi
/// - Hızlı teklif oluşturma
struct EngineeringPanelView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var selectedFilter: QuoteStatus? = nil
    @State private var showNewQuote    = false
    @State private var showCustomers   = false
    @State private var searchText      = ""
    @State private var sortMode: SortMode = .dateDesc

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.07, green: 0.07, blue: 0.09)

    // MARK: Enums

    enum SortMode: String, CaseIterable {
        case dateDesc  = "En Yeni"
        case dateAsc   = "En Eski"
        case amountDesc = "Tutar ↓"
        case amountAsc  = "Tutar ↑"
    }

    // MARK: Computed

    private var filteredQuotes: [Quote] {
        var list = persistence.quotes
        if let filter = selectedFilter {
            list = list.filter { $0.status == filter }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                $0.quoteNumber.localizedCaseInsensitiveContains(searchText) ||
                ($0.projectTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        switch sortMode {
        case .dateDesc:   list.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:    list.sort { $0.createdAt < $1.createdAt }
        case .amountDesc: list.sort { $0.grandTotal > $1.grandTotal }
        case .amountAsc:  list.sort { $0.grandTotal < $1.grandTotal }
        }
        return list
    }

    private var approvalRate: Double {
        guard !persistence.quotes.isEmpty else { return 0 }
        let approved = Double(persistence.quotes.filter { $0.status == .approved }.count)
        return (approved / Double(persistence.quotes.count)) * 100
    }

    private var pendingRevenue: Double {
        persistence.quotes
            .filter { $0.status == .sent }
            .reduce(0.0) { $0 + $1.grandTotal }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            VStack(spacing: 0) {
                searchAndActions
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(darkBG)

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // KPI Kartları
                        kpiSection
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        // Durum filtresi
                        statusFilterBar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                        // Teklif listesi
                        if filteredQuotes.isEmpty {
                            emptyState
                        } else {
                            Section {
                                ForEach(filteredQuotes) { quote in
                                    NavigationLink(destination:
                                        QuotePreviewView(vm: QuoteViewModel(existingQuote: quote,
                                                                            settings: persistence.settings))
                                        .environmentObject(persistence)
                                    ) {
                                        EngineeringQuoteRow(quote: quote)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 3)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            persistence.deleteQuote(id: quote.id)
                                        } label: {
                                            Label("Sil", systemImage: "trash")
                                        }
                                        Button {
                                            persistence.updateQuoteStatus(id: quote.id, status: .approved)
                                        } label: {
                                            Label("Onayla", systemImage: "checkmark.seal")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            persistence.updateQuoteStatus(id: quote.id, status: .sent)
                                        } label: {
                                            Label("Gönderildi", systemImage: "paperplane")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("\(filteredQuotes.count) teklif")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Picker("Sıralama", selection: $sortMode) {
                                        ForEach(SortMode.allCases, id: \.self) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(amber)
                                    .font(.system(size: 12))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(darkBG)
                            }
                        }
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .navigationTitle("Mühendislik Paneli")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showCustomers = true }) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(amber)
                            .font(.system(size: 16))
                    }
                    Button(action: { showNewQuote = true }) {
                        Image(systemName: "doc.badge.plus")
                            .foregroundColor(amber)
                            .font(.system(size: 18))
                    }
                }
            }
        }
        .sheet(isPresented: $showNewQuote) {
            NavigationStack {
                QuoteBuilderView()
                    .environmentObject(persistence)
            }
        }
        .sheet(isPresented: $showCustomers) {
            NavigationStack {
                CustomerListView()
                    .environmentObject(persistence)
            }
        }
    }

    // MARK: - Search & Actions

    private var searchAndActions: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                TextField("Müşteri, teklif no, proje ara...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)
        }
    }

    // MARK: - KPI Section

    private var kpiSection: some View {
        VStack(spacing: 10) {
            // Birinci satır: Ciro ve Onay Oranı
            HStack(spacing: 10) {
                kpiCard(
                    icon: "turkishlirasign.circle.fill",
                    title: "Toplam Ciro",
                    value: formatTLShort(persistence.totalRevenueTL),
                    subtitle: "Onaylanmış",
                    color: amber,
                    large: true
                )
                kpiCard(
                    icon: "checkmark.seal.fill",
                    title: "Onay Oranı",
                    value: String(format: "%%%.0f", approvalRate),
                    subtitle: "\(persistence.approvedQuoteCount) onaylandı",
                    color: .green,
                    large: true
                )
            }
            // İkinci satır: Bekleyen, Taslak, Müşteri
            HStack(spacing: 10) {
                kpiCard(
                    icon: "paperplane.fill",
                    title: "Bekleyen",
                    value: formatTLShort(pendingRevenue),
                    subtitle: "\(persistence.quotes.filter { $0.status == .sent }.count) teklif",
                    color: .blue
                )
                kpiCard(
                    icon: "doc.text.fill",
                    title: "Taslak",
                    value: "\(persistence.quotes.filter { $0.status == .draft }.count)",
                    subtitle: "Gönderilmedi",
                    color: .gray
                )
                kpiCard(
                    icon: "person.2.fill",
                    title: "Müşteri",
                    value: "\(persistence.customers.count)",
                    subtitle: "Kayıtlı",
                    color: .cyan
                )
            }
        }
    }

    private func kpiCard(icon: String, title: String, value: String, subtitle: String, color: Color, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: large ? 14 : 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: large ? 12 : 11, weight: .semibold))
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.system(size: large ? 24 : 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Status Filter Bar

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip(title: "Tümü (\(persistence.quotes.count))", status: nil)
                ForEach(QuoteStatus.allCases) { status in
                    let count = persistence.quotes.filter { $0.status == status }.count
                    statusChip(title: "\(status.rawValue) (\(count))", status: status)
                }
            }
        }
    }

    private func statusChip(title: String, status: QuoteStatus?) -> some View {
        let isSelected = selectedFilter == status
        let color: Color = status?.color ?? amber
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = isSelected ? nil : status
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .black : color.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(amber.opacity(0.3))
            Text(searchText.isEmpty && selectedFilter == nil ? "Henüz teklif yok" : "Sonuç bulunamadı")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text(searchText.isEmpty && selectedFilter == nil ?
                 "Sağ üstteki butona basarak\nilk teklifinizi oluşturun." :
                 "Filtreyi değiştirmeyi deneyin.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            if searchText.isEmpty && selectedFilter == nil {
                Button(action: { showNewQuote = true }) {
                    Label("Teklif Oluştur", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(amber)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func formatTLShort(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "₺%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "₺%.0fK", v / 1_000) }
        return String(format: "₺%.0f", v)
    }
}

// MARK: - Engineering Quote Row

struct EngineeringQuoteRow: View {
    let quote: Quote
    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 12) {
            // Durum indikatörü
            RoundedRectangle(cornerRadius: 3)
                .fill(quote.status.color)
                .frame(width: 4, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(quote.customerName.isEmpty ? "İsimsiz Müşteri" : quote.customerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(formatTL(quote.grandTotal))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(amber)
                }
                HStack(spacing: 8) {
                    Text(quote.quoteNumber)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    if let project = quote.projectTitle, !project.isEmpty {
                        Text("· \(project)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                    QuoteStatusBadge(status: quote.status)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(quote.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.5))
                    if quote.isExpired && quote.status == .sent {
                        Text("· SÜRESİ DOLDU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Text("\(quote.items.count) kalem")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(12)
        .background(Color.white.opacity(0.035))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₺"
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EngineeringPanelView()
            .environmentObject(PersistenceService.shared)
    }
    .preferredColorScheme(.dark)
}
