// PersistenceService.swift
// VoltAsist
//
// Uygulama verilerini UserDefaults + JSON (Codable) ile yerel olarak saklar.
// Müşteriler, teklifler ve uygulama ayarları bu servis aracılığıyla yönetilir.
// Singleton pattern ile tüm uygulama genelinde tek bir örnek kullanılır.

import Foundation
import Combine

// MARK: - PersistenceService

/// Uygulamanın yerel veri katmanı. Tüm CRUD işlemlerini ve istatistikleri yönetir.
final class PersistenceService: ObservableObject {

    // MARK: - Singleton
    static let shared = PersistenceService()

    // MARK: - Yayınlanan Veriler (Reactive State)

    /// Tüm müşteri listesi — değiştiğinde UI otomatik güncellenir
    @Published var customers: [Customer] = []

    /// Tüm teklif listesi — değiştiğinde UI otomatik güncellenir
    @Published var quotes: [Quote] = []

    /// Malzeme kataloğu — değiştiğinde UI otomatik güncellenir
    @Published var materials: [Material] = []

    /// Uygulama geneli ayarlar
    @Published var settings: AppSettings = .defaultSettings

    // MARK: - UserDefaults Anahtarları

    private enum Keys {
        static let customers  = "voltasist_customers_v1"
        static let quotes     = "voltasist_quotes_v1"
        static let settings   = "voltasist_settings_v1"
        static let materials  = "voltasist_materials_v1"
    }

    // MARK: - Init

    /// Private init — Singleton kullanımı zorunlu
    private init() {
        loadAll()
    }

    // MARK: - Genel Yükleme

    /// Uygulama başlangıcında UserDefaults'tan tüm veriyi yükler.
    /// Bozuk JSON varsa boş array ile güvenli şekilde devam eder.
    func loadAll() {
        customers  = load(key: Keys.customers,  type: [Customer].self)  ?? []
        quotes     = load(key: Keys.quotes,     type: [Quote].self)     ?? []
        materials  = load(key: Keys.materials,  type: [Material].self)  ?? []
        settings   = load(key: Keys.settings,   type: AppSettings.self) ?? .defaultSettings
    }

    // MARK: - Müşteri İşlemleri

