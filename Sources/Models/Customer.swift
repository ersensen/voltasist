// Customer.swift
// VoltAsist
//
// Müşteri veri modeli.
// Müşteriye ait teklifler, ciro takibi ve iletişim bilgileri.

import Foundation

// MARK: - Müşteri Tipi

/// Müşteri türü sınıflandırması
enum CustomerType: String, Codable, CaseIterable, Identifiable {
    case individual = "Bireysel"
    case corporate  = "Kurumsal"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .individual: return "person.fill"
        case .corporate:  return "building.2.fill"
        }
    }
}

// MARK: - Müşteri Modeli

/// Elektrikçinin müşteri kaydı
struct Customer: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Müşteri adı veya firma unvanı
    var name: String

    /// Telefon numarası
    var phone: String

    /// E-posta adresi (opsiyonel)
    var email: String?

    /// Adres
    var address: String

    /// Ek notlar (opsiyonel)
    var notes: String?

    /// Müşteri kaydı oluşturma tarihi
    var createdAt: Date

    /// Bu müşteriye ait teklif ID'leri (Quote.id)
    var quoteIds: [UUID]

    /// Bu müşteriden elde edilen toplam ciro (TL)
    var totalRevenueTL: Double

    /// Aktif müşteri mi?
    var isActive: Bool

    /// Müşteri tipi (bireysel / kurumsal)
    var customerType: CustomerType

    /// Vergi Kimlik Numarası veya TC (kurumsal için opsiyonel)
    var taxNumber: String?

    /// Son iletişim tarihi
    var lastContactDate: Date?

    /// Tercih edilen iletişim kanalı
    var preferredContact: PreferredContact

    // MARK: Hesaplanan Değerler

    /// Toplam teklif sayısı
    var totalQuoteCount: Int {
        quoteIds.count
    }

    /// Ortalama teklif değeri (TL)
    var averageQuoteValue: Double {
        guard totalQuoteCount > 0 else { return 0 }
        return totalRevenueTL / Double(totalQuoteCount)
    }

    init(
        id: UUID = UUID(),
        name: String,
        phone: String,
        email: String? = nil,
        address: String = "",
        notes: String? = nil,
        createdAt: Date = Date(),
        quoteIds: [UUID] = [],
        totalRevenueTL: Double = 0.0,
        isActive: Bool = true,
        customerType: CustomerType = .individual,
        taxNumber: String? = nil,
        lastContactDate: Date? = nil,
        preferredContact: PreferredContact = .phone
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.quoteIds = quoteIds
        self.totalRevenueTL = totalRevenueTL
        self.isActive = isActive
        self.customerType = customerType
        self.taxNumber = taxNumber
        self.lastContactDate = lastContactDate
        self.preferredContact = preferredContact
    }
}

// MARK: - Tercih Edilen İletişim

/// Müşterinin iletişim tercihi
enum PreferredContact: String, Codable, CaseIterable, Identifiable {
    case phone    = "Telefon"
    case whatsapp = "WhatsApp"
    case email    = "E-posta"
    case sms      = "SMS"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .phone:    return "phone.fill"
        case .whatsapp: return "message.fill"
        case .email:    return "envelope.fill"
        case .sms:      return "text.bubble.fill"
        }
    }
}

// MARK: - Müşteri Özeti

/// Müşteri listesi için hafif özet struct (büyük listeler için performans)
struct CustomerSummary: Identifiable {
    let id: UUID
    let name: String
    let phone: String
    let totalRevenueTL: Double
    let totalQuoteCount: Int
    let isActive: Bool
    let customerType: CustomerType

    init(from customer: Customer) {
        self.id = customer.id
        self.name = customer.name
        self.phone = customer.phone
        self.totalRevenueTL = customer.totalRevenueTL
        self.totalQuoteCount = customer.totalQuoteCount
        self.isActive = customer.isActive
        self.customerType = customer.customerType
    }
}
