import XCTest
import UIKit
@testable import Timetrace

@MainActor
final class TimelineStoreTests: XCTestCase {
    func testPhotoAndNoteSurviveReloadAndDeletion() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimelineStore(directory: directory)
        try store.createTopic(title: "  Fern  ", symbol: "leaf")
        let topicID = try XCTUnwrap(store.topics.first?.id)
        try store.addPhoto(topicID: topicID, image: testImage(), note: "First leaf")
        let photo = try XCTUnwrap(store.topics.first?.photos.first)
        XCTAssertNotNil(store.thumbnail(for: photo))
        XCTAssertNotNil(store.fullImage(for: photo))
        try store.updateNote(topicID: topicID, photoID: photo.id, note: "New growth")
        try store.renameTopic(id: topicID, title: "My fern")

        let reloaded = TimelineStore(directory: directory)
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.topics, store.topics)
        XCTAssertEqual(reloaded.topics.first?.title, "My fern")
        XCTAssertEqual(reloaded.topics.first?.photos.first?.note, "New growth")
        try reloaded.deletePhoto(topicID: topicID, photoID: photo.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reloaded.photoURL(for: photo).path))
        XCTAssertTrue(TimelineStore(directory: directory).topics[0].photos.isEmpty)
        try reloaded.addPhoto(topicID: topicID, image: testImage(), note: "")
        let remainingPhoto = try XCTUnwrap(reloaded.topics.first?.photos.first)
        try reloaded.deleteTopic(id: topicID)
        XCTAssertTrue(TimelineStore(directory: directory).topics.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reloaded.photoURL(for: remainingPhoto).path))
    }

    func testInvalidTitlesAndMissingIDsDoNotChangeLibrary() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimelineStore(directory: directory)
        XCTAssertThrowsError(try store.createTopic(title: " \n ", symbol: "leaf"))
        XCTAssertThrowsError(try store.createTopic(title: String(repeating: "a", count: 81), symbol: "leaf"))
        try store.createTopic(title: "Valid", symbol: "leaf")
        let topicID = try XCTUnwrap(store.topics.first?.id)
        try store.addPhoto(topicID: topicID, image: testImage(), note: String(repeating: "a", count: 2_000))
        let photo = try XCTUnwrap(store.topics.first?.photos.first)
        let manifestURL = directory.appendingPathComponent("timeline.json")
        let manifest = try Data(contentsOf: manifestURL)
        let imageData = try Data(contentsOf: store.photoURL(for: photo))
        let original = store.topics
        XCTAssertThrowsError(try store.renameTopic(id: original[0].id, title: ""))
        XCTAssertThrowsError(try store.deleteTopic(id: UUID()))
        XCTAssertThrowsError(try store.addPhoto(topicID: UUID(), image: testImage(), note: ""))
        XCTAssertThrowsError(try store.deletePhoto(topicID: original[0].id, photoID: UUID()))
        let longNote = String(repeating: "a", count: 2_001)
        XCTAssertThrowsError(try store.addPhoto(topicID: topicID, image: testImage(), note: longNote)) { error in
            guard case TimelineStore.StoreError.invalidNote = error else { return XCTFail("Expected invalidNote") }
        }
        XCTAssertThrowsError(try store.updateNote(topicID: topicID, photoID: photo.id, note: longNote)) { error in
            guard case TimelineStore.StoreError.invalidNote = error else { return XCTFail("Expected invalidNote") }
        }
        XCTAssertEqual(store.topics, original)
        XCTAssertEqual(TimelineStore(directory: directory).topics, original)
        XCTAssertEqual(try Data(contentsOf: manifestURL), manifest)
        XCTAssertEqual(try Data(contentsOf: store.photoURL(for: photo)), imageData)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Photos").path), [photo.filename])
    }

    func testDamagedManifestCannotBeOverwritten() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = directory.appendingPathComponent("timeline.json")
        let damaged = Data("damaged library".utf8)
        try damaged.write(to: manifest)
        let store = TimelineStore(directory: directory)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.createTopic(title: "Fern", symbol: "leaf"))
        XCTAssertEqual(try Data(contentsOf: manifest), damaged)
    }

    func testFailedCommitPreservesPhotoAndRollsBackAddedFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimelineStore(directory: directory)
        try store.createTopic(title: "Fern", symbol: "leaf")
        let topicID = try XCTUnwrap(store.topics.first?.id)
        try store.addPhoto(topicID: topicID, image: testImage(), note: "")
        let photo = try XCTUnwrap(store.topics.first?.photos.first)
        let original = store.topics
        let manifest = directory.appendingPathComponent("timeline.json")
        let savedData = try Data(contentsOf: manifest)
        try FileManager.default.removeItem(at: manifest)
        try FileManager.default.createDirectory(at: manifest, withIntermediateDirectories: false)

        XCTAssertThrowsError(try store.deletePhoto(topicID: topicID, photoID: photo.id))
        XCTAssertThrowsError(try store.deleteTopic(id: topicID))
        XCTAssertThrowsError(try store.addPhoto(topicID: topicID, image: testImage(), note: ""))
        XCTAssertEqual(store.topics, original)
        XCTAssertNotNil(store.fullImage(for: photo))
        let filenames = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Photos").path)
        XCTAssertEqual(filenames, [photo.filename])

        try FileManager.default.removeItem(at: manifest)
        try savedData.write(to: manifest)
        XCTAssertEqual(TimelineStore(directory: directory).topics, original)
    }

    func testDayNumbersUseCalendarDaysAndFirstPhoto() throws {
        let calendar = Calendar.current
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .hour, value: 2, to: firstDay))
        let laterDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: firstDay))
        let earlier = firstDay.addingTimeInterval(-86_400 * 5)
        let first = PhotoRecord(id: UUID(), capturedAt: firstDay, filename: "first.jpg", note: "")
        let later = PhotoRecord(id: UUID(), capturedAt: laterDay, filename: "later.jpg", note: "")
        let topic = Topic(id: UUID(), title: "Fern", symbol: "leaf", createdAt: earlier, photos: [later, first])
        XCTAssertEqual(topic.orderedPhotos.map(\.id), [first.id, later.id])
        XCTAssertEqual(topic.dayNumber(for: firstDay), 1)
        XCTAssertEqual(topic.dayNumber(for: nextDay), 2)
        XCTAssertEqual(topic.dayNumber(for: laterDay), 4)
        XCTAssertEqual(topic.dayNumber(for: earlier), 1)
        let empty = Topic(id: UUID(), title: "New", symbol: "leaf", createdAt: firstDay, photos: [])
        XCTAssertEqual(empty.dayNumber(for: nextDay), 2)
    }

    func testSavedPhotoHasBoundedDimensionsAndNormalizedOrientation() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let large = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 1_000), format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 1_000))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(large.cgImage), scale: 1, orientation: .right)
        let data = try PhotoFiles.jpegData(for: rotated)
        let result = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(result.imageOrientation, .up)
        XCTAssertLessThanOrEqual(max(result.size.width, result.size.height), 2_560)
        XCTAssertGreaterThan(result.size.height, result.size.width)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TimetraceTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }
    }
}
