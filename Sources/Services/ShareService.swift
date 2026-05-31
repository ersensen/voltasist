// ShareService.swift
// VoltAsist
//
// iOS paylaşım, WhatsApp entegrasyonu ve doğrudan arama işlemlerini yönetir.
// UIActivityViewController ile sistem paylaşım sayfasını açar.
// WhatsApp URL scheme aracılığıyla önceden hazırlanan mesaj gönderir.

import Foundation
import UIKit

// MARK: - ShareService

/// Teklif PDF'i paylaşma, WhatsApp mesajı oluşturma ve telefon araması yapma işlevlerini sunar.
struct ShareService {

    // MARK: - PDF Paylaşımı

    /// iOS sistem paylaşım sayfası (ShareSheet) aracılığıyla PDF dosyasını paylaşır.
    /// - Parameters:
    ///   - data: Paylaşılacak PDF verisi
    ///   - filename: PDF dosyasının adı (.pdf uzantısı otomatik eklenir)
    ///   - viewController: Paylaşım sayfasının sunulacağı UIViewController.
    ///                     nil geçilirse mevcut aktif penceredeki root VC kullanılır.
    static func sharePDF(data: Data,
                         filename: String,
                         from viewController: UIViewController? = nil) {
        // PDF'i geçici dizine kaydet
        let url = PDFService.savePDFToTemp(data: data, filename: filename)

        // Paylaşım aktivitesi
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // iPad için popover kaynağı (crash önleme)
        if let popover = activityVC.popoverPresentationController {
            let rootView = resolveViewController(viewController)?.view
            popover.sourceView = rootView
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX,
                                       y: UIScreen.main.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Sunumu gerçekleştir
        DispatchQueue.main.async {
            resolveViewController(viewController)?.present(activityVC, animated: true)
        }
    }

    // MARK: - WhatsApp Mesaj Metni

    /// Teklif bilgilerinden WhatsApp için hazır Türkçe mesaj metni oluşturur.
    /// Mesaj; teklif numarası, müşteri adı, kalem sayısı ve toplam tutarı içerir.
    /// - Parameter quote: Mesajı oluşturulacak teklif nesnesi
    /// - Returns: Göndermeye hazır Türkçe mesaj metni
    static func whatsappMessage(for quote: Quote) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "dd.MM.yyyy"

        let customerName = quote.customer?.fullName ?? "Değerli Müşterimiz"
        let itemCount    = quote.items.count

        let totalFmt = NumberFormatter()
        totalFmt.numberStyle = .currency
        totalFmt.currencySymbol = "₺"
        totalFmt.locale = Locale(identifier: "tr_TR")
        let totalStr = totalFmt.string(from: NSNumber(value: quote.grandTotal)) ?? "₺0,00"

        return """
        Merhaba \(customerName),

        ⚡ *VoltAsist — Elektrik Teklifi*

        📋 Teklif No: *\(quote.quoteNumber)*
        📅 Tarih: \(df.string(from: quote.createdAt))
        ⏳ Geçerlilik: \(df.string(from: quote.validUntil))
        📦 Kalem Sayısı: \(itemCount) adet
        💰 Genel Toplam (KDV Dahil): *\(totalStr)*

        Teklifinize ait PDF belge ekte yer almaktadır.
        Sorularınız için lütfen bize ulaşın. 🙏

        Saygılarımızla,
        *VoltAsist Ekibi*
        """
    }

    // MARK: - WhatsApp URL Açma

    /// WhatsApp URL scheme kullanarak verilen telefon numarasına önceden dolu mesaj penceresi açar.
    /// Numara otomatik olarak temizlenir (+90 formatına getirilir).
    /// - Parameters:
    ///   - phone: Aranacak telefon numarası (başında 0 veya +90 olabilir)
    ///   - message: Gönderilecek mesaj metni (URL-encode edilir)
    static func openWhatsApp(phone: String, message: String) {
        // Numarayı temizle: boşluk, tire, parantez kaldır
        var cleaned = phone
            .replacingOccurrences(of: " ",  with: "")
            .replacingOccurrences(of: "-",  with: "")
            .replacingOccurrences(of: "(",  with: "")
            .replacingOccurrences(of: ")",  with: "")

        // Türkiye ülke kodu normalizasyonu
        if cleaned.hasPrefix("0") {
            cleaned = "+90" + cleaned.dropFirst()
        } else if !cleaned.hasPrefix("+") {
            cleaned = "+90" + cleaned
        }

        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(cleaned)?text=\(encoded)") else {
            return
        }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // WhatsApp yüklü değil — App Store'a yönlendir
                if let storeURL = URL(string: "https://apps.apple.com/app/whatsapp/id310633997") {
                    UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
                }
            }
        }
    }

    // MARK: - Telefon Araması

    /// Verilen numarayı doğrudan tel: URL scheme ile arar.
    /// Geçersiz numara veya cihaz arama desteklemiyorsa sessizce geçer.
    /// - Parameter phone: Aranacak telefon numarası
    static func callPhone(_ phone: String) {
        let cleaned = phone
            .replacingOccurrences(of: " ",  with: "")
            .replacingOccurrences(of: "-",  with: "")
            .replacingOccurrences(of: "(",  with: "")
            .replacingOccurrences(of: ")",  with: "")

        guard let url = URL(string: "tel://\(cleaned)") else { return }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    // MARK: - Özel Yardımcı

    /// Aktif UIViewController'ı çözümler; parametre nil ise window'daki rootVC kullanılır.
    private static func resolveViewController(_ vc: UIViewController?) -> UIViewController? {
        if let vc = vc { return vc }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
