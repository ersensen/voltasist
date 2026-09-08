import Foundation

enum CableTrayEngine {
    enum InputError: LocalizedError {
        case invalid
        var errorDescription: String? { "Ölçüleri ve fiyatları kontrol edin. Uzunluk, kalınlık ve ağırlık pozitif; fiyatlar sıfır veya pozitif olmalıdır." }
    }

    static func calculate(_ input: CableTrayInput) throws -> CableTrayResult {
        let positive = [input.pieceLengthM]
        let nonnegative = [input.steelPricePerKG, input.coatingPrice, input.laborPerM, input.markupPercent, input.vatRate]
        guard positive.allSatisfy({ $0.isFinite && $0 > 0 }),
              nonnegative.allSatisfy({ $0.isFinite && $0 >= 0 }),
              input.pieces > 0, input.vatRate <= 1 else { throw InputError.invalid }
        let mass: Double
        let surface: Double
        if input.kind == .ladder && input.ladderFabrication {
            guard [input.railDevelopedCM, input.railThicknessMM, input.rungDevelopedCM,
                   input.rungThicknessMM, input.rungLengthCM, input.density].allSatisfy({ $0.isFinite && $0 > 0 }),
                  input.rungCount > 0 else { throw InputError.invalid }
            let railVolume = 2 * input.railDevelopedCM / 100 * input.railThicknessMM / 1000 * input.pieceLengthM
            let rungVolume = input.rungDevelopedCM / 100 * input.rungThicknessMM / 1000 * input.rungLengthCM / 100 * Double(input.rungCount)
            mass = (railVolume + rungVolume) * input.density / input.pieceLengthM
            surface = (4 * input.railDevelopedCM / 100 * input.pieceLengthM +
                       2 * input.rungDevelopedCM / 100 * input.rungLengthCM / 100 * Double(input.rungCount)) / input.pieceLengthM
        } else if input.usesCatalog {
            guard input.catalogMassPerM.isFinite, input.catalogMassPerM > 0,
                  !input.catalogReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InputError.invalid }
            mass = input.catalogMassPerM
            surface = input.catalogSurfacePerM
            if input.coating == .area {
                guard surface.isFinite, surface > 0 else { throw InputError.invalid }
            }
        } else {
            let dimensions = input.kind == .custom ? [input.customDevelopedCM] : [input.widthCM]
            guard dimensions.allSatisfy({ $0.isFinite && $0 > 0 }),
                  input.thicknessMM.isFinite, input.thicknessMM > 0,
                  input.density.isFinite, input.density > 0 else { throw InputError.invalid }
            if input.kind != .custom {
                guard input.returnCM.isFinite, input.returnCM >= 0 else { throw InputError.invalid }
                if input.kind != .cover {
                    guard input.sideCM.isFinite, input.sideCM > 0,
                          2 * input.returnCM <= input.widthCM else { throw InputError.invalid }
                }
            }
            mass = input.developedCM / 100 * input.thicknessMM / 1000 * input.density
            // Two broad faces; holes and narrow sheet edges are not adjusted.
            surface = 2 * input.developedCM / 100
        }
        let coating: Double
        switch input.coating {
        case .none: coating = 0
        case .mass: coating = mass * input.coatingPrice
        case .area: coating = surface * input.coatingPrice
        }
        let result = CableTrayResult(input: input, massPerM: mass, surfacePerM: surface,
            metalCostPerM: mass * input.steelPricePerKG, coatingCostPerM: coating)
        guard [result.massPerM, result.costPerM, result.salePerM, result.totalMass, result.totalGross].allSatisfy({ $0.isFinite }) else { throw InputError.invalid }
        return result
    }
}
