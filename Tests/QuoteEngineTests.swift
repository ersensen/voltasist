// QuoteEngineTests.swift
// VoltAsist — Birim Testleri
//
// QuoteEngine teklif toplam hesabı, iskonto uygulaması ve numara formatını doğrular.
// KDV dahil toplam, iskonto sonrası fiyat ve teklif numarası formatı test edilir.

import XCTest
@testable import VoltAsist

// MARK: - QuoteEngineTests

/// QuoteEngine teklif oluşturma, hesaplama ve format doğrulama test sınıfı.
final class QuoteEngineTests: XCTestCase {

    // MARK: - Yardımcı Fabrika Metotları

    /// Test için standart AppSettings oluşturur.
    private func makeSettings(quoteNumber: Int = 1) -> AppSettings {
        var s = AppSettings.defaultSettings
        s.companyName        = "Test Firma A.Ş."
        s.address             = "Test Caddesi No:1, İstanbul"   // companyAddress salt-okunur alias'tır (address'i döndürür)
        s.phone               = "0212 555 00 00"
        s.email               = "info@testfirma.com"
        s.taxNumber           = "1234567890"
        s.taxOffice            = "Kadıköy VD"
        s.defaultVatRate       = 0.20   // 0.20 = %20 (AppSettings fraksiyon olarak saklar)
        s.quoteValidityDays    = 30
        s.nextQuoteNumber      = quoteNumber
        return s
    }

