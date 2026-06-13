// AppSettings.swift
// VoltAsist
//
// Uygulama ayarları modeli.
// Firma bilgileri, fiyatlandırma parametreleri ve uygulama yapılandırması.

import Foundation

// MARK: - Uygulama Ayarları

/// VoltAsist uygulama geneli ayarlar
struct AppSettings: Codable {

    // MARK: Firma Bilgileri

    /// Firma adı veya serbest elektrikçi adı
    var companyName: String

    /// Yetkili kişi / usta adı
    var ownerName: String

    /// Telefon numarası
    var phone: String

    /// E-posta adresi
    var email: String

    /// Firma adresi
    var address: String

    /// Firma esas adresi (uyumluluk alias’ı — address ile aynı)
    var companyAddress: String { address }

    /// Vergi Dairesi (opsiyonel)
    var taxOffice: String

    /// Ödeme koşulları — PDF'te gösterilir
    var paymentTerms: String

    /// Vergi Kimlik Numarası (opsiyonel)
    var taxNumber: String?

    /// İl (konum tespiti için)
    var city: TurkishCity

    // MARK: Fiyatlandırma

    /// Saat başı işçilik ücreti (TL/saat)
    var laborRatePerHour: Double

    /// Varsayılan KDV oranı — 0.20 = %20
    var defaultVatRate: Double

    /// Elektrik birim fiyatı (TL/kWh) — müşteri tüketim hesabı için
    var electricityUnitPrice: Double

    /// TEDAŞ reaktif enerji ceza tarifesi (TL/kVArh)
    var tedasPenaltyTariff: Double

    /// Net metering tarife (TL/kWh) — solar gelir hesabı
    var feedInTariff: Double

    /// Solar sistem kurulum maliyeti (TL/kWp) — varsayılan fiyat
    var installationCostPerKWp: Double

    // MARK: Hesaplama Varsayılanları

    /// Varsayılan hedef güç faktörü — kompanzasyon hesabı için
    var defaultTargetCosPhi: Double

    /// Varsayılan gerilim düşüm limiti (%) — kablo hesabı için
    var defaultVoltageDrop: Double

    /// Varsayılan talep faktörü — yük hesabı için
    var defaultDemandFactor: Double

    /// Varsayılan güç faktörü — yük hesabı için
    var defaultCosPhi: Double

    // MARK: Teklif Ayarları

    /// Teklifin varsayılan geçerlilik süresi (gün)
    var quoteValidityDays: Int

    /// Bir sonraki teklif için sıra numarası
    var nextQuoteNumber: Int

    /// Teklif numarası ön eki — örn: "VU"
    var quotePrefix: String

    /// Varsayılan teklif notu
    var defaultQuoteNote: String?

    // MARK: Bildirim Ayarları

    /// Teklif süresi dolmadan kaç gün önce hatırlatma
    var quoteExpiryReminderDays: Int

    /// Uygulama teması — "system", "light", "dark"
    var appTheme: String

    // MARK: Lisans

    /// Pro lisansı etkin mi?
    var isProLicenseActive: Bool

    /// Lisans bitiş tarihi (opsiyonel)
    var licenseExpiryDate: Date?

    /// Acil arama numarası — Dashboard'daki Acil Ara butonunda kullanılır
    var emergencyPhone: String

    // MARK: Hesaplanan Değerler

    /// Teklif numarası formatı: "{prefix}-{yıl}-{3 basamak sıra}"
    var formattedNextQuoteNumber: String {
        let year = Calendar.current.component(.year, from: Date())
        return String(format: "%@-%d-%03d", quotePrefix, year, nextQuoteNumber)
    }

    // MARK: Varsayılan Ayarlar

    /// Gerçekçi varsayılan değerlerle önceden doldurulmuş ayarlar
    static var defaultSettings: AppSettings {
        AppSettings(
            companyName: "VoltAsist Elektrik",
            ownerName: "Elektrik Ustası",
            phone: "0555 000 00 00",
            email: "info@voltasist.com",
            address: "Türkiye",
            taxOffice: "Merkez Vergi Dairesi",
            paymentTerms: "Sipariş anında %50 peşin, teslimatta %50.",
            taxNumber: nil,
            city: .istanbul,
            laborRatePerHour: 450.0,
            defaultVatRate: 0.20,
            electricityUnitPrice: 4.50,
            tedasPenaltyTariff: 0.90,
            feedInTariff: 3.10,
            installationCostPerKWp: 25_000.0,
            defaultTargetCosPhi: 0.95,
            defaultVoltageDrop: 3.0,
            defaultDemandFactor: 0.80,
            defaultCosPhi: 0.85,
            quoteValidityDays: 30,
            nextQuoteNumber: 1,
            quotePrefix: "VU",
            defaultQuoteNote: "Bu teklif malzeme hariç işçilik bedeli içermektedir. Malzeme fiyatları piyasa koşullarına göre değişkenlik gösterebilir.",
            quoteExpiryReminderDays: 3,
            appTheme: "system",
            isProLicenseActive: false,
            licenseExpiryDate: nil,
            emergencyPhone: "0555 000 00 00"
        )
    }

    init(
        companyName: String = "VoltAsist Elektrik",
        ownerName: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        taxOffice: String = "Merkez Vergi Dairesi",
        paymentTerms: String = "Sipariş anında %50 peşin, teslimatta %50.",
        taxNumber: String? = nil,
        city: TurkishCity = .istanbul,
        laborRatePerHour: Double = 450.0,
        defaultVatRate: Double = 0.20,
        electricityUnitPrice: Double = 4.50,
        tedasPenaltyTariff: Double = 0.90,
        feedInTariff: Double = 3.10,
        installationCostPerKWp: Double = 25_000.0,
        defaultTargetCosPhi: Double = 0.95,
        defaultVoltageDrop: Double = 3.0,
        defaultDemandFactor: Double = 0.80,
        defaultCosPhi: Double = 0.85,
        quoteValidityDays: Int = 30,
        nextQuoteNumber: Int = 1,
        quotePrefix: String = "VU",
        defaultQuoteNote: String? = nil,
        quoteExpiryReminderDays: Int = 3,
        appTheme: String = "system",
        isProLicenseActive: Bool = false,
        licenseExpiryDate: Date? = nil,
        emergencyPhone: String = ""
    ) {
        self.companyName = companyName
        self.ownerName = ownerName
        self.phone = phone
        self.email = email
        self.address = address
        self.taxOffice = taxOffice
        self.paymentTerms = paymentTerms
        self.taxNumber = taxNumber
        self.city = city
        self.laborRatePerHour = laborRatePerHour
        self.defaultVatRate = defaultVatRate
        self.electricityUnitPrice = electricityUnitPrice
        self.tedasPenaltyTariff = tedasPenaltyTariff
        self.feedInTariff = feedInTariff
        self.installationCostPerKWp = installationCostPerKWp
        self.defaultTargetCosPhi = defaultTargetCosPhi
        self.defaultVoltageDrop = defaultVoltageDrop
        self.defaultDemandFactor = defaultDemandFactor
        self.defaultCosPhi = defaultCosPhi
        self.quoteValidityDays = quoteValidityDays
        self.nextQuoteNumber = nextQuoteNumber
        self.quotePrefix = quotePrefix
        self.defaultQuoteNote = defaultQuoteNote
        self.quoteExpiryReminderDays = quoteExpiryReminderDays
        self.appTheme = appTheme
        self.isProLicenseActive = isProLicenseActive
        self.licenseExpiryDate = licenseExpiryDate
        self.emergencyPhone = emergencyPhone
    }
}
