// DefaultMaterialCatalog.swift
// VoltAsist
//
// Hazır örnek malzeme kataloğu — 2026 Türkiye piyasa fiyatları (KDV dahil).
// Malzeme listesi ilk açılışta boşsa bu katalog otomatik yüklenir.

import Foundation

// MARK: - DefaultMaterialCatalog

enum DefaultMaterialCatalog {

    static var all: [Material] {
        cables + switchgear + panelEquipment + lighting + solar + grounding + conduitAndConsumables
    }

    // MARK: Kablo & İletken (22 malzeme)

    static let cables: [Material] = [
        Material(
            name: "NYY 3×1.5mm² Güç Kablosu",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 52,   salePrice: 64,
            catalogCode: "NYY-3x1.5"
        ),
        Material(
            name: "NYY 3×2.5mm² Güç Kablosu",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 78,   salePrice: 95,
            catalogCode: "NYY-3x2.5"
        ),
        Material(
            name: "NYY 3×4mm² Güç Kablosu",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 122,  salePrice: 148,
            catalogCode: "NYY-3x4"
        ),
        Material(
            name: "NYY 3×6mm² Güç Kablosu",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 172,  salePrice: 210,
            catalogCode: "NYY-3x6"
        ),
        Material(
            name: "NYY 5×2.5mm² Güç Kablosu",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 122,  salePrice: 149,
            catalogCode: "NYY-5x2.5"
        ),
        Material(
            name: "NYY 4×10mm² Güç Kablosu",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 295,  salePrice: 360,
            catalogCode: "NYY-4x10"
        ),
        Material(
            name: "NYY 4×16mm² Güç Kablosu",
            brand: "Nexans",
            category: .cable, unit: "m",
            purchasePrice: 440,  salePrice: 540,
            catalogCode: "NYY-4x16"
        ),
        Material(
            name: "NYY 4×25mm² Güç Kablosu",
            brand: "Nexans",
            category: .cable, unit: "m",
            purchasePrice: 670,  salePrice: 820,
            catalogCode: "NYY-4x25"
        ),
        Material(
            name: "NYY 4×35mm² Güç Kablosu",
            brand: "Nexans",
            category: .cable, unit: "m",
            purchasePrice: 920,  salePrice: 1_125,
            catalogCode: "NYY-4x35"
        ),
        Material(
            name: "NHXMH 3×1.5mm² Halojensiz Kablo",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 94,   salePrice: 115,
            catalogCode: "NHXMH-3x1.5",
            notes: "Yangına dayanıklı, halojensiz"
        ),
        Material(
            name: "NHXMH 3×2.5mm² Halojensiz Kablo",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 130,  salePrice: 160,
            catalogCode: "NHXMH-3x2.5"
        ),
        Material(
            name: "NHXMH 3×4mm² Halojensiz Kablo",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 188,  salePrice: 230,
            catalogCode: "NHXMH-3x4"
        ),
        Material(
            name: "NHXMH 5×2.5mm² Halojensiz Kablo",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 208,  salePrice: 255,
            catalogCode: "NHXMH-5x2.5"
        ),
        Material(
            name: "NHXMH 5×4mm² Halojensiz Kablo",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 295,  salePrice: 360,
            catalogCode: "NHXMH-5x4"
        ),
        Material(
            name: "H05VV-F TTR 3×1.5mm² Kordon",
            brand: "Sarkuysan",
            category: .cable, unit: "m",
            purchasePrice: 24,   salePrice: 30,
            catalogCode: "TTR-3x1.5"
        ),
        Material(
            name: "H05VV-F TTR 3×2.5mm² Kordon",
            brand: "Sarkuysan",
            category: .cable, unit: "m",
            purchasePrice: 36,   salePrice: 44,
            catalogCode: "TTR-3x2.5"
        ),
        Material(
            name: "H05VV-F TTR 5×2.5mm² Kordon",
            brand: "Sarkuysan",
            category: .cable, unit: "m",
            purchasePrice: 53,   salePrice: 65,
            catalogCode: "TTR-5x2.5"
        ),
        Material(
            name: "H07RN-F Ağır Lastik Kablo 3×2.5mm²",
            brand: "Nexans",
            category: .cable, unit: "m",
            purchasePrice: 68,   salePrice: 83,
            catalogCode: "H07RNF-3x2.5",
            notes: "Şantiye / hareketli ekipman kablosu, IP44"
        ),
        Material(
            name: "NYA 1×2.5mm² Tek Damarlı (BYS)",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 11,   salePrice: 14,
            catalogCode: "NYA-1x2.5"
        ),
        Material(
            name: "NYA 1×4mm² Tek Damarlı (BYS)",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 16,   salePrice: 20,
            catalogCode: "NYA-1x4"
        ),
        Material(
            name: "NYA 1×6mm² Tek Damarlı (BYS)",
            brand: "Öznur",
            category: .cable, unit: "m",
            purchasePrice: 23,   salePrice: 28,
            catalogCode: "NYA-1x6"
        ),
        Material(
            name: "PV1-F Solar DC Kablo 4mm²",
            brand: "Prysmian",
            category: .cable, unit: "m",
            purchasePrice: 28,   salePrice: 34,
            catalogCode: "PV1F-4",
            notes: "UV dayanımlı, 1000V DC solar kablo"
        ),
    ]

