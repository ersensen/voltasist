// MaterialListView.swift
// VoltAsist
//
// Elektrik malzeme kataloğu — stok takibi, fiyat yönetimi, teklife hızlı ekleme.

import SwiftUI

// MARK: - MaterialListView

struct MaterialListView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var searchText           = ""
    @State private var selectedCategory: MaterialCategory? = nil
    @State private var showAddSheet         = false
    @State private var editingMaterial: Material? = nil
    @State private var showLowStockOnly     = false
    @State private var showQuoteBuilder     = false

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bg     = Color(red: 0.06, green: 0.06, blue: 0.09)

    // MARK: Computed

    private var filtered: [Material] {
        persistence.materials.filter { m in
            let s = searchText.isEmpty
                || m.name.localizedCaseInsensitiveContains(searchText)
                || (m.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (m.catalogCode?.localizedCaseInsensitiveContains(searchText) ?? false)
            let c = selectedCategory == nil || m.category == selectedCategory
            let l = !showLowStockOnly || (m.isLowStock && m.minStockLevel > 0)
            return s && c && l
        }.sorted { $0.name < $1.name }
    }

    private var grouped: [(MaterialCategory, [Material])] {
        let dict = Dictionary(grouping: filtered, by: { $0.category })
        return MaterialCategory.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            // Arama + filtre
            searchBar
            filterChips

            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    // İstatistik satırı
                    if searchText.isEmpty && selectedCategory == nil && !showLowStockOnly {
                        Section {
                            statsRow
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }

                    // Gruplandırılmış malzemeler
                    ForEach(grouped, id: \.0) { category, items in
                        Section {
                            ForEach(items) { material in
                                MaterialRow(material: material) {
                                    editingMaterial = material
                                } onDelete: {
                                    persistence.deleteMaterial(id: material.id)
                                } onAddToQuote: {
                                    showQuoteBuilder = true
                                }
                                .listRowBackground(Color.white.opacity(0.04))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        } header: {
                            categoryHeader(category)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(bg)
            }
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Malzeme")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(amber)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            MaterialFormSheet(onSave: { persistence.saveMaterial($0) })
        }
        .sheet(item: $editingMaterial) { mat in
            MaterialFormSheet(material: mat, onSave: { persistence.saveMaterial($0) })
        }
        .sheet(isPresented: $showQuoteBuilder) {
            NavigationStack {
                QuoteBuilderView().environmentObject(persistence)
            }
        }
    }

    // MARK: - Arama Çubuğu

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                TextField("Malzeme, marka veya kod...", text: $searchText)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)

            // Düşük stok filtresi
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showLowStockOnly.toggle()
                }
            } label: {
                Image(systemName: "exclamationmark.triangle\(showLowStockOnly ? ".fill" : "")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(showLowStockOnly ? .orange : .gray)
                    .frame(width: 44, height: 44)
                    .background(showLowStockOnly ? Color.orange.opacity(0.13) : Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(showLowStockOnly ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(bg)
    }

    // MARK: - Filtre Chip'leri

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Tümü", selected: selectedCategory == nil, color: amber) {
                    selectedCategory = nil
                }
                ForEach(MaterialCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    chip(
                        cat.rawValue.components(separatedBy: " ").first ?? cat.rawValue,
                        selected: isSelected,
                        color: cat.accentColor
                    ) {
                        withAnimation { selectedCategory = isSelected ? nil : cat }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(bg)
    }

    private func chip(_ title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .medium, design: .rounded))
                .foregroundColor(selected ? .black : color.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? color : color.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(selected ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - İstatistik Satırı

    private var statsRow: some View {
        HStack(spacing: 10) {
            miniStat("\(persistence.materials.count)", "Malzeme", "shippingbox.fill", amber)
            miniStat("\(persistence.lowStockMaterialCount)", "Düşük Stok", "exclamationmark.triangle.fill", .orange)
            miniStat(persistence.totalMaterialStockValue.shortFormatted, "Stok Değeri", "turkishlirasign.circle.fill", .cyan)
        }
    }

    private func miniStat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Kategori Başlığı

    private func categoryHeader(_ category: MaterialCategory) -> some View {
        HStack(spacing: 7) {
            Image(systemName: category.systemIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(category.accentColor)
            Text(category.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(category.accentColor)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .background(bg)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Boş Durum

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 52))
                .foregroundColor(amber.opacity(0.25))
            Text(searchText.isEmpty ? "Henüz malzeme yok" : "Sonuç bulunamadı")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text(searchText.isEmpty
                 ? "Sağ üstteki + butonuna basarak\nmalzeme kataloğunuzu oluşturun."
                 : "Farklı bir arama veya filtre deneyin.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button { showAddSheet = true } label: {
                    Label("Malzeme Ekle", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(amber)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(bg)
    }
}

// MARK: - Material Row

struct MaterialRow: View {
    let material: Material
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddToQuote: () -> Void

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    var body: some View {
        HStack(spacing: 12) {
            // İkon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(material.category.accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: material.category.systemIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(material.category.accentColor)
            }

            // Bilgiler
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(material.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if material.isLowStock && material.minStockLevel > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                if let brand = material.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Text("Stok: \(fmtQty(material.stockQuantity)) \(material.unit)")
                    .font(.system(size: 11))
                    .foregroundColor(material.isLowStock && material.minStockLevel > 0 ? .orange : Color.gray.opacity(0.6))
            }

            Spacer(minLength: 4)

            // Fiyat
            VStack(alignment: .trailing, spacing: 3) {
                Text(fmtTL(material.salePrice))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("/ \(material.unit)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onAddToQuote) {
                Label("Teklife Ekle", systemImage: "doc.badge.plus")
            }
            .tint(Color(red: 0.0, green: 0.65, blue: 0.35))
        }
    }

    private func fmtTL(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₺"
        f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }

    private func fmtQty(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Material Form Sheet

struct MaterialFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    var material: Material? = nil
    let onSave: (Material) -> Void

    @State private var name          = ""
    @State private var brand         = ""
    @State private var category: MaterialCategory = .cable
    @State private var unit          = "adet"
    @State private var purchasePrice = ""
    @State private var salePrice     = ""
    @State private var stockQuantity = ""
    @State private var minStockLevel = ""
    @State private var catalogCode   = ""
    @State private var supplier      = ""
    @State private var notes         = ""

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.09)
    private let units   = ["adet", "m", "m²", "m³", "kg", "kutu", "rulo", "paket", "takım", "kWp", "kVAr", "saat"]

    private var canSave: Bool {
        !name.isEmpty && (Double(salePrice.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var salePriceDouble:    Double { Double(salePrice.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var purchasePriceDouble: Double { Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme Bilgileri") {
                    fRow(icon: "shippingbox.fill",   label: "Malzeme Adı *",   text: $name)
                    fRow(icon: "tag.fill",            label: "Marka / Üretici", text: $brand)
                    fRow(icon: "barcode",             label: "Katalog Kodu",    text: $catalogCode)
                    fRow(icon: "shippingbox",         label: "Tedarikçi",       text: $supplier)
                    Picker("Kategori", selection: $category) {
                        ForEach(MaterialCategory.allCases) { c in
                            Label(c.rawValue, systemImage: c.systemIcon).tag(c)
                        }
                    }
                }

                Section("Fiyat & Birim") {
                    numRow(icon: "turkishlirasign.circle",      label: "Alış Fiyatı (₺)",   text: $purchasePrice, color: amber)
                    numRow(icon: "turkishlirasign.circle.fill", label: "Satış Fiyatı (₺) *", text: $salePrice, color: amber)
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { u in Text(u).tag(u) }
                    }
                    if salePriceDouble > 0 && purchasePriceDouble > 0 {
                        let margin = ((salePriceDouble - purchasePriceDouble) / purchasePriceDouble) * 100
                        HStack {
                            Text("Kar Marjı")
                            Spacer()
                            Text(String(format: "%%%".dropLast() + "%.1f", margin))
                                .foregroundColor(margin >= 0 ? .green : .red)
                                .fontWeight(.bold)
                        }
                    }
                }

                Section("Stok") {
                    numRow(icon: "cube.box",                   label: "Mevcut Stok",     text: $stockQuantity, color: .cyan)
                    numRow(icon: "exclamationmark.triangle",   label: "Min. Stok Uyarı", text: $minStockLevel, color: .orange)
                }

                Section("Notlar") {
                    TextField("Ek açıklamalar...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(bgColor)
            .navigationTitle(material == nil ? "Malzeme Ekle" : "Malzemeyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .foregroundColor(canSave ? amber : .gray)
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func fRow(icon: String, label: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(amber)
                .frame(width: 20)
            TextField(label, text: text)
        }
    }

    private func numRow(icon: String, label: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).frame(width: 20)
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        let m = Material(
            id: material?.id ?? UUID(),
            name: name,
            brand: brand.isEmpty ? nil : brand,
            category: category,
            unit: unit,
            purchasePrice: purchasePriceDouble,
            salePrice: salePriceDouble,
            stockQuantity: Double(stockQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0,
            minStockLevel: Double(minStockLevel.replacingOccurrences(of: ",", with: ".")) ?? 0,
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            supplier: supplier.isEmpty ? nil : supplier,
            notes: notes.isEmpty ? nil : notes,
            createdAt: material?.createdAt ?? Date()
        )
        onSave(m)
        dismiss()
    }

    private func prefill() {
        guard let m = material else { return }
        name          = m.name
        brand         = m.brand ?? ""
        category      = m.category
        unit          = m.unit
        purchasePrice = m.purchasePrice > 0 ? String(format: "%.2f", m.purchasePrice) : ""
        salePrice     = m.salePrice > 0     ? String(format: "%.2f", m.salePrice) : ""
        stockQuantity = m.stockQuantity > 0  ? String(format: "%.2f", m.stockQuantity) : ""
        minStockLevel = m.minStockLevel > 0  ? String(format: "%.2f", m.minStockLevel) : ""
        catalogCode   = m.catalogCode ?? ""
        supplier      = m.supplier ?? ""
        notes         = m.notes ?? ""
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MaterialListView()
            .environmentObject(PersistenceService.shared)
    }
    .preferredColorScheme(.dark)
}
