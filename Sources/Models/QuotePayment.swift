// QuotePayment.swift
// VoltAsist
//
// Bir teklife karşılık alınan tahsilat kaydı.

import Foundation

// MARK: - Ödeme Yöntemi

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash     = "Nakit"
    case transfer = "Havale/EFT"
    case card     = "Kart"
    case other    = "Diğer"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .cash:     return "banknote.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .card:     return "creditcard.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Tahsilat Kaydı

struct QuotePayment: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Double
    var method: PaymentMethod = .cash
    var note: String = ""
}
