// QuoteItem.swift
// VoltAsist
//
// Teklif kalemi ve teklif belgesi modeli.
// KDV, iskonto ve toplam fiyat hesapları dahil.

import Foundation

// MARK: - Teklif Kalemi Kategorisi

/// Teklif kaleminin türünü belirtir
enum QuoteItemCategory: String, Codable, CaseIterable, Identifiable {
    case material     = "Malzeme"
    case labor        = "İşçilik"
    case equipment    = "Ekipman"
    case service      = "Hizmet"
    case compensation = "Kompanzasyon"
    case solar        = "Solar"
    case other        = "Diğer"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .material:     return "shippingbox.fill"
        case .labor:        return "person.fill.checkmark"
        case .equipment:    return "wrench.fill"
        case .service:      return "star.fill"
        case .compensation: return "waveform.path.ecg"
        case .solar:        return "sun.max.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Teklif Kalemi

/// Teklifte yer alan tek bir kalem (satır)
struct QuoteItem: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Kalem başlığı / malzeme adı
    var title: String

    /// Kalem açıklaması (opsiyonel)
    var description: String?

    /// Kalem kategorisi
    var category: QuoteItemCategory

    /// Miktar
    var quantity: Double

    /// Birim — örn: "adet", "m", "m²", "saat", "kVAr", "kWp"
    var unit: String

    /// Birim fiyat (TL) — KDV hariç
    var unitPrice: Double

    /// KDV oranı (0.10 = %10, 0.20 = %20)
    var vatRate: Double

    /// Kalem iskontosu (0.0–1.0 arası — 0.15 = %15 indirim)
    var discount: Double

    // MARK: Hesaplanan Değerler

    /// İskonto uygulanmış net tutar (TL) = miktar × birim fiyat × (1 - iskonto)
    var netPrice: Double {
        quantity * unitPrice * (1.0 - discount)
    }

    /// KDV tutarı (TL) = net fiyat × KDV oranı
    var vatAmount: Double {
        netPrice * vatRate
    }

    /// KDV dahil toplam (TL)
    var totalPrice: Double {
        netPrice + vatAmount
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        category: QuoteItemCategory = .material,
        quantity: Double = 1.0,
        unit: String = "adet",
        unitPrice: Double = 0.0,
        vatRate: Double = 0.20,
        discount: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.discount = discount
    }

    /// Uyumluluk init — description parametresiyle çağrılanlar için.
    /// vatRate parametresi > 1 ise yüzde değeri olarak kabul edilir (ör. 20 → 0.20)
    init(
        id: UUID = UUID(),
        description: String,
        unit: String = "adet",
        quantity: Double = 1.0,
        unitPrice: Double = 0.0,
        vatRate: Double = 0.20,
        category: QuoteItemCategory = .material,
        discount: Double = 0.0
    ) {
        self.id = id
        self.title = description
        self.description = description
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        // vatRate > 1 ise yüzde olarak verilmiş — normalize et
        self.vatRate = vatRate > 1.0 ? vatRate / 100.0 : vatRate
        self.discount = discount
    }
}


// MARK: - Teklif Durumu

/// Teklifin yaşam döngüsü durumu
enum QuoteStatus: String, Codable, CaseIterable, Identifiable {
    case draft    = "Taslak"
    case sent     = "Gönderildi"
    case approved = "Onaylandı"
    case rejected = "Reddedildi"
    case invoiced = "Faturalandı"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .draft:    return "doc.text.fill"
        case .sent:     return "paperplane.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        case .invoiced: return "banknote.fill"
        }
    }

    var colorName: String {
        switch self {
        case .draft:    return "StatusDraft"
        case .sent:     return "StatusSent"
        case .approved: return "StatusApproved"
        case .rejected: return "StatusRejected"
        case .invoiced: return "StatusInvoiced"
        }
    }

    /// Bu durumdan düzenlenebilir mi?
    var isEditable: Bool {
        switch self {
        case .draft:              return true
        case .sent, .approved,
             .rejected, .invoiced: return false
        }
    }
}

// MARK: - Teklif Belgesi