    /// Yeni müşteri ekler ya da mevcutu günceller (id eşleşmesine göre).
    /// - Parameter customer: Eklenecek veya güncellenecek müşteri nesnesi
    func saveCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            // Mevcut kaydı güncelle
            customers[index] = customer
        } else {
            // Yeni kayıt ekle
            customers.append(customer)
        }
        persist(customers, key: Keys.customers)
    }

    /// Verilen ID'ye sahip müşteriyi listeden ve UserDefaults'tan siler.
    /// İlişkili teklifleri silmez — bunu çağıran katman yönetmelidir.
    /// - Parameter id: Silinecek müşterinin UUID değeri
    func deleteCustomer(id: UUID) {
        customers.removeAll { $0.id == id }
        persist(customers, key: Keys.customers)
    }

    // MARK: - Teklif İşlemleri

    /// Yeni teklif ekler ya da mevcutu günceller (id eşleşmesine göre).
    /// - Parameter quote: Eklenecek veya güncellenecek teklif nesnesi
    func saveQuote(_ quote: Quote) {
        if let index = quotes.firstIndex(where: { $0.id == quote.id }) {
            quotes[index] = quote
        } else {
            quotes.append(quote)
        }
        persist(quotes, key: Keys.quotes)
    }

    /// Verilen ID'ye sahip teklifi listeden ve UserDefaults'tan siler.
    /// - Parameter id: Silinecek teklifin UUID değeri
    func deleteQuote(id: UUID) {
        quotes.removeAll { $0.id == id }
        persist(quotes, key: Keys.quotes)
    }

    /// Belirtilen teklifin durumunu günceller (Beklemede → Onaylandı vb.)
    /// - Parameters:
    ///   - id: Güncellenecek teklifin UUID değeri
    ///   - status: Yeni teklif durumu (QuoteStatus)
    func updateQuoteStatus(id: UUID, status: QuoteStatus) {
        guard let index = quotes.firstIndex(where: { $0.id == id }) else { return }
        quotes[index].status = status
        persist(quotes, key: Keys.quotes)
    }

    // MARK: - Malzeme İşlemleri

    /// Yeni malzeme ekler ya da mevcutu günceller (id eşleşmesine göre).
    /// - Parameter material: Eklenecek veya güncellenecek malzeme nesnesi
    func saveMaterial(_ material: Material) {
        var updated = material
        updated.updatedAt = Date()
        if let index = materials.firstIndex(where: { $0.id == material.id }) {
            materials[index] = updated
        } else {
            materials.append(updated)
        }
        persist(materials, key: Keys.materials)
    }

    /// Verilen ID'ye sahip malzemeyi listeden ve UserDefaults'tan siler.
    /// - Parameter id: Silinecek malzemenin UUID değeri
    func deleteMaterial(id: UUID) {
        materials.removeAll { $0.id == id }
        persist(materials, key: Keys.materials)
    }

    // MARK: - Malzeme İstatistikleri

    /// Stok uyarısı olan malzeme sayısı
    var lowStockMaterialCount: Int {
        materials.filter { $0.isLowStock && $0.minStockLevel > 0 }.count
    }

    /// Toplam stok değeri (TL)
    var totalMaterialStockValue: Double {
        materials.reduce(0.0) { $0 + $1.totalStockValue }
    }

    // MARK: - Ayar İşlemleri

    /// Uygulama ayarlarını kaydeder.
    /// - Parameter settings: Kaydedilecek AppSettings nesnesi
    func saveSettings(_ settings: AppSettings) {
        self.settings = settings
        persist(settings, key: Keys.settings)
    }

    // MARK: - İstatistikler (Computed Properties)

    /// Onaylanmış tekliflerin toplam KDV dahil ciro tutarı (TL)
    var totalRevenueTL: Double {
        quotes
            .filter { $0.status == .approved }
            .reduce(0.0) { $0 + $1.grandTotal }
    }

    /// Onaylanmış teklif sayısı
    var approvedQuoteCount: Int {
        quotes.filter { $0.status == .approved }.count
    }

    /// Beklemedeki (gönderilmiş ama henüz onaylanmamış) teklif sayısı
    var pendingQuoteCount: Int {
        quotes.filter { $0.status == .sent || $0.status == .draft }.count
    }

    /// Toplam müşteri sayısı
    var customerCount: Int {
        customers.count
    }

    /// Gelecek 7 gün içinde geçerlilik tarihi dolacak teklifler
    var expiringQuotes: [Quote] {
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return quotes.filter {
            $0.status == .sent &&
            $0.validUntil >= Date() &&
            $0.validUntil <= sevenDaysLater
        }
    }

    // MARK: - Özel Yardımcı Metodlar

    /// Codable nesneyi JSON'a çevirip UserDefaults'a kaydeder.
    /// - Parameters:
    ///   - value: Kaydedilecek Encodable nesne
    ///   - key: UserDefaults anahtarı
    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // Üretimde bu hata bir loglama servisine iletilmelidir
            print("⚠️ PersistenceService: '\(key)' kaydedilemedi — \(error.localizedDescription)")
        }
    }

    /// UserDefaults'tan JSON verisini okuyup Decodable nesneye dönüştürür.
    /// - Parameters:
    ///   - key: UserDefaults anahtarı
    ///   - type: Hedef tip (T.Type)
    /// - Returns: Başarıyla çözümlenen nesne, aksi halde nil
    private func load<T: Decodable>(key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("⚠️ PersistenceService: '\(key)' yüklenemedi — \(error.localizedDescription)")
            return nil
        }
    }
}
