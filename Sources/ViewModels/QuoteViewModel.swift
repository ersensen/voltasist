// QuoteViewModel.swift
// VoltAsist
//
// Tek bir teklifin oluşturulması, düzenlenmesi ve paylaşımını yöneten ViewModel.
// QuoteEngine, PDFService ve ShareService ile entegre çalışır.
// Kalem sıralaması, KDV hesabı ve PDF üretimi bu ViewModel üzerinden yürütülür.

import Foundation
import Combine
import SwiftUI

// MARK: - QuoteViewModel

/// Bir teklifin tüm yaşam döngüsünü yöneten ViewModel.
/// Kalem ekleme/çıkarma/taşıma, toplam hesabı, PDF üretimi ve WhatsApp paylaşımı sağlar.
final class QuoteViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Düzenlenmekte olan teklif nesnesi
    @Published var currentQuote: Quote

    /// PDF görüntüleme sayfasının gösterilip gösterilmediği
    @Published var isShowingPDF: Bool = false

    /// Üretilen PDF ham verisi
    @Published var pdfData: Data? = nil

    /// İşlem yükleniyor göstergesi (PDF üretimi, kaydetme vb.)
    @Published var isLoading: Bool = false

    /// Başarı/hata uyarı mesajı
    @Published var alertMessage: String? = nil

    /// Uyarı gösterilip gösterilmediği
    @Published var showAlert: Bool = false

    // MARK: - Özel Değişkenler

    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Yeni teklif oluşturur. Müşteri opsiyoneldir, ayarlar zorunludur.
    /// - Parameters:
    ///   - customer: Teklifin düzenleneceği müşteri (nil: müşterisiz teklif)
    ///   - settings: Firma bilgileri ve teklif ayarları
    init(customer: Customer? = nil, settings: AppSettings) {
        self.settings = settings
        self.currentQuote = QuoteEngine.createNewQuote(
            sequence: settings.nextQuoteNumber,
            settings: settings,
            customer: customer
        )
    }

    /// Mevcut teklifi düzenlemek için kullanılır.
    /// - Parameters:
    ///   - existingQuote: Düzenlenecek mevcut teklif
    ///   - settings: Uygulama ayarları
    init(existingQuote: Quote, settings: AppSettings) {
        self.settings = settings
        self.currentQuote = existingQuote
    }

    // MARK: - Kalem Yönetimi

    /// Teklif listesine yeni bir kalem ekler.
    /// - Parameter item: Eklenecek QuoteItem nesnesi
    func addItem(_ item: QuoteItem) {
        currentQuote.items.append(item)
    }

    /// Verilen konumlardaki kalemleri teklif listesinden kaldırır.
    /// - Parameter offsets: Silinecek kalem konumları (IndexSet)
    func removeItem(at offsets: IndexSet) {
        currentQuote.items.remove(atOffsets: offsets)
    }

    /// Kalem listesinde sıra değişikliği yapar (drag & drop desteği).
    /// - Parameters:
    ///   - source: Kaynak konumlar
    ///   - destination: Hedef konum
    func moveItem(from source: IndexSet, to destination: Int) {
        currentQuote.items.move(fromOffsets: source, toOffset: destination)
    }

    /// Mevcut bir kalemi günceller (id eşleşmesi ile bulunur).
    /// - Parameter item: Güncellenmiş kalem nesnesi
    func updateItem(_ item: QuoteItem) {
        guard let index = currentQuote.items.firstIndex(where: { $0.id == item.id }) else { return }
        currentQuote.items[index] = item
    }

    // MARK: - PDF Üretimi

    /// Mevcut teklifi PDF'e dönüştürür ve pdfData'ya kaydeder.
    /// - Parameter settings: Firma bilgileri içeren ayarlar
    /// - Returns: Üretilen PDF verisi
    @discardableResult
    func generatePDF(settings: AppSettings) -> Data {
        isLoading = true
        let data = PDFService.generateQuotePDF(quote: currentQuote, settings: settings)
        pdfData   = data
        isLoading = false
        return data
    }

    // MARK: - Paylaşım

    /// PDF üretir ve WhatsApp mesajı ile birlikte paylaşım akışını başlatır.
    /// Önce PDF dosyası iOS paylaşım paneli ile paylaşılır.
    /// - Parameter settings: Firma bilgileri
    func shareWhatsApp(settings: AppSettings) {
        let data      = generatePDF(settings: settings)
        let filename  = "\(currentQuote.quoteNumber).pdf"
        let message   = ShareService.whatsappMessage(for: currentQuote)

        // Önce PDF'i system share sheet ile paylaş
        ShareService.sharePDF(data: data, filename: filename)

        // Müşteri telefonu varsa WhatsApp'ı da aç
        let phone = currentQuote.customerPhone
        if !phone.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                ShareService.openWhatsApp(phone: phone, message: message)
            }
        }
    }

    // MARK: - Kaydetme

    /// Teklifi PersistenceService'e kaydeder.
    /// - Parameter persistence: Yerel veri katmanı
    func saveQuote(to persistence: PersistenceService) {
        persistence.saveQuote(currentQuote)
        showSuccessAlert("Teklif kaydedildi.")
    }

    // MARK: - Durum Güncelleme

    /// Teklifin durumunu günceller (Taslak → Gönderildi → Onaylandı vb.)
    /// - Parameter status: Yeni durum
    func updateStatus(_ status: QuoteStatus) {
        currentQuote.status = status
    }

    // MARK: - Görüntüleme Hesaplamaları

    /// Genel toplamı "₺45.320,00" biçiminde formatlar.
    var grandTotalFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt.string(from: NSNumber(value: currentQuote.grandTotal)) ?? "₺0,00"
    }

    /// Ara toplamı (KDV hariç, iskonto öncesi) formatlar.
    var subtotalFormatted: String {
        let subtotal = currentQuote.items.reduce(0.0) { $0 + $1.unitPrice * $1.quantity }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: subtotal)) ?? "₺0,00"
    }

    /// Toplam KDV tutarını formatlar.
    var vatTotalFormatted: String {
        let vat = currentQuote.items.reduce(0.0) { $0 + $1.unitPrice * $1.quantity * $1.vatRate }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: vat)) ?? "₺0,00"
    }


    /// Teklif kalemlerini kategoriye göre gruplandırır.
    /// Boş kategoriler döndürülmez.
    var itemsByCategory: [QuoteItemCategory: [QuoteItem]] {
        Dictionary(grouping: currentQuote.items, by: \.category)
    }

    /// Teklif geçerlilik tarihi geçmiş mi?
    var isExpired: Bool {
        currentQuote.validUntil < Date()
    }

    /// Teklif notları boş mu?
    var hasNotes: Bool {
        !(currentQuote.notes?.isEmpty ?? true)
    }

    // MARK: - Özel Yardımcılar

    private func showSuccessAlert(_ message: String) {
        alertMessage = message
        showAlert    = true
    }
}
