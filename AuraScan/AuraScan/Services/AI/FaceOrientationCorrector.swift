//
//  FaceOrientationCorrector.swift
//  AuraScan
//
//  Straightens photos whose pixels are rotated but whose EXIF says otherwise.
//
//  `UIImage.normalized` bakes in the orientation flag, which is enough for a
//  photo straight from the camera. It cannot help when an app re-encodes the
//  file and writes rotated pixels with an `.up` flag — WhatsApp and several
//  messengers do exactly that. The flag is then a lie and there is nothing in
//  the file to correct against.
//
//  A face is the ground truth we do have: it is upright in exactly one of the
//  four rotations.
//
//  The approach is deliberately "rotate, then check" rather than "detect, then
//  map". Translating a `CGImagePropertyOrientation` into a `UIImage.Orientation`
//  looks obvious but the `.left`/`.right` pairing is a well-known trap, and
//  getting it backwards rotates the wrong way — a 180° error that looks like a
//  bug in the camera rather than in this file. Producing the candidate image
//  and re-testing it needs no mapping to be correct.
//

import OSLog
import UIKit
import Vision

struct FaceOrientationCorrector: Sendable {
    /// Above this, a face is unambiguous and searching further is wasted work.
    private static let decisive: Float = 0.75

    private let logger = Logger(subsystem: "ai.aurascan", category: "orientation")

    /// The rotation of `image` in which a face stands upright.
    ///
    /// Returns the image unchanged when no rotation contains a face — a palm, a
    /// coffee cup or a room has no orientation cue, and guessing would be worse
    /// than leaving it alone.
    func upright(_ image: UIImage) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }

        // The common case: already straight. One detection, no redraw.
        let asIs = flattened(image) ?? image
        let straight = faceConfidence(in: asIs)
        if straight >= Self.decisive {
            logger.debug("already upright (\(straight, privacy: .public))")
            return asIs
        }

        var best = (image: asIs, confidence: straight)
        for rotation in [UIImage.Orientation.right, .left, .down] {
            guard let candidate = rotated(asIs, by: rotation) else { continue }
            // Test the candidate itself, at `.up`. Whatever the enum names
            // mean, the pixels either show an upright face or they do not.
            let confidence = faceConfidence(in: candidate)
            if confidence > best.confidence {
                best = (candidate, confidence)
            }
            if confidence >= Self.decisive { break }
        }

        logger.debug("chose orientation with confidence \(best.confidence, privacy: .public)")
        return best.confidence > straight ? best.image : asIs
    }

    // MARK: - Vision

    private func faceConfidence(in image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0 }
        let request = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                .perform([request])
        } catch {
            return 0
        }
        // Largest face wins: a bystander in the background should not decide
        // which way up the subject is.
        return (request.results ?? [])
            .max { $0.boundingBox.area < $1.boundingBox.area }?
            .confidence ?? 0
    }

    // MARK: - Pixels

    /// Redraws so the orientation flag is `.up` and the pixels are what they
    /// claim to be. Everything downstream then agrees.
    private func flattened(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }
        return render(size: image.size) { image.draw(in: $0) }
    }

    private func rotated(_ image: UIImage, by orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let turned = UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
        return render(size: turned.size) { turned.draw(in: $0) }
    }

    private func render(size: CGSize, _ draw: (CGRect) -> Void) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
