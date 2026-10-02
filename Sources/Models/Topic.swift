import Foundation

struct Topic: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var symbol: String
    let createdAt: Date
    var photos: [PhotoRecord]

    var orderedPhotos: [PhotoRecord] {
        photos.sorted { $0.capturedAt < $1.capturedAt }
    }

    func dayNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let start = photos.map(\.capturedAt).min() ?? createdAt
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)
        ).day ?? 0
        return max(1, days + 1)
    }
}

struct PhotoRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let capturedAt: Date
    let filename: String
    var note: String
}
