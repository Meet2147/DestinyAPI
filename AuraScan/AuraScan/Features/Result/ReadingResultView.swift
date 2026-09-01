//
//  ReadingResultView.swift
//  AuraScan
//
//  The reading itself: summary, elemental balance, zone breakdown with the
//  markers found in each, and actionable guidance.
//

import SwiftUI

struct ReadingResultView: View {
    let payload: ReadingPayload
    @Binding var path: NavigationPath

    @Environment(AppEnvironment.self) private var environment
    @State private var expandedZone: String?
    @State private var showsPhotoOverlay = true
    @State private var shareItem: ShareCardItem?

    private var analysis: AnalysisResponse { payload.analysis }
    private var modality: ModalityType { payload.modality }

    var body: some View {
        ZStack {
            CosmicBackground(accent: modality.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    hero
                    summaryCard
                    qualityNotice
                    zonesSection
                    guidanceSection
                    actionsBar
                    footer
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(modality.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareItem = ShareCardItem(payload: payload)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share this reading")
            }
        }
        .sheet(item: $shareItem) { item in
            ShareCardSheet(payload: item.payload)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let data = payload.imageData, let image = UIImage(data: data) {
                ZStack(alignment: .bottomTrailing) {
                    // The marker overlay maps the model's 0-1 coordinates onto
                    // this view's bounds, so the bounds have to BE the image.
                    // `scaledToFill` in a fixed-height frame cropped a portrait
                    // to a band and left every marker sitting in the wrong
                    // place — over a shoulder rather than on a brow.
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(
                            max(image.size.width, 1) / max(image.size.height, 1),
                            contentMode: .fit
                        )
                        .frame(maxHeight: 420)
                        .overlay {
                            if showsPhotoOverlay {
                                MarkerOverlay(markers: analysis.markers, accent: modality.accent)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, Theme.Palette.void.opacity(0.85)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .frame(height: 90)
                            .allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                        .padding(6)
                        .softRecessed(
                            RoundedRectangle(cornerRadius: Theme.Radius.large + 6, style: .continuous),
                            depth: .medium
                        )

                    if analysis.markers.contains(where: { $0.boundingBox != nil }) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showsPhotoOverlay.toggle() }
                        } label: {
                            Image(systemName: showsPhotoOverlay ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Palette.starlight)
                                .padding(10)
                                .softRaised(Circle(), depth: .subtle)
                        }
                        .padding(Theme.Spacing.sm)
                        .accessibilityLabel(showsPhotoOverlay ? "Hide marker pins" : "Show marker pins")
                    }
                }
            }

            Text(analysis.headline)
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Palette.starlight)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        GlassCard(tint: modality.accent) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    EnergyGauge(score: analysis.energyScore, tint: modality.accent)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(spacing: 6) {
                            Text(analysis.dominantElement.glyph)
                                .font(.system(size: 20))
                                .foregroundStyle(analysis.dominantElement.color)
                            Text("\(analysis.dominantElement.title) dominant")
                                .font(Theme.Font.headline)
                                .foregroundStyle(Theme.Palette.starlight)
                        }
                        Text(analysis.dominantElement.keyword)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.dusk)

