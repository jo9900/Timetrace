import AVFoundation
import ImageIO
import UIKit

actor VideoExporter {
    struct Frame: Sendable {
        let imageURL: URL
        let dateLabel: String
        let dayNumber: Int
    }

    enum ExportError: LocalizedError {
        case insufficientPhotos, unreadablePhoto, renderingFailed, encodingFailed

        var errorDescription: String? {
            switch self {
            case .insufficientPhotos: AppLocalization.current.text("export.insufficientPhotos")
            case .unreadablePhoto: AppLocalization.current.text("export.unreadablePhoto")
            case .renderingFailed: AppLocalization.current.text("export.renderingFailed")
            case .encodingFailed: AppLocalization.current.text("export.encodingFailed")
            }
        }
    }

    func export(
        frames: [Frame], title: String, brandName: String, secondsPerPhoto: Double,
        localization: AppLocalization = .current,
        progress: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        guard frames.count >= 2 else { throw ExportError.insufficientPhotos }
        guard secondsPerPhoto.isFinite, (0.5...2).contains(secondsPerPhoto) else {
            throw ExportError.encodingFailed
        }
        try Task.checkCancellation()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Timetrace-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1440,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1080,
            kCVPixelBufferHeightKey as String: 1440,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw ExportError.encodingFailed }
        writer.add(input)
        do {
            guard writer.startWriting() else { throw writer.error ?? ExportError.encodingFailed }
            writer.startSession(atSourceTime: .zero)
            let framesPerPhoto = Int((secondsPerPhoto * 30).rounded())
            let endingFrames = 45
            let totalFrames = frames.count * framesPerPhoto + endingFrames
            var frameIndex = 0
            for index in 0...frames.count {
                try Task.checkCancellation()
                let frame = index < frames.count ? frames[index] : nil
                let buffer = try autoreleasepool {
                    try render(frame: frame, title: title, brandName: brandName, localization: localization, pool: adaptor.pixelBufferPool)
                }
                let repetitions = frame == nil ? endingFrames : framesPerPhoto
                for _ in 0..<repetitions {
                    try Task.checkCancellation()
                    while !input.isReadyForMoreMediaData {
                        guard writer.status == .writing else { throw writer.error ?? ExportError.encodingFailed }
                        try await Task.sleep(for: .milliseconds(5))
                    }
                    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frameIndex), timescale: 30)) else {
                        throw writer.error ?? ExportError.encodingFailed
                    }
                    frameIndex += 1
                }
                await progress(Double(frameIndex) / Double(totalFrames))
            }
            input.markAsFinished()
            writer.endSession(atSourceTime: CMTime(value: Int64(totalFrames), timescale: 30))
            await writer.finishWriting()
            try Task.checkCancellation()
            guard writer.status == .completed else { throw writer.error ?? ExportError.encodingFailed }
            return url
        } catch {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private func render(frame: Frame?, title: String, brandName: String, localization: AppLocalization, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
        guard let pool else { throw ExportError.renderingFailed }
        var result: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &result) == kCVReturnSuccess, let buffer = result else {
            throw ExportError.renderingFailed
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: 1080, height: 1440,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { throw ExportError.renderingFailed }
        context.translateBy(x: 0, y: 1440)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1440))
        if let frame {
            guard let source = CGImageSourceCreateWithURL(frame.imageURL as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1440
                  ] as CFDictionary) else { throw ExportError.unreadablePhoto }
            let imageArea = CGRect(x: 40, y: 150, width: 1000, height: 1110)
            let scale = min(imageArea.width / CGFloat(image.width), imageArea.height / CGFloat(image.height))
            let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            UIImage(cgImage: image).draw(in: CGRect(
                x: imageArea.midX - size.width / 2, y: imageArea.midY - size.height / 2,
                width: size.width, height: size.height
            ))
            draw(title, in: CGRect(x: 54, y: 55, width: 972, height: 64), size: 40, weight: .semibold)
            draw(localization.text("export.frameCaption", frame.dayNumber, frame.dateLabel), in: CGRect(x: 54, y: 1300, width: 972, height: 48), size: 30)
            draw(brandName, in: CGRect(x: 54, y: 1364, width: 972, height: 42), size: 27, weight: .medium)
        } else {
            draw(brandName, in: CGRect(x: 60, y: 590, width: 960, height: 110), size: 80, weight: .semibold)
            draw(localization.text("export.endingTagline"), in: CGRect(x: 60, y: 726, width: 960, height: 70), size: 37)
            draw(localization.text("export.endingCallToAction"), in: CGRect(x: 60, y: 830, width: 960, height: 60), size: 28)
        }
        return buffer
    }

    private func draw(_ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor(red: 0.14, green: 0.24, blue: 0.19, alpha: 1),
            .paragraphStyle: paragraph
        ])
    }
}
