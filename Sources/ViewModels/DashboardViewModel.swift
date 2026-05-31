// DashboardViewModel.swift
// VoltAsist
//
// Ana ekran (Dashboard) için iş mantığını ve görüntüleme verilerini sağlar.
// PersistenceService'ten verileri çekerek özet istatistikleri hesaplar.
// Combine ile reaktif güncellemeler desteklenir.

import Foundation
import Combine
import SwiftUI

// MARK: - DashboardViewModel

/// Ana ekranın veri ve iş mantığını yöneten ViewModel.
/// MVVM mimarisine uygun olarak View'ı doğrudan bilgilendirmek yerine
/// @Published property'ler aracılığıyla reactive veri akışı sağlar.
final class DashboardViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Son 5 teklifin listesi (tarihe göre azalan sırada)
    @Published var recentQuotes: [Quote] = []

    /// Onaylanmış tekliflerin toplam ciro tutarı (TL, KDV dahil)
    @Published var totalRevenueTL: Double = 0

    /// Onaylanmış teklif sayısı
    @Published var approvedCount: Int = 0

    /// Beklemedeki (taslak + gönderildi) teklif sayısı
    @Published var pendingCount: Int = 0

    /// Toplam müşteri sayısı
    @Published var customerCount: Int = 0

    /// Günlük selamlama mesajı — sabah/öğleden sonra/akşam
    @Published var greetingMessage: String = ""

    /// Yaklaşan geçerlilik tarihi olan teklif sayısı (7 gün içinde)
    @Published var expiringQuoteCount: Int = 0

    // MARK: - Özel Değişkenler

    /// Combine abonelikleri için saklama koleksiyonu
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        updateGreeting()
    }

    // MARK: - Verileri Yenile

    /// PersistenceService'ten güncel verileri çekerek tüm yayınlanan state'leri günceller.
    /// Genellikle View'ın .onAppear veya pull-to-refresh işleminde çağrılır.
    /// - Parameter persistence: Yerel veri kaynağı
    func refresh(from persistence: PersistenceService) {
        // Son 5 teklif — oluşturulma tarihine göre azalan sıra
        recentQuotes = Array(
            persistence.quotes
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(5)
        )

        // Özet istatistikler
        totalRevenueTL  = persistence.totalRevenueTL
        approvedCount   = persistence.approvedQuoteCount
        pendingCount    = persistence.pendingQuoteCount
        customerCount   = persistence.customerCount
        expiringQuoteCount = persistence.expiringQuotes.count

        updateGreeting()
    }

    // MARK: - Hesaplanmış Görüntüleme Özellikleri

    /// Toplam ciroyu "₺125.430,00" biçiminde formatlar.
    var formattedRevenue: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 0
        return fmt.string(from: NSNumber(value: totalRevenueTL)) ?? "₺0"
    }

    /// Onay oranını 0.0–1.0 aralığında döndürür (progress bar için).
    var approvalRate: Double {
        let total = approvedCount + pendingCount
        guard total > 0 else { return 0 }
        return Double(approvedCount) / Double(total)
    }

    /// Onay oranını yüzde string olarak formatlar: "%72"
    var approvalRateFormatted: String {
        String(format: "%%%d", Int(approvalRate * 100))
    }

    // MARK: - Özel Yardımcılar

    /// Günün saatine göre Türkçe selamlama mesajı belirler.
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            greetingMessage = "Günaydın! ☀️"
        case 12..<18:
            greetingMessage = "İyi günler! 👋"
        case 18..<22:
            greetingMessage = "İyi akşamlar! 🌆"
        default:
            greetingMessage = "İyi geceler! 🌙"
        }
    }
}
