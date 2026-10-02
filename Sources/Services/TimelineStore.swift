import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class TimelineStore {
    private(set) var topics: [Topic] = []
    private var loadFailed = false
    var loadError: String? { loadFailed ? AppLocalization.current.text("store.loadFailed") : nil }

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let thumbnails = NSCache<NSString, UIImage>()

    private var manifestURL: URL { directory.appendingPathComponent("timeline.json") }
    private var photosDirectory: URL { directory.appendingPathComponent("Photos", isDirectory: true) }

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("Timetrace", isDirectory: true)
        thumbnails.totalCostLimit = 32 * 1_024 * 1_024
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(Manifest.self, from: data)
                guard manifest.version == 1,
                      Set(manifest.topics.map(\.id)).count == manifest.topics.count else {
                    throw StoreError.invalidLibrary
                }
                let photos = manifest.topics.flatMap(\.photos)
                guard Set(photos.map(\.id)).count == photos.count,
                      photos.allSatisfy({ $0.filename == "\($0.id.uuidString).jpg" }) else {
                    throw StoreError.invalidLibrary
                }
                topics = manifest.topics
            }
        } catch {
            loadFailed = true
        }
    }

    func createTopic(title: String, symbol: String) throws {
        let title = try validatedTitle(title)
        var updated = topics
        updated.insert(Topic(id: UUID(), title: title, symbol: symbol, createdAt: Date(), photos: []), at: 0)
        try save(updated)
    }

    func renameTopic(id: UUID, title: String) throws {
        let title = try validatedTitle(title)
        var updated = topics
        guard let index = updated.firstIndex(where: { $0.id == id }) else { throw StoreError.topicMissing }
        updated[index].title = title
        try save(updated)
    }

    func deleteTopic(id: UUID) throws {
        guard let topic = topics.first(where: { $0.id == id }) else { throw StoreError.topicMissing }
        try save(topics.filter { $0.id != id })
        topic.photos.forEach(removePhotoFile)
    }

    func addPhoto(topicID: UUID, image: UIImage, note: String) throws {
        try ensureWritable()
        guard note.count <= 2_000 else { throw StoreError.invalidNote }
        var updated = topics
        guard let index = updated.firstIndex(where: { $0.id == topicID }) else { throw StoreError.topicMissing }
        let id = UUID()
        let photo = PhotoRecord(id: id, capturedAt: Date(), filename: "\(id.uuidString).jpg", note: note)
        let data = try PhotoFiles.jpegData(for: image)
        try data.write(to: photoURL(for: photo), options: .atomic)
        updated[index].photos.append(photo)
        do {
            try save(updated)
        } catch {
            removePhotoFile(photo)
            throw error
        }
    }

    func deletePhoto(topicID: UUID, photoID: UUID) throws {
        var updated = topics
        guard let index = updated.firstIndex(where: { $0.id == topicID }) else { throw StoreError.topicMissing }
        guard let photo = updated[index].photos.first(where: { $0.id == photoID }) else { throw StoreError.photoMissing }
        updated[index].photos.removeAll { $0.id == photoID }
        try save(updated)
        removePhotoFile(photo)
    }

    func updateNote(topicID: UUID, photoID: UUID, note: String) throws {
        guard note.count <= 2_000 else { throw StoreError.invalidNote }
        var updated = topics
        guard let index = updated.firstIndex(where: { $0.id == topicID }) else { throw StoreError.topicMissing }
        guard let photoIndex = updated[index].photos.firstIndex(where: { $0.id == photoID }) else {
            throw StoreError.photoMissing
        }
        updated[index].photos[photoIndex].note = note
        try save(updated)
    }

    func photoURL(for photo: PhotoRecord) -> URL {
        photosDirectory.appendingPathComponent(photo.filename)
    }

    func thumbnail(for photo: PhotoRecord) -> UIImage? {
        let key = photo.filename as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let image = PhotoFiles.thumbnail(at: photoURL(for: photo)) else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        thumbnails.setObject(image, forKey: key, cost: cost)
        return image
    }

    func fullImage(for photo: PhotoRecord) -> UIImage? {
        UIImage(contentsOfFile: photoURL(for: photo).path)
    }

    private func validatedTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { throw StoreError.invalidTitle }
        return trimmed
    }

    private func ensureWritable() throws {
        guard loadError == nil else { throw StoreError.libraryUnavailable }
    }

    private func save(_ updated: [Topic]) throws {
        try ensureWritable()
        let data = try JSONEncoder().encode(Manifest(version: 1, topics: updated))
        try data.write(to: manifestURL, options: .atomic)
        topics = updated
    }

    private func removePhotoFile(_ photo: PhotoRecord) {
        thumbnails.removeObject(forKey: photo.filename as NSString)
        // Metadata is already committed; a leftover file is safer than a lost photo.
        try? FileManager.default.removeItem(at: photoURL(for: photo))
    }

    private struct Manifest: Codable {
        let version: Int
        let topics: [Topic]
    }

    enum StoreError: LocalizedError {
        case invalidTitle, invalidNote, invalidImage, topicMissing, photoMissing, invalidLibrary, libraryUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidTitle: AppLocalization.current.text("store.invalidTitle")
            case .invalidNote: AppLocalization.current.text("store.invalidNote")
            case .invalidImage: AppLocalization.current.text("store.invalidImage")
            case .topicMissing: AppLocalization.current.text("store.topicMissing")
            case .photoMissing: AppLocalization.current.text("store.photoMissing")
            case .invalidLibrary: AppLocalization.current.text("store.invalidLibrary")
            case .libraryUnavailable: AppLocalization.current.text("store.libraryUnavailable")
            }
        }
    }
}
