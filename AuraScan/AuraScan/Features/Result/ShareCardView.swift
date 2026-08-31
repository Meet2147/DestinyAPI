//
//  ShareCardView.swift
//  AuraScan
//
//  Exportable summary card. Rendered off-screen with ImageRenderer at 3x so the
//  shared PNG is crisp, then handed to the system share sheet.
//

import SwiftUI

struct ShareCardSheet: View {
    let payload: ReadingPayload

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(accent: payload.modality.accent)

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        ShareCardView(payload: payload)
                            .frame(width: 320, height: 500)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                            .padding(.top, Theme.Spacing.md)

                        if let rendered {
                            ShareLink(
                                item: Image(uiImage: rendered),
                                preview: SharePreview(payload.analysis.headline, image: Image(uiImage: rendered))
                            ) {
                                Label("Share card", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(AuraButtonStyle(colors: payload.modality.gradient))
                            .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            ProgressView().tint(Theme.Palette.aura)
                        }

                        ShareLink(item: plainTextSummary) {
                            Label("Share as text", systemImage: "text.alignleft")
                        }
                        .buttonStyle(AuraButtonStyle(isProminent: false))
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.bottom, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .task { rendered = render() }
    }

    @MainActor
    private func render() -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(payload: payload)
                .frame(width: 320, height: 500)
        )
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private var plainTextSummary: String {
        let analysis = payload.analysis
        var lines = [
            "\(payload.modality.title) — AuraScan",
            analysis.headline,
            "",
            analysis.summary,
            "",
            "Dominant element: \(analysis.dominantElement.title) · Energy \(analysis.energyScore)/100",
            "Focus: \(analysis.guidance.focus)",
        ]
        if !analysis.guidance.actions.isEmpty {
            lines.append("")
            lines.append(contentsOf: analysis.guidance.actions.map { "• [\($0.horizon.title)] \($0.title) — \($0.detail)" })
        }
        return lines.joined(separator: "\n")
    }
}

/// The card itself. Kept free of environment dependencies so `ImageRenderer`
/// can rasterise it without a live view hierarchy.
struct ShareCardView: View {
    let payload: ReadingPayload

    private var analysis: AnalysisResponse { payload.analysis }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.void, Theme.Palette.deepSpace],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [payload.modality.accent.opacity(0.4), .clear],
                center: .init(x: 0.8, y: 0.1),
                startRadius: 2,
                endRadius: 300
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: payload.modality.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Text(payload.modality.title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2)
                    Spacer()
                    Text("AURASCAN")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.Palette.gold)
                }
                .foregroundStyle(payload.modality.accent)

                Text(analysis.headline)
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Palette.starlight)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                HStack(spacing: 14) {
                    EnergyGauge(score: analysis.energyScore, tint: payload.modality.accent, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(analysis.dominantElement.glyph)  \(analysis.dominantElement.title)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(analysis.dominantElement.color)
                        Text(analysis.dominantElement.keyword)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.dusk)
                    }
                }

                ElementBalanceBar(balance: analysis.elementBalance, showsLegend: false)

                Text(analysis.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.moonlight)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 5) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Palette.gold)
                    Text(analysis.guidance.focus)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Palette.starlight)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(Date.now.formatted(.dateTime.day().month(.abbreviated).year()))
                    Spacer()
                    if let color = analysis.guidance.luckyColor {
                        HStack(spacing: 4) {
                            Circle().fill(color.color).frame(width: 8, height: 8)
                            Text(color.name)
                        }
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Palette.dusk)
            }
            .padding(22)
        }
    }
}

#Preview {
    ShareCardSheet(
        payload: ReadingPayload(
            id: UUID(),
            modality: .face,
            analysis: .sampleFace,
            imageData: nil,
            isFreshlySaved: true
        )
    )
}
