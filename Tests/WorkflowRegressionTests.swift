import XCTest
import UIKit
@testable import VoltAsist

final class WorkflowRegressionTests: XCTestCase {
    func testSolarInclusivePricesSurviveQuoteConversion() {
        // Same prices displayed by the solar bill of materials, with mixed VAT.
        let lines: [(Double, Double, Double)] = [(12, 2200, 0.10), (50, 36, 0.20), (1, 1200, 0.20)]
        let items = lines.map { quantity, gross, vat in
            QuoteItem(title: "Solar", category: .material, quantity: quantity, unit: "adet",
                unitPrice: QuoteItem.netUnitPrice(includingVAT: gross, vatRate: vat), vatRate: vat)
        }
        XCTAssertEqual(items.reduce(0) { $0 + $1.totalPrice }, 29400, accuracy: 0.001)
    }

    func testCatalogDeletionAndCustomPricesSurviveRelaunch() throws {
        let suite = "VoltAsistTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceService(defaults: defaults)
        var material = try XCTUnwrap(store.materials.first)
        material.salePrice = 12345
        material.stockQuantity = 7
        store.saveMaterial(material)
        let deleted = try XCTUnwrap(store.materials.last)
        XCTAssertNotEqual(material.id, deleted.id)
        store.deleteMaterial(id: deleted.id)
        let reopened = PersistenceService(defaults: defaults)
        XCTAssertNil(reopened.materials.first { $0.id == deleted.id })
        let restored = try XCTUnwrap(reopened.materials.first { $0.id == material.id })
        XCTAssertEqual(restored.salePrice, 12345)
        XCTAssertEqual(restored.stockQuantity, 7)
        for item in reopened.materials { reopened.deleteMaterial(id: item.id) }
        XCTAssertTrue(PersistenceService(defaults: defaults).materials.isEmpty)
    }

    func testInvalidCatalogIsNotOverwrittenDuringStartup() throws {
        let suite = "VoltAsistTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = Data("invalid json".utf8)
        defaults.set(original, forKey: "voltasist_materials_v1")
        _ = PersistenceService(defaults: defaults)
        XCTAssertEqual(defaults.data(forKey: "voltasist_materials_v1"), original)
    }

    func testStepPlansCoverDemandWithinRelayLimit() {
        for demand in [0.3, 6, 33, 44, 68, 87, 122, 133, 400] {
            let plan = CompensationEngine.selectCapacitorSteps(totalQcKVAr: demand, maximumSteps: 6)
            XCTAssertGreaterThanOrEqual(plan.reduce(0) { $0 + $1.totalKVAr }, demand)
            XCTAssertLessThanOrEqual(plan.reduce(0) { $0 + $1.quantity }, 6)
            XCTAssertTrue(plan.allSatisfy { CompensationEngine.standardStepRatings.contains($0.ratingKVAr) })
        }
        XCTAssertTrue(CompensationEngine.selectCapacitorSteps(totalQcKVAr: 601, maximumSteps: 6).isEmpty)
        XCTAssertTrue(CompensationEngine.selectCapacitorSteps(totalQcKVAr: .infinity).isEmpty)
    }

    func testProgressivePlanAvoidsLargeBlindZone() {
        let plan = CompensationEngine.selectCapacitorSteps(totalQcKVAr: 44, maximumSteps: 6)
        let ratings = plan.flatMap { Array(repeating: $0.ratingKVAr, count: $0.quantity) }
        XCTAssertLessThanOrEqual(CompensationEngine.maximumReachableGap(ratings), 10)
    }

    func testEditedStepsRecomputeDependentResults() throws {
        let input = CompensationInput(activePowerKW: 100, apparentPowerKVA: 125,
            measuredCosPhi: 0.8, transformerKVA: 50, totalHarmonicDistortion: 3)
        let steps = [CapacitorStep(ratingKVAr: 10, quantity: 5)]
        let result = try CompensationEngine.calculate(input: input, selectedSteps: steps)
        XCTAssertEqual(result.totalInstalledKVAr, 50)
        XCTAssertEqual(result.stepCount, 5)
        XCTAssertEqual(result.stepSizeKVAr, 10)
        XCTAssertEqual(result.contactorCurrentA, 20.6402721235, accuracy: 0.0001)
        // 50 kVA / 6% / 50 kVAr -> 204.124 Hz, outside the engine proximity bands.
        XCTAssertEqual(result.resonanceFrequencyHz, 204.1241452, accuracy: 0.001)
        XCTAssertFalse(result.reactorRequired)
        XCTAssertThrowsError(try CompensationEngine.calculate(input: input,
            selectedSteps: [CapacitorStep(ratingKVAr: 5, quantity: 6)]))
    }

    func testLowTHDReactorRecommendationUsesInstalledCapacity() throws {
        let input = CompensationInput(activePowerKW: 100, apparentPowerKVA: 125,
            measuredCosPhi: 0.8, transformerKVA: 75, totalHarmonicDistortion: 3)
        let result = try CompensationEngine.calculate(input: input,
            selectedSteps: [CapacitorStep(ratingKVAr: 10, quantity: 5)])
        // 50 * sqrt((75 / 0.06) / 50) = 250 Hz.
        XCTAssertEqual(result.resonanceFrequencyHz, 250, accuracy: 0.001)
        XCTAssertTrue(result.reactorRequired)
        XCTAssertEqual(result.recommendedReactorFactor, 0.0567)
    }
    func testPhotoSaveReturnsNilWhenDestinationIsNotDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1]).write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        XCTAssertNil(PhotoStorageService.save(image: image, entityID: UUID(), storageRoot: root))
    }

    func testCompensationQuoteUsesEnteredCosts() throws {
        let input = CompensationInput(activePowerKW: 100, apparentPowerKVA: 125,
            measuredCosPhi: 0.8, transformerKVA: 75, totalHarmonicDistortion: 3)
        let result = try CompensationEngine.calculate(input: input,
            selectedSteps: [CapacitorStep(ratingKVAr: 10, quantity: 5)])
        let items = QuoteEngine.itemsFromCompensation(result,
            costs: (cap: 7500, con: 4000, reactor: 10000, panel: 6000, labor: 4950))
        XCTAssertEqual(items.reduce(0) { $0 + $1.netPrice }, 32450, accuracy: 0.001)
        XCTAssertEqual(items.reduce(0) { $0 + $1.totalPrice }, 38940, accuracy: 0.001)
    }

}
