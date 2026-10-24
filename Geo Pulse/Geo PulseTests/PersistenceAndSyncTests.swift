import Foundation
import Testing
import PDFKit
@testable import Geo_Pulse

@MainActor
@Suite("Persistence and files")
struct PersistenceAndFileTests {
    @Test func roundtripAllFieldsAndClearOptionals() throws {
        let store = CoreDataStack(inMemory: true)
        var record = Inspection(taskId: UUID(), siteId: UUID(), siteName: "Site", inspectorName: "Inspector",
            completedAt: Date(timeIntervalSince1970: 100), durationMinutes: 10, resultSummary: "Result",
            passedCount: 2, totalCount: 3, statusTag: "Conditional", hazardTag: "Crack",
            hazardConfidence: 0.42, voiceNote: "Note", photoName: "photo.jpg", syncState: .syncing)
        try store.saveInspection(record)
        #expect(try store.fetchAllInspections() == [record])
        record.hazardTag = nil; record.hazardConfidence = nil; record.photoName = nil; record.voiceNote = nil
        try store.saveInspection(record)
        #expect(try store.fetchAllInspections() == [record])
    }

    @Test func invalidCountsDoNotWriteRecords() throws {
        let store = CoreDataStack(inMemory: true)
        let invalid = Inspection(taskId: UUID(), siteName: "Site", inspectorName: "Tester", passedCount: 4, totalCount: 3)
        #expect(throws: (any Error).self) { try store.saveInspection(invalid) }
        #expect(try store.fetchAllInspections().isEmpty)
    }

    @Test func storesAreIsolatedAndSortedNewestFirst() throws {
        let first = CoreDataStack(inMemory: true)
        let second = CoreDataStack(inMemory: true)
        let old = Inspection(taskId: UUID(), siteName: "Old", inspectorName: "Tester", completedAt: .distantPast)
        let new = Inspection(taskId: UUID(), siteName: "New", inspectorName: "Tester", completedAt: .distantFuture)
        try first.saveInspection(old); try first.saveInspection(new)
        #expect(try first.fetchAllInspections().map(\.id) == [new.id, old.id])
        #expect(try second.fetchAllInspections().isEmpty)
    }

    @Test func sqliteSurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let record = Inspection(taskId: UUID(), siteId: UUID(), siteName: "Persistent", inspectorName: "Tester")
        do { let store = CoreDataStack(storeURL: url); try store.saveInspection(record) }
        let reopened = CoreDataStack(storeURL: url)
        #expect(try reopened.fetchAllInspections() == [record])
    }

    @Test func photosAreDurableAndPathTraversalIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PhotoStore(directory: directory)
        let data = Data([1, 2, 3])
        let name = try store.save(data)
        let url = try #require(PhotoStore(directory: directory).url(for: name))
        #expect(try Data(contentsOf: url) == data)
        #expect(store.url(for: "../private.jpg") == nil)
    }

    @Test func longNotesContinueAcrossPages() throws {
        let record = Inspection(taskId: UUID(), siteName: "Site", inspectorName: "Tester",
            voiceNote: String(repeating: "Detailed observation recorded on site. ", count: 600) + "END OF NOTES")
        let url = try #require(PDFReportBuilder.build(for: record, user: SampleData.currentUser))
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount > 1)
        #expect(pdf.string?.contains("END OF NOTES") == true)
    }

    @Test func pdfContainsSubmittedInspection() throws {
        let record = Inspection(taskId: UUID(), siteName: "Unique Test Facility", inspectorName: "Test Inspector",
            resultSummary: "Observed seal condition", passedCount: 2, totalCount: 2)
        let url = try #require(PDFReportBuilder.build(for: record, user: SampleData.currentUser))
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount == 1)
        let text = try #require(pdf.string).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        #expect(text.contains("Unique Test Facility"))
        #expect(text.contains("Observed seal condition"))
    }
}

@MainActor
@Suite("Local feed delivery", .timeLimit(.minutes(1)))
struct LocalFeedTests {
    @Test func queuedEventIsReplayedOnceAfterConnection() async {
        let repo = MockSyncRepository(connected: false)
        let record = Inspection(taskId: UUID(), siteName: "Site", inspectorName: "Tester")
        await repo.publish(inspection: record); await repo.publish(inspection: record)
        await repo.connect()
        var iterator = repo.activityFeed().makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.siteName == "Site")
        #expect(event?.kind == .inspectionLogged)
        #expect(repo.connectionStatus == .live)
    }

    @Test func bothSubscribersReceiveSameSafetyEvent() async {
        let repo = MockSyncRepository()
        var first = repo.activityFeed().makeAsyncIterator()
        var second = repo.activityFeed().makeAsyncIterator()
        await repo.publish(inspection: Inspection(taskId: UUID(), siteName: "Site", inspectorName: "Tester", statusTag: "Safety incident"))
        let a = await first.next(); let b = await second.next()
        #expect(a == b)
        #expect(a?.kind == .fallAlert)
    }
}
