//
//  SoftDepth.swift
//  AuraScan
//
//  Neumorphic depth, adapted for a dark photo-first app.
//
//  Classic soft UI extrudes *everything* from one flat ground, which on a dark
//  background leaves the light shadow nowhere to go and drags body text down to
//  ~3:1 contrast. So AuraScan applies depth only to chrome — anything you can
//  tap, drag or read a value off — and leaves content (photos, body copy, glass
//  cards) at full contrast.
//
//  The rule of thumb when adding a new control:
//    • It responds to touch        → .softRaised, pressing to .softRecessed
//    • It holds a value or a track → .softRecessed (a well)
//    • It carries text to be read  → GlassCard, not depth
//
//  Light comes from the top-left, consistently, everywhere.
//

import SwiftUI

enum SoftDepth {
    /// Highlight and shade for the extrusion. Tuned against `Palette.raisedBase`:
    /// bright enough to read on a dark ground without looking like a glow.
    static let highlight = Color.white.opacity(0.10)
    static let shade = Color.black.opacity(0.66)

    /// Inner-shadow pair for recessed wells — deliberately stronger than the
    /// raised pair, because a shallow inset reads as a rendering artifact.
    static let innerShade = Color.black.opacity(0.78)
    static let innerHighlight = Color.white.opacity(0.07)

    enum Depth {
        case subtle
        case medium
        case pronounced

        var blur: CGFloat {
            switch self {
            case .subtle: 5
            case .medium: 9
            case .pronounced: 16
            }
        }

        var offset: CGFloat {
            switch self {
            case .subtle: 2.5
            case .medium: 5
            case .pronounced: 8
            }
        }

        /// Inner shadows need less spread than outer ones to read at the same weight.
        var innerBlur: CGFloat { blur * 0.6 }
        var innerOffset: CGFloat { offset * 0.55 }
    }

