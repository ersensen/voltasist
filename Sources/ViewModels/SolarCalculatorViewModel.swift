// SolarCalculatorViewModel.swift
import Foundation
import Combine
import SwiftUI

final class SolarCalculatorViewModel: ObservableObject {

    @Published var input = SolarCalculationInput()
    @Published var result: SolarCalculationResult? = nil
    @Published var errorMessage: String? = nil
    @Published var selectedTab: Int = 0
    @Published var citySearchText: String = ""
    @Published var showResult: Bool = false

    init() {}

    func calculate() {
        errorMessage = nil
        showResult   = false
        do {
            let res = try SolarEngine.calculate(input: input)
            result = res
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showResult = true
            }
        } catch let error as CalculationError {
            errorMessage = error.localizedDescription
            result       = nil
        } catch {
            errorMessage = "Solar hesaplama hatası: \(error.localizedDescription)"
            result       = nil
        }
    }

    func addToQuote(quoteVM: QuoteViewModel) {
        guard let res = result else { return }

        let panelItem = QuoteItem(
            title: "Güneş Paneli Grubu — \(String(format: "%.2f", res.requiredCapacityKWp)) kWp",
            category: .material,
            quantity: res.requiredCapacityKWp,
            unit: "kWp",
            unitPrice: input.installationCostPerKWp * 0.55,
            vatRate: 0.20
        )
        quoteVM.addItem(panelItem)

        let inverterItem = QuoteItem(
            title: "\(input.systemType == .offGrid ? "Off-Grid İnverter" : "On-Grid İnverter") — \(String(format: "%.1f", res.requiredCapacityKWp)) kWp",
            category: .equipment,
            quantity: 1,
            unit: "Adet",
            unitPrice: inverterPrice(kwp: res.requiredCapacityKWp),
            vatRate: 0.20
        )
        quoteVM.addItem(inverterItem)

        if input.systemType != .onGrid && res.batteryCapacityKWh > 0 {
            let batItem = QuoteItem(
                title: "\(input.batteryType.rawValue) Batarya — \(String(format: "%.1f", res.batteryCapacityKWh)) kWh",
                category: .material,
                quantity: 1,
                unit: "Adet",
                unitPrice: res.batteryCapacityKWh * batteryUnitPrice(),
                vatRate: 0.20
            )
            quoteVM.addItem(batItem)
        }

        let mountItem = QuoteItem(
            title: "Çatı Montaj ve Kurulum",
            category: .labor,
            quantity: res.requiredCapacityKWp,
            unit: "kWp",
            unitPrice: input.installationCostPerKWp * 0.20,
            vatRate: 0.20
        )
        quoteVM.addItem(mountItem)
    }

    var filteredCities: [TurkishCity] {
        let query = citySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return TurkishCity.allCases }
        return TurkishCity.allCases.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.rawValue.lowercased().contains(query)
        }
    }

    var systemCapacityFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.2f kWp", res.requiredCapacityKWp)
    }

    var annualProductionFormatted: String {
        guard let res = result else { return "—" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        let str = fmt.string(from: NSNumber(value: res.annualProductionKWh)) ?? "0"
        return "\(str) kWh"
    }

    var paybackYearsFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f yıl", res.paybackYears)
    }

    var annualSavingsFormatted: String {
        guard let res = result else { return "—" }
        return formatCurrency(res.annualSavingTL)
    }

    var co2SavingsFormatted: String {
        guard let res = result else { return "—" }
        return String(format: "%.1f ton CO₂", res.co2SavingTonPerYear * 25)
    }

    var pshFormatted: String {
        String(format: "%.1f saat/gün", input.city.peakSunHours)
    }

    var systemTypeLabel: String {
        switch input.systemType {
        case .onGrid:  return "Şebeke Bağlantılı (On-Grid)"
        case .offGrid: return "Bağımsız (Off-Grid)"
        case .hybrid:  return "Hibrit"
        }
    }

    private func inverterPrice(kwp: Double) -> Double {
        switch kwp {
        case ..<5:    return 15_000
        case 5..<10:  return 25_000
        case 10..<20: return 45_000
        default:      return 80_000
        }
    }

    private func batteryUnitPrice() -> Double {
        switch input.batteryType {
        case .lifepo4: return 6_500
        case .agm:     return 2_800
        case .gel:     return 3_200
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencySymbol = "₺"
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "₺0"
    }
}
