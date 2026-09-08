import XCTest
@testable import VoltAsist

final class CableTrayEngineTests: XCTestCase {
    func testLadderFabricationExample() throws {
        var input = CableTrayInput()
        input.kind = .ladder
        input.ladderFabrication = true
        input.vatRate = 0
        let result = try CableTrayEngine.calculate(input)
        // Two rails: 7.065 kg; ten rungs: 2.1195 kg per 3 m piece.
        XCTAssertEqual(result.totalMass, 9.1845, accuracy: 0.000001)
        XCTAssertEqual(result.massPerM, 3.0615, accuracy: 0.000001)
        XCTAssertEqual(result.totalNet, 505.1475, accuracy: 0.000001)
        input.pieces = 2
        XCTAssertEqual(try CableTrayEngine.calculate(input).totalMass, 18.369, accuracy: 0.000001)
        input.coating = .area
        input.coatingPrice = 10
        XCTAssertEqual(try CableTrayEngine.calculate(input).coatingCostPerM, 5.2, accuracy: 0.000001)
        input.rungCount = 0
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
    }

    func testUserExampleCentimetersAndMillimeters() throws {
        var input = CableTrayInput()
        input.vatRate = 0
        let result = try CableTrayEngine.calculate(input)
        // 0.22 m × 0.0008 m × 1 m × 7850 kg/m³
        XCTAssertEqual(input.developedCM, 22)
        XCTAssertEqual(result.massPerM, 1.3816, accuracy: 0.000001)
        XCTAssertEqual(result.metalCostPerM, 75.988, accuracy: 0.000001)
        XCTAssertEqual(result.totalMass, 4.1448, accuracy: 0.000001)
        XCTAssertEqual(result.totalNet, 227.964, accuracy: 0.000001)
    }

    func testCoatingMarkupVATAndQuoteStayConsistent() throws {
        var input = CableTrayInput()
        input.coating = .mass
        input.coatingPrice = 10
        input.laborPerM = 5
        input.markupPercent = 25
        input.pieces = 2
        let result = try CableTrayEngine.calculate(input)
        XCTAssertEqual(result.coatingCostPerM, 13.816, accuracy: 0.000001)
        XCTAssertEqual(result.costPerM, 94.804, accuracy: 0.000001)
        XCTAssertEqual(result.salePerM, 118.505, accuracy: 0.000001)
        XCTAssertEqual(result.totalGross, 853.236, accuracy: 0.000001)
        XCTAssertEqual(result.quoteItem.quantity, 6)
        XCTAssertEqual(result.quoteItem.totalPrice, result.totalGross, accuracy: 0.000001)
        XCTAssertEqual(result.material.purchasePrice, result.costPerM)
        XCTAssertEqual(result.material.salePrice, result.salePerM)
        XCTAssertEqual(result.material.marginPercent, 25, accuracy: 0.000001)
    }

    func testSurfaceCoatingUsesBothFaces() throws {
        var input = CableTrayInput()
        input.coating = .area
        input.coatingPrice = 100
        let result = try CableTrayEngine.calculate(input)
        XCTAssertEqual(result.surfacePerM, 0.44, accuracy: 0.000001)
        XCTAssertEqual(result.coatingCostPerM, 44, accuracy: 0.000001)
    }

    func testPerforatedWeightDoesNotSubtractHoles() throws {
        var input = CableTrayInput()
        let perforated = try CableTrayEngine.calculate(input)
        input.kind = .solid
        XCTAssertEqual(try CableTrayEngine.calculate(input).massPerM, perforated.massPerM)
    }

    func testCoverAndCustomProfileDevelopedWidths() throws {
        var input = CableTrayInput()
        input.kind = .cover
        XCTAssertEqual(input.developedCM, 14)
        XCTAssertEqual(try CableTrayEngine.calculate(input).massPerM, 0.8792, accuracy: 0.000001)
        input.kind = .custom
        input.customDevelopedCM = 50
        XCTAssertEqual(try CableTrayEngine.calculate(input).massPerM, 3.14, accuracy: 0.000001)
    }

    func testMeshAndLadderRequireCatalogInsteadOfSheetApproximation() throws {
        for kind in [CableTrayKind.mesh, .ladder] {
            var input = CableTrayInput()
            input.kind = kind
            XCTAssertThrowsError(try CableTrayEngine.calculate(input))
            input.catalogMassPerM = 2
            input.catalogReference = "Üretici ürün kodu"
            XCTAssertEqual(try CableTrayEngine.calculate(input).massPerM, 2)
            input.coating = .area
            input.coatingPrice = 20
            XCTAssertThrowsError(try CableTrayEngine.calculate(input))
            input.catalogSurfacePerM = 0.5
            XCTAssertEqual(try CableTrayEngine.calculate(input).coatingCostPerM, 10)
        }
    }

    func testInvalidInputsAndOverflowRejected() {
        var input = CableTrayInput()
        input.thicknessMM = 0
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.pieces = 0
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.returnCM = 6
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.steelPricePerKG = -1
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.vatRate = 20
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.density = .infinity
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
        input = CableTrayInput(); input.pieceLengthM = .greatestFiniteMagnitude
        XCTAssertThrowsError(try CableTrayEngine.calculate(input))
    }
}
