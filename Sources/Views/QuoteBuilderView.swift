// QuoteBuilderView.swift
// VoltAsist
//
// Kalem kalem detaylı fiyat teklifi oluşturma ekranı.
// Malzeme, işçilik, ekipman kategorileri, KDV hesabı ve PDF/WhatsApp paylaşımı.

import SwiftUI

// MARK: - QuoteBuilderView

/// Teklif oluşturma ve düzenleme ana ekranı.
/// Müşteri bilgileri, kalem listesi, ara toplamlar ve paylaşım aksiyonları içerir.
struct QuoteBuilderView: View {

    @StateObject private var vm: QuoteViewModel
    @EnvironmentObject private var persistence: PersistenceService
    @State private var showAddItem    = false
    @State private var editingItem: QuoteItem? = nil
    @State private var showPreview    = false
    @State private var showSaveAlert  = false
    @State private var showCustomerPicker = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG  = Color(red: 0.07, green: 0.07, blue: 0.09)

    init() {
        let settings = PersistenceService.shared.settings
        _vm = StateObject(wrappedValue: QuoteViewModel(settings: settings))
    }

    init(existingQuote: Quote) {
        let settings = PersistenceService.shared.settings
        _vm = StateObject(wrappedValue: QuoteViewModel(existingQuote: existingQuote, settings: settings))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            darkBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    customerSection
                    quoteMetaSection
                    itemsSection
                    notesSection
                    Spacer(minLength: 130) // alt butonlar için boşluk
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Yapışkan alt buton barı
            bottomActionBar
        }
        .navigationTitle("Teklif Oluştur")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddItem = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(amber)
                        .font(.system(size: 22))
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            QuoteItemFormSheet(onSave: { vm.addItem($0) })
        }
        .sheet(item: $editingItem) { item in
            QuoteItemFormSheet(item: item, onSave: { vm.updateItem($0) })
        }
        .sheet(isPresented: $showPreview) {
            QuotePreviewView(vm: vm)
                .environmentObject(persistence)
        }
        .alert("Kaydedildi", isPresented: $showSaveAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Teklif başarıyla kaydedildi.")
        }
    }

    // MARK: - Müşteri Bölümü

    private var customerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("👤 Müşteri Bilgileri")

            VStack(spacing: 10) {
                floatingField(icon: "person.fill",
                              placeholder: "Ad Soyad / Firma",
                              text: $vm.currentQuote.customerName)

                floatingField(icon: "phone.fill",
                              placeholder: "Telefon",
                              text: $vm.currentQuote.customerPhone)
                    .keyboardType(.phonePad)

                floatingField(icon: "map.fill",
                              placeholder: "Adres",
                              text: $vm.currentQuote.customerAddress)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Teklif Meta

    private var quoteMetaSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Teklif No")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Text(vm.currentQuote.quoteNumber)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Geçerlilik")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                DatePicker("", selection: $vm.currentQuote.validUntil, displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Durum")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                QuoteStatusBadge(status: vm.currentQuote.status)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Kalemler Bölümü

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("📋 Teklif Kalemleri")
                Spacer()
                Text("\(vm.currentQuote.items.count) kalem")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }

            if vm.currentQuote.items.isEmpty {
                emptyItemsPlaceholder
            } else {
                // Kategorilere göre gruplandırılmış kalemler
                ForEach(QuoteItemCategory.allCases, id: \.self) { category in
                    let categoryItems = vm.currentQuote.items.filter { $0.category == category }
                    if !categoryItems.isEmpty {
                        categoryGroup(category: category, items: categoryItems)
                    }
                }
            }

            // Kalem ekleme butonu
            Button(action: { showAddItem = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Kalem Ekle")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(amber.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(amber.opacity(0.25), lineWidth: 1.5).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5])))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.15), lineWidth: 1))
    }

    private var emptyItemsPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(amber.opacity(0.4))
            Text("Henüz kalem eklenmedi")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Text("Hesap makinelerinden otomatik ekleyebilir\nveya manuel kalem girebilirsiniz.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func categoryGroup(category: QuoteItemCategory, items: [QuoteItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(category.color)
                Text(category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(category.color)
            }

            ForEach(items) { item in
                QuoteItemRow(item: item) {
                    editingItem = item
                } onDelete: {
                    if let idx = vm.currentQuote.items.firstIndex(where: { $0.id == item.id }) {
                        vm.removeItem(at: IndexSet(integer: idx))
                    }
                }
            }
        }
    }

    // MARK: - Notlar

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("📝 Notlar")
            TextEditor(text: Binding(
                get: { vm.currentQuote.notes ?? "" },
                set: { vm.currentQuote.notes = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 80)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Alt Buton Barı

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            // Toplam özeti
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KDV Dahil Toplam")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(vm.grandTotalFormatted)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(amber)
                }
                Spacer()
                // Mini özet
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ara Toplam: \(vm.subtotalFormatted)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("KDV: \(vm.vatTotalFormatted)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            HStack(spacing: 10) {
                // Kaydet
                Button(action: {
                    vm.saveQuote(to: persistence)
                    showSaveAlert = true
                }) {
                    Label("Kaydet", systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                // Önizle & Paylaş
                Button(action: { showPreview = true }) {
                    Label("Önizle & Paylaş", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LinearGradient(colors: [amber, .orange], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                        .shadow(color: amber.opacity(0.3), radius: 6, y: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Yardımcılar

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
    }

    private func floatingField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(amber)
                .frame(width: 18)
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            text.wrappedValue.isEmpty ? Color.white.opacity(0.07) : amber.opacity(0.3),
            lineWidth: 1
        ))
    }
}

// MARK: - Kalem Satırı

struct QuoteItemRow: View {
    let item: QuoteItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(formatDouble(item.quantity)) \(item.unit)  ×  \(formatTL(item.unitPrice))")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTL(item.totalPrice))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                Text("KDV %\(Int(item.vatRate))")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencySymbol = "₺"; f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }
    private func formatDouble(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.2f", v)
    }
}

// MARK: - Durum Badge

struct QuoteStatusBadge: View {
    let status: QuoteStatus
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .cornerRadius(8)
    }
}

// MARK: - Kategori Uzantıları

extension QuoteItemCategory {
    var icon: String {
        switch self {
        case .material:  return "shippingbox.fill"
        case .labor:     return "person.badge.plus"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .service:   return "gearshape.fill"
        case .solar:     return "sun.max.fill"
        case .other:     return "ellipsis.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .material:  return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .labor:     return .cyan
        case .equipment: return .orange
        case .service:   return .purple
        case .solar:     return .yellow
        case .other:     return .gray
        }
    }
}

extension QuoteStatus {
    var color: Color {
        switch self {
        case .draft:     return .gray
        case .sent:      return .blue
        case .approved:  return .green
        case .rejected:  return .red
        case .invoiced:  return .purple
        }
    }
}

// MARK: - Kalem Formu Sheet

struct QuoteItemFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    var item: QuoteItem? = nil
    let onSave: (QuoteItem) -> Void

    @State private var title       = ""
    @State private var description = ""
    @State private var category    = QuoteItemCategory.material
    @State private var quantity    = 1.0
    @State private var unit        = "adet"
    @State private var unitPrice   = 0.0
    @State private var vatRate     = 20.0
    @State private var discount    = 0.0

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let units = ["adet", "m", "m²", "m³", "kg", "saat", "kWp", "kVAr", "gün"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Kalem Bilgileri") {
                    TextField("Kalem Açıklaması *", text: $title)
                    TextField("Detay (opsiyonel)", text: $description)
                    Picker("Kategori", selection: $category) {
                        ForEach(QuoteItemCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                Section("Miktar & Fiyat") {
                    HStack {
                        Text("Miktar")
                        Spacer()
                        TextField("1", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { u in Text(u).tag(u) }
                    }
                    HStack {
                        Text("Birim Fiyat (₺)")
                        Spacer()
                        TextField("0", value: $unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("KDV Oranı", selection: $vatRate) {
                        Text("%0").tag(0.0)
                        Text("%10").tag(10.0)
                        Text("%20").tag(20.0)
                    }
                    HStack {
                        Text("İskonto (%)")
                        Spacer()
                        TextField("0", value: $discount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Özet") {
                    let net   = quantity * unitPrice * (1 - discount / 100)
                    let vat   = net * vatRate / 100
                    let total = net + vat
                    HStack {
                        Text("Net Tutar")
                        Spacer()
                        Text(formatTL(net))
                    }
                    HStack {
                        Text("KDV")
                        Spacer()
                        Text(formatTL(vat))
                    }
                    HStack {
                        Text("Toplam")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatTL(total))
                            .fontWeight(.bold)
                            .foregroundColor(amber)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))
            .navigationTitle(item == nil ? "Kalem Ekle" : "Kalemi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        let newItem = QuoteItem(
                            id: item?.id ?? UUID(),
                            title: title,
                            description: description.isEmpty ? nil : description,
                            category: category,
                            quantity: quantity,
                            unit: unit,
                            unitPrice: unitPrice,
                            vatRate: vatRate,
                            discount: discount / 100
                        )
                        onSave(newItem)
                        dismiss()
                    }
                    .disabled(title.isEmpty || unitPrice <= 0)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let item {
                    title       = item.title
                    description = item.description ?? ""
                    category    = item.category
                    quantity    = item.quantity
                    unit        = item.unit
                    unitPrice   = item.unitPrice
                    vatRate     = item.vatRate
                    discount    = item.discount * 100
                }
            }
        }
    }

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencySymbol = "₺"; f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }
}

#Preview {
    NavigationStack {
        QuoteBuilderView()
            .environmentObject(PersistenceService.shared)
    }
}
