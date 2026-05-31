// ElectricianService.swift
// VoltAsist
//
// Elektrikçi hizmet kategorileri ve hizmet modeli.
// Her kategori için gerçekçi Türkçe hizmet örnekleri içerir.

import Foundation

// MARK: - Hizmet Kategorisi

/// Elektrikçinin sunduğu hizmet kategorileri
enum ServiceCategory: String, Codable, CaseIterable, Identifiable {
    case cableWiring    = "Kablo ve Tesisatçılık"
    case panelBreaker   = "Pano ve Sigorta"
    case lighting       = "Aydınlatma"
    case grounding      = "Topraklama"
    case socket         = "Priz ve Anahtar"
    case compensation   = "Reaktif Güç Kompanzasyonu"
    case solar          = "Güneş Enerjisi (Solar)"
    case maintenance    = "Bakım ve Arıza"

    var id: String { rawValue }

    /// SF Symbols ikonları
    var systemIcon: String {
        switch self {
        case .cableWiring:   return "cable.connector"
        case .panelBreaker:  return "square.grid.3x3.fill"
        case .lighting:      return "lightbulb.fill"
        case .grounding:     return "arrow.down.to.line"
        case .socket:        return "powerplug.fill"
        case .compensation:  return "waveform.path.ecg"
        case .solar:         return "sun.max.fill"
        case .maintenance:   return "wrench.and.screwdriver.fill"
        }
    }

    /// Kategori renk adı (Asset Catalog)
    var colorName: String {
        switch self {
        case .cableWiring:   return "CategoryCable"
        case .panelBreaker:  return "CategoryPanel"
        case .lighting:      return "CategoryLight"
        case .grounding:     return "CategoryGround"
        case .socket:        return "CategorySocket"
        case .compensation:  return "CategoryComp"
        case .solar:         return "CategorySolar"
        case .maintenance:   return "CategoryMaint"
        }
    }
}

// MARK: - Hizmet Modeli

/// Elektrikçinin sunduğu bir hizmet kalemi
struct ElectricianService: Codable, Identifiable {
    /// Benzersiz kimlik
    var id: UUID

    /// Hizmet başlığı (Türkçe)
    var title: String

    /// Hizmet açıklaması
    var description: String

    /// SF Symbols ikon adı
    var systemIcon: String

    /// Hizmet kategorisi
    var category: ServiceCategory

    /// Taban fiyat (TL) — malzeme hariç sadece işçilik
    var basePrice: Double

    /// Birim (adet, m, m², saat vb.)
    var unit: String

    /// Tahmini süre (saat)
    var estimatedHours: Double

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        systemIcon: String,
        category: ServiceCategory,
        basePrice: Double,
        unit: String = "adet",
        estimatedHours: Double = 1.0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.systemIcon = systemIcon
        self.category = category
        self.basePrice = basePrice
        self.unit = unit
        self.estimatedHours = estimatedHours
    }
}

// MARK: - Örnek Hizmetler

extension ElectricianService {

