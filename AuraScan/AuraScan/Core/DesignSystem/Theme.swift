//
//  Theme.swift
//  AuraScan
//
//  Dark-first palette, type scale and reusable surfaces. The app is locked to
//  dark mode: the whole aesthetic is luminous marks on deep ground.
//

import SwiftUI

enum Theme {
    // MARK: - Palette

    enum Palette {
        static let void = Color(hex: 0x07060F)
        static let deepSpace = Color(hex: 0x0F0D1F)
        static let nebula = Color(hex: 0x191634)
        static let surface = Color(hex: 0x1E1B3A)
        static let surfaceRaised = Color(hex: 0x272348)

        // Depth grounds. `raisedTop`/`raisedBottom` give an extrusion its
        // top-lit gradient; `recessed`/`recessedDeep` line the wells. They sit
        // close together on purpose — soft UI reads as depth, not as colour.
        static let raisedTop = Color(hex: 0x2A2551)
        static let raisedBottom = Color(hex: 0x1B1836)
        static let recessed = Color(hex: 0x161331)
        static let recessedDeep = Color(hex: 0x100E24)

        static let starlight = Color(hex: 0xF4F1FF)
        static let moonlight = Color(hex: 0xB9B2D9)
        static let dusk = Color(hex: 0x7C7499)

        static let gold = Color(hex: 0xE7C56B)
        static let aura = Color(hex: 0x8B5CF6)
        static let glow = Color(hex: 0x5EE7DF)
    }

    // MARK: - Metrics

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 28
        static let xl: CGFloat = 40
    }

    // MARK: - Type

    enum Font {
        static let display = SwiftUI.Font.system(size: 34, weight: .semibold, design: .serif)
        static let title = SwiftUI.Font.system(size: 24, weight: .semibold, design: .serif)
        static let headline = SwiftUI.Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 14, weight: .medium, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 12, weight: .medium, design: .rounded)
        static let mono = SwiftUI.Font.system(size: 12, weight: .medium, design: .monospaced)
    }
}

// MARK: - Surfaces

/// The standard translucent card used throughout the app.
struct GlassCard<Content: View>: View {
    var tint: Color = Theme.Palette.aura
    var cornerRadius: CGFloat = Theme.Radius.large
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Palette.surface.opacity(0.72))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.45), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

/// Section header with an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.starlight)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            accessory
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Primary call-to-action. Raised out of the ground, sinking when pressed.
struct AuraButtonStyle: ButtonStyle {
    var colors: [Color] = [Theme.Palette.aura, Theme.Palette.glow]
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline)
            .foregroundStyle(labelColor(isPressed: configuration.isPressed))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background { face(isPressed: configuration.isPressed) }
            .overlay {
                Capsule().strokeBorder(
                    .white.opacity(configuration.isPressed ? 0.04 : 0.16),
                    lineWidth: 1
                )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }

    /// One face per state — a prominent button keeps its gradient and gets its
    /// depth from the shadow pair; pressing swaps it for a recessed well.
    @ViewBuilder
    private func face(isPressed: Bool) -> some View {
        if isPressed {
            Capsule().fill(
                SoftDepth.recessedFill(tint: isProminent ? colors.first : nil)
                    .shadow(.inner(color: SoftDepth.innerShade, radius: 6, x: 3, y: 3))
                    .shadow(.inner(color: SoftDepth.innerHighlight, radius: 6, x: -3, y: -3))
            )
        } else if isProminent {
            Capsule()
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .shadow(color: SoftDepth.highlight, radius: 9, x: -5, y: -5)
                .shadow(color: SoftDepth.shade, radius: 11, x: 5, y: 6)
                .shadow(color: (colors.first ?? .clear).opacity(0.35), radius: 18, y: 8)
        } else {
            Capsule()
                .fill(SoftDepth.raisedFill())
                .shadow(color: SoftDepth.highlight, radius: 9, x: -5, y: -5)
                .shadow(color: SoftDepth.shade, radius: 11, x: 5, y: 6)
        }
    }

    private func labelColor(isPressed: Bool) -> Color {
        if isPressed { return Theme.Palette.moonlight }
        return isProminent ? Theme.Palette.void : Theme.Palette.starlight
    }
}

/// Small rounded label used for elements, planets and polarity. Subtly raised —
/// enough to separate it from the card behind it, not enough to read as a button.
struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.Palette.moonlight

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text)
        }
        .font(Theme.Font.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .softRaised(Capsule(), depth: .subtle, tint: tint)
    }
}

/// A value read off a surface rather than tapped — sits in a well.
struct ValueWell: View {
    let text: String
    var tint: Color = Theme.Palette.moonlight

    var body: some View {
        Text(text)
            .font(Theme.Font.mono)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .softRecessed(Capsule(), depth: .subtle)
    }
}
