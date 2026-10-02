import ImageIO
import UIKit

@MainActor
enum PhotoFiles {
    static func jpegData(for image: UIImage) throws -> Data {
        let width = image.size.width
        let height = image.size.height
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw TimelineStore.StoreError.invalidImage
        }
        let ratio = min(1, 2_560 / max(width, height))
        let size = CGSize(width: max(1, width * ratio), height: max(1, height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.9) else {
            throw TimelineStore.StoreError.invalidImage
        }
        return data
    }

    static func thumbnail(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 720,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
