// SolarCalculation.swift
// VoltAsist
//
// Güneş enerjisi sistemi boyutlandırma modeli.
// 81 Türk ili için gerçek PSH değerleri, panel/batarya/ekonomi hesabı.

import Foundation

// MARK: - Sistem Tipi

/// Güneş enerjisi sistemi bağlantı tipi
enum SolarSystemType: String, Codable, CaseIterable, Identifiable {
    case onGrid  = "Şebeke Bağlantılı (On-Grid)"
    case offGrid = "Bağımsız (Off-Grid)"
    case hybrid  = "Hibrit"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .onGrid:  return "antenna.radiowaves.left.and.right"
        case .offGrid: return "sun.max.fill"
        case .hybrid:  return "bolt.badge.clock.fill"
        }
    }

    var description: String {
        switch self {
        case .onGrid:
            return "Şebeke ile paralel çalışır. Fazla üretim şebekeye satılır (net metering). Batarya gerekmez."
        case .offGrid:
            return "Şebekeden bağımsız. Depolama için batarya zorunludur. Uzak lokasyonlar için idealdir."
        case .hybrid:
            return "Hem şebeke bağlantısı hem batarya içerir. Kesintisiz güç ve esneklik sağlar."
        }
    }
}

// MARK: - Batarya Tipi

/// Güneş enerji sisteminde kullanılan batarya teknolojisi
enum BatteryType: String, Codable, CaseIterable, Identifiable {
    case agm     = "AGM"
    case gel     = "Jel"
    case lifepo4 = "LiFePO4 (Lityum)"

    var id: String { rawValue }

    /// Deşarj Derinliği (DoD — Depth of Discharge)
    /// AGM/Jel: %50, LiFePO4: %80
    var dod: Double {
        switch self {
        case .agm:     return 0.50
        case .gel:     return 0.50
        case .lifepo4: return 0.80
        }
    }

    /// Şarj/Deşarj çevrim verimi
    var efficiency: Double {
        switch self {
        case .agm:     return 0.85
        case .gel:     return 0.85
        case .lifepo4: return 0.97
        }
    }

    /// Yaklaşık piyasa fiyatı (TL/kWh — 2024 yılı)
    var pricePerKWh: Double {
        switch self {
        case .agm:     return 4_500.0
        case .gel:     return 5_200.0
        case .lifepo4: return 9_500.0
        }
    }

    /// Beklenen ömür (yıl)
    var lifespanYears: Int {
        switch self {
        case .agm:     return 5
        case .gel:     return 7
        case .lifepo4: return 15
        }
    }

    /// Beklenen çevrim sayısı
    var cycleCount: Int {
        switch self {
        case .agm:     return 500
        case .gel:     return 800
        case .lifepo4: return 4000
        }
    }
}

// MARK: - Hesaplama Girişi

/// Solar sistem boyutlandırma için gerekli giriş parametreleri
struct SolarCalculationInput: Codable {
    /// Aylık elektrik tüketimi (kWh/ay) — fatura verisi
    var monthlyConsumptionKWh: Double

    /// Kurulum yapılacak il
    var city: TurkishCity

    /// Çatı eğim açısı (derece) — varsayılan 30°
    var roofTiltDeg: Double

    /// Çatı yönü (derece) — 0=Güney, 90=Batı, -90=Doğu
    var roofOrientationDeg: Double

    /// Sistem tipi
    var systemType: SolarSystemType

    /// Off-grid özerklik süresi (gün) — bu kadar bulutlu gün batarya besler
    var autonomyDays: Double

    /// Batarya tipi
    var batteryType: BatteryType

    /// Sistem gerilimi (V) — 12, 24 veya 48
    var systemVoltage: Int

    /// Net metering tarife (TL/kWh) — şebekeye satış fiyatı
    var feedInTariff: Double

    /// Satın alma elektrik fiyatı (TL/kWh)
    var electricityPrice: Double

    /// Kurulum maliyeti (TL/kWp) — panel+inverter+işçilik
    var installationCostPerKWp: Double

