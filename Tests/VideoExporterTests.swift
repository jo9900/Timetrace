import AVFoundation
import UIKit
import XCTest
@testable import Timetrace

final class VideoExporterTests: XCTestCase {
    func testExportProducesPortraitVideoAndRejectsMissingPhoto() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let imageURL = directory.appendingPathComponent("sample.jpg")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 60, width: 80, height: 60))
        }
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: imageURL)
        let localization = AppLocalization(language: .japanese)
        let frames = [1, 2].map {
            VideoExporter.Frame(imageURL: imageURL, dateLabel: localization.date(Date(timeIntervalSince1970: 1_788_264_000 + Double($0) * 86_400)), dayNumber: $0)
        }
        let exporter = VideoExporter()
        let url = try await exporter.export(frames: frames, title: "Plant", brandName: localization.brandName, secondsPerPhoto: 0.5, localization: localization) { _ in }
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 2.5, accuracy: 0.05)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1440))
        XCTAssertTrue(try Data(contentsOf: url).count > 0)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let firstFrame = try await generator.image(at: .zero).image
        let endingFrame = try await generator.image(at: CMTime(seconds: 1.2, preferredTimescale: 30)).image
        for (name, frame) in [("Japanese exported first photo", firstFrame), ("Japanese branded ending", endingFrame)] {
            let png = try XCTUnwrap(UIImage(cgImage: frame).pngData())
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let top = try pixel(in: firstFrame, x: 540, y: 420)
        let bottom = try pixel(in: firstFrame, x: 540, y: 1000)
        XCTAssertGreaterThan(top[0], 200, "The upper half must retain the red source pixels")
        XCTAssertLessThan(top[1], 50)
        XCTAssertLessThan(top[2], 50)
        XCTAssertGreaterThan(bottom[2], 200, "The lower half must retain the blue source pixels")
        XCTAssertLessThan(bottom[0], 50)
        XCTAssertLessThan(bottom[1], 50)
        let missing = VideoExporter.Frame(imageURL: directory.appendingPathComponent("missing.jpg"), dateLabel: "Today", dayNumber: 1)
        do {
            _ = try await exporter.export(frames: [missing, missing], title: "Plant", brandName: "Timetrace", secondsPerPhoto: 0.5) { _ in }
            XCTFail("Missing photos must fail the export")
        } catch VideoExporter.ExportError.unreadablePhoto {
        }
    }

    private func pixel(in image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let sample = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(
                data: storage.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes
    }

    func testCancellationStopsExport() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let frame = VideoExporter.Frame(imageURL: URL(fileURLWithPath: "/missing"), dateLabel: "Today", dayNumber: 1)
            return try await VideoExporter().export(frames: [frame, frame], title: "Plant", brandName: "Timetrace", secondsPerPhoto: 1) { _ in }
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled export must fail")
        } catch is CancellationError {
        }
    }
}
