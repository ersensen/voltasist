// QuoteEngineTests.swift
// VoltAsist — Birim Testleri
//
// QuoteEngine teklif toplam hesabı, iskonto uygulaması ve numara formatını doğrular.
// KDV dahil toplam, iskonto sonrası fiyat ve teklif numarası formatı test edilir.

import XCTest
@testable import UygulamaMotoru

// MARK: - QuoteEngineTests

/// QuoteEngine teklif oluşturma, hesaplama ve format doğrulama test sınıfı.
final class QuoteEngineTests: XCTestCase {

    // MARK: - Yardımcı Fabrika Metotları

    /// Test için standart AppSettings oluşturur.
    private func makeSettings(quoteNumber: Int = 1) -> AppSettings {
        var s = AppSettings.defaultSettings
        s.companyName       = "Test Firma A.Ş."
        s.companyAddress    = "Test Caddesi No:1, İstanbul"
        s.phone             = "0212 555 00 00"
        s.email             = "info@testfirma.com"
        s.taxNumber         = "1234567890"
        s.taxOffice         = "Kadıköy VD"
        s.defaultVATRate    = 20.0
        s.defaultValidityDays = 30
        s.nextQuoteNumber   = quoteNumber
        return s
    }

    /// Birim fiyat ve KDV ile basit bir QuoteItem oluşturur.
    private func makeItem(description: String,
                          unitPrice: Double,
                          quantity: Double = 1.0,
                          vatRate: Double = 20.0) -> QuoteItem {
        QuoteItem(
            description: description,
            unit: "Adet",
            quantity: quantity,
            unitPrice: unitPrice,
            vatRate: vatRate,
            category: .cableWiring
        )
    }

    // MARK: - Test 1: 3 Kalem × KDV%20 → Doğru Toplam

    /// 3 kalem: 1000 TL + 2000 TL + 500 TL = 3500 TL ara toplam
    /// KDV%20 → 700 TL KDV → Genel Toplam = 4200 TL
    func test_threeItems_VAT20_shouldReturnCorrectGrandTotal() {
        // Given
        let settings = makeSettings()
        let items = [
            makeItem(description: "Kablo Döşeme", unitPrice: 1_000.0, quantity: 1),
            makeItem(description: "Sigorta Grubu", unitPrice: 2_000.0, quantity: 1),
            makeItem(description: "Priz Montajı",  unitPrice: 500.0,   quantity: 1)
        ]

        // When
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        for item in items { quote.items.append(item) }

        // Then
        let subtotal = 1_000.0 + 2_000.0 + 500.0           // 3500 TL
        let vatTotal = subtotal * 0.20                       // 700 TL
        let expected = subtotal + vatTotal                   // 4200 TL

        XCTAssertEqual(quote.grandTotal, expected, accuracy: 0.01,
            "3 kalem KDV%20 ile genel toplam 4200 TL (±0.01) olmalıdır.")
        XCTAssertEqual(quote.items.count, 3,
            "Teklif tam olarak 3 kalem içermelidir.")
    }

    // MARK: - Test 2: İskonto Uygulanmış Teklif Toplamı

    /// Ara toplam 10.000 TL, %10 iskonto = 1000 TL, KDV matrahı = 9000 TL
    /// KDV%18 → 1620 TL → Genel Toplam = 10.620 TL
    func test_discountedQuote_10Percent_shouldReduceGrandTotal() {
        // Given
        let settings = makeSettings()
        let items = [
            makeItem(description: "Solar Panel Grubu",   unitPrice: 5_000.0, vatRate: 18),
            makeItem(description: "İnverter",            unitPrice: 3_000.0, vatRate: 18),
            makeItem(description: "Montaj ve Kablolama", unitPrice: 2_000.0, vatRate: 18)
        ]
        // Ara toplam = 10.000 TL, %10 iskonto uygulanıyor

        // When
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        for item in items { quote.items.append(item) }
        quote.discountRate = 10.0  // %10 iskonto

        // Then
        // Subtotal = 10.000, iskonto = 1.000, KDV matrahı = 9.000
        // KDV@18% = 9000 × 0.18 = 1.620 → Toplam = 10.620 TL
        let subtotal   = 10_000.0
        let discount   = subtotal * 0.10          // 1.000
        let vatBase    = subtotal - discount       // 9.000
        let vat        = vatBase * 0.18           // 1.620
        let expected   = vatBase + vat            // 10.620

        XCTAssertEqual(quote.grandTotal, expected, accuracy: 0.01,
            "%10 iskonto sonrası genel toplam 10.620 TL (±0.01) olmalıdır.")
        XCTAssertLessThan(quote.grandTotal, 12_000.0,
            "İskontolu teklif 12.000 TL'den küçük olmalıdır.")
    }

