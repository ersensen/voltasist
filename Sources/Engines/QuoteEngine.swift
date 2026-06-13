// QuoteEngine.swift
// VoltAsist
//
// Teklif oluşturma ve hesaplama motoru.
// Kablo, kompanzasyon ve solar hesap sonuçlarından otomatik teklif kalemleri üretir.

import Foundation

// MARK: - Teklif Hesaplama Motoru

/// Teklif oluşturma, kalem üretme ve özet hesaplama motoru
struct QuoteEngine {

    // MARK: - Kablo Hesabından Teklif Kalemleri

    /// Kablo kesiti hesaplama sonucundan standart teklif kalemleri oluştur
    /// - Parameters:
    ///   - result: CableEngine çıktısı
    ///   - lengthM: Kablo uzunluğu (m)
    ///   - conductorType: İletken tipi
    ///   - installationType: Döşeme tipi
    ///   - laborRatePerHour: Saat başı işçilik (TL)
    /// - Returns: Teklif kalemleri dizisi
    static func itemsFromCableCalculation(
        _ result: CableCalculationResult,
        lengthM: Double,
        conductorType: ConductorType = .copper,
        installationType: InstallationType = .inWall,
        laborRatePerHour: Double = 450.0
    ) -> [QuoteItem] {

        var items: [QuoteItem] = []
        let section = result.recommendedSectionMM2
        let conductorName = conductorType.rawValue

        // 1. Kablo malzemesi
        // NYM-J 3×n mm² kablo birim fiyatı (TL/m) — yaklaşık piyasa
        let cableUnitPrice = cablelPricePerMeter(sectionMM2: section, conductorType: conductorType)
        items.append(QuoteItem(
            title: "NYM-J \(conductorName) Kablo \(formatSection(section)) mm²",
            description: "IEC 60228 uyumlu PVC izoleli \(conductorName.lowercased()) kablo, 3 damarlı",
            category: .material,
            quantity: lengthM * 1.05,  // %5 fire payı
            unit: "m",
            unitPrice: cableUnitPrice,
            vatRate: 0.20
        ))

        // 2. PVC Boru (sıva altı montajda)
        if installationType == .inWall {
            let pipePrice = 4.50 + (section > 16 ? 3.0 : 0.0)
            items.append(QuoteItem(
                title: "PVC Koruge Boru Ø\(pipeSize(for: section)) mm",
                description: "Sıva altı kablo için esnek koruge boru",
                category: .material,
                quantity: lengthM * 1.05,
                unit: "m",
                unitPrice: pipePrice,
                vatRate: 0.20
            ))
        }

        // 3. Sigorta
        let fusePrice = fuseUnitPrice(amps: result.recommendedFuseA)
        items.append(QuoteItem(
            title: "MCB Otomat Sigorta \(result.recommendedFuseA)A C-Karakteristik",
            description: "IEC 60898 uyumlu minyatür devre kesici, \(result.recommendedFuseA)A",
            category: .material,
            quantity: 1,
            unit: "adet",
            unitPrice: fusePrice,
            vatRate: 0.20
        ))

        // 4. İşçilik — döşeme ve bağlantı
        let laborHours = lengthM * 0.25  // ortalama 4m/saat hız
        items.append(QuoteItem(
            title: "Kablo Döşeme ve Bağlantı İşçiliği",
            description: "\(Int(lengthM))m \(installationType.rawValue) döşeme, bağlantı ve test",
            category: .labor,
            quantity: laborHours,
            unit: "saat",
            unitPrice: laborRatePerHour,
            vatRate: 0.20
        ))

        return items
    }

    // MARK: - Kompanzasyon Sonucundan Teklif Kalemleri

