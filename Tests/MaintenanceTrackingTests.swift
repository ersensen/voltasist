import XCTest
import UIKit
@testable import VoltAsist

final class MaintenanceTrackingTests: XCTestCase {
    private func date(_ day: Int, month: Int = 1) -> Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: month, day: day, hour: 12))!
    }

    func testLegacyVisitWithoutCapacitorsStillDecodes() throws {
        let original = MaintenanceVisit.standard()
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "capacitors")
        let restored = try JSONDecoder().decode(MaintenanceVisit.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.capacitors)
        XCTAssertEqual(restored.items.count, 10)
    }

    func testCapacitorInspectionIsResetWithoutLosingIdentityOrConnection() {
        var capacitor = MaintenanceCapacitor(label: "K1-C1", connection: .l2Neutral, nominalKVAr: 2.5)
        capacitor.measuredKVAr = 1.5
        capacitor.status = .failure
        let next = capacitor.awaitingInspection
        XCTAssertEqual(next.id, capacitor.id)
        XCTAssertEqual(next.connection, .l2Neutral)
        XCTAssertEqual(next.nominalKVAr, 2.5)
        XCTAssertNil(next.measuredKVAr)
        XCTAssertEqual(next.status, .unchecked)
    }

    func testBlankCapacitorInspectionDoesNotCloseFailure() {
        var capacitor = MaintenanceCapacitor(label: "K1-C1", nominalKVAr: 10)
        capacitor.status = .failure
        var first = MaintenanceVisit.standard()
        first.date = date(1); first.capacitors = [capacitor]
        XCTAssertEqual(first.failureCount, 1)
        var second = MaintenanceVisit.standard()
        second.date = date(2); second.capacitors = [capacitor.awaitingInspection]
        var record = MaintenanceRecord()
        record.visits = [first, second]
        XCTAssertTrue(record.hasOpenFailures)
        XCTAssertEqual(record.capacitorInventory.count, 1)
        capacitor.status = .ok
        second.capacitors = [capacitor]
        record.visits[1] = second
        XCTAssertTrue(record.openCapacitorFindings.isEmpty)
        XCTAssertFalse(record.hasOpenFailures)
    }

    func testUncheckedCapacitorPreventsVisitCompletion() {
        var visit = MaintenanceVisit.standard()
        for index in visit.items.indices { visit.items[index].status = .ok }
        XCTAssertTrue(visit.isComplete)
        var capacitor = MaintenanceCapacitor(label: "K1-C1", nominalKVAr: 10)
        visit.capacitors = [capacitor]
        XCTAssertFalse(visit.isComplete)
        capacitor.status = .ok
        visit.capacitors = [capacitor]
        XCTAssertTrue(visit.isComplete)
    }

    func testCapacitorValidationAndOptionalMeasurement() {
        var capacitor = MaintenanceCapacitor(label: "K1-C1", nominalKVAr: 2.5)
        XCTAssertTrue(capacitor.isValid)
        XCTAssertNil(capacitor.capacityRatio)
        capacitor.measuredKVAr = 0
        XCTAssertEqual(capacitor.capacityRatio, 0)
        capacitor.measuredKVAr = -1
        XCTAssertFalse(capacitor.isValid)
        capacitor.measuredKVAr = nil
        capacitor.nominalKVAr = .infinity
        XCTAssertFalse(capacitor.isValid)
    }

    func testBothReactiveRegistersCannotCancelTheirWarnings() {
        var reading = MaintenanceReading()
        reading.activeKWh = 1000
        reading.inductiveKVArh = 400
        reading.capacitiveKVArh = 400
        XCTAssertEqual(reading.cosPhi, 1)
        XCTAssertEqual(reading.status, .critical)
        var record = MaintenanceRecord()
        record.readings = [reading]
        XCTAssertEqual(record.lastStatus, .critical)
        XCTAssertEqual(record.totalEstimatedPenalty, 108, accuracy: 0.0001)
    }

    func testReactiveBoundariesAndMissingData() {
        var reading = MaintenanceReading()
        XCTAssertEqual(reading.status, .unknown)
        reading.activeKWh = 1000
        XCTAssertEqual(reading.status, .good)
        reading.capacitiveKVArh = 180
        XCTAssertEqual(reading.status, .warning)
        reading.capacitiveKVArh = 201
        XCTAssertEqual(reading.status, .critical)
        reading.capacitiveKVArh = 0
        reading.inductiveKVArh = 331
        XCTAssertEqual(reading.status, .critical)
    }

    func testReadingsAndDraftsDoNotPostponeMaintenance() {
        var record = MaintenanceRecord()
        record.installationDate = date(1)
        record.checkPeriodMonths = 3
        let original = record.nextCheckDate
        var reading = MaintenanceReading()
        reading.date = date(20, month: 2)
        record.readings = [reading]
        var draft = MaintenanceVisit.standard()
        draft.date = date(25, month: 2)
        record.visits = [draft]
        XCTAssertEqual(record.nextCheckDate, original)
        for i in draft.items.indices { draft.items[i].status = .ok }
        record.visits = [draft]
        XCTAssertEqual(record.nextCheckDate, date(25, month: 5))
        var newerDraft = MaintenanceVisit.standard()
        newerDraft.date = date(15, month: 3)
        record.visits.append(newerDraft)
        XCTAssertEqual(record.nextCheckDate, date(25, month: 5))
        XCTAssertFalse(MaintenanceVisit(items: []).isComplete)
    }

    func testDueTodayIsNotOverdueAndQueuesAgree() {
        var record = MaintenanceRecord()
        record.installationDate = date(1)
        record.checkPeriodMonths = 1
        let evening = date(1, month: 2).addingTimeInterval(6 * 3600)
        XCTAssertTrue(MaintenanceQueue.today.includes(record, on: evening))
        XCTAssertFalse(MaintenanceQueue.overdue.includes(record, on: evening))
        XCTAssertTrue(MaintenanceQueue.overdue.includes(record, on: date(2, month: 2)))
    }

    func testUncheckedVisitDoesNotClearFailureButExplicitRepairDoes() {
        var record = MaintenanceRecord()
        var failed = MaintenanceVisit.standard()
        failed.date = date(1)
        failed.items[2].status = .failure
        record.visits = [failed]
        var blank = MaintenanceVisit.standard()
        blank.date = date(2)
        record.visits.append(blank)
        XCTAssertTrue(record.hasOpenFailures)
        XCTAssertTrue(MaintenanceQueue.failures.includes(record))
        blank.items[2].status = .ok
        record.visits[1] = blank
        XCTAssertFalse(record.hasOpenFailures)
        XCTAssertTrue(record.openFindings.isEmpty)
    }

    func testLegacyChecklistTitleCanBeResolvedByNewKind() {
        var record = MaintenanceRecord()
        var legacy = MaintenanceVisit.standard()
        legacy.date = date(1)
        legacy.items[2].kind = nil
        legacy.items[2].status = .failure
        var repair = MaintenanceVisit.standard()
        repair.date = date(2)
        repair.items[2].status = .ok
        record.visits = [repair, legacy] // storage order must not change chronology
        XCTAssertTrue(record.openFindings.isEmpty)
    }

    func testOldRecordRoundTripPreservesFractionAndDraft() throws {
        var record = MaintenanceRecord()
        record.totalKVAr = 12.5
        record.visits = [.standard()]
        let data = try JSONEncoder().encode(record)
        let restored = try JSONDecoder().decode(MaintenanceRecord.self, from: data)
        XCTAssertEqual(restored.totalKVAr, 12.5)
        XCTAssertFalse(restored.visits[0].isComplete)
        XCTAssertEqual(MaintenanceNumber.parse(String(restored.totalKVAr)), 12.5)
    }

    func testNumericValidationRejectsInvalidAndNonFiniteValues() {
        for text in ["", "abc", "-1", "nan", "inf", "1e999"] {
            XCTAssertNil(MaintenanceNumber.parse(text), text)
        }
        XCTAssertEqual(MaintenanceNumber.parse(" 12,5 "), 12.5)
        var reading = MaintenanceReading()
        reading.activeKWh = 100
        reading.inductiveKVArh = -1
        XCTAssertFalse(reading.isValid)
        reading.inductiveKVArh = 0
        reading.thdPercent = .infinity
        XCTAssertFalse(reading.isValid)
    }

    func testSummaryIncludesCapacitiveAndOnlyLastTwelveReadings() {
        var record = MaintenanceRecord()
        for day in 1...13 {
            var reading = MaintenanceReading()
            reading.date = date(day)
            reading.activeKWh = 1000
            reading.capacitiveKVArh = 300
            reading.tariff = 1
            record.readings.append(reading)
        }
        XCTAssertEqual(record.totalEstimatedPenalty, 1200)
    }

    func testRemindersHaveExactMorningTimeAndNoPastDates() {
        var record = MaintenanceRecord()
        record.installationDate = date(10)
        record.checkPeriodMonths = 1
        let reminders = MaintenanceNotificationService.dates(for: record, now: date(1))
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.map { Calendar.current.component(.hour, from: $0.1) }, [9, 9])
        XCTAssertEqual(reminders.map { Calendar.current.component(.minute, from: $0.1) }, [0, 0])
        XCTAssertTrue(MaintenanceNotificationService.dates(for: record, now: date(11, month: 2)).isEmpty)
    }

    func testDeletingPanelDeletesVisitAndReadingPhotos() throws {
        let suite = "MaintenanceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceService(defaults: defaults)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        var reading = MaintenanceReading()
        var visit = MaintenanceVisit.standard()
        let a = try XCTUnwrap(PhotoStorageService.save(image: image, entityID: reading.id))
        let b = try XCTUnwrap(PhotoStorageService.save(image: image, entityID: visit.id))
        defer {
            PhotoStorageService.delete(photoID: a, entityID: reading.id)
            PhotoStorageService.delete(photoID: b, entityID: visit.id)
        }
        reading.photoIDs = [a]; visit.photoIDs = [b]
        var record = MaintenanceRecord()
        record.readings = [reading]; record.visits = [visit]
        store.saveMaintenanceRecord(record)
        store.deleteMaintenanceRecord(id: record.id)
        XCTAssertNil(PhotoStorageService.load(photoID: a, entityID: reading.id))
        XCTAssertNil(PhotoStorageService.load(photoID: b, entityID: visit.id))
        XCTAssertTrue(PersistenceService(defaults: defaults).maintenanceRecords.isEmpty)
    }
}
