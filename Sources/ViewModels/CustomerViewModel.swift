// CustomerViewModel.swift
// VoltAsist
//
// Müşteri listesi arama, filtreleme ve CRUD işlemlerini yöneten ViewModel.
// PersistenceService ile koordineli çalışır; arama reaktif olarak güncellenir.

import Foundation
import Combine
import SwiftUI

// MARK: - CustomerViewModel

/// Müşteri listesinin görüntüleme ve yönetim iş mantığını barındıran ViewModel.
/// İsim ve telefon numarasına göre anlık arama, müşteri bazında istatistikler sunar.
final class CustomerViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Arama metin kutusu değeri — değiştikçe filteredCustomers otomatik güncellenir
    @Published var searchText: String = ""

    /// Kullanıcı seçimi için seçili müşteri (sheet/navigation için)
    @Published var selectedCustomer: Customer? = nil

    /// Yeni müşteri formu göster/gizle
    @Published var isAddingCustomer: Bool = false

    /// Silme onay uyarısı
    @Published var customerToDelete: Customer? = nil

    // MARK: - Init

    init() {}

    // MARK: - Filtrelenmiş Müşteri Listesi

    /// Arama metnine göre müşterileri isim veya telefon numarasıyla filtreler.
    /// Arama boşsa tüm müşterileri isme göre alfabetik sırada döndürür.
    /// - Parameter persistence: Müşteri listesinin kaynağı
    func filteredCustomers(from persistence: PersistenceService) -> [Customer] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = persistence.customers.sorted { $0.fullName.lowercased() < $1.fullName.lowercased() }
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.phone.lowercased().contains(query) ||
            ($0.email?.lowercased().contains(query) ?? false) ||
            ($0.companyName?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - CRUD Operasyonları

    /// Yeni bir müşteri ekler veya mevcut müşteriyi günceller.
    /// - Parameters:
    ///   - customer: Eklenecek veya güncellenecek müşteri
    ///   - persistence: Yerel veri katmanı
    func addCustomer(_ customer: Customer, to persistence: PersistenceService) {
        persistence.saveCustomer(customer)
        isAddingCustomer = false
    }

    /// Verilen ID'ye sahip müşteriyi siler.
    /// - Parameters:
    ///   - id: Silinecek müşterinin UUID'si
    ///   - persistence: Yerel veri katmanı
    func deleteCustomer(id: UUID, from persistence: PersistenceService) {
        persistence.deleteCustomer(id: id)
        customerToDelete = nil
    }

    // MARK: - Müşteri İstatistikleri

    /// Belirtilen müşteriye ait tüm teklifleri döndürür (en yeniden eskiye).
    /// - Parameters:
    ///   - id: Müşteri UUID'si
    ///   - persistence: Yerel veri katmanı
    /// - Returns: Müşteriye ait teklifler, tarihe göre azalan sırada
    func quotesForCustomer(id: UUID, from persistence: PersistenceService) -> [Quote] {
        persistence.quotes
            .filter { $0.customerId == id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Belirtilen müşterinin onaylanmış tekliflerinden elde edilen toplam ciro.
    /// - Parameters:
    ///   - id: Müşteri UUID'si
    ///   - persistence: Yerel veri katmanı
    /// - Returns: KDV dahil toplam tutar (TL)
    func totalRevenueForCustomer(id: UUID, from persistence: PersistenceService) -> Double {
        persistence.quotes
            .filter { $0.customerId == id && $0.status == .approved }
            .reduce(0.0) { $0 + $1.grandTotal }
    }

    /// Müşteri bazında toplam ciroyu formatlanmış string olarak döndürür.
    func formattedRevenueForCustomer(id: UUID, from persistence: PersistenceService) -> String {
        let total = totalRevenueForCustomer(id: id, from: persistence)
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: total)) ?? "₺0"
    }

    /// Müşterinin kaç aktif (onaylanmamış) teklifi olduğunu döndürür.
    func activeDealCount(for id: UUID, from persistence: PersistenceService) -> Int {
        persistence.quotes.filter {
            $0.customerId == id && ($0.status == .sent || $0.status == .draft)
        }.count
    }

    // MARK: - Sıralama

    /// Müşterileri toplam ciroya göre azalan sırada sıralar.
    func customersByRevenue(from persistence: PersistenceService) -> [Customer] {
        persistence.customers.sorted {
            totalRevenueForCustomer(id: $0.id, from: persistence) >
            totalRevenueForCustomer(id: $1.id, from: persistence)
        }
    }
}