    /// Kompanzasyon hesaplama sonucundan teklif kalemleri oluştur
    /// - Parameter result: CompensationEngine çıktısı
    /// - Returns: Teklif kalemleri dizisi
    static func itemsFromCompensation(_ result: CompensationResult) -> [QuoteItem] {
        var items: [QuoteItem] = []

        // 1. Kondansatör kademeleri
        for step in result.selectedSteps {
            let condUnitPrice = capacitorUnitPrice(kvar: step.ratingKVAr)
            items.append(QuoteItem(
                title: "Güç Kondansatörü \(formatKVAr(step.ratingKVAr)) kVAr",
                description: "440V AC, cylindrical, dry-type alüminyum folyo kondansatör",
                category: .material,
                quantity: Double(step.quantity),
                unit: "adet",
                unitPrice: condUnitPrice,
                vatRate: 0.20
            ))
        }

        // 2. Reaktör (gerekiyorsa)
        if result.reactorRequired {
            let reactorDesc = "Detuned reaktör %\(String(format: "%.2f", result.reactorRatingPercent)) — harmonik filtre"
            let reactorPrice = result.totalInstalledKVAr * 350.0  // ~350 TL/kVAr
            items.append(QuoteItem(
                title: "Harmonik Filtre Reaktörü \(formatKVAr(result.totalInstalledKVAr)) kVAr",
                description: reactorDesc,
                category: .material,
                quantity: 1,
                unit: "adet",
                unitPrice: reactorPrice,
                vatRate: 0.20
            ))
        }

        // 3. AKP panosu (otomatik ise)
        if result.stepCount > 1 {
            let panelPrice = 8000.0 + result.totalInstalledKVAr * 200.0
            items.append(QuoteItem(
                title: "Otomatik Kompanzasyon Panosu (AKP) \(formatKVAr(result.totalInstalledKVAr)) kVAr",
                description: "\(result.stepCount) kademeli, mikrodenetleyicili, \(result.panelSizeDescription)",
                category: .equipment,
                quantity: 1,
                unit: "adet",
                unitPrice: panelPrice,
                vatRate: 0.20
            ))
        }

        // 4. Kontaktör (her kademe için)
        let contactorPrice = contactorUnitPrice(amps: result.contactorCurrentA)
        items.append(QuoteItem(
            title: "Güç Kontaktörü \(Int(ceil(result.contactorCurrentA)))A",
            description: "3 kutuplu, kondansatör şarj sınırlayıcılı özel kontaktör",
            category: .material,
            quantity: Double(result.stepCount),
            unit: "adet",
            unitPrice: contactorPrice,
            vatRate: 0.20
        ))

        // 5. Montaj işçiliği
        let laborHours = 4.0 + Double(result.stepCount) * 1.5
        items.append(QuoteItem(
            title: "Kompanzasyon Sistemi Montaj İşçiliği",
            description: "Pano montajı, bağlantı, devreye alma ve ölçüm raporu",
            category: .labor,
            quantity: laborHours,
            unit: "saat",
            unitPrice: 500.0,  // Uzman elektrikçi
            vatRate: 0.20
        ))

        return items
    }

    // MARK: - Solar Sonucundan Teklif Kalemleri

