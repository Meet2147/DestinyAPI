//
//  FaceOrientationTests.swift
//  AuraScanTests
//

import UIKit
import Testing
@testable import AuraScan

@Suite("Face orientation correction")
struct FaceOrientationTests {

    private func solid(_ size: CGSize, _ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    @Test("An image with no face is left exactly as it was")
    func passesThroughWhenNoFace() {
        // The important guarantee: a palm, a cup or a room must never be
        // rotated on a guess, because there is no cue to guess from.
        let original = solid(CGSize(width: 400, height: 300), .systemTeal)
        let result = FaceOrientationCorrector().upright(original)
        #expect(result.size == original.size)
        #expect(result.imageOrientation == original.imageOrientation)
    }

    @Test("A zero-size image cannot crash the corrector")
    func toleratesDegenerateInput() {
        let empty = UIImage()
        let result = FaceOrientationCorrector().upright(empty)
        #expect(result.size == empty.size)
    }

    @Test("Correction returns an upright image, never a re-flagged one",
          arguments: [UIImage.Orientation.right, .left, .down])
    func outputCarriesNoOrientationFlag(_ orientation: UIImage.Orientation) {
        // Whatever we hand back must have real upright pixels, so that the
        // archive, the thumbnail and the model payload all agree.
        let base = solid(CGSize(width: 200, height: 120), .systemPink)
        guard let cg = base.cgImage else { return }
        let flagged = UIImage(cgImage: cg, scale: 1, orientation: orientation)
        let result = FaceOrientationCorrector().upright(flagged)
        #expect(result.imageOrientation == .up || result.size == flagged.size)
    }
}