    // MARK: Şalt & Kesici (13 malzeme)

    static let switchgear: [Material] = [
        Material(
            name: "Otomatik Sigorta 1P 6A B Eğri",
            brand: "Hager",
            category: .switchgear, unit: "adet",
            purchasePrice: 48,   salePrice: 59,
            catalogCode: "MBN106B"
        ),
        Material(
            name: "Otomatik Sigorta 1P 10A C Eğri",
            brand: "Schneider Electric",
            category: .switchgear, unit: "adet",
            purchasePrice: 61,   salePrice: 75,
            catalogCode: "A9F74110"
        ),
        Material(
            name: "Otomatik Sigorta 1P 16A C Eğri",
            brand: "Schneider Electric",
            category: .switchgear, unit: "adet",
            purchasePrice: 67,   salePrice: 82,
            catalogCode: "A9F74116"
        ),
        Material(
            name: "Otomatik Sigorta 2P 16A C Eğri",
            brand: "Hager",
            category: .switchgear, unit: "adet",
            purchasePrice: 118,  salePrice: 145,
            catalogCode: "MCN216C"
        ),
        Material(
            name: "Otomatik Sigorta 2P 25A C Eğri",
            brand: "Hager",
            category: .switchgear, unit: "adet",
            purchasePrice: 160,  salePrice: 195,
            catalogCode: "MCN225C"
        ),
        Material(
            name: "Otomatik Sigorta 3P 25A C Eğri",
            brand: "ABB",
            category: .switchgear, unit: "adet",
            purchasePrice: 245,  salePrice: 300,
            catalogCode: "S803C-C25"
        ),
        Material(
            name: "Otomatik Sigorta 3P 40A C Eğri",
            brand: "ABB",
            category: .switchgear, unit: "adet",
            purchasePrice: 310,  salePrice: 380,
            catalogCode: "S803C-C40"
        ),
        Material(
            name: "Otomatik Sigorta 3P 63A C Eğri",
            brand: "ABB",
            category: .switchgear, unit: "adet",
            purchasePrice: 415,  salePrice: 510,
            catalogCode: "S803C-C63"
        ),
        Material(
            name: "Kompakt Şalter (MCCB) 3P 100A",
            brand: "Schneider Electric",
            category: .switchgear, unit: "adet",
            purchasePrice: 1_960, salePrice: 2_400,
            catalogCode: "NSX100F-TM100D"
        ),
        Material(
            name: "Kompakt Şalter (MCCB) 3P 160A",
            brand: "Schneider Electric",
            category: .switchgear, unit: "adet",
            purchasePrice: 3_200, salePrice: 3_900,
            catalogCode: "NSX160F-TM160D"
        ),
        Material(
            name: "Kompakt Şalter (MCCB) 3P 250A",
            brand: "ABB",
            category: .switchgear, unit: "adet",
            purchasePrice: 5_800, salePrice: 7_100,
            catalogCode: "TMAX-T4N-250"
        ),
        Material(
            name: "Kaçak Akım Koruyucu 4P 40A 30mA",
            brand: "Legrand",
            category: .switchgear, unit: "adet",
            purchasePrice: 392,  salePrice: 480,
            catalogCode: "411675",
            notes: "RCCB, tip AC, 6kA"
        ),
        Material(
            name: "Yük Ayırıcı (Bıçaklı Sigorta) 3P 100A",
            brand: "Hager",
            category: .switchgear, unit: "adet",
            purchasePrice: 495,  salePrice: 605,
            catalogCode: "HFL100-3P",
            notes: "NH00 sigorta tabanı"
        ),
    ]

