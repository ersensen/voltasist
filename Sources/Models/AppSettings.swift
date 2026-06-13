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
    var companyName: String
    var ownerName: String
    var phone: String
    var email: String
    var address: String
    var taxNumber: String?
    var city: TurkishCity

    // MARK: Fiyatlandırma
    var laborRatePerHour: Double
    var defaultVatRate: Double
    var electricityUnitPrice: Double
    var tedasPenaltyTariff: Double
    var feedInTariff: Double
    var installationCostPerKWp: Double

    // MARK: Hesaplama Varsayılanları
    var defaultTargetCosPhi: Double
    var defaultVoltageDrop: Double
    var defaultDemandFactor: Double
    var defaultCosPhi: Double

    // MARK: Teklif Ayarları
    var quoteValidityDays: Int
    var nextQuoteNumber: Int
    var quotePrefix: String
    var defaultQuoteNote: String?
    var quoteExpiryReminderDays: Int
    var appTheme: String

    // MARK: Lisans
    var isProLicenseActive: Bool
    var licenseExpiryDate: Date?

    // MARK: Alias Properties (SettingsViewModel uyumluluğu)
    var defaultVATRate: Double {
        get { defaultVatRate }
        set { defaultVatRate = newValue }
    }

    var defaultValidityDays: Int {
        get { quoteValidityDays }
        set { quoteValidityDays = newValue }
    }

    // MARK: Hesaplanan Değerler
    var formattedNextQuoteNumber: String {
        let year = Calendar.current.component(.year, from: Date())
        return String(format: "%@-%d-%03d", quotePrefix, year, nextQuoteNumber)
    }

    // MARK: Varsayılan Ayarlar
    static var defaultSettings: AppSettings {
        AppSettings(
            companyName: "VoltAsist Elektrik",
            ownerName: "Elektrik Ustası",
            phone: "0555 000 00 00",
            email: "info@voltasist.com",
            address: "Türkiye",
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
            defaultQuoteNote: "Bu teklif malzeme hariç işçilik bedeli içermektedir.",
            quoteExpiryReminderDays: 3,
            appTheme: "system",
            isProLicenseActive: false,
            licenseExpiryDate: nil
        )
    }

    init(
        companyName: String = "VoltAsist Elektrik",
        ownerName: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
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
        licenseExpiryDate: Date? = nil
    ) {
        self.companyName = companyName
        self.ownerName = ownerName
        self.phone = phone
        self.email = email
        self.address = address
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
    }
}
