// MaterialListView.swift
// VoltAsist
//
// Elektrik malzeme kataloğu — stok takibi, fiyat yönetimi ve teklife hızlı ekleme.

import SwiftUI

// MARK: - MaterialListView

/// Tüm malzemelerin kategorize edilmiş listesi.
/// Arama, filtreleme, stok uyarısı ve teklife hızlı ekleme özelliklerine sahiptir.
struct MaterialListView: View {

    @EnvironmentObject private var persistence: PersistenceService
    @State private var searchText        = ""
    @State private var selectedCategory: MaterialCategory? = nil
    @State private var showAddSheet      = false
    @State private var editingMaterial: Material? = nil
    @State private var showLowStockOnly  = false
    @State private var addToQuoteItem: QuoteItem? = nil
    @State private var showQuoteBuilder  = false
    @State private var pendingQuoteItems: [QuoteItem] = []

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG  = Color(red: 0.07, green: 0.07, blue: 0.09)

    // MARK: Computed

    private var filteredMaterials: [Material] {
        persistence.materials.filter { m in
            let matchSearch = searchText.isEmpty ||
                m.name.localizedCaseInsensitiveContains(searchText) ||
                (m.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (m.catalogCode?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchCategory = selectedCategory == nil || m.category == selectedCategory
            let matchStock = !showLowStockOnly || m.isLowStock
            return matchSearch && matchCategory && matchStock
        }.sorted { $0.name < $1.name }
    }

    private var groupedMaterials: [(MaterialCategory, [Material])] {
        if selectedCategory != nil || !searchText.isEmpty || showLowStockOnly {
            // Filtrelenmiş modda tüm sonuçları tek grup olarak göster
            let cats = Dictionary(grouping: filteredMaterials, by: { $0.category })
            return cats.sorted { $0.key.rawValue < $1.key.rawValue }
        }
        // Normal modda: kategorilere göre grupla
        let cats = Dictionary(grouping: filteredMaterials, by: { $0.category })
        return MaterialCategory.allCases
            .compactMap { cat in
                guard let items = cats[cat], !items.isEmpty else { return nil }
                return (cat, items)
            }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            darkBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Arama ve filtre çubuğu
                headerBar

                if filteredMaterials.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                            // İstatistik kartları (normal modda)
                            if searchText.isEmpty && selectedCategory == nil && !showLowStockOnly {
                                statsRow
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            }

                            // Gruplara göre malzemeler
                            ForEach(groupedMaterials, id: \.0) { category, items in
                                Section {
                                    ForEach(items) { material in
                                        MaterialRow(material: material) {
                                            editingMaterial = material
                                        } onDelete: {
                                            persistence.deleteMaterial(id: material.id)
                                        } onAddToQuote: {
                                            addToQuoteAction(material: material)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                } header: {
                                    categoryHeader(category)
                                }
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
        }
        .navigationTitle("Malzeme Kataloğu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(amber)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            MaterialFormSheet(onSave: { persistence.saveMaterial($0) })
        }
        .sheet(item: $editingMaterial) { material in
            MaterialFormSheet(material: material, onSave: { persistence.saveMaterial($0) })
        }
        .sheet(isPresented: $showQuoteBuilder) {
            NavigationStack {
                QuoteBuilderView()
                    .environmentObject(persistence)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(spacing: 10) {
            // Arama
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    TextField("Malzeme, marka, kod ara...", text: $searchText)
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

                // Stok filtresi
                Button {
                    withAnimation { showLowStockOnly.toggle() }
                } label: {
                    Image(systemName: showLowStockOnly ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundColor(showLowStockOnly ? .orange : .gray)
                        .frame(width: 40, height: 40)
                        .background(showLowStockOnly ? Color.orange.opacity(0.15) : Color.white.opacity(0.07))
                        .cornerRadius(12)
                }
            }

            // Kategori filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Tümü", category: nil)
                    ForEach(MaterialCategory.allCases) { cat in
                        filterChip(title: cat.rawValue.components(separatedBy: " ").first ?? cat.rawValue,
                                   category: cat)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(darkBG)
    }

    private func filterChip(title: String, category: MaterialCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = isSelected ? nil : category
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? amber : Color.white.opacity(0.08))
                .cornerRadius(20)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "shippingbox.fill",
                value: "\(persistence.materials.count)",
                label: "Toplam",
                color: amber
            )
            statCard(
                icon: "exclamationmark.triangle.fill",
                value: "\(persistence.lowStockMaterialCount)",
                label: "Düşük Stok",
                color: .orange
            )
            statCard(
                icon: "turkishlirasign.circle.fill",
                value: formatShort(persistence.totalMaterialStockValue),
                label: "Stok Değeri",
                color: .cyan
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Category Header

    private func categoryHeader(_ category: MaterialCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.systemIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(category.accentColor)
            Text(category.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(category.accentColor)
            Spacer()
            let count = groupedMaterials.first(where: { $0.0 == category })?.1.count ?? 0
            Text("\(count) kalem")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(darkBG)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(amber.opacity(0.3))
            Text(searchText.isEmpty ? "Henüz malzeme yok" : "Sonuç bulunamadı")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text(searchText.isEmpty ? "Sağ üstteki + butonuna basarak\nmalzeme kataloğunuzu oluşturun." : "Farklı bir arama terimi deneyin.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button(action: { showAddSheet = true }) {
                    Label("Malzeme Ekle", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(amber)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func addToQuoteAction(material: Material) {
        showQuoteBuilder = true
    }

    // MARK: - Helpers

    private func formatShort(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "₺%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "₺%.0fK", v / 1_000) }
        return String(format: "₺%.0f", v)
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
            // Kategori ikonu
            ZStack {
                Circle()
                    .fill(material.category.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: material.category.systemIcon)
                    .font(.system(size: 16))
                    .foregroundColor(material.category.accentColor)
            }

            // Bilgi
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
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
                HStack(spacing: 6) {
                    if let brand = material.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    if let code = material.catalogCode, !code.isEmpty {
                        Text("· \(code)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                HStack(spacing: 8) {
                    Text("Stok: \(formatQty(material.stockQuantity)) \(material.unit)")
                        .font(.system(size: 11))
                        .foregroundColor(material.isLowStock && material.minStockLevel > 0 ? .orange : .gray.opacity(0.7))
                }
            }

            Spacer()

            // Fiyat
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTL(material.salePrice))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(amber)
                Text("/ \(material.unit)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(material.isLowStock && material.minStockLevel > 0 ?
                        Color.orange.opacity(0.25) : Color.white.opacity(0.06),
                        lineWidth: 1)
        )
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
            .tint(Color(red: 0.0, green: 0.6, blue: 0.3))
        }
    }

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₺"
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }

    private func formatQty(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
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

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let units = ["adet", "m", "m²", "m³", "kg", "kutu", "rulo", "paket", "takım", "kWp", "kVAr", "saat"]
    private let bgColor = Color(red: 0.07, green: 0.07, blue: 0.09)

    var canSave: Bool { !name.isEmpty && (Double(salePrice.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                Form {
                    Section("Malzeme Bilgileri") {
                        formRow(icon: "shippingbox.fill", placeholder: "Malzeme Adı *", text: $name)
                        formRow(icon: "tag.fill", placeholder: "Marka / Üretici", text: $brand)
                        formRow(icon: "barcode", placeholder: "Katalog Kodu", text: $catalogCode)
                        formRow(icon: "truck.box.fill", placeholder: "Tedarikçi", text: $supplier)

                        Picker("Kategori", selection: $category) {
                            ForEach(MaterialCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.systemIcon).tag(cat)
                            }
                        }
                    }

                    Section("Fiyat & Birim") {
                        HStack {
                            Image(systemName: "turkishlirasign.circle").foregroundColor(amber).frame(width: 20)
                            Text("Alış Fiyatı (₺)")
                            Spacer()
                            TextField("0", text: $purchasePrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Image(systemName: "turkishlirasign.circle.fill").foregroundColor(amber).frame(width: 20)
                            Text("Satış Fiyatı (₺) *")
                            Spacer()
                            TextField("0", text: $salePrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Birim", selection: $unit) {
                            ForEach(units, id: \.self) { u in Text(u).tag(u) }
                        }
                    }

                    Section("Stok Bilgisi") {
                        HStack {
                            Image(systemName: "number.circle").foregroundColor(.cyan).frame(width: 20)
                            Text("Mevcut Stok")
                            Spacer()
                            TextField("0", text: $stockQuantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange).frame(width: 20)
                            Text("Min. Stok Uyarı")
                            Spacer()
                            TextField("0", text: $minStockLevel)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Özet
                    let salePriceDouble = Double(salePrice.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let purchasePriceDouble = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) ?? 0
                    if salePriceDouble > 0 && purchasePriceDouble > 0 {
                        Section("Özet") {
                            let margin = purchasePriceDouble > 0 ?
                                ((salePriceDouble - purchasePriceDouble) / purchasePriceDouble) * 100 : 0
                            HStack {
                                Text("Kar Marjı")
                                Spacer()
                                Text(String(format: "%%%.1f", margin))
                                    .foregroundColor(margin >= 0 ? .green : .red)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    Section("Notlar") {
                        TextField("Ek açıklamalar...", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(material == nil ? "Malzeme Ekle" : "Malzemeyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        let m = Material(
                            id: material?.id ?? UUID(),
                            name: name,
                            brand: brand.isEmpty ? nil : brand,
                            category: category,
                            unit: unit,
                            purchasePrice: Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            salePrice: Double(salePrice.replacingOccurrences(of: ",", with: ".")) ?? 0,
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
                    .disabled(!canSave)
                    .fontWeight(.bold)
                    .foregroundColor(canSave ? amber : .gray)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func formRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(amber).frame(width: 20)
            TextField(placeholder, text: text)
        }
    }

    private func prefill() {
        guard let m = material else { return }
        name          = m.name
        brand         = m.brand ?? ""
        category      = m.category
        unit          = m.unit
        purchasePrice = m.purchasePrice > 0 ? String(format: "%.2f", m.purchasePrice) : ""
        salePrice     = m.salePrice > 0 ? String(format: "%.2f", m.salePrice) : ""
        stockQuantity = m.stockQuantity > 0 ? String(format: "%.2f", m.stockQuantity) : ""
        minStockLevel = m.minStockLevel > 0 ? String(format: "%.2f", m.minStockLevel) : ""
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
