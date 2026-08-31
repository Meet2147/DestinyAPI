//
//  AnalyzingView.swift
//  AuraScan
//
//  Loading state for the vision call: an orbiting cosmic loader plus rotating
//  status copy so a 20-second wait reads as progress rather than a hang.
//

import Combine
import SwiftUI

struct AnalyzingView: View {
    let modality: ModalityType
    var onCancel: (() -> Void)?

    @State private var stageIndex = 0
    @State private var elapsed: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var stages: [String] {
        switch modality {
        case .face:
            ["Mapping facial zones…", "Assigning planetary rulers…", "Reading symmetry…", "Weighing the markers…", "Composing your reading…"]
        case .coffee:
            ["Locating the rim and handle…", "Tracing symbols in the grounds…", "Reading the base…", "Placing signs in time…", "Composing your reading…"]
        case .palm:
            ["Finding the major lines…", "Measuring line depth…", "Reading the mounts…", "Classifying the hand's element…", "Composing your reading…"]
        case .space:
            ["Framing the room…", "Checking the command position…", "Tracing energy flow…", "Balancing the five phases…", "Composing your reading…"]
        }
    }

    var body: some View {
        ZStack {
            CosmicBackground(accent: modality.accent)

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                CosmicLoader(colors: modality.gradient)
                    .frame(width: 190, height: 190)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(stages[min(stageIndex, stages.count - 1)])
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.Palette.starlight)
                        .contentTransition(.opacity)
                        .id(stageIndex)
                        .transition(.opacity)

                    Text("This usually takes about \(modality.estimatedAnalysisSeconds) seconds.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer()

                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(AuraButtonStyle(isProminent: false))
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                }
            }
        }
        .onReceive(timer) { _ in
            elapsed += 1
            // Advance roughly evenly across the expected duration, and hold on
            // the final stage if the call runs long.
            let step = max(3, modality.estimatedAnalysisSeconds / stages.count)
            let target = min(elapsed / step, stages.count - 1)
            if target != stageIndex {
                withAnimation(.easeInOut(duration: 0.4)) { stageIndex = target }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analysing your \(modality.title.lowercased())")
    }
}

/// Three counter-rotating orbits with a pulsing core.
struct CosmicLoader: View {
    var colors: [Color] = [Theme.Palette.aura, Theme.Palette.glow]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    let scale = 1.0 - Double(ring) * 0.22
                    let speed = [26.0, -38.0, 52.0][ring]

                    Circle()
                        .trim(from: 0.05, to: 0.55)
                        .stroke(
                            AngularGradient(
                                colors: [colors.first ?? .white, (colors.last ?? .white).opacity(0.15)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .scaleEffect(scale)
                        .rotation3DEffect(.degrees(Double(ring) * 34), axis: (x: 1, y: 0.35, z: 0))
                        .rotationEffect(.degrees(time * speed))
                }

                // Core.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(colors.first ?? .white).opacity(0.9), .clear],
                            center: .center,
                            startRadius: 1,
                            endRadius: 46
                        )
                    )
                    .frame(width: 84, height: 84)
                    .scaleEffect(1 + 0.08 * sin(time * 1.6))

                Image(systemName: "sparkle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.Palette.starlight)
                    .opacity(0.75 + 0.25 * sin(time * 2.2))
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

#Preview {
    AnalyzingView(modality: .palm) {}
        .preferredColorScheme(.dark)
}