    /// Top-lit gradient that sells the extrusion even before the shadows land.
    static func raisedFill(tint: Color? = nil) -> LinearGradient {
        LinearGradient(
            colors: [
                Theme.Palette.raisedTop.blended(with: tint, amount: tint == nil ? 0 : 0.14),
                Theme.Palette.raisedBottom.blended(with: tint, amount: tint == nil ? 0 : 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func recessedFill(tint: Color? = nil) -> LinearGradient {
        LinearGradient(
            colors: [
                Theme.Palette.recessed.blended(with: tint, amount: tint == nil ? 0 : 0.18),
                Theme.Palette.recessedDeep.blended(with: tint, amount: tint == nil ? 0 : 0.1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Modifiers

private struct SoftRaised<S: InsettableShape>: ViewModifier {
    let shape: S
    let depth: SoftDepth.Depth
    let tint: Color?
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isPressed {
                    // Pressing inverts the extrusion — the control sinks into
                    // the ground rather than merely dimming.
                    shape.fill(
                        SoftDepth.recessedFill(tint: tint)
                            .shadow(.inner(color: SoftDepth.innerShade, radius: depth.innerBlur, x: depth.innerOffset, y: depth.innerOffset))
                            .shadow(.inner(color: SoftDepth.innerHighlight, radius: depth.innerBlur, x: -depth.innerOffset, y: -depth.innerOffset))
                    )
                } else {
                    shape.fill(SoftDepth.raisedFill(tint: tint))
                        .shadow(color: SoftDepth.highlight, radius: depth.blur, x: -depth.offset, y: -depth.offset)
                        .shadow(color: SoftDepth.shade, radius: depth.blur, x: depth.offset, y: depth.offset)
                }
            }
            .overlay {
                // A one-pixel top-left rim keeps the edge crisp against the
                // background; without it the shape dissolves at small sizes.
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(isPressed ? 0.04 : 0.16), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(0.9)
            }
            .animation(.spring(duration: 0.22), value: isPressed)
    }
}

private struct SoftRecessed<S: InsettableShape>: ViewModifier {
    let shape: S
    let depth: SoftDepth.Depth
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(
                    SoftDepth.recessedFill(tint: tint)
                        .shadow(.inner(color: SoftDepth.innerShade, radius: depth.innerBlur, x: depth.innerOffset, y: depth.innerOffset))
                        .shadow(.inner(color: SoftDepth.innerHighlight, radius: depth.innerBlur, x: -depth.innerOffset, y: -depth.innerOffset))
                )
            }
            .overlay {
                shape.strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
            }
    }
}

// These helpers only read their parameters and compose a view, but they
// inherit main-actor isolation from `View` under Swift 6. That made them
// uncallable from nonisolated SwiftUI closures — a `PhotosPicker` label, for
// one — because `some View` is not Sendable. `nonisolated` drops the isolation
// they never needed.
extension View {
    /// Extrudes the view from the ground. Use for anything tappable.
    nonisolated func softRaised(
        _ shape: some InsettableShape,
        depth: SoftDepth.Depth = .medium,
        tint: Color? = nil,
        isPressed: Bool = false
    ) -> some View {
        modifier(SoftRaised(shape: shape, depth: depth, tint: tint, isPressed: isPressed))
    }

    /// Sinks the view into the ground. Use for tracks, wells and value fields.
    nonisolated func softRecessed(
        _ shape: some InsettableShape,
        depth: SoftDepth.Depth = .medium,
        tint: Color? = nil
    ) -> some View {
        modifier(SoftRecessed(shape: shape, depth: depth, tint: tint))
    }

    /// Convenience for the app's standard rounded rectangle.
    nonisolated func softRaisedCard(
        cornerRadius: CGFloat = Theme.Radius.large,
        depth: SoftDepth.Depth = .medium,
        tint: Color? = nil,
        isPressed: Bool = false
    ) -> some View {
        softRaised(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            depth: depth,
            tint: tint,
            isPressed: isPressed
        )
    }

    nonisolated func softRecessedField(cornerRadius: CGFloat = Theme.Radius.small, depth: SoftDepth.Depth = .subtle) -> some View {
        softRecessed(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), depth: depth)
    }
}

// MARK: - Colour blending

extension Color {
    /// Mixes toward `other` in sRGB. Used to tint the raised/recessed grounds
    /// by a modality accent without leaving the neutral depth palette.
    func blended(with other: Color?, amount: Double) -> Color {
        guard let other, amount > 0 else { return self }
        let base = UIColor(self)
        let top = UIColor(other)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        top.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let t = CGFloat(amount.clamped(to: 0...1))
        return Color(
            .sRGB,
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1)
        )
    }
}

// MARK: - Preview

#Preview("Soft Depth") {
    ZStack {
        CosmicBackground()
        VStack(spacing: 28) {
            HStack(spacing: 20) {
                Circle().fill(.clear).frame(width: 64, height: 64)
                    .softRaised(Circle(), depth: .pronounced, tint: Theme.Palette.aura)
                    .overlay { Image(systemName: "camera.fill").foregroundStyle(Theme.Palette.starlight) }

                Circle().fill(.clear).frame(width: 64, height: 64)
                    .softRaised(Circle(), depth: .pronounced, tint: Theme.Palette.aura, isPressed: true)
                    .overlay { Image(systemName: "camera.fill").foregroundStyle(Theme.Palette.dusk) }

                Circle().fill(.clear).frame(width: 64, height: 64)
                    .softRecessed(Circle(), depth: .medium)
                    .overlay { Text("68").font(Theme.Font.mono).foregroundStyle(Theme.Palette.moonlight) }
            }

            Button("Read this image") {}
                .buttonStyle(AuraButtonStyle())
                .padding(.horizontal, 24)

            Button("Retake") {}
                .buttonStyle(AuraButtonStyle(isProminent: false))
                .padding(.horizontal, 24)

            HStack {
                Chip(text: "Fire", systemImage: "flame.fill", tint: Element.fire.color)
                Chip(text: "♃ Jupiter", tint: Theme.Palette.gold)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