    /// Solar hesaplama sonucundan teklif kalemleri oluştur
    /// - Parameters:
    ///   - result: SolarEngine çıktısı
    ///   - input: Solar hesaplama girişi
    /// - Returns: Teklif kalemleri dizisi
    static func itemsFromSolar(
        _ result: SolarCalculationResult,
        input: SolarCalculationInput
    ) -> [QuoteItem] {

        var items: [QuoteItem] = []

        // 1. Solar panel
        let panelUnitPrice = 3_500.0  // 400Wp panel yaklaşık TL
        items.append(QuoteItem(
            title: "Monokristal Solar Panel 400 Wp",
            description: "25 yıl güç garantili, IEC 61215 sertifikalı, ±2% güç toleransı",
            category: .material,
            quantity: Double(result.panelCount),
            unit: "adet",
            unitPrice: panelUnitPrice,
            vatRate: 0.10  // Yenilenebilir enerji — %10 KDV
        ))

        // 2. İnverter
        let inverterPrice = result.inverterKW * 4_500.0  // ~4.500 TL/kW
        items.append(QuoteItem(
            title: "On-Grid İnverter \(String(format: "%.1f", result.inverterKW)) kW",
            description: "MPPT, Wi-Fi izleme, IP65, IEC 62109 sertifikalı",
            category: .equipment,
            quantity: 1,
            unit: "adet",
            unitPrice: inverterPrice,
            vatRate: 0.10
        ))

        // 3. Batarya (off-grid/hybrid)
        if result.batteryCapacityKWh > 0 {
            let batteryUnitPrice = input.batteryType.pricePerKWh
            items.append(QuoteItem(
                title: "Batarya Paketi \(String(format: "%.1f", result.batteryCapacityKWh)) kWh (\(input.batteryType.rawValue))",
                description: "DoD %\(Int(input.batteryType.dod * 100)), çevrim ömrü \(input.batteryType.cycleCount) döngü",
                category: .material,
                quantity: result.batteryCapacityKWh,
                unit: "kWh",
                unitPrice: batteryUnitPrice,
                vatRate: 0.10
            ))
        }

        // 4. Çatı montaj sistemi
        let rackingPrice = Double(result.panelCount) * 450.0
        items.append(QuoteItem(
            title: "Çatı Montaj Sistemi (Alüminyum Profil)",
            description: "Galvaniz çatı kancaları, alüminyum ray sistemi, paslanmaz vida seti",
            category: .material,
            quantity: Double(result.panelCount),
            unit: "adet",
            unitPrice: 450.0,
            vatRate: 0.20
        ))

        // 5. DC/AC kablolama
        let cablePrice = result.roofAreaM2 * 35.0  // m² başına yaklaşık
        items.append(QuoteItem(
            title: "DC/AC Kablolama ve Bağlantı Malzemeleri",
            description: "Solar DC kablo 6mm², AC kablo, konektörler, koruyucular",
            category: .material,
            quantity: 1,
            unit: "lot",
            unitPrice: cablePrice,
            vatRate: 0.20
        ))

        // 6. Montaj işçiliği
        let laborHours = result.requiredCapacityKWp * 6.0  // 6 saat/kWp
        items.append(QuoteItem(
            title: "GES Kurulum İşçiliği",
            description: "Panel montajı, kablaj, devreye alma, şebeke bağlantısı ve YEKDEM başvurusu",
            category: .labor,
            quantity: laborHours,
            unit: "saat",
            unitPrice: 450.0,
            vatRate: 0.20
        ))

        // 7. İzleme sistemi
        items.append(QuoteItem(
            title: "Uzaktan İzleme ve Veri Kaydedici",
            description: "Wi-Fi/4G datalogger, bulut izleme, mobil uygulama erişimi — 5 yıl",
            category: .service,
            quantity: 1,
            unit: "adet",
            unitPrice: 2_500.0,
            vatRate: 0.20
        ))

        // Kullanılmayan değişken için
        _ = rackingPrice

        return items
    }

    // MARK: - Teklif Özeti Hesabı

    /// Teklif toplam değerlerini hesapla
    /// - Parameter quote: Teklif belgesi
    /// - Returns: (ara toplam, toplam KDV, genel toplam)
    static func calculateSummary(quote: Quote) -> (subtotal: Double, totalVAT: Double, grandTotal: Double) {
        let subtotal  = quote.subtotal
        let totalVAT  = quote.totalVAT
        let grandTotal = quote.grandTotalAfterDiscount
        return (subtotal, totalVAT, grandTotal)
    }

    // MARK: - Teklif Numarası Üretimi

    /// Otomatik artan teklif numarası oluştur
    /// Format: "{prefix}-{yıl}-{3 basamak sıra}" — örn: "VA-2024-001"
    /// - Parameters:
    ///   - sequence: Sıra numarası
    ///   - prefix: Teklif ön eki (varsayılan "VU")
    /// - Returns: Biçimlendirilmiş teklif numarası
    static func generateQuoteNumber(sequence: Int, prefix: String = "VU") -> String {
        let year = Calendar.current.component(.year, from: Date())
        return String(format: "%@-%d-%03d", prefix, year, sequence)
    }

    // MARK: - Boş Teklif Oluştur