    // MARK: Pano & Ekipman (13 malzeme)

    static let panelEquipment: [Material] = [
        Material(
            name: "AC Kontaktör 9A 220V Bobin (LC1-D09)",
            brand: "Schneider Electric",
            category: .panel, unit: "adet",
            purchasePrice: 278,  salePrice: 340,
            catalogCode: "LC1D09M7"
        ),
        Material(
            name: "AC Kontaktör 18A 220V Bobin (LC1-D18)",
            brand: "Schneider Electric",
            category: .panel, unit: "adet",
            purchasePrice: 380,  salePrice: 465,
            catalogCode: "LC1D18M7"
        ),
        Material(
            name: "AC Kontaktör 32A 220V Bobin (LC1-D32)",
            brand: "Schneider Electric",
            category: .panel, unit: "adet",
            purchasePrice: 556,  salePrice: 680,
            catalogCode: "LC1D32M7"
        ),
        Material(
            name: "AC Kontaktör 65A 220V Bobin (LC1-D65)",
            brand: "Schneider Electric",
            category: .panel, unit: "adet",
            purchasePrice: 890,  salePrice: 1_090,
            catalogCode: "LC1D65M7"
        ),
        Material(
            name: "Termik Röle 6–10A (LRD14)",
            brand: "Schneider Electric",
            category: .panel, unit: "adet",
            purchasePrice: 241,  salePrice: 295,
            catalogCode: "LRD14"
        ),
        Material(
            name: "Faz Sırası Koruma Rölesi",
            brand: "ABB",
            category: .panel, unit: "adet",
            purchasePrice: 294,  salePrice: 360,
            catalogCode: "CM-PAS",
            notes: "3 faz kontrol, faz kesme + sıra hatalı"
        ),
        Material(
            name: "Dijital Zaman Rölesi Günlük 16A",
            brand: "Legrand",
            category: .panel, unit: "adet",
            purchasePrice: 178,  salePrice: 218,
            catalogCode: "ZR-16A-DIG",
            notes: "DIN ray tipi, 230V, 1 kanal"
        ),
        Material(
            name: "Dijital Voltmetre Panometre (DIN)",
            brand: "Generic",
            category: .panel, unit: "adet",
            purchasePrice: 215,  salePrice: 263,
            catalogCode: "DVM-72x72",
            notes: "72×72mm, 3 faz / tek faz seçilebilir"
        ),
        Material(
            name: "Dijital Ampermetre Panometre (DIN)",
            brand: "Generic",
            category: .panel, unit: "adet",
            purchasePrice: 235,  salePrice: 288,
            catalogCode: "DAM-72x72",
            notes: "72×72mm, CT girişli"
        ),
        Material(
            name: "DIN Ray 35mm TS (1m)",
            brand: "Generic",
            category: .panel, unit: "m",
            purchasePrice: 31,   salePrice: 38,
            catalogCode: "DIN35-1M"
        ),
        Material(
            name: "Kablo Kanalı Pano İçi 25×40mm (2m)",
            brand: "Hager",
            category: .panel, unit: "adet",
            purchasePrice: 53,   salePrice: 65,
            catalogCode: "VN425"
        ),
        Material(
            name: "3 Fazlı Bara Bağlantı Kiti 63A",
            brand: "Legrand",
            category: .panel, unit: "takım",
            purchasePrice: 159,  salePrice: 195,
            catalogCode: "004890"
        ),
        Material(
            name: "Akım Trafosu (CT) 100/5A Pano Tipi",
            brand: "Generic",
            category: .panel, unit: "adet",
            purchasePrice: 142,  salePrice: 174,
            catalogCode: "CT-100-5A",
            notes: "Panometre ve enerji sayaçları için"
        ),
    ]