    init(
        monthlyConsumptionKWh: Double = 400.0,
        city: TurkishCity = .ankara,
        roofTiltDeg: Double = 30.0,
        roofOrientationDeg: Double = 0.0,
        systemType: SolarSystemType = .onGrid,
        autonomyDays: Double = 2.0,
        batteryType: BatteryType = .lifepo4,
        systemVoltage: Int = 48,
        feedInTariff: Double = 3.10,
        electricityPrice: Double = 4.50,
        installationCostPerKWp: Double = 25_000.0
    ) {
        self.monthlyConsumptionKWh = monthlyConsumptionKWh
        self.city = city
        self.roofTiltDeg = roofTiltDeg
        self.roofOrientationDeg = roofOrientationDeg
        self.systemType = systemType
        self.autonomyDays = autonomyDays
        self.batteryType = batteryType
        self.systemVoltage = systemVoltage
        self.feedInTariff = feedInTariff
        self.electricityPrice = electricityPrice
        self.installationCostPerKWp = installationCostPerKWp
    }

    var isValid: Bool {
        return monthlyConsumptionKWh > 0
            && electricityPrice > 0
            && installationCostPerKWp > 0
            && [12, 24, 48].contains(systemVoltage)
    }
}

// MARK: - Hesaplama Sonucu

/// Solar sistem boyutlandırma sonuçları
struct SolarCalculationResult: Codable {

    // MARK: Panel Sistemi

    /// Gerekli kurulu güç (kWp)
    var requiredCapacityKWp: Double

    /// Panel adedi (400 Wp = 0.4 kWp panel varsayılan)
    var panelCount: Int

    /// Gerekli çatı alanı (m²) — 400Wp panel 2.0 m²
    var roofAreaM2: Double

    /// Yıllık enerji üretimi (kWh/yıl)
    var annualProductionKWh: Double

    /// Özgül verim (kWh/kWp/yıl)
    var specificYield: Double

    // MARK: Batarya Sistemi

    /// Gerekli batarya kapasitesi (kWh)
    var batteryCapacityKWh: Double

    /// Gerekli batarya kapasitesi (Ah — sistem gerilimine göre)
    var batteryCapacityAh: Double

    /// 100Ah 12V batarya eşdeğeri adet (seri/paralel)
    var batteryCount: Int

    /// Batarya şarj akımı (A)
    var chargeCurrentA: Double

    // MARK: Ekonomik Analiz

    /// Toplam kurulum maliyeti (TL)
    var totalInvestmentTL: Double

    /// Yıllık elektrik tasarrufu (TL) — öz tüketim kısmı
    var annualSavingTL: Double

    /// Şebekeye verilen fazla üretim geliri (TL/yıl) — sadece On-Grid/Hybrid
    var annualGridIncomeTL: Double

    /// Yatırım geri ödeme süresi (yıl)
    var paybackYears: Double

    /// Yıllık CO₂ tasarrufu (ton/yıl) = kWh × 0.42 / 1000
    var co2SavingTonPerYear: Double

    /// 25 yıllık Net Bugünkü Değer (TL)
    var npcTL: Double

    /// 25 yıllık yıllık üretim dizisi (panel degredasyonuyla — yıl %0.5)
    var yearlyProduction: [Double]

    // MARK: İnverter

    /// Önerilen inverter gücü (kW)
    var inverterKW: Double

    /// DC/AC oranı
    var dcAcRatio: Double

    // MARK: Çatı Yönü Düzeltmesi

    /// Yön ve eğim düzeltme katsayısı (0.7–1.0)
    var orientationFactor: Double
}

// MARK: - Türk İlleri (81 İl) — PSH Değerleri

