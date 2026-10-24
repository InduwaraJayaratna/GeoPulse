//
//  Geo_PulseTests.swift
//  Geo PulseTests
//
//  Coordinate, local event publishing, persistence, and PDF smoke tests.
//

import Testing
import CoreLocation
@testable import Geo_Pulse

// MARK: - Geofence math

@Suite("Geofence math")
@MainActor
struct GeofenceTests {

    @Test("Site exposes a valid CoreLocation coordinate")
    func siteCoordinate() {
        let site = Site(name: "Test", latitude: 30.4515, longitude: -91.1871)
        #expect(site.coordinate.latitude == 30.4515)
        #expect(site.coordinate.longitude == -91.1871)
    }

    @Test("Two coordinates in Baton Rouge are within 2km of each other")
    func distanceSanity() {
        let a = CLLocation(latitude: 30.4515, longitude: -91.1871)
        let b = CLLocation(latitude: 30.4600, longitude: -91.1800)
        let distance = a.distance(from: b)
        #expect(distance > 0)
        #expect(distance < 2_000)
    }
}

// MARK: - Local event publishing

@Suite("Mock sync repository", .timeLimit(.minutes(1)))
struct SyncTests {

    @Test("Publishing an inspection with a hazard emits a hazardFlagged event")
    @MainActor
    func publishWithHazardEmitsHazardFlagged() async throws {
        let repo = MockSyncRepository()
        // Subscribe before publication to observe the event directly.
        var iterator = repo.activityFeed().makeAsyncIterator()

        let inspection = Inspection(
            taskId: UUID(),
            siteName: "Test Facility",
            inspectorName: "Tester",
            resultSummary: "sample",
            hazardTag: "Surface corrosion",
            hazardConfidence: 0.9
        )
        await repo.publish(inspection: inspection)

        let event = await iterator.next()
        #expect(event?.kind == .hazardFlagged)
        #expect(event?.siteName == "Test Facility")
    }

    @Test("Publishing a clean inspection emits inspectionLogged (not hazardFlagged)")
    @MainActor
    func publishWithoutHazardEmitsInspectionLogged() async throws {
        let repo = MockSyncRepository()
        var iterator = repo.activityFeed().makeAsyncIterator()

        let clean = Inspection(
            taskId: UUID(),
            siteName: "Clean Site",
            inspectorName: "Tester",
            resultSummary: "All nominal"
        )
        await repo.publish(inspection: clean)

        let event = await iterator.next()
        #expect(event?.kind == .inspectionLogged)
    }

    @Test("Connection status eventually reaches .live")
    @MainActor
    func statusReachesLive() async throws {
        let repo = MockSyncRepository()
        #expect(repo.connectionStatus == .live)
    }
}

// MARK: - Core Data persistence

@Suite("Core Data persistence")
@MainActor
struct PersistenceTests {

    @Test("saveInspection then fetchAllInspections returns the record")
    func saveAndFetchRoundtrip() throws {
        let stack = CoreDataStack(inMemory: true)
        let unique = Inspection(
            taskId: UUID(),
            siteName: "Persistence Test Site \(UUID().uuidString.prefix(4))",
            inspectorName: "Tester",
            completedAt: Date(),
            resultSummary: "roundtrip",
            statusTag: "Verified"
        )
        try stack.saveInspection(unique)

        let all = try stack.fetchAllInspections()
        #expect(all.contains { $0.id == unique.id })

        let found = all.first { $0.id == unique.id }
        #expect(found?.siteName == unique.siteName)
        #expect(found?.statusTag == "Verified")
    }

    @Test("Saving the same inspection id twice upserts (no duplicate rows)")
    func upsertSemantics() throws {
        let stack = CoreDataStack(inMemory: true)
        let id = UUID()

        let v1 = Inspection(
            id: id, taskId: UUID(), siteName: "Upsert Site",
            inspectorName: "Tester", resultSummary: "v1", statusTag: "Draft"
        )
        try stack.saveInspection(v1)

        let v2 = Inspection(
            id: id, taskId: UUID(), siteName: "Upsert Site",
            inspectorName: "Tester", resultSummary: "v2", statusTag: "Verified"
        )
        try stack.saveInspection(v2)

        let matches = try stack.fetchAllInspections().filter { $0.id == id }
        #expect(matches.count == 1)
        #expect(matches.first?.statusTag == "Verified")
    }
}

// MARK: - PDF generation smoke test

@Suite("PDF Report Builder")
struct PDFReportBuilderTests {

    @Test("Builds a non-empty PDF file for a sample inspection")
    @MainActor
    func buildsPDF() {
        let inspection = Inspection(
            taskId: UUID(),
            siteName: "PDF Test Site",
            inspectorName: "Alex Mercer, PE",
            resultSummary: "All checkpoints nominal.",
            passedCount: 7,
            totalCount: 7,
            statusTag: "Verified",
            voiceNote: "Pressure reading nominal."
        )
        let user = UserProfile(
            displayName: "Alex Mercer",
            role: "Lead Inspector",
            inspectorId: "84920",
            email: "a@x.com",
            currentSiteName: "PDF Test Site",
            isActive: true
        )
        let url = PDFReportBuilder.build(for: inspection, user: user)
        #expect(url != nil)
        if let url {
            defer { try? FileManager.default.removeItem(at: url) }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            #expect(size > 500)
        }
    }
}
