import Foundation

enum CableTrayKind: String, CaseIterable, Codable {
    case perforated = "Delikli sac tava"
    case solid = "Deliksiz sac tava"
    case cover = "Tava kapağı"
    case custom = "Özel sac profil"
    case ladder = "Merdiven tava"
    case mesh = "Tel sepet tava"
    var usesCatalog: Bool { self == .ladder || self == .mesh }
}

enum TrayCoatingBasis: String, CaseIterable, Codable {
    case none = "Yok / sac fiyatına dahil"
    case mass = "TL/kg"
    case area = "TL/m² (iki yüz toplamı)"
}

struct CableTrayInput {
    var kind: CableTrayKind = .perforated
    var ladderFabrication = false
    var railDevelopedCM: Double = 10
    var railThicknessMM: Double = 1.5
    var rungDevelopedCM: Double = 6
    var rungThicknessMM: Double = 1.5
    var rungLengthCM: Double = 30
    var rungCount: Int = 10
    var usesCatalog: Bool { kind.usesCatalog && !(kind == .ladder && ladderFabrication) }
    var widthCM: Double = 10
    var sideCM: Double = 4
    var returnCM: Double = 2
    var thicknessMM: Double = 0.8
    var customDevelopedCM: Double = 22
    var density: Double = 7850
    var catalogMassPerM: Double = 0
    var catalogSurfacePerM: Double = 0
    var catalogReference: String = ""
    var pieceLengthM: Double = 3
    var pieces: Int = 1
    var steelPricePerKG: Double = 55
    var coating: TrayCoatingBasis = .none
    var coatingPrice: Double = 0
    var laborPerM: Double = 0
    var markupPercent: Double = 0
    var vatRate: Double = 0.20

    var developedCM: Double {
        switch kind {
        case .cover: return widthCM + 2 * returnCM
        case .custom: return customDevelopedCM
        default: return widthCM + 2 * sideCM + 2 * returnCM
        }
    }
}

struct CableTrayResult {
    let input: CableTrayInput
    let massPerM: Double
    let surfacePerM: Double
    let metalCostPerM: Double
    let coatingCostPerM: Double
    var lengthM: Double { input.pieceLengthM * Double(input.pieces) }
    var costPerM: Double { metalCostPerM + coatingCostPerM + input.laborPerM }
    var salePerM: Double { costPerM * (1 + input.markupPercent / 100) }
    var totalMass: Double { massPerM * lengthM }
    var totalNet: Double { salePerM * lengthM }
    var totalVAT: Double { totalNet * input.vatRate }
    var totalGross: Double { totalNet + totalVAT }
    var title: String {
        if input.kind == .ladder && input.ladderFabrication {
            return "Kablo merdiveni — basamak \(input.rungLengthCM) cm, \(input.rungCount) adet / \(input.pieceLengthM) m"
        }
        if input.usesCatalog { return "\(input.kind.rawValue) — \(input.catalogReference)" }
        if input.kind == .custom { return "Özel sac profil — açınım \(input.developedCM) cm / \(input.thicknessMM) mm" }
        if input.kind == .cover { return "Tava kapağı — \(input.widthCM) cm / dönüş \(input.returnCM) cm / \(input.thicknessMM) mm" }
        return "\(input.kind.rawValue) — \(input.widthCM) × \(input.sideCM) cm / dönüş \(input.returnCM) cm / \(input.thicknessMM) mm"
    }
    var description: String {
        "\(input.pieces) adet × \(input.pieceLengthM) m; \(massPerM) kg/m. Kaplama: \(input.coating.rawValue), \(coatingCostPerM) TL/m. " +
        (input.kind == .ladder && input.ladderFabrication ? "İki yan: \(input.railDevelopedCM) cm açınım × \(input.railThicknessMM) mm; basamak: \(input.rungDevelopedCM) cm açınım × \(input.rungThicknessMM) mm × \(input.rungLengthCM) cm, \(input.rungCount) adet/parça. Delik, kaynak ve bağlantı ağırlığı hariç." : input.usesCatalog ? "Üretici ağırlığı kullanıldı." : "Yoğunluk: \(input.density) kg/m³; delik/fire ve büküm düzeltmesi uygulanmadı.")
    }
    var materialKey: String { title + description + String(costPerM) + String(salePerM) }
    var quoteItem: QuoteItem {
        QuoteItem(title: title, description: description, category: .material,
                  quantity: lengthM, unit: "m", unitPrice: salePerM, vatRate: input.vatRate)
    }
    var material: Material {
        Material(name: title, category: .conduit, unit: "m", purchasePrice: costPerM,
                 salePrice: salePerM, notes: description)
    }
}
