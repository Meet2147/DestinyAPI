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

/// Primary call-to-action.
struct AuraButtonStyle: ButtonStyle {
    var colors: [Color] = [Theme.Palette.aura, Theme.Palette.glow]
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline)
            .foregroundStyle(isProminent ? Theme.Palette.void : Theme.Palette.starlight)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background {
                Capsule().fill(
                    isProminent
                        ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Theme.Palette.surfaceRaised)
                )
            }
            .overlay {
                if !isProminent {
                    Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Small rounded label used for elements, planets and polarity.
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
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 0.5))
    }
}