    // MARK: - Test 3: Teklif Numarası Formatı — "VA-2024-001"

    /// Teklif numarası "VA-YYYY-NNN" formatında üretilmelidir.
    /// Yıl güncel yıl, numara settings.nextQuoteNumber'dan gelmeli ve 3 hane sıfır dolgusu olmalı.
    func test_quoteNumber_shouldFollowVUFormat() {
        // Given
        var settings = makeSettings(quoteNumber: 1)
        settings.nextQuoteNumber = 1

        // When
        let quote = QuoteEngine.newQuote(customer: nil, settings: settings)

        // Then
        let currentYear = Calendar.current.component(.year, from: Date())
        let expectedPrefix = "VA-\(currentYear)-"

        XCTAssertTrue(quote.quoteNumber.hasPrefix(expectedPrefix),
            "Teklif numarası '\(expectedPrefix)' ile başlamalıdır. Bulunan: \(quote.quoteNumber)")

        // Sayı kısmı 3+ hane ve sıfır dolgulu olmalı
        let numberPart = quote.quoteNumber.components(separatedBy: "-").last ?? ""
        XCTAssertGreaterThanOrEqual(numberPart.count, 3,
            "Teklif numarasının sayı kısmı en az 3 hane olmalıdır.")
        XCTAssertTrue(numberPart.allSatisfy { $0.isNumber },
            "Teklif numarasının sayı kısmı yalnızca rakam içermelidir.")
    }

    // MARK: - Test 4: Boş Teklif Edge Case

    /// Hiç kalem eklenmemiş teklif → grandTotal = 0, items boş olmalı.
    func test_emptyQuote_shouldHaveZeroTotalAndEmptyItems() {
        // Given
        let settings = makeSettings()

        // When
        let quote = QuoteEngine.newQuote(customer: nil, settings: settings)

        // Then
        XCTAssertEqual(quote.grandTotal, 0.0, accuracy: 0.001,
            "Boş teklif için genel toplam 0 TL olmalıdır.")
        XCTAssertTrue(quote.items.isEmpty,
            "Yeni teklif kalem listesi boş olmalıdır.")
        XCTAssertNotNil(quote.id,
            "Teklif UUID'si nil olmamalıdır.")
        XCTAssertEqual(quote.status, .draft,
            "Yeni teklif 'Taslak' (draft) durumuyla oluşturulmalıdır.")
    }

    // MARK: - Test 5: Farklı KDV Oranları Karışık Kalem Toplamı

    /// %18 ve %20 KDV'li kalemlerin toplamı ayrı ayrı hesaplanmalı.
    /// 1000 TL@%18 → KDV=180 TL, 2000 TL@%20 → KDV=400 TL → Toplam: 3580 TL
    func test_mixedVATRates_shouldCalculateCorrectly() {
        // Given
        let settings = makeSettings()
        let items = [
            makeItem(description: "Malzeme A", unitPrice: 1_000.0, vatRate: 18.0),
            makeItem(description: "Malzeme B", unitPrice: 2_000.0, vatRate: 20.0)
        ]

        // When
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        for item in items { quote.items.append(item) }

        // Then
        // 1000 + 180 = 1180, 2000 + 400 = 2400, Toplam = 3580 TL
        let expected = 1_000.0 * 1.18 + 2_000.0 * 1.20   // 3580 TL
        XCTAssertEqual(quote.grandTotal, expected, accuracy: 0.01,
            "Karma KDV oranlı teklif toplamı 3580 TL (±0.01) olmalıdır.")
    }

    // MARK: - Test 6: Çok Adetli Kalem Toplam Hesabı

    /// 5 adet × 750 TL = 3750 TL ara toplam → KDV%20 = 750 TL → Toplam 4500 TL
    func test_multipleQuantity_shouldMultiplyUnitPriceCorrectly() {
        // Given
        let settings = makeSettings()
        let item = makeItem(description: "LED Armatür", unitPrice: 750.0, quantity: 5.0, vatRate: 20.0)

        // When
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        quote.items.append(item)

        // Then
        let expected = 750.0 * 5.0 * 1.20   // 4500 TL
        XCTAssertEqual(quote.grandTotal, expected, accuracy: 0.01,
            "5 adet × 750 TL × 1.20 KDV = 4500 TL olmalıdır.")
    }
}
