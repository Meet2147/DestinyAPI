//
//  ImageProcessor.swift
//  AuraScan
//
//  Downscales and JPEG-encodes captures before they go over the wire. Vision
//  models gain nothing from a 12MP original, and a 4MB base64 payload is the
//  difference between a 6s and a 25s round trip on cellular.
//

import UIKit

protocol ImageProcessing: Sendable {
    /// Resized, orientation-corrected, base64 JPEG ready for a provider.
    func payload(from image: UIImage) -> ImagePayload?
    /// Full-size-ish JPEG for local storage.
    func archiveData(from image: UIImage) -> Data?
    /// Square thumbnail for history rows.
    func thumbnailData(from image: UIImage) -> Data?
}

struct ImageProcessor: ImageProcessing {
    /// Longest edge sent to the model. ~1568px is the point past which the major
    /// vision APIs downsample server-side anyway.
    var maxUploadEdge: CGFloat = 1_568
    var uploadQuality: CGFloat = 0.82

    var maxArchiveEdge: CGFloat = 2_048
    var archiveQuality: CGFloat = 0.85

    var thumbnailEdge: CGFloat = 320

    init() {}

    func payload(from image: UIImage) -> ImagePayload? {
        guard
            let resized = image.normalized(maxEdge: maxUploadEdge),
            let data = resized.jpegData(compressionQuality: uploadQuality)
        else {
            return nil
        }
        return ImagePayload(mimeType: "image/jpeg", base64: data.base64EncodedString())
    }

    func archiveData(from image: UIImage) -> Data? {
        image.normalized(maxEdge: maxArchiveEdge)?.jpegData(compressionQuality: archiveQuality)
    }

    func thumbnailData(from image: UIImage) -> Data? {
        image.squareCropped()?
            .normalized(maxEdge: thumbnailEdge)?
            .jpegData(compressionQuality: 0.8)
    }
}

extension UIImage {
    /// Redraws the image upright at or below `maxEdge`, discarding EXIF
    /// orientation — models read raw pixels and ignore the orientation flag.
    func normalized(maxEdge: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        guard target.width > 0, target.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func squareCropped() -> UIImage? {
        guard let cgImage else { return nil }
        let side = min(cgImage.width, cgImage.height)
        let rect = CGRect(
            x: (cgImage.width - side) / 2,
            y: (cgImage.height - side) / 2,
            width: side,
            height: side
        )
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
