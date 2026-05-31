// LoadEngine.swift
// VoltAsist
//
// Elektrik yük listesi hesaplama motoru.
// Toplam bağlı güç, talep gücü, enerji tüketimi, fatura ve CO₂ emisyonu.

import Foundation

// MARK: - Yük Hesaplama Motoru

/// Yük listesi analiz motoru — talep gücü, enerji ve fatura hesabı
struct LoadEngine {

    // MARK: Sabitler

    /// CO₂ emisyon faktörü (kgCO₂/kWh) — EPDK 2023 yılı Türkiye elektrik sistemi
    static let co2FactorKgPerKWh: Double = 0.42

    /// Hesaplama için referans şebeke gerilimi (V) — 3 faz
    static let referenceVoltageV: Double = 400.0

    /// Aylık gün sayısı — hesaplama için sabit
    static let daysPerMonth: Double = 30.0

    // MARK: Ana Hesaplama

    /// Yük listesi analizini gerçekleştir
    /// - Parameter input: Hesaplama girdi parametreleri
    /// - Returns: Hesaplama sonuçları
    static func calculate(input: LoadCalculationInput) -> LoadCalculationResult {
        guard !input.loads.isEmpty else {
            return emptyResult()
        }

        // --- 1. Toplam Bağlı Güç ---
        // P_toplam = Σ(P_i × adet_i)  [W]
        let totalConnectedW = input.loads.reduce(0.0) { sum, load in
            sum + (load.powerW * Double(load.quantity))
        }
        let totalConnectedKW = totalConnectedW / 1000.0

        // --- 2. Talep Gücü ---
        // P_talep = P_toplam × talep_faktörü  [kW]
        // Her yük için kendi talep faktörü varsa onu kullan, yoksa genel kullan
        let demandW = input.loads.reduce(0.0) { sum, load in
            let df = load.localDemandFactor ?? input.demandFactor
            return sum + (load.powerW * Double(load.quantity) * df)
        }
        let demandKW = demandW / 1000.0

        // --- 3. Görünür Güç ---
        // S = P / cos φ  [kVA]
        let cosPhi = max(0.1, min(input.cosPhi, 1.0))
        let apparentKVA = demandKW / cosPhi

        // --- 4. Reaktif Güç ---
        // Q = √(S² - P²)  [kVAr]
        let reactivePower = sqrt(max(0.0, apparentKVA * apparentKVA - demandKW * demandKW))

        // --- 5. Hat Akımı (3 Faz 400V) ---
        // I = S / (√3 × V)
        let currentA = (apparentKVA * 1000.0) / (sqrt(3.0) * referenceVoltageV)

        // --- 6. Aylık Enerji Tüketimi ---
        // kWh/ay = Σ(P_i × adet_i × saat_i × 30) / 1000
        let monthlyKWh = input.loads.reduce(0.0) { sum, load in
            let df = load.localDemandFactor ?? input.demandFactor
            return sum + (load.powerW * Double(load.quantity) * load.hoursPerDay * daysPerMonth * df / 1000.0)
        }

        // --- 7. Elektrik Faturası ---
        let monthlyBillTL = monthlyKWh * input.electricityUnitPrice
        let yearlyBillTL = monthlyBillTL * 12.0

        // --- 8. CO₂ Emisyonu ---
        // CO₂ (kg/yıl) = kWh/yıl × 0.42
        let yearlyKWh = monthlyKWh * 12.0
        let co2KgPerYear = yearlyKWh * co2FactorKgPerKWh

        // --- 9. Önerilen Ana Sigorta ---
        // Sigorta = hat akımı × 1.25 — yukarı standart değere yuvarlama
        let minFuse = currentA * 1.25
        let recommendedMainFuse = nextStandardFuse(for: minFuse)

        // --- 10. Kategori Dağılımı ---
        var categoryBreakdown: [String: Double] = [:]
        for load in input.loads {
            let df = load.localDemandFactor ?? input.demandFactor
            let kw = (load.powerW * Double(load.quantity) * df) / 1000.0
            categoryBreakdown[load.category.rawValue, default: 0.0] += kw
        }

        // --- 11. En Büyük Yük ---
        let largestLoad = input.loads.max(by: { a, b in
            (a.powerW * Double(a.quantity)) < (b.powerW * Double(b.quantity))
        })

        return LoadCalculationResult(
            totalConnectedKW: totalConnectedKW,
            demandKW: demandKW,
            apparentKVA: apparentKVA,
            reactiveKVAr: reactivePower,
            currentA: currentA,
            monthlyKWh: monthlyKWh,
            monthlyBillTL: monthlyBillTL,
            yearlyBillTL: yearlyBillTL,
            co2KgPerYear: co2KgPerYear,
            recommendedMainFuseA: recommendedMainFuse,
            categoryBreakdown: categoryBreakdown,
            largestLoadName: largestLoad?.name ?? "-",
            largestLoadKW: (largestLoad.map { $0.powerW * Double($0.quantity) } ?? 0.0) / 1000.0
        )
    }

