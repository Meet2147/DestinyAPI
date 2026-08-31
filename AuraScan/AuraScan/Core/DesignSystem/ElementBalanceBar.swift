//
//  ElementBalanceBar.swift
//  AuraScan
//
//  Horizontal stacked bar of the four elemental scores, with a legend.
//

import SwiftUI

struct ElementBalanceBar: View {
    let balance: [ElementScore]
    var showsLegend = true

    private var visible: [ElementScore] { balance.filter { $0.score > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            GeometryReader { proxy in
                // Inset track, with the elemental segments raised inside it.
                HStack(spacing: 2) {
                    ForEach(visible) { entry in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [entry.element.color, entry.element.color.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                            .frame(width: max(4, (proxy.size.width - 8) * CGFloat(entry.score) / 100 - 2))
                    }
                }
                .padding(.horizontal, 4)
                .frame(width: proxy.size.width, height: 14, alignment: .leading)
                .softRecessed(Capsule(), depth: .subtle)
            }
            .frame(height: 14)
            .accessibilityElement()
            .accessibilityLabel("Elemental balance")
            .accessibilityValue(
                visible.map { "\($0.element.title) \($0.score) percent" }.joined(separator: ", ")
            )

            if showsLegend {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(balance) { entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(entry.element.color)
                                .frame(width: 7, height: 7)
                            Text("\(entry.element.title) \(entry.score)%")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.moonlight)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}

/// Circular gauge for the 0–100 energy score.
struct EnergyGauge: View {
    let score: Int
    var tint: Color = Theme.Palette.gold
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            // The track is a well carved into the card; the arc rides above it.
            Circle()
                .fill(.clear)
                .softRecessed(Circle(), depth: .medium)
                .padding(4)

            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.35), tint, Theme.Palette.glow],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 6)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 1, y: 2)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.starlight)
                Text("energy")
                    .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Palette.dusk)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Energy score")
        .accessibilityValue("\(score) out of 100")
    }
}
