// PDFService.swift
// VoltAsist
//
// PDFKit kullanarak profesyonel teklif belgesi oluşturur.
// Firma logosu, kalem tablosu, KDV hesabı ve imza alanı içerir.
// Amber/koyu renk şeridi başlık bandı ile kurumsal görünüm sağlar.

import Foundation
import PDFKit
import UIKit

// MARK: - PDFService

/// Teklif PDF belgesi oluşturma ve geçici dosyaya kaydetme işlemlerini yürütür.
struct PDFService {

    // MARK: - Sayfa Sabitleri

    private struct Layout {
        static let pageWidth: CGFloat   = 595.2  // A4 genişliği (points)
        static let pageHeight: CGFloat  = 841.8  // A4 yüksekliği (points)
        static let marginH: CGFloat     = 40     // Yatay kenar boşluğu
        static let marginV: CGFloat     = 36     // Dikey kenar boşluğu
        static let headerHeight: CGFloat = 110   // Üst başlık bandı yüksekliği
        static let rowHeight: CGFloat   = 24     // Tablo satır yüksekliği
        static let footerHeight: CGFloat = 80    // İmza / not alanı yüksekliği
    }

    // MARK: - Renk Paleti

    private struct Palette {
        /// Amber/turuncu — marka rengi, başlık bandı
        static let amber     = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        /// Koyu antrasit — başlık metinleri
        static let dark      = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
        /// Tablo çift satır arka planı
        static let tableAlt  = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        /// Tablo başlık arka planı
        static let tableHead = UIColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1)
        /// Nötr ince çizgi rengi
        static let divider   = UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1)
    }

    // MARK: - Font Yardımcıları

    private static func font(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Ana PDF Üretme Fonksiyonu

    /// Verilen teklif ve ayarlara göre A4 boyutunda PDF Data üretir.
    /// - Parameters:
    ///   - quote: PDF'e dönüştürülecek teklif nesnesi
    ///   - settings: Firma adı, adresi, vergi numarası vb. bilgileri içeren ayarlar
    /// - Returns: PDF içeriği ham Data olarak
    static func generateQuotePDF(quote: Quote, settings: AppSettings) -> Data {
        let pageRect = CGRect(x: 0, y: 0,
                              width: Layout.pageWidth,
                              height: Layout.pageHeight)

        // PDF renderer oluştur
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            var cursorY: CGFloat = 0

            // 1. Başlık bandı
            cursorY = drawHeaderBand(in: ctx.cgContext,
                                     pageRect: pageRect,
                                     settings: settings,
                                     quote: quote)

            // 2. Müşteri bilgileri
            cursorY = drawCustomerSection(in: ctx.cgContext,
                                          pageRect: pageRect,
                                          quote: quote,
                                          startY: cursorY + 16)

            // 3. Tablo başlığı
            cursorY = drawTableHeader(in: ctx.cgContext,
                                      pageRect: pageRect,
                                      startY: cursorY + 12)

            // 4. Kalem satırları (çok sayfalı destek)
            cursorY = drawTableRows(in: ctx.cgContext,
                                    pageRect: pageRect,
                                    items: quote.items,
                                    startY: cursorY,
                                    pageContext: ctx)

            // 5. Alt toplam / KDV / genel toplam bloğu
            cursorY = drawTotalsBlock(in: ctx.cgContext,
                                      pageRect: pageRect,
                                      quote: quote,
                                      startY: cursorY + 8)

            // 6. Notlar ve ödeme koşulları
            if let notes = quote.notes, !notes.isEmpty {
                cursorY = drawNotesSection(in: ctx.cgContext,
                                           pageRect: pageRect,
                                           notes: notes,
                                           paymentTerms: settings.paymentTerms,
                                           startY: cursorY + 16)
            } else {
                cursorY = drawNotesSection(in: ctx.cgContext,
                                           pageRect: pageRect,
                                           notes: nil,
                                           paymentTerms: settings.paymentTerms,
                                           startY: cursorY + 16)
            }

            // 7. İmza alanı
            drawSignatureBlock(in: ctx.cgContext,
                               pageRect: pageRect,
                               settings: settings,
                               startY: cursorY + 24)
        }

        return data
    }

    // MARK: - Başlık Bandı

    /// Amber arka planlı firma logosu, adı, adresi ve teklif meta bilgilerini çizer.
    @discardableResult
    private static func drawHeaderBand(in ctx: CGContext,
                                       pageRect: CGRect,
                                       settings: AppSettings,
                                       quote: Quote) -> CGFloat {
        let bandRect = CGRect(x: 0, y: 0,
                              width: pageRect.width,
                              height: Layout.headerHeight)

        // Arka plan
        ctx.setFillColor(Palette.dark.cgColor)
        ctx.fill(bandRect)

        // Sol amber şerit (logo alanı)
        let logoStripeRect = CGRect(x: 0, y: 0, width: 90, height: Layout.headerHeight)
        ctx.setFillColor(Palette.amber.cgColor)
        ctx.fill(logoStripeRect)

        // Logo placeholder — elektrik sembolü (⚡)
        let logoAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 38, weight: .bold),
            .foregroundColor: Palette.dark
        ]
        let logoStr = NSAttributedString(string: "⚡", attributes: logoAttrs)
        logoStr.draw(at: CGPoint(x: 22, y: (Layout.headerHeight - 46) / 2))

        // Firma Adı
        let companyAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 17, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        NSAttributedString(string: settings.companyName, attributes: companyAttrs)
            .draw(at: CGPoint(x: 104, y: 18))

        // Firma alt bilgileri
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8.5),
            .foregroundColor: UIColor(white: 0.78, alpha: 1)
        ]
        let taxNoStr = settings.taxNumber ?? "—"
        let firmInfo = "\(settings.companyAddress)\nTel: \(settings.phone)  |  \(settings.email)\nVergi No: \(taxNoStr)  |  Vergi Dairesi: \(settings.taxOffice)"
        NSAttributedString(string: firmInfo, attributes: infoAttrs)
            .draw(in: CGRect(x: 104, y: 40, width: 260, height: 65))

        // Teklif bilgileri (sağ üst)
        let rightX: CGFloat = pageRect.width - Layout.marginH - 160
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8.5),
            .foregroundColor: UIColor(white: 0.80, alpha: 1)
        ]
        let boldMetaAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 9.5, weight: .semibold),
            .foregroundColor: Palette.amber
        ]
        NSAttributedString(string: "TEKLİF NO", attributes: metaAttrs).draw(at: CGPoint(x: rightX, y: 18))
        NSAttributedString(string: quote.quoteNumber, attributes: boldMetaAttrs).draw(at: CGPoint(x: rightX, y: 29))

        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "dd MMMM yyyy"
        NSAttributedString(string: "TARİH", attributes: metaAttrs).draw(at: CGPoint(x: rightX, y: 50))
        NSAttributedString(string: df.string(from: quote.createdAt), attributes: boldMetaAttrs)
            .draw(at: CGPoint(x: rightX, y: 61))

        NSAttributedString(string: "GEÇERLİLİK", attributes: metaAttrs).draw(at: CGPoint(x: rightX, y: 80))
        NSAttributedString(string: df.string(from: quote.validUntil), attributes: boldMetaAttrs)
            .draw(at: CGPoint(x: rightX, y: 91))

        return Layout.headerHeight
    }

    // MARK: - Müşteri Bilgileri

    /// Müşteri adı ve adres bilgilerini sol blok olarak çizer.
    @discardableResult
    private static func drawCustomerSection(in ctx: CGContext,
                                            pageRect: CGRect,
                                            quote: Quote,
                                            startY: CGFloat) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 7.5, weight: .semibold),
            .foregroundColor: Palette.amber
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 9.5),
            .foregroundColor: Palette.dark
        ]

        NSAttributedString(string: "SAYIN", attributes: labelAttrs)
            .draw(at: CGPoint(x: Layout.marginH, y: startY))

        let custName = quote.customerName.isEmpty ? "—" : quote.customerName
        NSAttributedString(string: custName, attributes: [
            .font: font(size: 12, weight: .semibold),
            .foregroundColor: Palette.dark
        ]).draw(at: CGPoint(x: Layout.marginH, y: startY + 11))

        var detailY = startY + 26
        if !quote.customerAddress.isEmpty {
            NSAttributedString(string: quote.customerAddress, attributes: valueAttrs)
                .draw(in: CGRect(x: Layout.marginH, y: detailY, width: 250, height: 32))
            detailY += 14
        }
        if !quote.customerPhone.isEmpty {
            NSAttributedString(string: "Tel: \(quote.customerPhone)", attributes: valueAttrs)
                .draw(at: CGPoint(x: Layout.marginH, y: detailY + 14))
            detailY += 13
        }

        // Yatay çizgi
        let lineY = detailY + 26
        ctx.setStrokeColor(Palette.divider.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: Layout.marginH, y: lineY))
        ctx.addLine(to: CGPoint(x: pageRect.width - Layout.marginH, y: lineY))
        ctx.strokePath()

        return lineY
    }

    // MARK: - Tablo Başlığı

    /// Kablo ve kalem tablolarının koyu başlık satırını çizer.
    @discardableResult
    private static func drawTableHeader(in ctx: CGContext,
                                        pageRect: CGRect,
                                        startY: CGFloat) -> CGFloat {
        let headerRect = CGRect(x: Layout.marginH,
                                y: startY,
                                width: pageRect.width - 2 * Layout.marginH,
                                height: Layout.rowHeight)
        ctx.setFillColor(Palette.tableHead.cgColor)
        ctx.fill(headerRect)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8, weight: .semibold),
            .foregroundColor: UIColor.white
        ]

        let cols = columnLayout(pageRect: pageRect)
        let headers = ["#", "AÇIKLAMA", "BİRİM", "ADET", "BİRİM FİYAT", "KDV%", "TUTAR"]
        for (i, header) in headers.enumerated() {
            NSAttributedString(string: header, attributes: attrs)
                .draw(at: CGPoint(x: cols[i].x + 4, y: startY + 7))
        }

        return startY + Layout.rowHeight
    }

    // MARK: - Kalem Satırları

    /// Teklif kalemlerini satır satır çizer; sayfa taşarsa yeni sayfa açar.
    @discardableResult
    private static func drawTableRows(in ctx: CGContext,
                                      pageRect: CGRect,
                                      items: [QuoteItem],
                                      startY: CGFloat,
                                      pageContext: UIGraphicsPDFRendererContext) -> CGFloat {
        var cursorY = startY
        let cols = columnLayout(pageRect: pageRect)

        let darkAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8.5),
            .foregroundColor: Palette.dark
        ]
        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8.5),
            .foregroundColor: Palette.dark,
            .paragraphStyle: rightAligned()
        ]

        for (index, item) in items.enumerated() {
            // Sayfa taşma kontrolü
            if cursorY + Layout.rowHeight > pageRect.height - Layout.footerHeight - 30 {
                pageContext.beginPage()
                cursorY = Layout.marginV
            }

            // Çift/tek satır arka planı
            if index % 2 == 1 {
                let rowRect = CGRect(x: Layout.marginH,
                                     y: cursorY,
                                     width: pageRect.width - 2 * Layout.marginH,
                                     height: Layout.rowHeight)
                ctx.setFillColor(Palette.tableAlt.cgColor)
                ctx.fill(rowRect)
            }

            // Sıra numarası
            NSAttributedString(string: "\(index + 1)", attributes: darkAttrs)
                .draw(at: CGPoint(x: cols[0].x + 4, y: cursorY + 6))

            // Açıklama
            NSAttributedString(string: item.description ?? item.title, attributes: darkAttrs)
                .draw(in: CGRect(x: cols[1].x + 4,
                                 y: cursorY + 5,
                                 width: cols[1].width - 8,
                                 height: Layout.rowHeight))

            // Birim
            NSAttributedString(string: item.unit, attributes: darkAttrs)
                .draw(at: CGPoint(x: cols[2].x + 4, y: cursorY + 6))

            // Adet
            let qtyStr = item.quantity == Double(Int(item.quantity))
                ? "\(Int(item.quantity))"
                : String(format: "%.2f", item.quantity)
            NSAttributedString(string: qtyStr, attributes: numAttrs)
                .draw(in: CGRect(x: cols[3].x, y: cursorY + 6,
                                 width: cols[3].width - 4, height: Layout.rowHeight))

            // Birim fiyat
            NSAttributedString(string: formatCurrency(item.unitPrice), attributes: numAttrs)
                .draw(in: CGRect(x: cols[4].x, y: cursorY + 6,
                                 width: cols[4].width - 4, height: Layout.rowHeight))

            // KDV%
            // vatRate 0.20 formatında — gösterim için yüzde'ye çevir
            NSAttributedString(string: "%\(Int((item.vatRate * 100).rounded()))", attributes: numAttrs)
                .draw(in: CGRect(x: cols[5].x, y: cursorY + 6,
                                 width: cols[5].width - 4, height: Layout.rowHeight))

            // Tutar (KDV dahil)
            // vatRate model içinde 0.20 formatında saklanır (ondalik)
            let lineTotal = item.unitPrice * item.quantity * (1.0 + item.vatRate)
            NSAttributedString(string: formatCurrency(lineTotal), attributes: numAttrs)
                .draw(in: CGRect(x: cols[6].x, y: cursorY + 6,
                                 width: cols[6].width - 4, height: Layout.rowHeight))

            cursorY += Layout.rowHeight
        }

        // Alt çizgi
        ctx.setStrokeColor(Palette.divider.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: Layout.marginH, y: cursorY))
        ctx.addLine(to: CGPoint(x: pageRect.width - Layout.marginH, y: cursorY))
        ctx.strokePath()

        return cursorY
    }

    // MARK: - Alt Toplam Bloğu

    /// Alt toplam, KDV ve genel toplam satırlarını çizer.
    @discardableResult
    private static func drawTotalsBlock(in ctx: CGContext,
                                        pageRect: CGRect,
                                        quote: Quote,
                                        startY: CGFloat) -> CGFloat {
        let blockW: CGFloat = 220
        let blockX = pageRect.width - Layout.marginH - blockW
        var rowY = startY

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 9),
            .foregroundColor: Palette.dark
        ]
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 11, weight: .bold),
            .foregroundColor: Palette.dark
        ]
        let amberAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 11, weight: .bold),
            .foregroundColor: Palette.amber
        ]

        // Ara toplam
        let subtotal = quote.items.reduce(0.0) { $0 + $1.unitPrice * $1.quantity }
        drawTotalRow(ctx: ctx,
                     label: "Ara Toplam",
                     value: formatCurrency(subtotal),
                     x: blockX, y: rowY, w: blockW,
                     labelAttrs: labelAttrs, valueAttrs: valueAttrs)
        rowY += 18

        // İskonto
        if quote.discountRate > 0 {
            let disc = subtotal * (quote.discountRate / 100)
            drawTotalRow(ctx: ctx,
                         label: "İskonto (%\(Int(quote.discountRate)))",
                         value: "-\(formatCurrency(disc))",
                         x: blockX, y: rowY, w: blockW,
                         labelAttrs: labelAttrs, valueAttrs: valueAttrs)
            rowY += 18
        }

        // Toplam KDV
        let vatTotal = quote.items.reduce(0.0) {
            $0 + ($1.unitPrice * $1.quantity * $1.vatRate)
        }
        drawTotalRow(ctx: ctx,
                     label: "KDV",
                     value: formatCurrency(vatTotal),
                     x: blockX, y: rowY, w: blockW,
                     labelAttrs: labelAttrs, valueAttrs: valueAttrs)
        rowY += 18

        // Genel toplam satırı arka planı
        let totalRowRect = CGRect(x: blockX - 4, y: rowY - 2, width: blockW + 4, height: 22)
        ctx.setFillColor(Palette.dark.cgColor)
        ctx.fill(totalRowRect)

        drawTotalRow(ctx: ctx,
                     label: "GENEL TOPLAM",
                     value: formatCurrency(quote.grandTotal),
                     x: blockX, y: rowY + 2, w: blockW,
                     labelAttrs: [.font: font(size: 9, weight: .semibold),
                                   .foregroundColor: UIColor.white],
                     valueAttrs: amberAttrs)
        rowY += 22

        return rowY
    }

    /// Tek bir toplam satırı çizer (etiket + değer).
    private static func drawTotalRow(ctx: CGContext,
                                     label: String,
                                     value: String,
                                     x: CGFloat, y: CGFloat, w: CGFloat,
                                     labelAttrs: [NSAttributedString.Key: Any],
                                     valueAttrs: [NSAttributedString.Key: Any]) {
        NSAttributedString(string: label, attributes: labelAttrs)
            .draw(at: CGPoint(x: x, y: y))

        let valStr = NSAttributedString(string: value, attributes: valueAttrs)
        let valSize = valStr.size()
        valStr.draw(at: CGPoint(x: x + w - valSize.width - 4, y: y))
    }

    // MARK: - Notlar Bölümü

    /// Teklif notları ve ödeme koşullarını küçük font ile çizer.
    @discardableResult
    private static func drawNotesSection(in ctx: CGContext,
                                         pageRect: CGRect,
                                         notes: String?,
                                         paymentTerms: String,
                                         startY: CGFloat) -> CGFloat {
        var cursorY = startY

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8, weight: .semibold),
            .foregroundColor: Palette.amber
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 8),
            .foregroundColor: UIColor.darkGray
        ]

        if let notes = notes, !notes.isEmpty {
            NSAttributedString(string: "NOTLAR", attributes: titleAttrs)
                .draw(at: CGPoint(x: Layout.marginH, y: cursorY))
            cursorY += 12
            NSAttributedString(string: notes, attributes: bodyAttrs)
                .draw(in: CGRect(x: Layout.marginH, y: cursorY,
                                 width: pageRect.width / 2 - Layout.marginH - 10,
                                 height: 40))
            cursorY += 44
        }

        // Ödeme koşulları
        NSAttributedString(string: "ÖDEME KOŞULLARI", attributes: titleAttrs)
            .draw(at: CGPoint(x: Layout.marginH, y: cursorY))
        cursorY += 12
        NSAttributedString(string: paymentTerms, attributes: bodyAttrs)
            .draw(in: CGRect(x: Layout.marginH, y: cursorY,
                             width: pageRect.width / 2 - Layout.marginH - 10,
                             height: 32))
        cursorY += 32
        return cursorY
    }

    // MARK: - İmza Alanı

    /// Müşteri ve yetkili imza kutularını sayfanın altına çizer.
    private static func drawSignatureBlock(in ctx: CGContext,
                                           pageRect: CGRect,
                                           settings: AppSettings,
                                           startY: CGFloat) {
        let boxW: CGFloat = 160
        let boxH: CGFloat = 50
        let leftX = Layout.marginH
        let rightX = pageRect.width - Layout.marginH - boxW

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 7.5, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]

        // Sol kutu — Müşteri onayı
        ctx.setStrokeColor(Palette.divider.cgColor)
        ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: leftX, y: startY, width: boxW, height: boxH))
        NSAttributedString(string: "Müşteri Onayı / Kaşe-İmza", attributes: labelAttrs)
            .draw(at: CGPoint(x: leftX + 6, y: startY + boxH - 14))

        // Sağ kutu — Firma yetkilisi
        ctx.stroke(CGRect(x: rightX, y: startY, width: boxW, height: boxH))
        NSAttributedString(string: "\(settings.companyName) — Yetkili İmza", attributes: labelAttrs)
            .draw(at: CGPoint(x: rightX + 6, y: startY + boxH - 14))

        // Alt çizgi — küçük hukuki not
        let disclaimerAttrs: [NSAttributedString.Key: Any] = [
            .font: font(size: 6.5),
            .foregroundColor: UIColor.lightGray
        ]
        NSAttributedString(
            string: "Bu teklif \(settings.companyName) tarafından düzenlenmiştir. Geçerlilik tarihinden sonra hükmü kalmaz.",
            attributes: disclaimerAttrs
        ).draw(at: CGPoint(x: Layout.marginH,
                           y: startY + boxH + 10))
    }

    // MARK: - Sütun Düzeni

    /// Her sütun için x konumu ve genişliği döndürür.
    private static func columnLayout(pageRect: CGRect) -> [(x: CGFloat, width: CGFloat)] {
        let totalW = pageRect.width - 2 * Layout.marginH
        let widths: [CGFloat] = [
            totalW * 0.04,   // #
            totalW * 0.34,   // Açıklama
            totalW * 0.07,   // Birim
            totalW * 0.07,   // Adet
            totalW * 0.16,   // Birim Fiyat
            totalW * 0.07,   // KDV%
            totalW * 0.15    // Tutar
        ]
        var result: [(CGFloat, CGFloat)] = []
        var x = Layout.marginH
        for w in widths {
            result.append((x, w))
            x += w
        }
        return result
    }

    // MARK: - Sağa Hizalı Paragraf Stili

    private static func rightAligned() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .right
        return ps
    }

    // MARK: - Para Formatı

    /// TL cinsinden sayıyı Türkçe formatlı stringe çevirir: "₺1.234,56"
    private static func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "₺0,00"
    }

    // MARK: - Geçici Dosyaya Kaydet

    /// PDF Data'yı cihazın geçici dizinine yazar ve dosya URL'sini döndürür.
    /// - Parameters:
    ///   - data: Yazılacak PDF verisi
    ///   - filename: Dosya adı (.pdf uzantısı otomatik eklenir)
    /// - Returns: Geçici dizindeki dosya URL'si
    static func savePDFToTemp(data: Data, filename: String) -> URL {
        let cleanName = filename.hasSuffix(".pdf") ? filename : "\(filename).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(cleanName)
        try? data.write(to: url)
        return url
    }
}