/// Türkiye'nin 81 ili ve her il için gerçekçi Tepe Güneş Saati (PSH) değerleri.
/// PSH: Günlük ortalama etkili güneşlenme süresi (saat/gün).
/// Kaynak: ETKB YEGM Güneş Atlası, Meteonorm, SolarGIS verileri (2023 yılı).
enum TurkishCity: String, Codable, CaseIterable, Identifiable {
    case adana      = "Adana"
    case adiyaman   = "Adıyaman"
    case afyon      = "Afyonkarahisar"
    case agri       = "Ağrı"
    case aksaray    = "Aksaray"
    case amasya     = "Amasya"
    case ankara     = "Ankara"
    case antalya    = "Antalya"
    case ardahan    = "Ardahan"
    case artvin     = "Artvin"
    case aydin      = "Aydın"
    case balikesir  = "Balıkesir"
    case bartin     = "Bartın"
    case batman     = "Batman"
    case bayburt    = "Bayburt"
    case bilecik    = "Bilecik"
    case bingol     = "Bingöl"
    case bitlis     = "Bitlis"
    case bolu       = "Bolu"
    case burdur     = "Burdur"
    case bursa      = "Bursa"
    case canakkale  = "Çanakkale"
    case cankiri    = "Çankırı"
    case corum      = "Çorum"
    case denizli    = "Denizli"
    case diyarbakir = "Diyarbakır"
    case duzce      = "Düzce"
    case edirne     = "Edirne"
    case elazig     = "Elazığ"
    case erzincan   = "Erzincan"
    case erzurum    = "Erzurum"
    case eskisehir  = "Eskişehir"
    case gaziantep  = "Gaziantep"
    case giresun    = "Giresun"
    case gumushane  = "Gümüşhane"
    case hakkari    = "Hakkari"
    case hatay      = "Hatay"
    case igdir      = "Iğdır"
    case isparta    = "Isparta"
    case istanbul   = "İstanbul"
    case izmir      = "İzmir"
    case kahramanmaras = "Kahramanmaraş"
    case karabuk    = "Karabük"
    case karaman    = "Karaman"
    case kars       = "Kars"
    case kastamonu  = "Kastamonu"
    case kayseri    = "Kayseri"
    case kilis      = "Kilis"
    case kirikkale  = "Kırıkkale"
    case kirklareli = "Kırklareli"
    case kirsehir   = "Kırşehir"
    case kocaeli    = "Kocaeli"
    case konya      = "Konya"
    case kutahya    = "Kütahya"
    case malatya    = "Malatya"
    case manisa     = "Manisa"
    case mardin     = "Mardin"
    case mersin     = "Mersin"
    case mugla      = "Muğla"
    case mus        = "Muş"
    case nevsehir   = "Nevşehir"
    case nigde      = "Niğde"
    case ordu       = "Ordu"
    case osmaniye   = "Osmaniye"
    case rize       = "Rize"
    case sakarya    = "Sakarya"
    case samsun     = "Samsun"
    case sanliurfa  = "Şanlıurfa"
    case siirt      = "Siirt"
    case sinop      = "Sinop"
    case sirnak     = "Şırnak"
    case sivas      = "Sivas"
    case tekirdag   = "Tekirdağ"
    case tokat      = "Tokat"
    case trabzon    = "Trabzon"
    case tunceli    = "Tunceli"
    case usak       = "Uşak"
    case van        = "Van"
    case yalova     = "Yalova"
    case yozgat     = "Yozgat"
    case zonguldak  = "Zonguldak"

    var id: String { rawValue }