    /// Yeni boş teklif belgesi oluştur
    /// - Parameters:
    ///   - sequence: Sıra numarası
    ///   - settings: Uygulama ayarları
    ///   - customer: Müşteri (opsiyonel)
    /// - Returns: Boş teklif belgesi
    static func createNewQuote(
        sequence: Int,
        settings: AppSettings,
        customer: Customer? = nil
    ) -> Quote {
        let validUntil = Calendar.current.date(
            byAdding: .day,
            value: settings.quoteValidityDays,
            to: Date()
        ) ?? Date()

        return Quote(
            id: UUID(),
            quoteNumber: generateQuoteNumber(sequence: sequence, prefix: settings.quotePrefix),
            customerId: customer?.id,
            customerName: customer?.name ?? "",
            customerPhone: customer?.phone ?? "",
            customerEmail: customer?.email,
            customerAddress: customer?.address ?? "",
            items: [],
            notes: settings.defaultQuoteNote,
            validUntil: validUntil,
            createdAt: Date(),
            status: .draft,
            discountPercent: 0.0
        )
    }

    // MARK: Yardımcı Fiyat Fonksiyonları

    /// Kablo birim fiyatı (TL/m) — kesit ve iletkene göre yaklaşık piyasa fiyatı
    private static func cablelPricePerMeter(sectionMM2: Double, conductorType: ConductorType) -> Double {
        let basePrice: Double
        switch sectionMM2 {
        case 1.5:  basePrice = 12.0
        case 2.5:  basePrice = 18.0
        case 4.0:  basePrice = 27.0
        case 6.0:  basePrice = 38.0
        case 10.0: basePrice = 58.0
        case 16.0: basePrice = 88.0
        case 25.0: basePrice = 130.0
        case 35.0: basePrice = 175.0
        case 50.0: basePrice = 240.0
        case 70.0: basePrice = 330.0
        case 95.0: basePrice = 440.0
        case 120.0: basePrice = 550.0
        case 150.0: basePrice = 680.0
        case 185.0: basePrice = 830.0
        case 240.0: basePrice = 1_070.0
        default:    basePrice = sectionMM2 * 4.5
        }
        // Alüminyum kablo bakıra göre %30 ucuz
        return conductorType == .aluminum ? basePrice * 0.70 : basePrice
    }

    /// Sigorta birim fiyatı (TL/adet)
    private static func fuseUnitPrice(amps: Int) -> Double {
        switch amps {
        case ...16:   return 45.0
        case 17...32: return 65.0
        case 33...63: return 120.0
        case 64...100: return 350.0
        case 101...200: return 800.0
        default:       return 1_500.0
        }
    }

    /// Kondansatör birim fiyatı (TL/adet)
    private static func capacitorUnitPrice(kvar: Double) -> Double {
        return 250.0 + kvar * 80.0  // Yaklaşık: sabit 250 TL + 80 TL/kVAr
    }

    /// Kontaktör birim fiyatı (TL/adet) — akıma göre
    private static func contactorUnitPrice(amps: Double) -> Double {
        switch amps {
        case ...25:   return 350.0
        case 26...50: return 550.0
        case 51...100: return 900.0
        default:       return 1_500.0
        }
    }

    /// Kesit değerini formatla
    private static func formatSection(_ section: Double) -> String {
        if section == section.rounded() {
            return String(Int(section))
        }
        return String(format: "%.1f", section)
    }

    /// kVAr değerini formatla
    private static func formatKVAr(_ kvar: Double) -> String {
        if kvar == kvar.rounded() {
            return String(Int(kvar))
        }
        return String(format: "%.1f", kvar)
    }

    /// Kablo kesitime göre PVC boru çapı
    private static func pipeSize(for section: Double) -> Int {
        switch section {
        case ..<4:   return 16
        case 4..<10: return 20
        case 10..<25: return 25
        case 25..<50: return 32
        case 50..<95: return 40
        default:      return 50
        }
    }
    /// Yeni boş teklif oluştur — ViewModel uyumlu API
    /// - Parameters:
    ///   - customer: Müşteri (opsiyonel)
    ///   - settings: Uygulama ayarları
    /// - Returns: Oluşturulan Quote
    static func newQuote(customer: Customer? = nil, settings: AppSettings) -> Quote {
        return createNewQuote(
            sequence: settings.nextQuoteNumber,
            settings: settings,
            customer: customer
        )
    }
}
