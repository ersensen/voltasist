import XCTest
import PDFKit
import UIKit
@testable import VoltAsist

final class QuotePrivacyTests: XCTestCase {
    func testLetterheadSettingsRoundTripAndLegacyCompatibility() throws {
        var settings = AppSettings.defaultSettings
        settings.companyLogoData = Data([1, 2, 3])
        settings.taxOffice = "Test Vergi Dairesi"
        settings.defaultVatRate = 0.01
        let encoded = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(restored.companyLogoData, settings.companyLogoData)
        XCTAssertEqual(restored.defaultVatRate, 0.01)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "companyLogoData")
        let oldSettings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldSettings.companyLogoData)
        XCTAssertEqual(oldSettings.taxOffice, settings.taxOffice)
    }

    func testBrandedQuoteIncludesLetterheadAndOnePercentVAT() throws {
        var settings = AppSettings.defaultSettings
        settings.companyName = "Test Firma"
        settings.address = "Test Adres"
        settings.taxOffice = "Test Dairesi"
        settings.taxNumber = "1234567890"
        settings.companyLogoData = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 40)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 40))
        }.pngData()
        var quote = QuoteEngine.newQuote(settings: settings)
        quote.notes = nil
        let item = QuoteItem(title: "Test", quantity: 1, unitPrice: 100, vatRate: 0.01)
        quote.items = [item]
        XCTAssertEqual(item.totalPrice, 101, accuracy: 0.001)
        let pdf = try XCTUnwrap(PDFDocument(data: PDFService.generateQuotePDF(quote: quote, settings: settings)))
        let text = try XCTUnwrap(pdf.string)
        for value in [settings.companyName, settings.address, settings.taxOffice, settings.taxNumber!] {
            XCTAssertTrue(text.contains(value))
        }
    }

    func testCustomerOutputsExcludeInternalMaterialInformation() throws {
        // Aynı satış fiyatında farklı alış fiyatları müşteri teklifini değiştirmemeli.
        for purchasePrice in [0.0, 100.0, 200.0] {
            let material = Material(name: "Test malzemesi", category: .conduit, unit: "m",
                                    purchasePrice: purchasePrice, salePrice: 150,
                                    notes: "INTERNAL_ONLY Kar Marjı %50")
            let item = material.toQuoteItem(quantity: 2, vatRate: 0.20)
            XCTAssertEqual(item.unitPrice, 150)
            XCTAssertEqual(item.totalPrice, 360, accuracy: 0.001)
            XCTAssertNil(item.description)
            XCTAssertEqual(material.purchasePrice, purchasePrice)
            XCTAssertEqual(material.marginPercent,
                           purchasePrice > 0 ? (150 - purchasePrice) / purchasePrice * 100 : 0,
                           accuracy: 0.001)

            var quote = QuoteEngine.newQuote(settings: .defaultSettings)
            quote.items = [item]
            quote.notes = nil
            let pdf = try XCTUnwrap(PDFDocument(data: PDFService.generateQuotePDF(
                quote: quote, settings: .defaultSettings)))
            let pdfText = try XCTUnwrap(pdf.string)
            XCTAssertTrue(pdfText.contains("Test malzemesi"))
            XCTAssertTrue(pdfText.contains("GENEL TOPLAM"))

            // Yazdırma ve dosya paylaşımı aynı PDF'i kullanır.
            let message = ShareService.whatsappMessage(for: quote)
            let encodedItem = String(decoding: try JSONEncoder().encode(item), as: UTF8.self)
            for output in [pdfText, message, encodedItem] {
                for privateField in ["INTERNAL_ONLY", "Kar Marjı", "Kâr Marjı", "purchasePrice", "marginPercent"] {
                    XCTAssertFalse(output.contains(privateField), "İç bilgi müşteri çıktısına sızdı: \(privateField)")
                }
            }
        }
    }
}