    /// Birim fiyat ve KDV ile basit bir QuoteItem oluşturur.
    /// - Not: `vatRate` burada yüzde (ör. 20.0) olarak verilir; QuoteItem'ın
    ///   `description:` init'i >1 olan değerleri otomatik /100 normalize eder.
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
            category: .material
        )
    }

    // MARK: - Test 1: 3 Kalem × KDV%20 → Doğru Toplam

    /// 3 kalem: 1000 TL + 2000 TL + 500 TL = 3500 TL ara toplam
    /// KDV%20 → 700 TL KDV → Genel Toplam (grandTotal = subtotal + totalVAT) = 4200 TL
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

    /// Ara toplam 10.000 TL, KDV%18 → totalVAT = 1.800 TL → grandTotal (iskontosuz) = 11.800 TL
    /// %10 genel iskonto (discountPercent) uygulanınca:
    /// grandTotalAfterDiscount = grandTotal × (1 - 0.10) = 11.800 × 0.9 = 10.620 TL
    /// (Not: subtotal × (1-iskonto) × (1+KDV) ile grandTotal × (1-iskonto) matematiksel olarak
    /// aynı sonucu verir — çarpma işleminin değişme özelliği nedeniyle her iki sıralama da 10.620 TL'ye ulaşır.)
    func test_discountedQuote_10Percent_shouldReduceGrandTotalAfterDiscount() {
        // Given
        let settings = makeSettings()
        let items = [
            makeItem(description: "Solar Panel Grubu",   unitPrice: 5_000.0, vatRate: 18),
            makeItem(description: "İnverter",            unitPrice: 3_000.0, vatRate: 18),
            makeItem(description: "Montaj ve Kablolama", unitPrice: 2_000.0, vatRate: 18)
        ]
        // Ara toplam = 10.000 TL

        // When
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        for item in items { quote.items.append(item) }
        quote.discountPercent = 10.0  // %10 genel iskonto (discountRate salt-okunur alias'tır, ayarlanamaz)

        // Then
        let subtotal          = 10_000.0
        let vat                = subtotal * 0.18                 // 1.800 TL
        let expectedGrandTotal = subtotal + vat                    // 11.800 TL (iskontosuz)
        let expectedAfterDiscount = expectedGrandTotal * (1.0 - 0.10)  // 10.620 TL

        XCTAssertEqual(quote.grandTotal, expectedGrandTotal, accuracy: 0.01,
            "İskonto uygulanmadan önce genel toplam 11.800 TL (±0.01) olmalıdır.")
        XCTAssertEqual(quote.grandTotalAfterDiscount, expectedAfterDiscount, accuracy: 0.01,
            "%10 iskonto sonrası genel toplam 10.620 TL (±0.01) olmalıdır.")
        XCTAssertLessThan(quote.grandTotalAfterDiscount, 12_000.0,
            "İskontolu teklif 12.000 TL'den küçük olmalıdır.")
    }

    // MARK: - Test 3: Teklif Numarası Formatı — "{prefix}-{yıl}-{sıra}"

    /// Teklif numarası "{quotePrefix}-YYYY-NNN" formatında üretilmelidir.
    /// AppSettings.defaultSettings.quotePrefix gerçek değeri "VU"'dur (bkz. AppSettings.swift satır 147/179) — "VA" değil.
    /// Yıl güncel yıl, numara settings.nextQuoteNumber'dan gelmeli ve 3 hane sıfır dolgusu olmalı.
    func test_quoteNumber_shouldFollowPrefixYearSequenceFormat() {
        // Given
        var settings = makeSettings(quoteNumber: 1)
        settings.nextQuoteNumber = 1

        // When
        let quote = QuoteEngine.newQuote(customer: nil, settings: settings)

        // Then
        let currentYear = Calendar.current.component(.year, from: Date())
        let expectedPrefix = "\(settings.quotePrefix)-\(currentYear)-"

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

    /// 5 adet × 750 TL = 3750 TL ara toplam (netPrice) → KDV%20 = 750 TL (vatAmount) → grandTotal 4500 TL
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

    // MARK: - Test 7: Kısmi Tahsilat — Kalan Bakiye Hesabı

    /// 1000 TL × KDV%20 = 1200 TL grandTotal (iskonto yok, grandTotalAfterDiscount = grandTotal).
    /// 500 + 300 = 800 TL tahsil edilirse kalan bakiye 1200 - 800 = 400 TL olmalı, tam ödenmemiş sayılmalı.
    func test_partialPayments_shouldComputeCorrectRemainingBalance() {
        // Given
        let settings = makeSettings()
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        quote.items.append(makeItem(description: "Kablo Döşeme", unitPrice: 1_000.0, quantity: 1, vatRate: 20.0))

        // When
        quote.payments = [
            QuotePayment(amount: 500.0),
            QuotePayment(amount: 300.0)
        ]

        // Then
        XCTAssertEqual(quote.grandTotalAfterDiscount, 1_200.0, accuracy: 0.01,
            "İskonto uygulanmadığından grandTotalAfterDiscount, grandTotal ile aynı (1200 TL) olmalıdır.")
        XCTAssertEqual(quote.totalPaidTL, 800.0, accuracy: 0.01,
            "Tahsil edilen toplam 500 + 300 = 800 TL olmalıdır.")
        XCTAssertEqual(quote.remainingBalanceTL, 400.0, accuracy: 0.01,
            "Kalan bakiye 1200 - 800 = 400 TL olmalıdır.")
        XCTAssertFalse(quote.isFullyPaid,
            "Kalan bakiye pozitifken teklif tam ödenmiş sayılmamalıdır.")
    }

    // MARK: - Test 8: Tam Tahsilat ve Fazla Ödeme — Bakiye Negatife İnmemeli

    /// Tam tutar tahsil edilince kalan bakiye 0 ve isFullyPaid true olmalı.
    /// Fazladan ödeme yapılsa bile kalan bakiye negatife inmemeli (max(0, ...) ile sınırlı).
    func test_fullAndOverPayment_shouldMarkAsFullyPaidWithoutNegativeBalance() {
        // Given
        let settings = makeSettings()
        var quote = QuoteEngine.newQuote(customer: nil, settings: settings)
        quote.items.append(makeItem(description: "İnverter", unitPrice: 1_000.0, quantity: 1, vatRate: 20.0))
        // grandTotal = 1000 × 1.20 = 1200 TL

        // When — tam tutarın üzerinde ödeme (1200 + 300 fazla)
        quote.payments = [QuotePayment(amount: 1_500.0)]

        // Then
        XCTAssertEqual(quote.totalPaidTL, 1_500.0, accuracy: 0.01,
            "Tahsil edilen toplam, girilen ödeme tutarına eşit (1500 TL) olmalıdır.")
        XCTAssertEqual(quote.remainingBalanceTL, 0.0, accuracy: 0.01,
            "Fazla ödeme yapılsa da kalan bakiye negatife inmemeli, 0'da sınırlı kalmalıdır.")
        XCTAssertTrue(quote.isFullyPaid,
            "Tahsilat, genel toplamı karşılayıp aştığında teklif tam ödenmiş sayılmalıdır.")
    }
}
