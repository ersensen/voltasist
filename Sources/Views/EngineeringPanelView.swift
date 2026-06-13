// EngineeringPanelView.swift
// VoltAsist
//
// Mühendislik & Teklif Paneli — KPI dashboard, teklif yönetimi.

import SwiftUI

// MARK: - EngineeringPanelView

struct EngineeringPanelView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var selectedFilter: QuoteStatus? = nil
    @State private var showNewQuote   = false
    @State private var showCustomers  = false
    @State private var searchText     = ""
    @State private var sortMode: SortMode = .dateDesc

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bg     = Color(red: 0.06, green: 0.06, blue: 0.09)

    enum SortMode: String, CaseIterable {
        case dateDesc   = "En Yeni"
        case dateAsc    = "En Eski"
        case amountDesc = "Tutar ↓"
        case amountAsc  = "Tutar ↑"
    }

    // MARK: Computed

    private var filtered: [Quote] {
        var list = persistence.quotes
        if let f = selectedFilter { list = list.filter { $0.status == f } }
        if !searchText.isEmpty {
            list = list.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText)
                || $0.quoteNumber.localizedCaseInsensitiveContains(searchText)
                || ($0.projectTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
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
        return Double(persistence.quotes.filter { $0.status == .approved }.count) / Double(persistence.quotes.count) * 100
    }

    private var pendingRevenue: Double {
        persistence.quotes.filter { $0.status == .sent }.reduce(0) { $0 + $1.grandTotal }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            // Arama çubuğu
            searchBar

            List {
                // KPI bölümü
                Section {
                    kpiSection
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                // Durum filtresi
                Section {
                    statusFilterBar
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                // Teklif listesi
                if filtered.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(filtered) { quote in
                            NavigationLink {
                                QuotePreviewView(
                                    vm: QuoteViewModel(existingQuote: quote, settings: persistence.settings)
                                )
                                .environmentObject(persistence)
                            } label: {
                                EngineeringQuoteRow(quote: quote)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    persistence.deleteQuote(id: quote.id)
                                } label: { Label("Sil", systemImage: "trash") }

                                Button {
                                    persistence.updateQuoteStatus(id: quote.id, status: .approved)
                                } label: { Label("Onayla", systemImage: "checkmark.seal") }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    persistence.updateQuoteStatus(id: quote.id, status: .sent)
                                } label: { Label("Gönderildi", systemImage: "paperplane") }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        HStack {
                            Text("\(filtered.count) teklif")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Menu {
                                Picker("Sıralama", selection: $sortMode) {
                                    ForEach(SortMode.allCases, id: \.self) { m in
                                        Text(m.rawValue).tag(m)
                                    }
                                }
                            } label: {
                                Label(sortMode.rawValue, systemImage: "arrow.up.arrow.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(amber)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(bg)
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Mühendislik")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button { showCustomers = true } label: {
                        Image(systemName: "person.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(amber)
                    }
                    Button { showNewQuote = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(amber)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewQuote) {
            NavigationStack {
                QuoteBuilderView().environmentObject(persistence)
            }
        }
        .sheet(isPresented: $showCustomers) {
            NavigationStack {
                CustomerListView().environmentObject(persistence)
            }
        }
    }

    // MARK: - Arama

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            TextField("Müşteri, teklif no veya proje...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.07))
        .cornerRadius(13)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(bg)
    }

    // MARK: - KPI Bölümü

    private var kpiSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                kpiCard("Ciro", persistence.totalRevenueTL.shortFormatted, "turkishlirasign.circle.fill", amber)
                kpiCard("Onay Oranı", String(format: "%%%.0f", approvalRate), "checkmark.seal.fill", .green)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                kpiCard("Bekleyen", pendingRevenue.shortFormatted, "paperplane.fill", .blue)
                kpiCard("Taslak", "\(persistence.quotes.filter { $0.status == .draft }.count)", "doc.text.fill", .gray)
                kpiCard("Müşteri", "\(persistence.customers.count)", "person.2.fill", .cyan)
            }
            .padding(.horizontal, 16)
        }
    }

    private func kpiCard(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(color.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Durum Filtresi

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Tümü (\(persistence.quotes.count))", status: nil, color: amber)
                ForEach(QuoteStatus.allCases) { status in
                    let count = persistence.quotes.filter { $0.status == status }.count
                    filterChip("\(status.rawValue) (\(count))", status: status, color: status.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func filterChip(_ title: String, status: QuoteStatus?, color: Color) -> some View {
        let selected = selectedFilter == status
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = selected ? nil : status
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .medium, design: .rounded))
                .foregroundColor(selected ? .black : color.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? color : color.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(selected ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Boş Durum

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(amber.opacity(0.25))
                .padding(.top, 20)
            Text(searchText.isEmpty && selectedFilter == nil ? "Henüz teklif yok" : "Sonuç bulunamadı")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text(searchText.isEmpty && selectedFilter == nil
                 ? "Sağ üstteki + butonuna basarak\nilk teklifinizi oluşturun."
                 : "Filtre veya aramayı değiştirin.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            if searchText.isEmpty && selectedFilter == nil {
                Button { showNewQuote = true } label: {
                    Label("Teklif Oluştur", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(amber)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Engineering Quote Row

struct EngineeringQuoteRow: View {
    let quote: Quote
    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 10) {
            // Sol renkli şerit
            RoundedRectangle(cornerRadius: 2)
                .fill(quote.status.color)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(quote.customerName.isEmpty ? "İsimsiz Müşteri" : quote.customerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(quote.grandTotal.currencyFormatted)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(amber)
                }
                HStack(spacing: 6) {
                    Text(quote.quoteNumber)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    if let p = quote.projectTitle, !p.isEmpty {
                        Text("· \(p)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(quote.status.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(quote.status.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(quote.status.color.opacity(0.15))
                        .cornerRadius(6)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.45))
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
        }
        .padding(.vertical, 6)
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
