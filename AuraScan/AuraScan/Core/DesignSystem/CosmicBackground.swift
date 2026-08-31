//
//  CosmicBackground.swift
//  AuraScan
//
//  Deep-space gradient with a static star field. The stars are generated once
//  from a seeded RNG so they don't shimmer on every redraw.
//

import SwiftUI

struct CosmicBackground: View {
    var accent: Color = Theme.Palette.aura
    var starCount = 90

    private let stars: [Star]

    init(accent: Color = Theme.Palette.aura, starCount: Int = 90) {
        self.accent = accent
        self.starCount = starCount
        var generator = SeededGenerator(seed: 0xA1B2_C3D4)
        stars = (0..<starCount).map { _ in
            Star(
                x: Double.random(in: 0...1, using: &generator),
                y: Double.random(in: 0...1, using: &generator),
                radius: Double.random(in: 0.5...1.8, using: &generator),
                opacity: Double.random(in: 0.15...0.7, using: &generator)
            )
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.void, Theme.Palette.deepSpace, Theme.Palette.nebula],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [accent.opacity(0.35), .clear],
                center: .init(x: 0.85, y: 0.08),
                startRadius: 4,
                endRadius: 420
            )

            RadialGradient(
                colors: [Theme.Palette.glow.opacity(0.16), .clear],
                center: .init(x: 0.1, y: 0.85),
                startRadius: 4,
                endRadius: 360
            )

            Canvas { context, size in
                for star in stars {
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private struct Star {
        let x: Double
        let y: Double
        let radius: Double
        let opacity: Double
    }
}

/// Deterministic RNG so decorative randomness is stable across redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