    /// Günlük ortalama Tepe Güneş Saati (PSH — saat/gün)
    /// ETKB YEGM Güneş Atlası + SolarGIS verileri
    var peakSunHours: Double {
        switch self {
        case .adana:         return 5.10  // Akdeniz, bol güneş
        case .adiyaman:      return 4.90  // Güneydoğu
        case .afyon:         return 4.60  // İç Batı Anadolu
        case .agri:          return 4.30  // Doğu — yüksek rakım, soğuk
        case .aksaray:       return 4.75  // İç Anadolu
        case .amasya:        return 4.30  // Karadeniz geçiş
        case .ankara:        return 4.70  // İç Anadolu başkent
        case .antalya:       return 5.50  // Türkiye'nin en yüksek PSH'si
        case .ardahan:       return 3.90  // Kuzey doğu — olumsuz iklim
        case .artvin:        return 3.80  // Karadeniz, dağlık
        case .aydin:         return 5.20  // Ege, güneşli
        case .balikesir:     return 4.70  // Ege iç
        case .bartin:        return 3.80  // Karadeniz kıyısı
        case .batman:        return 5.00  // Güneydoğu
        case .bayburt:       return 4.00  // Doğu Karadeniz dağlık
        case .bilecik:       return 4.30  // Marmara iç
        case .bingol:        return 4.50  // Doğu
        case .bitlis:        return 4.20  // Van gölü çevresi
        case .bolu:          return 4.00  // Batı Karadeniz
        case .burdur:        return 4.90  // Göller yöresi
        case .bursa:         return 4.40  // Marmara
        case .canakkale:     return 4.60  // Ege-Marmara geçiş
        case .cankiri:       return 4.40  // İç Anadolu kuzey
        case .corum:         return 4.40  // İç Anadolu
        case .denizli:       return 5.00  // Ege, güneşli
        case .diyarbakir:    return 5.10  // Güneydoğu, bol güneş
        case .duzce:         return 3.90  // Batı Karadeniz
        case .edirne:        return 4.50  // Trakya
        case .elazig:        return 4.80  // Doğu Anadolu
        case .erzincan:      return 4.40  // Doğu — vadili
        case .erzurum:       return 4.20  // Doğu — yüksek plato
        case .eskisehir:     return 4.50  // İç Anadolu
        case .gaziantep:     return 5.10  // Güneydoğu, güneşli
        case .giresun:       return 3.70  // Karadeniz, bulutlu
        case .gumushane:     return 4.10  // Doğu Karadeniz
        case .hakkari:       return 4.50  // Güneydoğu dağlık
        case .hatay:         return 5.20  // Akdeniz kıyısı
        case .igdir:         return 4.70  // Aras vadisi, güneşli
        case .isparta:       return 4.85  // Göller yöresi
        case .istanbul:      return 4.20  // Marmara, şehir gölgesi
        case .izmir:         return 5.30  // Ege kıyısı, çok güneşli
        case .kahramanmaras: return 5.00  // Akdeniz-Güneydoğu geçiş
        case .karabuk:       return 3.90  // Batı Karadeniz dağlık
        case .karaman:       return 4.90  // İç Anadolu güneyi
        case .kars:          return 4.00  // Kuzeydoğu, soğuk
        case .kastamonu:     return 4.00  // Kuzey İç Anadolu
        case .kayseri:       return 4.70  // İç Anadolu, Erciyes
        case .kilis:         return 5.20  // Güney sınır, çok güneşli
        case .kirikkale:     return 4.65  // Ankara çevresi
        case .kirklareli:    return 4.40  // Trakya
        case .kirsehir:      return 4.70  // İç Anadolu
        case .kocaeli:       return 4.10  // Marmara doğu
        case .konya:         return 4.90  // İç Anadolu, güneşli düzlük
        case .kutahya:       return 4.55  // İç Batı Anadolu
        case .malatya:       return 4.85  // Doğu Anadolu güneşli
        case .manisa:        return 5.00  // Ege iç
        case .mardin:        return 5.10  // Güneydoğu, bol güneş
        case .mersin:        return 5.30  // Akdeniz kıyısı
        case .mugla:         return 5.40  // Ege-Akdeniz, çok güneşli
        case .mus:           return 4.30  // Doğu
        case .nevsehir:      return 4.75  // Kapadokya, İç Anadolu
        case .nigde:         return 4.80  // İç Anadolu
        case .ordu:          return 3.70  // Karadeniz, bulutlu
        case .osmaniye:      return 5.10  // Akdeniz-Güneydoğu
        case .rize:          return 3.50  // En yağışlı il, en az güneş
        case .sakarya:       return 4.00  // Marmara doğu
        case .samsun:        return 3.80  // Orta Karadeniz
        case .sanliurfa:     return 5.30  // Güneydoğu, çok güneşli
        case .siirt:         return 5.00  // Güneydoğu
        case .sinop:         return 3.80  // Karadeniz kıyısı
        case .sirnak:        return 5.00  // Güneydoğu
        case .sivas:         return 4.50  // İç Anadolu
        case .tekirdag:      return 4.40  // Trakya
        case .tokat:         return 4.30  // Orta Karadeniz geçiş
        case .trabzon:       return 3.70  // Doğu Karadeniz, bulutlu
        case .tunceli:       return 4.40  // Doğu dağlık
        case .usak:          return 4.80  // İç Batı Anadolu
        case .van:           return 4.50  // Doğu — Van gölü
        case .yalova:        return 4.10  // Marmara
        case .yozgat:        return 4.55  // İç Anadolu
        case .zonguldak:     return 3.80  // Karadeniz kıyısı
        }
    }

    /// Bölgesel İklim Bölgesi
    var climateZone: String {
        switch self {
        case .antalya, .mersin, .hatay, .adana, .mugla, .aydin, .izmir, .kilis, .osmaniye:
            return "Akdeniz"
        case .istanbul, .kocaeli, .sakarya, .bursa, .yalova, .tekirdag, .edirne,
             .kirklareli, .canakkale, .balikesir:
            return "Marmara"
        case .trabzon, .rize, .giresun, .ordu, .samsun, .sinop, .zonguldak, .bartin,
             .bolu, .duzce, .artvin, .giresun:
            return "Karadeniz"
        case .erzurum, .kars, .ardahan, .agri, .igdir, .van, .mus, .bitlis,
             .hakkari, .siirt, .sirnak, .batman, .mardin, .diyarbakir, .sanliurfa,
             .gaziantep, .adiyaman, .kahramanmaras, .malatya, .elazig, .bingol,
             .tunceli, .erzincan, .bayburt, .gumushane:
            return "Doğu/Güneydoğu"
        default:
            return "İç Anadolu"
        }
    }

    /// Yıllık toplam güneşlenme saati (saat/yıl)
    var annualSunHours: Double {
        return peakSunHours * 365.0
    }
}
