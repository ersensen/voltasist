// CustomerListView.swift
// VoltAsist
//
// Müşteri listesi, arama, yeni müşteri ekleme ve müşteri detayına geçiş ekranı.

import SwiftUI

// MARK: - CustomerListView

/// Tüm müşterileri arama destekli liste şeklinde sunan ekran.
struct CustomerListView: View {

    @StateObject private var vm = CustomerViewModel()
    @EnvironmentObject private var persistence: PersistenceService
    @State private var showAddSheet   = false
    @State private var selectedCustomer: Customer? = nil

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.07, green: 0.07, blue: 0.09)

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // İstatistik özeti
                statsBar

                // Liste
                let customers = vm.filteredCustomers(from: persistence)

                if customers.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(customers) { customer in
                            Button(action: { selectedCustomer = customer }) {
                                CustomerListRow(
                                    customer: customer,
                                    revenue: vm.formattedRevenueForCustomer(id: customer.id, from: persistence),
                                    activeDeals: vm.activeDealCount(for: customer.id, from: persistence)
                                )
                            }
                            .listRowBackground(Color.white.opacity(0.03))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vm.deleteCustomer(id: customer.id, from: persistence)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }

                                Button {
                                    if let phone = URL(string: "tel://\(customer.phone.filter { $0.isNumber })") {
                                        UIApplication.shared.open(phone)
                                    }
                                } label: {
                                    Label("Ara", systemImage: "phone.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Müşteriler")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.searchText, prompt: "İsim, telefon veya firma ara...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(amber)
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CustomerFormSheet { newCustomer in
                vm.addCustomer(newCustomer, to: persistence)
            }
        }
        .sheet(item: $selectedCustomer) { customer in
            NavigationStack {
                CustomerDetailView(customer: customer)
                    .environmentObject(persistence)
            }
        }
    }

    // MARK: - İstatistik Barı

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(title: "Toplam Müşteri", value: "\(persistence.customers.count)", icon: "person.2.fill", color: amber)
            Divider().frame(height: 40)
            statCell(title: "Aktif Teklifler", value: "\(persistence.pendingQuoteCount)", icon: "doc.text.fill", color: .orange)
            Divider().frame(height: 40)
            statCell(title: "Toplam Ciro", value: formatTL(persistence.totalRevenueTL), icon: "turkishlirasign.circle.fill", color: .green)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }

    private func statCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Boş Durum

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(amber.opacity(0.3))
            Text(vm.searchText.isEmpty ? "Henüz müşteri yok" : "Eşleşen müşteri bulunamadı")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text(vm.searchText.isEmpty ? "Sağ üstteki + butonu ile müşteri ekleyin." : "Farklı bir arama terimi deneyin.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            if vm.searchText.isEmpty {
                Button(action: { showAddSheet = true }) {
                    Label("Müşteri Ekle", systemImage: "person.badge.plus")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(amber)
                        .cornerRadius(12)
                }
            }
            Spacer()
        }
        .padding(32)
    }

    private func formatTL(_ v: Double) -> String {
        guard v > 0 else { return "₺0" }
        if v >= 1_000_000 { return String(format: "₺%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "₺%.0fK", v / 1_000) }
        return String(format: "₺%.0f", v)
    }
}

// MARK: - Müşteri Liste Satırı

struct CustomerListRow: View {
    let customer: Customer
    let revenue: String
    let activeDeals: Int

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(amber.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(customer.initials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(customer.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(customer.phone)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                if !customer.address.isEmpty {
                    Text(customer.address)
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(revenue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                if activeDeals > 0 {
                    Text("\(activeDeals) aktif")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Customer Uzantıları

extension Customer {
    var initials: String {
        let parts = fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - Müşteri Ekleme Formu

struct CustomerFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Customer) -> Void

    @State private var fullName    = ""
    @State private var phone       = ""
    @State private var email       = ""
    @State private var address     = ""
    @State private var companyName = ""
    @State private var notes       = ""

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var isValid: Bool { !fullName.isEmpty && !phone.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kişisel Bilgiler") {
                    TextField("Ad Soyad *", text: $fullName)
                    TextField("Telefon *", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                Section("Firma & Adres") {
                    TextField("Firma Adı", text: $companyName)
                    TextField("Adres", text: $address)
                }
                Section("Notlar") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Yeni Müşteri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        let customer = Customer(
                            id: UUID(),
                            fullName: fullName,
                            phone: phone,
                            email: email,
                            address: address,
                            companyName: companyName.isEmpty ? nil : companyName,
                            notes: notes.isEmpty ? nil : notes,
                            createdAt: Date()
                        )
                        onSave(customer)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                    .foregroundColor(isValid ? amber : .gray)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CustomerListView()
            .environmentObject(PersistenceService.shared)
    }
}
