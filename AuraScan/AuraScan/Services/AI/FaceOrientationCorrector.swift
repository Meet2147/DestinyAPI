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
//  A face is the ground truth we do have: it is only upright in one of the four
//  rotations. So try each, and keep the one Vision is most sure about.
//

import UIKit
import Vision

struct FaceOrientationCorrector: Sendable {
    /// Rotations to try, in the order they are worth trying. `.up` first so a
    /// correctly-oriented photo costs one detection and no redraw.
    private static let candidates: [(CGImagePropertyOrientation, UIImage.Orientation)] = [
        (.up, .up), (.right, .right), (.left, .left), (.down, .down),
    ]

    /// The rotation of `image` in which a face stands upright.
    ///
    /// Returns the image unchanged when no rotation contains a face — a palm, a
    /// coffee cup or a room has no orientation cue, and guessing would be worse
    /// than leaving it alone.
    func upright(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        var best: (orientation: UIImage.Orientation, confidence: Float)?
        for (cgOrientation, uiOrientation) in Self.candidates {
            let confidence = faceConfidence(in: cgImage, orientation: cgOrientation)
            guard confidence > 0 else { continue }
            if best == nil || confidence > best!.confidence {
                best = (uiOrientation, confidence)
            }
            // An unambiguous hit on the first candidate means the photo is
            // already straight; stop rather than pay for three more passes.
            if cgOrientation == .up && confidence > 0.9 { return image }
        }

        guard let best, best.orientation != .up else { return image }
        return redraw(cgImage, as: best.orientation) ?? image
    }

    private func faceConfidence(in cgImage: CGImage,
                                orientation: CGImagePropertyOrientation) -> Float {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        do {
            try handler.perform([request])
        } catch {
            return 0
        }
        // Largest face wins ties: a bystander in the background should not
        // decide which way up the subject is.
        return (request.results ?? [])
            .max { $0.boundingBox.area < $1.boundingBox.area }?
            .confidence ?? 0
    }

    /// Rewrites the pixels in the given orientation so everything downstream —
    /// display, archive, thumbnail and the model payload — sees it upright.
    private func redraw(_ cgImage: CGImage, as orientation: UIImage.Orientation) -> UIImage? {
        let oriented = UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: oriented.size, format: format).image { _ in
            oriented.draw(in: CGRect(origin: .zero, size: oriented.size))
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