    // MARK: Yük Ekleme Yardımcıları

    /// Verilen yük listesine yeni bir örnek yük kalemi ekle
    /// - Parameter name: Yük adı
    /// - Parameter powerW: Güç (W)
    /// - Returns: Hazır LoadItem
    static func makeLoadItem(name: String, powerW: Double, quantity: Int = 1,
                              hoursPerDay: Double = 8.0, category: LoadCategory = .other) -> LoadItem {
        return LoadItem(
            id: UUID(),
            name: name,
            powerW: powerW,
            quantity: quantity,
            hoursPerDay: hoursPerDay,
            localDemandFactor: nil,
            category: category
        )
    }

    /// Tipik ev/ofis yük listesi oluştur
    static func sampleResidentialLoads() -> [LoadItem] {
        return [
            makeLoadItem(name: "Aydınlatma (LED)",     powerW: 10,   quantity: 10, hoursPerDay: 5.0, category: .lighting),
            makeLoadItem(name: "Buzdolabı",             powerW: 150,  quantity: 1,  hoursPerDay: 8.0, category: .kitchen),
            makeLoadItem(name: "Çamaşır Makinesi",      powerW: 2000, quantity: 1,  hoursPerDay: 1.0, category: .other),
            makeLoadItem(name: "Klima (12.000 BTU)",    powerW: 1200, quantity: 1,  hoursPerDay: 6.0, category: .heating),
            makeLoadItem(name: "TV",                    powerW: 120,  quantity: 1,  hoursPerDay: 4.0, category: .office),
            makeLoadItem(name: "Bilgisayar + Monitör",  powerW: 300,  quantity: 1,  hoursPerDay: 8.0, category: .office),
            makeLoadItem(name: "Fırın (Elektrikli)",    powerW: 2500, quantity: 1,  hoursPerDay: 0.5, category: .kitchen),
            makeLoadItem(name: "Elektrikli Su Isıtıcı", powerW: 2000, quantity: 1,  hoursPerDay: 1.5, category: .heating)
        ]
    }

    // MARK: Yardımcı Fonksiyonlar

    /// Güç faktörü açısı (tan φ)
    static func tanPhi(cosPhi: Double) -> Double {
        let sinPhi = sqrt(max(0.0, 1.0 - cosPhi * cosPhi))
        return sinPhi / max(cosPhi, 0.001)
    }

    /// Standart sigorta değeri seçimi
    private static func nextStandardFuse(for minCurrentA: Double) -> Int {
        let fuseRatings = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400]
        return fuseRatings.first { Double($0) >= minCurrentA } ?? 400
    }

    /// Boş sonuç döndür (yük listesi boşsa)
    private static func emptyResult() -> LoadCalculationResult {
        return LoadCalculationResult(
            totalConnectedKW: 0, demandKW: 0, apparentKVA: 0,
            reactiveKVAr: 0, currentA: 0, monthlyKWh: 0,
            monthlyBillTL: 0, yearlyBillTL: 0, co2KgPerYear: 0,
            recommendedMainFuseA: 6, categoryBreakdown: [:],
            largestLoadName: "-", largestLoadKW: 0
        )
    }
}