    // MARK: Aydınlatma (16 malzeme)

    static let lighting: [Material] = [
        Material(
            name: "LED Panel Armatür 60×60 40W",
            brand: "Philips",
            category: .lighting, unit: "adet",
            purchasePrice: 392,  salePrice: 480,
            catalogCode: "RC048B-40W",
            notes: "4000K, 3600 lm, IP40, 595×595mm"
        ),
        Material(
            name: "LED Panel Armatür 120×30 36W",
            brand: "Hiled",
            category: .lighting, unit: "adet",
            purchasePrice: 298,  salePrice: 365,
            catalogCode: "LP120-36W",
            notes: "4000K, 3240 lm, IP40, sıva altı"
        ),
        Material(
            name: "LED Panel Armatür 30×30 18W",
            brand: "Hiled",
            category: .lighting, unit: "adet",
            purchasePrice: 192,  salePrice: 235,
            catalogCode: "LP30-18W",
            notes: "4000K, 1620 lm, IP40"
        ),
        Material(
            name: "LED Tüp T8 1200mm 18W",
            brand: "Osram",
            category: .lighting, unit: "adet",
            purchasePrice: 155,  salePrice: 190,
            catalogCode: "T8-1200-18W",
            notes: "4000K, 2100 lm, G13 duy"
        ),
        Material(
            name: "LED Tüp T8 600mm 9W",
            brand: "Osram",
            category: .lighting, unit: "adet",
            purchasePrice: 95,   salePrice: 116,
            catalogCode: "T8-600-9W",
            notes: "4000K, 1050 lm, G13 duy"
        ),
        Material(
            name: "LED Projektör 50W Dış Mekan (IP65)",
            brand: "Opple",
            category: .lighting, unit: "adet",
            purchasePrice: 362,  salePrice: 443,
            catalogCode: "FLD50-IP65",
            notes: "6500K, 5000 lm, IP65"
        ),
        Material(
            name: "LED Projektör 100W Dış Mekan",
            brand: "Opple",
            category: .lighting, unit: "adet",
            purchasePrice: 638,  salePrice: 780,
            catalogCode: "FLD100-IP65",
            notes: "6500K, IP65, 10000 lm"
        ),
        Material(
            name: "LED Projektör 200W Saha (IP65)",
            brand: "Hiled",
            category: .lighting, unit: "adet",
            purchasePrice: 1_350, salePrice: 1_650,
            catalogCode: "FLD200-IP65",
            notes: "6500K, 20000 lm, dış mekan"
        ),
        Material(
            name: "High Bay LED Armatür 150W (Depo)",
            brand: "Philips",
            category: .lighting, unit: "adet",
            purchasePrice: 1_120, salePrice: 1_370,
            catalogCode: "BY121P-150W",
            notes: "IP65, 19500 lm, endüstriyel depo"
        ),
        Material(
            name: "LED Downlight Sıva Altı 9W",
            brand: "Philips",
            category: .lighting, unit: "adet",
            purchasePrice: 80,   salePrice: 98,
            catalogCode: "DL-9W-SA",
            notes: "4000K, 820 lm, Ø90mm"
        ),
        Material(
            name: "LED Aplik 12W İç Mekan",
            brand: "Opple",
            category: .lighting, unit: "adet",
            purchasePrice: 122,  salePrice: 150,
            catalogCode: "APLIK-12W"
        ),
        Material(
            name: "Sızdırmaz Armatür IP65 36W LED",
            brand: "Hiled",
            category: .lighting, unit: "adet",
            purchasePrice: 344,  salePrice: 420,
            catalogCode: "WP36-IP65",
            notes: "Islak hacim / depo, 3600 lm"
        ),
        Material(
            name: "Acil Aydınlatma Armatürü 3 Saat",
            brand: "Legrand",
            category: .lighting, unit: "adet",
            purchasePrice: 588,  salePrice: 720,
            catalogCode: "ACL-3H",
            notes: "Ni-Cd batarya, 3 saat özerk çalışma"
        ),
        Material(
            name: "Yönlendirme (EXIT) Armatürü LED",
            brand: "Legrand",
            category: .lighting, unit: "adet",
            purchasePrice: 310,  salePrice: 380,
            catalogCode: "EXIT-LED-2H",
            notes: "2 saat pil, çift yönlü çıkış işareti"
        ),
        Material(
            name: "LED Sokak Armatürü 60W",
            brand: "Philips",
            category: .lighting, unit: "adet",
            purchasePrice: 1_512, salePrice: 1_850,
            catalogCode: "BRP102-60W",
            notes: "IP65, IK08, 7200 lm, 4000K"
        ),
        Material(
            name: "LED Şerit 12V 14.4W/m (5m Rulo)",
            brand: "Osram",
            category: .lighting, unit: "rulo",
            purchasePrice: 385,  salePrice: 472,
            catalogCode: "LST-1200-5M",
            notes: "3000K/4000K/6500K, IP20, SMD5050"
        ),
    ]

