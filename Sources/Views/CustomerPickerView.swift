// CustomerPickerView.swift
// VoltAsist
//
// Hesap ekranlarından müşteri seçimi veya hızlı yeni müşteri oluşturma.

import SwiftUI

// MARK: - CustomerPickerView

struct CustomerPickerView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Customer) -> Void

    @State private var searchText  = ""
    @State private var quickName   = ""
    @State private var quickPhone  = ""
    @State private var showQuickAdd = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    private var filtered: [Customer] {
        let all = persistence.customers.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    if showQuickAdd { quickAddForm }
                    customerList
                }
            }
            .navigationTitle("Müşteri Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }.foregroundStyle(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showQuickAdd.toggle()
                        }
                    } label: {
                        Image(systemName: showQuickAdd ? "xmark.circle.fill" : "person.badge.plus")
                            .foregroundStyle(amber)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Arama

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.gray)
            TextField("Müşteri ara...", text: $searchText)
                .font(.system(size: 14)).foregroundStyle(.white).autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray).font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.white.opacity(0.07)).cornerRadius(13)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(bgColor)
    }

    // MARK: Hızlı Müşteri Ekle

    private var quickAddForm: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "person.badge.plus").foregroundStyle(amber)
                Text("Yeni Müşteri")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(amber)
                Spacer()
            }
            HStack(spacing: 10) {
                TextField("Ad / Firma", text: $quickName)
                    .font(.system(size: 13)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.white.opacity(0.07)).cornerRadius(10)
                TextField("Telefon", text: $quickPhone)
                    .keyboardType(.phonePad)
                    .font(.system(size: 13)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.white.opacity(0.07)).cornerRadius(10)
            }
            Button {
                guard !quickName.isEmpty else { return }
                let customer = Customer(name: quickName, phone: quickPhone)
                persistence.saveCustomer(customer)
                onSelect(customer)
                dismiss()
            } label: {
                Text("Ekle ve Seç")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(quickName.isEmpty ? Color.gray.opacity(0.3) : amber)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain).disabled(quickName.isEmpty)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(amber.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.25), lineWidth: 1))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Müşteri Listesi

    private var customerList: some View {
        Group {
            if filtered.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "person.slash")
                        .font(.system(size: 44)).foregroundStyle(amber.opacity(0.3))
                    Text(searchText.isEmpty ? "Henüz müşteri yok" : "Sonuç bulunamadı")
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    Text("Sağ üstteki + butonu ile hızlıca ekleyin.")
                        .font(.system(size: 13)).foregroundStyle(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filtered) { customer in
                        Button {
                            onSelect(customer)
                            dismiss()
                        } label: {
                            customerRow(customer)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(bgColor)
            }
        }
    }

    private func customerRow(_ customer: Customer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(amber.opacity(0.12)).frame(width: 40, height: 40)
                Text(String(customer.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(amber)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.name)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if !customer.phone.isEmpty {
                    Text(customer.phone)
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.gray)
                }
            }
            Spacer()

            // Var olan taslak teklif varsa göster
            let draftCount = persistence.quotes.filter {
                $0.customerId == customer.id && $0.status == .draft
            }.count
            if draftCount > 0 {
                Text("\(draftCount) taslak")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(amber)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(amber.opacity(0.1)).cornerRadius(8)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.gray.opacity(0.4))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ActiveQuotePickerView
// Malzeme ekranı için aktif teklif seçici

struct ActiveQuotePickerView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    private var drafts: [Quote] {
        persistence.quotes.filter { $0.status == .draft }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                if drafts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 44)).foregroundStyle(amber.opacity(0.3))
                        Text("Taslak teklif yok")
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        Text("Önce bir hesap ekranından teklif oluşturun.")
                            .font(.system(size: 13)).foregroundStyle(.gray)
                    }
                } else {
                    List {
                        if persistence.activeQuoteId != nil {
                            Section {
                                Button {
                                    persistence.activeQuoteId = nil
                                    dismiss()
                                } label: {
                                    Label("Aktif Teklifi Kaldır", systemImage: "xmark.circle")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.red)
                                }
                                .listRowBackground(Color.red.opacity(0.06))
                                .listRowSeparator(.hidden)
                            }
                        }
                        Section(header: Text("Taslak Teklifler").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.gray)) {
                            ForEach(drafts) { quote in
                                Button {
                                    persistence.activeQuoteId = quote.id
                                    dismiss()
                                } label: {
                                    draftRow(quote)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    persistence.activeQuoteId == quote.id
                                    ? Color.green.opacity(0.08)
                                    : Color.white.opacity(0.04)
                                )
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(bgColor)
                }
            }
            .navigationTitle("Aktif Teklif Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }.foregroundStyle(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func draftRow(_ quote: Quote) -> some View {
        HStack(spacing: 12) {
            let isActive = persistence.activeQuoteId == quote.id
            ZStack {
                Circle().fill(isActive ? Color.green.opacity(0.15) : amber.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: isActive ? "checkmark.circle.fill" : "doc.text.fill")
                    .font(.system(size: 18)).foregroundStyle(isActive ? .green : amber)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(quote.customerName.isEmpty ? "İsimsiz Müşteri" : quote.customerName)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("\(quote.quoteNumber) · \(quote.items.count) kalem")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
            }
            Spacer()
            Text(quote.grandTotal.currencyFormatted)
                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(amber)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    CustomerPickerView { _ in }
        .environmentObject(PersistenceService.shared)
}
