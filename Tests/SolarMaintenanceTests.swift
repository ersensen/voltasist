import XCTest
import PDFKit
@testable import VoltAsist

final class SolarMaintenanceTests: XCTestCase {
    func testLegacyRecordRemainsCompensation() throws {
        let data = try JSONEncoder().encode(MaintenanceRecord())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "solar")
        let restored = try JSONDecoder().decode(MaintenanceRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(restored.isSolar)
        XCTAssertEqual(restored.maintenanceTypeLabel, "Kompanzasyon")
    }

    func testSolarVisitUpdatesScheduleAndClosesFindingOnlyAfterExplicitOK() throws {
        let calendar = Calendar.current
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)))
        var record = MaintenanceRecord()
        record.solar = SolarMaintenanceSystem(installedKWp: 12, panelCount: 24, inverterInfo: "Test")
        record.installationDate = start
        record.checkPeriodMonths = 6
        var first = MaintenanceVisit.solarVisit()
        first.date = start
        first.items[0].status = .failure
        record.visits = [first]
        XCTAssertTrue(MaintenanceQueue.failures.includes(record))
        var next = MaintenanceVisit.solarVisit()
        next.date = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))
        record.visits.append(next)
        XCTAssertTrue(record.hasOpenFailures)
        for index in next.items.indices { next.items[index].status = .ok }
        record.visits[1] = next
        XCTAssertFalse(record.hasOpenFailures)
        let due = try XCTUnwrap(calendar.date(byAdding: .month, value: 6, to: next.date))
        XCTAssertEqual(record.nextCheckDate, due)
        XCTAssertTrue(MaintenanceQueue.today.includes(record, on: due))
        XCTAssertTrue(MaintenanceQueue.overdue.includes(record, on: calendar.date(byAdding: .day, value: 1, to: due)!))
        let restored = try JSONDecoder().decode(MaintenanceRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored.solar?.installedKWp, 12)
        XCTAssertEqual(restored.visits[1].items.first?.kind, .solarPanels)
    }

    func testInvalidMeasurementsCannotCompleteVisit() {
        var visit = MaintenanceVisit.solarVisit()
        for index in visit.items.indices { visit.items[index].status = .ok }
        XCTAssertTrue(visit.isComplete)
        visit.solarMeasurements = SolarMaintenanceMeasurements(dailyProductionKWh: -1)
        XCTAssertFalse(visit.isComplete)
        visit.solarMeasurements = SolarMaintenanceMeasurements(dailyProductionKWh: 0)
        XCTAssertTrue(visit.isComplete)
    }

    func testSolarPDFIncludesMeasurementsAndLongNotesAcrossPages() throws {
        var record = MaintenanceRecord()
        record.solar = SolarMaintenanceSystem(installedKWp: 10, panelCount: 20, inverterInfo: "Solar Inverter")
        var visit = MaintenanceVisit.solarVisit()
        visit.solarMeasurements = SolarMaintenanceMeasurements(dailyProductionKWh: 42)
        visit.overallNotes = String(repeating: "Bakım kontrol notu. ", count: 800) + "SON_NOT"
        record.visits = [visit]
        let pdf = try XCTUnwrap(PDFDocument(data: PDFService.generateSolarMaintenancePDF(record: record, settings: .defaultSettings)))
        XCTAssertGreaterThan(pdf.pageCount, 1)
        let text = try XCTUnwrap(pdf.string)
        XCTAssertTrue(text.contains("Solar Inverter"))
        XCTAssertTrue(text.contains("42.00 kWh"))
        // PDFKit may extract the underscore on a separate line, despite intact PDF content.
        let compactText = text.filter { !$0.isWhitespace }
        XCTAssertTrue(compactText.contains("SON_NOT"), "PDF ending (\(pdf.pageCount) pages): \(text.suffix(1000))")
        XCTAssertFalse(text.contains("cos φ"))
    }
}