    // MARK: Solar Ekipman (14 malzeme)

    static let solar: [Material] = [
        Material(
            name: "Solar Panel Monokristal 400Wp",
            brand: "Canadian Solar",
            category: .solar, unit: "adet",
            purchasePrice: 1_800, salePrice: 2_200,
            catalogCode: "CS6R-400MS",
            notes: "Monoperce PERC, 1722×1134mm, 25 yıl garanti"
        ),
        Material(
            name: "Solar Panel Monokristal 550Wp",
            brand: "Canadian Solar",
            category: .solar, unit: "adet",
            purchasePrice: 2_400, salePrice: 2_930,
            catalogCode: "CS6R-550MS",
            notes: "Bifacial PERC, 2279×1134mm, 25 yıl garanti"
        ),
        Material(
            name: "On-Grid İnverter 3kW Tek Fazlı",
            brand: "Huawei",
            category: .solar, unit: "adet",
            purchasePrice: 12_000, salePrice: 14_650,
            catalogCode: "SUN2000-3KTL-M3"
        ),
        Material(
            name: "On-Grid İnverter 5kW Tek Fazlı",
            brand: "Huawei",
            category: .solar, unit: "adet",
            purchasePrice: 18_000, salePrice: 22_000,
            catalogCode: "SUN2000-5KTL-M3"
        ),
        Material(
            name: "On-Grid İnverter 10kW Üç Fazlı",
            brand: "Huawei",
            category: .solar, unit: "adet",
            purchasePrice: 31_000, salePrice: 38_000,
            catalogCode: "SUN2000-10KTL-M1"
        ),
        Material(
            name: "Off-Grid İnverter 3kW (Saf Sinüs)",
            brand: "Growatt",
            category: .solar, unit: "adet",
            purchasePrice: 9_500, salePrice: 11_600,
            catalogCode: "SPF3000TL-HVM",
            notes: "MPPT şarj kontrol dahil, 24V sistem"
        ),
        Material(
            name: "Hibrit İnverter 5kW",
            brand: "Growatt",
            category: .solar, unit: "adet",
            purchasePrice: 23_000, salePrice: 28_000,
            catalogCode: "SPH5000TL3-BH-UP"
        ),
        Material(
            name: "LiFePO4 Batarya 100Ah / 12V",
            brand: "CATL",
            category: .solar, unit: "adet",
            purchasePrice: 8_600, salePrice: 10_500,
            catalogCode: "LFP100-12V",
            notes: "≥4000 çevrim, BMS dahil"
        ),
        Material(
            name: "LiFePO4 Batarya 200Ah / 12V",
            brand: "CATL",
            category: .solar, unit: "adet",
            purchasePrice: 16_000, salePrice: 19_500,
            catalogCode: "LFP200-12V",
            notes: "≥4000 çevrim, BMS dahil"
        ),
        Material(
            name: "Solar Alüminyum Montaj Rayı 3.4m",
            brand: "Generic",
            category: .solar, unit: "adet",
            purchasePrice: 210,  salePrice: 257,
            catalogCode: "ALU-RAY-3400",
            notes: "35×35mm eloksal alüminyum profil"
        ),
        Material(
            name: "Solar Çatı Kancası Alüminyum",
            brand: "Generic",
            category: .solar, unit: "adet",
            purchasePrice: 110,  salePrice: 135,
            catalogCode: "CATI-KANCA-ALU",
            notes: "Kiremit / trapez çatı uyumlu"
        ),
        Material(
            name: "MC4 Solar Konnektör Çifti",
            brand: "Generic",
            category: .solar, unit: "çift",
            purchasePrice: 28,   salePrice: 34,
            catalogCode: "MC4-PAIR",
            notes: "IP67, 1000V DC, 30A"
        ),
        Material(
            name: "DC String Sigorta + MC4 Tutucu",
            brand: "Generic",
            category: .solar, unit: "adet",
            purchasePrice: 135,  salePrice: 165,
            catalogCode: "DCFUSE-MC4-10A"
        ),
        Material(
            name: "DC Combiner Box / Junction Box 4 String",
            brand: "Generic",
            category: .solar, unit: "adet",
            purchasePrice: 475,  salePrice: 580,
            catalogCode: "JBOX-4S",
            notes: "IP65, 4 string giriş, sigorta dahil"
        ),
    ]