/// Müşteriye sunulan teklif belgesi
struct Quote: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Teklif numarası — örn: "VA-2024-001"
    var quoteNumber: String

    /// Müşteri ID (Customer tablosunda kayıtlıysa)
    var customerId: UUID?

    /// Müşteri adı/unvanı
    var customerName: String

    /// Müşteri telefonu
    var customerPhone: String

    /// Müşteri e-postası (opsiyonel)
    var customerEmail: String?

    /// Müşteri adresi
    var customerAddress: String

    /// Teklif kalemleri
    var items: [QuoteItem]

    /// Ek notlar veya özel koşullar (opsiyonel)
    var notes: String?

    /// Teklifin geçerlilik tarihi
    var validUntil: Date

    /// Teklifin oluşturulma tarihi
    var createdAt: Date

    /// Teklif durumu
    var status: QuoteStatus

    /// Genel iskonto oranı (%) — tüm toplama uygulanır
    var discountPercent: Double

    /// İşin gerçekleşeceği adres (teslimat/şantiye farklıysa)
    var workSiteAddress: String?

    /// Proje adı / açıklaması
    var projectTitle: String?

    // MARK: Hesaplanan Değerler

    /// Ara toplam (TL) — tüm kalemlerin net fiyatı toplamı
    var subtotal: Double {
        items.reduce(0.0) { $0 + $1.netPrice }
    }

    /// Toplam KDV (TL)
    var totalVAT: Double {
        items.reduce(0.0) { $0 + $1.vatAmount }
    }

    /// KDV dahil genel toplam (TL) — genel iskonto uygulanmadan
    var grandTotal: Double {
        subtotal + totalVAT
    }

    /// Genel iskonto uygulanmış son toplam (TL)
    var grandTotalAfterDiscount: Double {
        grandTotal * (1.0 - discountPercent / 100.0)
    }

    /// İskonto tutarı (TL)
    var discountAmount: Double {
        grandTotal - grandTotalAfterDiscount
    }

    /// Teklifin süresi dolmuş mu?
    var isExpired: Bool {
        validUntil < Date()
    }

    /// Kalem kategorilerine göre dağılım (TL)
    var categoryBreakdown: [QuoteItemCategory: Double] {
        var breakdown: [QuoteItemCategory: Double] = [:]
        for item in items {
            breakdown[item.category, default: 0.0] += item.netPrice
        }
        return breakdown
    }

    init(
        id: UUID = UUID(),
        quoteNumber: String = "",
        customerId: UUID? = nil,
        customerName: String = "",
        customerPhone: String = "",
        customerEmail: String? = nil,
        customerAddress: String = "",
        items: [QuoteItem] = [],
        notes: String? = nil,
        validUntil: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        createdAt: Date = Date(),
        status: QuoteStatus = .draft,
        discountPercent: Double = 0.0,
        workSiteAddress: String? = nil,
        projectTitle: String? = nil
    ) {
        self.id = id
        self.quoteNumber = quoteNumber
        self.customerId = customerId
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerEmail = customerEmail
        self.customerAddress = customerAddress
        self.items = items
        self.notes = notes
        self.validUntil = validUntil
        self.createdAt = createdAt
        self.status = status
        self.discountPercent = discountPercent
        self.workSiteAddress = workSiteAddress
        self.projectTitle = projectTitle
    }

    // MARK: Uyumluluk Computed Property'leri

    /// İskonto oranı (%) — discountPercent ile aynı
    var discountRate: Double { discountPercent }

    /// Müşteri özet nesnesi — ViewModel ve Service uyumluluğu için
    var customer: QuoteCustomerProxy? {
        guard !customerName.isEmpty else { return nil }
        return QuoteCustomerProxy(
            fullName: customerName,
            name: customerName,
            phone: customerPhone,
            email: customerEmail,
            address: customerAddress
        )
    }
}

// MARK: - QuoteCustomerProxy

/// Quote'un müşteri alanlarına nesne olarak erişim sağlayan proxy
struct QuoteCustomerProxy {
    var fullName: String
    var name: String
    var phone: String
    var email: String?
    var address: String
}