    /// Her kategori için gerçekçi örnek hizmetler
    static let samples: [ElectricianService] = [

        // MARK: Kablo ve Tesisatçılık
        ElectricianService(
            title: "Dahili Elektrik Tesisatı (Yeni)",
            description: "Yeni inşaat veya tadilat için komple iç elektrik tesisatı döşemesi. Boru ve kablo dahil.",
            systemIcon: "cable.connector",
            category: .cableWiring,
            basePrice: 350,
            unit: "m²",
            estimatedHours: 2.0
        ),
        ElectricianService(
            title: "NYM Kablo Döşeme",
            description: "Sıva altı boru içine veya sıva üstü NYM kablo döşeme ve bağlantı işlemi.",
            systemIcon: "cable.connector",
            category: .cableWiring,
            basePrice: 45,
            unit: "m",
            estimatedHours: 0.25
        ),
        ElectricianService(
            title: "Kablo Kanalı Montajı",
            description: "Kanal tipi kablo taşıyıcı montajı, içine kablo çekimi dahil.",
            systemIcon: "cable.connector",
            category: .cableWiring,
            basePrice: 60,
            unit: "m",
            estimatedHours: 0.3
        ),

        // MARK: Pano ve Sigorta
        ElectricianService(
            title: "Dağıtım Panosu Montajı (8 Devre)",
            description: "8 devreli kompakt dağıtım panosu montajı ve devreye alma. Sigorta ve kaçak akım röleleri dahil.",
            systemIcon: "square.grid.3x3.fill",
            category: .panelBreaker,
            basePrice: 1800,
            unit: "adet",
            estimatedHours: 4.0
        ),
        ElectricianService(
            title: "Sigorta Değişimi",
            description: "Mevcut tabloda sigorta değişimi veya ekleme. Tek devre başına fiyat.",
            systemIcon: "square.grid.3x3.fill",
            category: .panelBreaker,
            basePrice: 250,
            unit: "adet",
            estimatedHours: 0.5
        ),
        ElectricianService(
            title: "Kaçak Akım Rölesi (RCD) Montajı",
            description: "30 mA hassasiyetinde kaçak akım koruma rölesi montajı ve test.",
            systemIcon: "square.grid.3x3.fill",
            category: .panelBreaker,
            basePrice: 600,
            unit: "adet",
            estimatedHours: 1.0
        ),

        // MARK: Aydınlatma
        ElectricianService(
            title: "LED Aydınlatma Armatürü Montajı",
            description: "Panel LED armatür veya sıva altı downlight montajı. Elektrik bağlantısı dahil.",
            systemIcon: "lightbulb.fill",
            category: .lighting,
            basePrice: 150,
            unit: "adet",
            estimatedHours: 0.5
        ),
        ElectricianService(
            title: "Dış Mekan Aydınlatma Tesisatı",
            description: "Bahçe, cephe veya park aydınlatması için topraklı tesisat döşeme ve armatür montajı.",
            systemIcon: "lightbulb.fill",
            category: .lighting,
            basePrice: 500,
            unit: "adet",
            estimatedHours: 2.0
        ),
        ElectricianService(
            title: "Dimmer Anahtarı Montajı",
            description: "LED uyumlu dokunmatik veya döner dimmer anahtar montajı.",
            systemIcon: "lightbulb.fill",
            category: .lighting,
            basePrice: 280,
            unit: "adet",
            estimatedHours: 0.75
        ),

        // MARK: Topraklama
        ElectricianService(
            title: "Topraklama Tesisatı (Konut)",
            description: "Konut için PE iletkeni ve toprak hattı döşemesi, ölçüm ve sertifika.",
            systemIcon: "arrow.down.to.line",
            category: .grounding,
            basePrice: 2500,
            unit: "adet",
            estimatedHours: 6.0
        ),
        ElectricianService(
            title: "Toprak Direnci Ölçümü",
            description: "Mevcut topraklama sisteminin direnç ölçümü, rapor ve öneri.",
            systemIcon: "arrow.down.to.line",
            category: .grounding,
            basePrice: 800,
            unit: "adet",
            estimatedHours: 2.0
        ),
        ElectricianService(
            title: "Yıldırım Paratoner Sistemi",
            description: "Aktif iyonize paratoner montajı, inme iletkenli topraklama bağlantısı.",
            systemIcon: "arrow.down.to.line",
            category: .grounding,
            basePrice: 8500,
            unit: "adet",
            estimatedHours: 8.0
        ),

        // MARK: Priz ve Anahtar
        ElectricianService(
            title: "Topraklı Priz Montajı",
            description: "Sıva altı veya sıva üstü topraklı priz montajı. Kablo bağlantısı dahil.",
            systemIcon: "powerplug.fill",
            category: .socket,
            basePrice: 180,
            unit: "adet",
            estimatedHours: 0.5
        ),
        ElectricianService(
            title: "USB'li Akıllı Priz Montajı",
            description: "USB-A ve USB-C çıkışlı, akıllı enerji ölçümlü priz montajı.",
            systemIcon: "powerplug.fill",
            category: .socket,
            basePrice: 350,
            unit: "adet",
            estimatedHours: 0.75
        ),
        ElectricianService(
            title: "Kombi Anahtar Grubu Montajı",
            description: "2'li veya 3'lü kombi anahtar/priz grubu montajı.",
            systemIcon: "powerplug.fill",
            category: .socket,
            basePrice: 250,
            unit: "adet",
            estimatedHours: 0.75
        ),

        // MARK: Reaktif Güç Kompanzasyonu
        ElectricianService(
            title: "Sabit Kondansatör Montajı",
            description: "Tek hatlı sabit kondansatör grubu montajı ve devreye alma. TEDAŞ ceza önleme.",
            systemIcon: "waveform.path.ecg",
            category: .compensation,
            basePrice: 3500,
            unit: "adet",
            estimatedHours: 5.0
        ),
        ElectricianService(
            title: "Otomatik Kompanzasyon Panosu (AKP)",
            description: "Mikrodenetleyicili otomatik kademeli kompanzasyon panosu montajı, test ve komisyon.",
            systemIcon: "waveform.path.ecg",
            category: .compensation,
            basePrice: 18000,
            unit: "adet",
            estimatedHours: 16.0
        ),
        ElectricianService(
            title: "Harmonik Filtreli Reaktör Sistemi",
            description: "THD değerine göre %5.67/%7/%14 detuned reaktörlü filtreli kompanzasyon sistemi.",
            systemIcon: "waveform.path.ecg",
            category: .compensation,
            basePrice: 28000,
            unit: "adet",
            estimatedHours: 20.0
        ),

        // MARK: Güneş Enerjisi (Solar)
        ElectricianService(
            title: "Çatı Tipi GES Kurulumu (On-Grid)",
            description: "Şebeke bağlantılı çatı tipi güneş enerji sistemi kurulumu. Panel, inverter ve montaj dahil.",
            systemIcon: "sun.max.fill",
            category: .solar,
            basePrice: 12000,
            unit: "kWp",
            estimatedHours: 8.0
        ),
        ElectricianService(
            title: "Off-Grid Solar Sistem (Bataryalı)",
            description: "Bağımsız güneş enerjisi sistemi. Panel, inverter/şarj regülatörü ve batarya dahil.",
            systemIcon: "sun.max.fill",
            category: .solar,
            basePrice: 18000,
            unit: "kWp",
            estimatedHours: 12.0
        ),
        ElectricianService(
            title: "Solar Sistem Bakımı ve Temizliği",
            description: "Yıllık panel temizliği, bağlantı kontrolü, inverter yazılım güncelleme ve performans raporu.",
            systemIcon: "sun.max.fill",
            category: .solar,
            basePrice: 1200,
            unit: "adet",
            estimatedHours: 4.0
        ),

        // MARK: Bakım ve Arıza
        ElectricianService(
            title: "Elektrik Arıza Tespiti ve Onarım",
            description: "Termal kamera ve multimetre ile arıza tespiti, yerinde onarım. İlk 2 saat dahil.",
            systemIcon: "wrench.and.screwdriver.fill",
            category: .maintenance,
            basePrice: 600,
            unit: "adet",
            estimatedHours: 2.0
        ),
        ElectricianService(
            title: "Periyodik Elektrik Tesisatı Kontrolü",
            description: "Yıllık tesisatın genel durumu, yalıtım direnci ölçümü ve rapor.",
            systemIcon: "wrench.and.screwdriver.fill",
            category: .maintenance,
            basePrice: 1500,
            unit: "adet",
            estimatedHours: 3.0
        ),
        ElectricianService(
            title: "Termal Kamera Analizi",
            description: "Pano, kablo ve bağlantı noktalarının termal kamera ile sıcaklık analizi ve rapor.",
            systemIcon: "wrench.and.screwdriver.fill",
            category: .maintenance,
            basePrice: 2200,
            unit: "adet",
            estimatedHours: 4.0
        )
    ]
}