    // MARK: Topraklama (10 malzeme)

    static let grounding: [Material] = [
        Material(
            name: "Topraklama Elektrodu Ø14mm 1.5m",
            brand: "Generic",
            category: .grounding, unit: "adet",
            purchasePrice: 241,  salePrice: 295,
            catalogCode: "TE-14-150",
            notes: "Bakır kaplı çelik, IEC 62561-2"
        ),
        Material(
            name: "Toprak İletkeni NYY 1×16mm² Sarı/Yeşil",
            brand: "Öznur",
            category: .grounding, unit: "m",
            purchasePrice: 47,   salePrice: 58,
            catalogCode: "NYY-1x16-YG"
        ),
        Material(
            name: "Toprak İletkeni NYY 1×25mm² Sarı/Yeşil",
            brand: "Öznur",
            category: .grounding, unit: "m",
            purchasePrice: 72,   salePrice: 88,
            catalogCode: "NYY-1x25-YG"
        ),
        Material(
            name: "Topraklama Bakır Şeridi 25×3mm",
            brand: "Sarkuysan",
            category: .grounding, unit: "m",
            purchasePrice: 80,   salePrice: 98,
            catalogCode: "BS-25X3"
        ),
        Material(
            name: "Toprak Pabucu / Klemens 16mm²",
            brand: "Generic",
            category: .grounding, unit: "adet",
            purchasePrice: 14,   salePrice: 18,
            catalogCode: "KLEM-16-YG"
        ),
        Material(
            name: "Eşpotansiyel Topraklama Barası 12 Delik",
            brand: "Legrand",
            category: .grounding, unit: "adet",
            purchasePrice: 118,  salePrice: 145,
            catalogCode: "ESPO-BARA-12",
            notes: "Bakır nikel kaplı, DIN ray montaj"
        ),
        Material(
            name: "Parafudr (SPD) 3P+N Tip 2 — 40kA",
            brand: "Schneider Electric",
            category: .grounding, unit: "adet",
            purchasePrice: 1_420, salePrice: 1_740,
            catalogCode: "PRD40r-3P+N",
            notes: "Aşırı gerilim koruyucu, IEC 61643-11"
        ),
        Material(
            name: "Toprak Test Klemensi (Çatal Klemens)",
            brand: "Generic",
            category: .grounding, unit: "adet",
            purchasePrice: 42,   salePrice: 52,
            catalogCode: "TEST-KLEM-YG",
            notes: "Ölçüm bağlantısını kesintisiz kesmek için"
        ),
        Material(
            name: "Topraklama Komple Set",
            brand: "Generic",
            category: .grounding, unit: "set",
            purchasePrice: 1_554, salePrice: 1_900,
            catalogCode: "TSET-KOMPLE",
            notes: "Elektrot + iletken + klemens + bağlantı"
        ),
        Material(
            name: "İletken Bağlantı Kelepçesi Ø14mm Elektrot",
            brand: "Generic",
            category: .grounding, unit: "adet",
            purchasePrice: 35,   salePrice: 43,
            catalogCode: "KELPCE-14",
            notes: "Bakır, topraklama elektrotu bağlantısı"
        ),
    ]

