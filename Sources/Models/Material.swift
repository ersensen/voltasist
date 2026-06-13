// Material.swift
// VoltAsist
//
// Elektrik malzeme kataloğu modeli.
// Stok takibi, birim fiyat ve teklife hızlı ekleme desteği.

import Foundation
import SwiftUI

// MARK: - Malzeme Kategorisi

/// Elektrik malzemelerinin ana kategorileri
enum MaterialCategory: String, Codable, CaseIterable, Identifiable {
    case cable          = "Kablo & İletken"
    case switchgear     = "Şalt & Kesici"
    case panel          = "Pano & Ekipman"
    case socket         = "Priz & Anahtar"
    case lighting       = "Aydınlatma"
    case solar          = "Solar Ekipman"
    case protection     = "Koruma & Kompanzasyon"
    case grounding      = "Topraklama"
    case conduit        = "Boru & Kanal"
    case tools          = "Alet & Ekipman"
    case other          = "Diğer"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .cable:       return "cable.coaxial"
        case .switchgear:  return "light.max"
        case .panel:       return "square.grid.3x3.fill"
        case .socket:      return "powerplug.fill"
        case .lighting:    return "lightbulb.fill"
        case .solar:       return "sun.max.fill"
        case .protection:  return "shield.fill"
        case .grounding:   return "arrow.down.to.line"
        case .conduit:     return "cylinder.fill"
        case .tools:       return "wrench.and.screwdriver.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .cable:       return Color(red: 1.0, green: 0.75, blue: 0.0)  // amber
        case .switchgear:  return .orange
        case .panel:       return .blue
        case .socket:      return .cyan
        case .lighting:    return .yellow
        case .solar:       return Color(red: 1.0, green: 0.9, blue: 0.0)
        case .protection:  return .mint
        case .grounding:   return .brown
        case .conduit:     return .gray
        case .tools:       return .purple
        case .other:       return .secondary
        }
    }
}

// MARK: - Malzeme

/// Elektrik malzeme kataloğundaki tek bir malzeme kaydı
struct Material: Codable, Identifiable {

    /// Benzersiz kimlik
    var id: UUID

    /// Malzeme adı — örn: "NYY 3x2.5mm² Kablo"
    var name: String

    /// Marka / üretici (opsiyonel) — örn: "Prysmian"
    var brand: String?

    /// Ana kategori
    var category: MaterialCategory

    /// Birim — örn: "m", "adet", "m²", "kg"
    var unit: String

    /// Birim alış fiyatı (TL, KDV hariç)
    var purchasePrice: Double

    /// Birim satış / teklif fiyatı (TL, KDV hariç)
    var salePrice: Double

    /// Mevcut stok miktarı (0 ise stok yok)
    var stockQuantity: Double

    /// Minimum stok uyarı seviyesi
    var minStockLevel: Double

    /// Malzeme kodu / katalog numarası (opsiyonel)
    var catalogCode: String?

    /// Tedarikçi adı (opsiyonel)
    var supplier: String?

    /// Ek notlar
    var notes: String?

    /// Oluşturulma tarihi
    var createdAt: Date

    /// Son güncelleme tarihi
    var updatedAt: Date

    // MARK: Hesaplanan Değerler

    /// Kar marjı (%)
    var marginPercent: Double {
        guard purchasePrice > 0 else { return 0 }
        return ((salePrice - purchasePrice) / purchasePrice) * 100.0
    }

    /// Stok uyarısı var mı?
    var isLowStock: Bool {
        stockQuantity <= minStockLevel
    }

    /// Toplam stok değeri (satış fiyatı × stok miktarı)
    var totalStockValue: Double {
        salePrice * stockQuantity
    }

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        category: MaterialCategory = .cable,
        unit: String = "adet",
        purchasePrice: Double = 0.0,
        salePrice: Double = 0.0,
        stockQuantity: Double = 0.0,
        minStockLevel: Double = 0.0,
        catalogCode: String? = nil,
        supplier: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.unit = unit
        self.purchasePrice = purchasePrice
        self.salePrice = salePrice
        self.stockQuantity = stockQuantity
        self.minStockLevel = minStockLevel
        self.catalogCode = catalogCode
        self.supplier = supplier
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - QuoteItem Dönüşümü

extension Material {
    /// Bu malzemeyi verilen miktarda bir QuoteItem'a dönüştür
    func toQuoteItem(quantity: Double = 1.0, vatRate: Double = 0.20) -> QuoteItem {
        QuoteItem(
            id: UUID(),
            title: name,
            description: brand,
            category: .material,
            quantity: quantity,
            unit: unit,
            unitPrice: salePrice,
            vatRate: vatRate,
            discount: 0.0
        )
    }
}
