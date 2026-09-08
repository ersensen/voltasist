import SwiftUI

struct CableTrayCalculatorView: View {
    @EnvironmentObject private var persistence: PersistenceService
    @State private var kind: CableTrayKind = .perforated
    @State private var ladderFabrication = true
    @State private var coating: TrayCoatingBasis = .none
    @State private var values: [Field: String] = [:]
    @State private var reference = ""
    @State private var customerPicker = false
    @State private var pendingItem: QuoteItem?
    @State private var confirmation = false
    @State private var message = ""
    @State private var savedMaterialKey = ""
    @State private var initialized = false

    private var usesCatalog: Bool { kind.usesCatalog && !(kind == .ladder && ladderFabrication) }

    enum Field: String {
        case railDeveloped = "Tek yan taşıyıcı açınımı (cm)"
        case railThickness = "Yan taşıyıcı kalınlığı (mm)"
        case rungDeveloped = "Tek basamak profil açınımı (cm)"
        case rungThickness = "Basamak kalınlığı (mm)"
        case rungLength = "Basamak kesim boyu (cm)"
        case rungCount = "Bir merdivendeki basamak adedi"
        case width = "Taban genişliği (cm)"
        case side = "Tek yan yüksekliği (cm)"
        case lip = "Tek kenar dönüşü (cm)"
        case developed = "Toplam sac açınımı (cm)"
        case thickness = "Sac kalınlığı (mm)"
        case density = "Malzeme yoğunluğu (kg/m³)"
        case mass = "Üretici ağırlığı (kg/m)"
        case area = "Üretici kaplama yüzeyi (m²/m)"
        case length = "Bir parça boyu (m)"
        case pieces = "Parça adedi"
        case metal = "Sac / metal fiyatı (TL/kg)"
        case coatingRate = "Kaplama birim fiyatı"
        case labor = "İşçilik (TL/m)"
        case markup = "Maliyet üzerine kâr (%)"
        case vat = "KDV (%)"

        var initial: String {
            switch self {
            case .railDeveloped, .rungCount: return "10"
            case .railThickness, .rungThickness: return "1,5"
            case .rungDeveloped: return "6"
            case .rungLength: return "30"
            case .width: return "10"
            case .side: return "4"
            case .lip: return "2"
            case .developed: return "22"
            case .thickness: return "0,8"
            case .density: return "7850"
            case .length: return "3"
            case .pieces: return "1"
            case .metal: return "55"
            case .vat: return "20"
            default: return "0"
            }
        }
    }

    private func number(_ field: Field) throws -> Double {
        let text = values[field] ?? field.initial
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0 else { throw CableTrayEngine.InputError.invalid }
        return value
    }