    // MARK: Boru, Kanal & Sarf Malzemeleri (15 malzeme)

    static let conduitAndConsumables: [Material] = [
        Material(
            name: "Spiral Plastik Boru 16mm (LF)",
            brand: "Generic",
            category: .conduit, unit: "m",
            purchasePrice: 5,    salePrice: 7,
            catalogCode: "SPB-16"
        ),
        Material(
            name: "Spiral Plastik Boru 20mm (LF)",
            brand: "Generic",
            category: .conduit, unit: "m",
            purchasePrice: 7,    salePrice: 9,
            catalogCode: "SPB-20"
        ),
        Material(
            name: "Spiral Plastik Boru 32mm (LF)",
            brand: "Generic",
            category: .conduit, unit: "m",
            purchasePrice: 13,   salePrice: 16,
            catalogCode: "SPB-32"
        ),
        Material(
            name: "Metal Oluklu Boru 20mm (Galvaniz)",
            brand: "Generic",
            category: .conduit, unit: "m",
            purchasePrice: 18,   salePrice: 22,
            catalogCode: "MOB-20",
            notes: "Elektrikli galvaniz çelik boru"
        ),
        Material(
            name: "Metal Oluklu Boru 25mm (Galvaniz)",
            brand: "Generic",
            category: .conduit, unit: "m",
            purchasePrice: 24,   salePrice: 30,
            catalogCode: "MOB-25"
        ),
        Material(
            name: "PVC Kablo Kanalı 40×40mm",
            brand: "Hager",
            category: .conduit, unit: "m",
            purchasePrice: 47,   salePrice: 58,
            catalogCode: "KK-40X40"
        ),
        Material(
            name: "PVC Kablo Kanalı 60×60mm",
            brand: "Hager",
            category: .conduit, unit: "m",
            purchasePrice: 72,   salePrice: 88,
            catalogCode: "KK-60X60"
        ),
        Material(
            name: "Klemens 2.5mm² (12li Kutu)",
            brand: "Wago",
            category: .conduit, unit: "kutu",
            purchasePrice: 39,   salePrice: 48,
            catalogCode: "KLEM-2.5-12"
        ),
        Material(
            name: "Klemens 4mm² (12li Kutu)",
            brand: "Wago",
            category: .conduit, unit: "kutu",
            purchasePrice: 55,   salePrice: 68,
            catalogCode: "KLEM-4-12"
        ),
        Material(
            name: "Kablo Bağı Siyah 100mm (100'lü Paket)",
            brand: "Generic",
            category: .conduit, unit: "paket",
            purchasePrice: 24,   salePrice: 30,
            catalogCode: "KB-100-100"
        ),
        Material(
            name: "Kablo Bağı Siyah 200mm (100'lü Paket)",
            brand: "Generic",
            category: .conduit, unit: "paket",
            purchasePrice: 35,   salePrice: 43,
            catalogCode: "KB-200-100"
        ),
        Material(
            name: "Wago 221 Hızlı Bağlantı Klemens 5li",
            brand: "Wago",
            category: .conduit, unit: "adet",
            purchasePrice: 37,   salePrice: 45,
            catalogCode: "WAGO-221-5",
            notes: "3'e kadar kesit, 32A, levye kilidi"
        ),
        Material(
            name: "Elektrikçi İzole Bandı PVC (10m)",
            brand: "Generic",
            category: .conduit, unit: "rulo",
            purchasePrice: 12,   salePrice: 15,
            catalogCode: "IZOBANT-10M"
        ),
        Material(
            name: "Geçirgen Buji Seti (10 Adet Karışık)",
            brand: "Generic",
            category: .conduit, unit: "set",
            purchasePrice: 48,   salePrice: 59,
            catalogCode: "BUJI-KIT-10",
            notes: "Pano kablo girişi sızdırmazlık"
        ),
        Material(
            name: "Kablo Koruyucu Lastik Manşon Ø20mm",
            brand: "Generic",
            category: .conduit, unit: "adet",
            purchasePrice: 8,    salePrice: 10,
            catalogCode: "MANSON-20",
            notes: "Metal boru çıkış kenarı için"
        ),
    ]
}