                        Chip(
                            text: "confidence \(Int(analysis.confidence * 100))%",
                            systemImage: "gauge.with.dots.needle.33percent",
                            tint: confidenceTint
                        )
                        .padding(.top, 2)
                    }
                }

                ElementBalanceBar(balance: analysis.elementBalance)

                Text(analysis.summary)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.moonlight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var confidenceTint: Color {
        switch analysis.confidence {
        case ..<0.4: .orange
        case ..<0.7: Theme.Palette.gold
        default: Theme.Palette.glow
        }
    }

    @ViewBuilder
    private var qualityNotice: some View {
        if !analysis.imageQuality.issues.isEmpty || analysis.imageQuality.suggestion != nil {
            GlassCard(tint: Theme.Palette.gold, cornerRadius: Theme.Radius.medium) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label("About this photo", systemImage: "camera.metering.spot")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.gold)
                    ForEach(analysis.imageQuality.issues, id: \.self) { issue in
                        Text("• \(issue)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.moonlight)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let suggestion = analysis.imageQuality.suggestion {
                        Text(suggestion)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.dusk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Zones

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(
                title: zonesTitle,
                subtitle: "\(analysis.markers.count) markers across \(analysis.zones.count) zones"
            )

            ForEach(analysis.markersByZone) { entry in
                ZoneCard(
                    zone: entry.zone,
                    markers: entry.markers,
                    accent: modality.accent,
                    isExpanded: expandedZone == entry.zone.id
                ) {
                    withAnimation(.spring(duration: 0.35)) {
                        expandedZone = expandedZone == entry.zone.id ? nil : entry.zone.id
                    }
                }
            }

            if !analysis.unzonedMarkers.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Other signs")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.dusk)
                    ForEach(analysis.unzonedMarkers) { marker in
                        MarkerRow(marker: marker)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private var zonesTitle: String {
        switch modality {
        case .face: "Zones of the face"
        case .coffee: "Around the cup"
        case .palm: "Lines and mounts"
        case .space: "Through the room"
        }
    }

    // MARK: - Guidance

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Guidance", subtitle: analysis.guidance.focus)

            GlassCard(tint: Theme.Palette.gold) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if !analysis.guidance.affirmation.isEmpty {
                        Text("“\(analysis.guidance.affirmation)”")
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Theme.Palette.starlight)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(analysis.guidance.actions) { action in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Text(action.horizon.title.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Palette.void)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Theme.Palette.gold))
                                .frame(width: 74, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(Theme.Font.callout)
                                    .foregroundStyle(Theme.Palette.starlight)
                                Text(action.detail)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.moonlight)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if !analysis.guidance.cautions.isEmpty {
                        Divider().overlay(Color.white.opacity(0.08))
                        ForEach(analysis.guidance.cautions, id: \.self) { caution in
                            Label(caution, systemImage: "exclamationmark.circle")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Color.orange.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    talismanRow
                }
            }
        }
    }

    @ViewBuilder
    private var talismanRow: some View {
        let guidance = analysis.guidance
        let hasTalisman = guidance.luckyColor != nil
            || guidance.luckyNumber != nil
            || guidance.favorableWindow != nil

        if hasTalisman || guidance.ritual != nil {
            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if hasTalisman {
                    HStack(spacing: Theme.Spacing.sm) {
                        if let color = guidance.luckyColor {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                                Text(color.name)
                            }
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.moonlight)
                        }
                        if let number = guidance.luckyNumber {
                            Chip(text: "№ \(number)", tint: Theme.Palette.gold)
                        }
                        if let window = guidance.favorableWindow {
                            Chip(text: window, systemImage: "clock", tint: Theme.Palette.glow)
                        }
                    }
                }

                if let ritual = guidance.ritual {
                    Label(ritual, systemImage: "moon.stars")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                shareItem = ShareCardItem(payload: payload)
            } label: {
                Label("Share this reading", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(AuraButtonStyle(colors: modality.gradient))

            Button("Take another reading") {
                path.removeLast(path.count)
            }
            .buttonStyle(AuraButtonStyle(isProminent: false))
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if payload.isFreshlySaved {
                Label("Saved to your history", systemImage: "checkmark.circle.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.glow)
            }
            Text("AuraScan offers reflective, traditional interpretation. It is not medical, psychological, legal or financial advice.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.sm)
    }
}

// MARK: - Zone card

struct ZoneCard: View {
    let zone: ZoneInsight
    let markers: [Marker]
    let accent: Color
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(zone.label)
                            .font(Theme.Font.headline)
                            .foregroundStyle(Theme.Palette.starlight)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Theme.Spacing.xs)
                        ValueWell(text: "\(zone.score)", tint: scoreTint)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Palette.dusk)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }

                    if !zone.timeframe.isEmpty {
                        Text(zone.timeframe)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.dusk)
                    }

                    Text(zone.summary)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.moonlight)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Score track: a well with a raised fill.
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient(colors: [scoreTint, scoreTint.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                            .frame(width: max(6, (proxy.size.width - 6) * CGFloat(zone.score) / 100))
                            .padding(3)
                            .frame(width: proxy.size.width, height: 10, alignment: .leading)
                            .softRecessed(Capsule(), depth: .subtle)
                    }
                    .frame(height: 10)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the markers in this zone" : "Expands the markers in this zone")

            if isExpanded {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(markers) { marker in
                        MarkerRow(marker: marker)
                    }
                    if markers.isEmpty {
                        Text("No individual markers recorded in this zone.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.dusk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.md)
        .softRaisedCard(depth: isExpanded ? .pronounced : .medium, tint: accent)
    }

    private var scoreTint: Color {
        switch zone.score {
        case ..<40: .orange
        case ..<65: Theme.Palette.gold
        default: Theme.Palette.glow
        }
    }
}

// MARK: - Marker row

struct MarkerRow: View {
    let marker: Marker

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: marker.polarity.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(marker.polarity.color)
                Text(marker.name)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.starlight)
                Spacer(minLength: 4)
                IntensityDots(intensity: marker.intensity, tint: marker.polarity.color)
            }

            Text(marker.observation)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
                .fixedSize(horizontal: false, vertical: true)

            Text(marker.interpretation)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.moonlight)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.xs) {
                if let element = marker.element {
                    Chip(text: element.title, systemImage: element.systemImage, tint: element.color)
                }
                if let planet = marker.planet {
                    Chip(text: "\(planet.glyph) \(planet.title)", tint: Theme.Palette.gold)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softRecessed(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous), depth: .subtle)
        .accessibilityElement(children: .combine)
    }
}

struct IntensityDots: View {
    let intensity: Int
    var tint: Color = Theme.Palette.gold

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= intensity ? tint : Color.black.opacity(0.45))
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: level <= intensity ? tint.opacity(0.7) : .clear,
                        radius: 3
                    )
                    .overlay {
                        if level > intensity {
                            Circle().strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                        }
                    }
            }
        }
        .accessibilityLabel("Intensity \(intensity) of 5")
    }
}

// MARK: - Marker pins over the photo

struct MarkerOverlay: View {
    let markers: [Marker]
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ForEach(markers.filter { $0.boundingBox != nil }) { marker in
                if let box = marker.boundingBox {
                    let rect = box.rect(in: proxy.size)
                    // Boxes only, no names. Facial features genuinely overlap —
                    // brow, eyes and nose share space — so eight labels stack
                    // into an unreadable pile and bury the face they describe.
                    // Every name is already in the zone cards below.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(accent.opacity(0.7), lineWidth: 1.2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Share plumbing

struct ShareCardItem: Identifiable {
    let payload: ReadingPayload
    var id: UUID { payload.id }
}

#Preview {
    NavigationStack {
        ReadingResultView(
            payload: ReadingPayload(
                id: UUID(),
                modality: .coffee,
                analysis: .sampleCoffee,
                imageData: nil,
                isFreshlySaved: true
            ),
            path: .constant(NavigationPath())
        )
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