    private var calculation: Result<CableTrayResult, Error> {
        Result {
            var input = CableTrayInput()
            input.kind = kind
            input.ladderFabrication = ladderFabrication
            if kind == .ladder && ladderFabrication {
                input.railDevelopedCM = try number(.railDeveloped)
                input.railThicknessMM = try number(.railThickness)
                input.rungDevelopedCM = try number(.rungDeveloped)
                input.rungThicknessMM = try number(.rungThickness)
                input.rungLengthCM = try number(.rungLength)
                input.density = try number(.density)
                let rungs = try number(.rungCount)
                guard rungs >= 1, rungs <= 10000, rungs.rounded() == rungs else { throw CableTrayEngine.InputError.invalid }
                input.rungCount = Int(rungs)
            } else if usesCatalog {
                input.catalogMassPerM = try number(.mass)
                input.catalogReference = reference
                if coating == .area { input.catalogSurfacePerM = try number(.area) }
            } else {
                input.thicknessMM = try number(.thickness)
                input.density = try number(.density)
                if kind == .custom {
                    input.customDevelopedCM = try number(.developed)
                } else {
                    input.widthCM = try number(.width)
                    input.returnCM = try number(.lip)
                    if kind != .cover { input.sideCM = try number(.side) }
                }
            }
            input.pieceLengthM = try number(.length)
            let count = try number(.pieces)
            guard count >= 1, count <= 100000, count.rounded() == count else { throw CableTrayEngine.InputError.invalid }
            input.pieces = Int(count)
            input.steelPricePerKG = try number(.metal)
            input.coating = coating
            if coating != .none { input.coatingPrice = try number(.coatingRate) }
            input.laborPerM = try number(.labor)
            input.markupPercent = try number(.markup)
            input.vatRate = try number(.vat) / 100
            return try CableTrayEngine.calculate(input)
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Kablo Tavası").font(.title2.bold())
                Text("Ağırlık, kaplama ve satış maliyeti")
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker("Tava tipi", selection: $kind) {
                    ForEach(CableTrayKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            geometrySection
            Section("Miktar") { field(.length); field(.pieces) }
            pricingSection
            switch calculation {
            case .success(let result): resultSection(result)
            case .failure:
                Section {
                    Text("Geçerli ölçü ve fiyat girin. Adet tam sayı, boy ve kalınlık pozitif olmalı. Katalog tiplerinde ürün adı ve kg/m gerekir.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                Text("Sac tiplerinde delik ve fire düşülmez; büküm yarıçapı düzeltmesi yapılmaz. İçe dönüşler açınıma dahildir. Kaplama yüzeyi iki geniş yüzün toplamıdır; ince kesit kenarları hariçtir. Hesap ağırlık ve maliyet içindir; taşıma kapasitesi veya askı aralığı seçmez.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .onAppear {
            if !initialized {
                values[.vat] = String(persistence.settings.defaultVatRate * 100)
                initialized = true
            }
        }
        .alert("Kablo Tavası", isPresented: $confirmation) { Button("Tamam", role: .cancel) {} } message: { Text(message) }
        .sheet(isPresented: $customerPicker) {
            CustomerPickerView { customer in
                if let item = pendingItem {
                    persistence.addItemsToQuote([item], forCustomer: customer)
                    pendingItem = nil
                    message = "Müşteri teklifine eklendi."
                    confirmation = true
                }
                customerPicker = false
            }.environmentObject(persistence)
        }
    }

    private var geometrySection: some View {
        Section("Ölçüler") {
            if kind == .ladder { Toggle("Ölçülerden imalat hesabı", isOn: $ladderFabrication) }
            if kind == .ladder && ladderFabrication {
                field(.railDeveloped); field(.railThickness)
                field(.rungDeveloped); field(.rungThickness)
                field(.rungLength); field(.rungCount)
                field(.density)
                Text("Örnek: 3 m boy, 30 cm basamak, 10 basamak. Yan açınım 10 cm ve basamak açınım 6 cm örnek varsayımlardır; üretim çizimine göre değiştirin. İki yan taşıyıcı hesaba dahildir. Basamak sayısı parça başınadır; uç yerleşimi nedeniyle otomatik türetilmez.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("Üretici örneği: OBO LCIS 60", destination: URL(string: "https://www.obo.com.tr/en-tr/products/cable-ladder-lcis-60-3-m-c30-ft-3000-300-no-1-5-6209723.html")!)
            } else if usesCatalog {
                TextField("Üretici / ürün kodu", text: $reference)
                field(.mass)
                Text("Bu tiplerde sac açınımı kullanılmaz. Ürüne ait kg/m değerini girin; kaplama dahil ağırlığı kullanıyorsanız kaplamayı ikinci kez eklemeyin.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if kind == .custom { field(.developed) }
                else {
                    field(.width)
                    if kind != .cover { field(.side) }
                    field(.lip)
                }
                field(.thickness)
                DisclosureGroup("Malzeme yoğunluğu") { field(.density) }
                Text("Çelik varsayılanı: 7850 kg/m³. Alüminyum veya farklı malzeme için yoğunluğu ve kg fiyatını değiştirin.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var pricingSection: some View {
        Section("Fiyatlandırma · KDV hariç giriş") {
            field(.metal)
            Picker("Kaplama", selection: $coating) {
                ForEach(TrayCoatingBasis.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if coating != .none { field(.coatingRate) }
            if coating == .area && usesCatalog { field(.area) }
            field(.labor)
            field(.markup)
            field(.vat)
        }
    }

    private func resultSection(_ result: CableTrayResult) -> some View {
        Section("Hesap sonucu") {
            if !usesCatalog && kind != .ladder { row("Sac açınımı", "\(result.input.developedCM.formatted()) cm") }
            row("Ağırlık", "\(result.massPerM.formatted(.number.precision(.fractionLength(3)))) kg/m")
            row("Metal maliyeti / m", result.metalCostPerM.currencyFormatted)
            row("Kaplama / m", result.coatingCostPerM.currencyFormatted)
            row("İşçilik / m", result.input.laborPerM.currencyFormatted)
            row("Toplam maliyet / m", result.costPerM.currencyFormatted)
            row("Kârlı satış / m (KDV hariç)", result.salePerM.currencyFormatted)
            row("Bir parça satış (KDV hariç)", (result.salePerM * result.input.pieceLengthM).currencyFormatted)
            row("Toplam uzunluk", "\(result.lengthM.formatted()) m")
            row("Toplam ağırlık", "\(result.totalMass.formatted(.number.precision(.fractionLength(3)))) kg")
            row("KDV hariç toplam", result.totalNet.currencyFormatted)
            row("KDV", result.totalVAT.currencyFormatted)
            row("KDV dahil toplam", result.totalGross.currencyFormatted)
            Button("Teklife ekle", systemImage: "doc.badge.plus") {
                if persistence.activeQuote != nil {
                    persistence.addItemToActiveQuote(result.quoteItem)
                    message = "Aktif teklife eklendi."
                    confirmation = true
                } else {
                    pendingItem = result.quoteItem
                    customerPicker = true
                }
            }
            Button("Malzeme kataloğuna kaydet", systemImage: "shippingbox") {
                persistence.saveMaterial(result.material)
                savedMaterialKey = result.materialKey
                message = "Metre birimiyle kaydedildi. Alış: maliyet; satış: kâr dahil, KDV hariç fiyat. Katalogdan teklif oluştururken genel KDV ayarı kullanılır."
                confirmation = true
            }.disabled(savedMaterialKey == result.materialKey)
        }
    }

    private func field(_ field: Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(field.rawValue).font(.subheadline)
            TextField(field.initial, text: Binding(get: { values[field] ?? field.initial }, set: { values[field] = $0 }))
                .keyboardType(.decimalPad).font(.body.monospacedDigit())
                .accessibilityLabel(field.rawValue)
        }.padding(.vertical, 3)
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).monospacedDigit() }
    }
}
