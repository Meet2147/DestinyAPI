//
//  SampleData.swift
//  AuraScan
//
//  Canned readings for previews, the stub analyzer and snapshot tests. These
//  are also useful as a reference for what a well-formed model response looks
//  like when tuning the prompts.
//

import Foundation

extension AnalysisResponse {
    static func sample(for modality: ModalityType) -> AnalysisResponse {
        switch modality {
        case .face: .sampleFace
        case .coffee: .sampleCoffee
        case .palm: .samplePalm
        case .space: .sampleSpace
        }
    }

    static let sampleFace = AnalysisResponse(
        modality: .face,
        confidence: 0.78,
        imageQuality: .acceptable,
        headline: "A Jupiter-bright brow over a set Mars jaw",
        summary: """
        The upper face carries most of the light here: a broad, unlined forehead reads as \
        room to think and a genuine appetite for the long view. Below it, the jaw is held — \
        Mars is doing work that the brow has not yet been asked to plan. The eyes are steady \
        but the tissue beneath them is soft, which the tradition reads as lunar reserves \
        running thinner than usual. Taken together this is a chart for a person carrying a \
        big idea and a clenched schedule at the same time. The resolution is not more effort; \
        it is letting the forehead's Jupiter set the pace the jaw is currently setting alone.
        """,
        dominantElement: .fire,
        elementBalance: [
            ElementScore(element: .fire, score: 38),
            ElementScore(element: .earth, score: 27),
            ElementScore(element: .air, score: 22),
            ElementScore(element: .water, score: 13),
        ],
        energyScore: 68,
        markers: [
            Marker(
                id: "broad-forehead",
                name: "Broad, unlined forehead",
                zone: "forehead",
                observation: "The forehead is wide and high with no strong horizontal creasing, evenly lit across its width.",
                interpretation: "Jupiter's zone is open. Expansive thinking, teaching instinct, and a natural pull toward the long horizon rather than the immediate task.",
                element: .fire,
                planet: .jupiter,
                polarity: .supportive,
                intensity: 4,
                boundingBox: NormalizedRect(x: 0.24, y: 0.08, width: 0.52, height: 0.18)
            ),
            Marker(
                id: "set-jaw",
                name: "Held jaw line",
                zone: "jaw",
                observation: "The masseter is visibly engaged and the jaw line is sharply defined even at rest.",
                interpretation: "Mars is storing effort here. Endurance is available, but it is being spent on holding rather than moving.",
                element: .earth,
                planet: .mars,
                polarity: .challenging,
                intensity: 3,
                boundingBox: NormalizedRect(x: 0.2, y: 0.62, width: 0.6, height: 0.2)
            ),
            Marker(
                id: "soft-under-eye",
                name: "Softness beneath the eyes",
                zone: "eyes",
                observation: "The tissue under both eyes is slightly shadowed and full.",
                interpretation: "Lunar reserves are low — the receptive, replenishing side of the chart has been running on borrowed time.",
                element: .water,
                planet: .moon,
                polarity: .challenging,
                intensity: 3,
                boundingBox: NormalizedRect(x: 0.26, y: 0.4, width: 0.48, height: 0.1)
            ),
            Marker(
                id: "lifted-cheeks",
                name: "Lifted, warm cheeks",
                zone: "cheeks",
                observation: "Both cheeks carry colour and sit high.",
                interpretation: "Venus is well-resourced: social warmth and the capacity to be met halfway are both available today.",
                element: .fire,
                planet: .venus,
                polarity: .supportive,
                intensity: 3,
                boundingBox: nil
            ),
        ],
        zones: [
            ZoneInsight(zone: "forehead", label: "Forehead — Jupiter's field", timeframe: "Vision and the coming season", summary: "Open and bright. The best decisions today are the ones made at altitude.", score: 82, element: .fire),
            ZoneInsight(zone: "eyes", label: "Eyes — Sun and Moon", timeframe: "Present vitality", summary: "Solar output steady, lunar replenishment overdrawn.", score: 55, element: .water),
            ZoneInsight(zone: "jaw", label: "Jaw — Mars and Saturn", timeframe: "Where effort is stored", summary: "Tension held rather than discharged. This is the release point.", score: 44, element: .earth),
            ZoneInsight(zone: "cheeks", label: "Cheeks — Venus", timeframe: "Social and material warmth", summary: "Well-resourced; lean on people today rather than around them.", score: 74, element: .fire),
        ],
        guidance: DayGuidance(
            focus: "Let the forehead lead and the jaw follow — plan before you push.",
            affirmation: "I set the pace at the height where I can see the whole road.",
            actions: [
                ActionTip(title: "Unclench, deliberately", detail: "Three times today, notice the jaw and let it drop. The Mars marker is the most actionable thing in this reading.", horizon: .now),
                ActionTip(title: "Give the big idea an hour", detail: "The Jupiter brow is asking for altitude. Block one uninterrupted hour for the long-horizon piece before the day fragments.", horizon: .today),
                ActionTip(title: "Refill the lunar side", detail: "One early night this week. The under-eye softness is the reading's clearest deficit.", horizon: .week),
            ],
            cautions: ["Don't mistake the held jaw for productivity.", "Avoid committing to a second big obligation this week."],
            luckyColor: LuckyColor(name: "Amber", hex: "#E7C56B"),
            luckyNumber: 3,
            favorableWindow: "Late morning, between 10am and noon",
            ritual: "Wash the face with cool water at dusk and let the jaw stay loose for the length of one slow breath."
        )
    )

    static let sampleCoffee = AnalysisResponse(
        modality: .coffee,
        confidence: 0.71,
        imageQuality: .acceptable,
        headline: "A bird at the rim, heavy sediment at the base",
        summary: """
        News is arriving before the underlying matter is settled. The clearest form in the \
        cup is a winged shape right at the rim — a message or an arrival within days. But the \
        base carries thick, dark sediment: whatever is being answered has roots that have not \
        been worked through. Near the handle the grounds are thin and clear, which reads as \
        the querent themselves being unencumbered and free to move. The reading is favourable \
        for receiving, cautious about concluding.
        """,
        dominantElement: .air,
        elementBalance: [
            ElementScore(element: .fire, score: 18),
            ElementScore(element: .earth, score: 30),
            ElementScore(element: .air, score: 37),
            ElementScore(element: .water, score: 15),
        ],
        energyScore: 62,
        markers: [
            Marker(id: "rim-bird", name: "Bird at the rim", zone: "rim", observation: "A distinct winged shape with a narrow head sits on the rim at roughly the two-o'clock position.", interpretation: "News in motion. Arriving within days, and arriving toward you rather than requiring pursuit.", element: .air, planet: .mercury, polarity: .supportive, intensity: 5, boundingBox: NormalizedRect(x: 0.58, y: 0.12, width: 0.16, height: 0.14)),
            Marker(id: "base-sediment", name: "Heavy sediment across the base", zone: "base", observation: "The base is covered in a thick, unbroken dark deposit with no clear areas.", interpretation: "The foundation of this matter is unresolved. Outcomes reached now would rest on ground that has not been examined.", element: .earth, planet: .saturn, polarity: .challenging, intensity: 4, boundingBox: NormalizedRect(x: 0.3, y: 0.66, width: 0.42, height: 0.26)),
            Marker(id: "clear-handle", name: "Clear ground by the handle", zone: "handle", observation: "The area immediately adjacent to the handle is nearly free of grounds.", interpretation: "The querent is personally unencumbered — freedom of movement is genuinely available right now.", element: .air, planet: nil, polarity: .supportive, intensity: 3, boundingBox: nil),
            Marker(id: "wall-fork", name: "Forking line on the upper wall", zone: "upper-wall", observation: "A thin line runs up the wall and splits into two near the rim.", interpretation: "A decision with two live branches inside the next few weeks. Neither branch is marked as the wrong one.", element: .air, planet: .mercury, polarity: .neutral, intensity: 3, boundingBox: nil),
        ],
        zones: [
            ZoneInsight(zone: "rim", label: "Rim — the next few days", timeframe: "Days", summary: "Active and favourable. Something is already on its way to you.", score: 80, element: .air),
            ZoneInsight(zone: "upper-wall", label: "Upper wall — the coming weeks", timeframe: "2–4 weeks", summary: "A fork. Gather before choosing; the reading does not mark a wrong branch.", score: 60, element: .air),
            ZoneInsight(zone: "base", label: "Base — roots and outcomes", timeframe: "Months, and the underlying cause", summary: "Dense and unresolved. Do not force a conclusion from here yet.", score: 35, element: .earth),
            ZoneInsight(zone: "handle", label: "Handle — you", timeframe: "The self, now", summary: "Clear and mobile. You are not the obstacle in this matter.", score: 78, element: .air),
        ],
        guidance: DayGuidance(
            focus: "Receive the news before you decide anything with it.",
            affirmation: "I can welcome what arrives without concluding what it means.",
            actions: [
                ActionTip(title: "Answer the message", detail: "The rim bird is the strongest marker in the cup. Whatever arrives in the next few days, respond to it rather than letting it sit.", horizon: .now),
                ActionTip(title: "Name the two branches", detail: "Write down the fork on the upper wall as two explicit options. It reads as much smaller once it is on paper.", horizon: .today),
                ActionTip(title: "Go back to the root", detail: "The base sediment says a foundational conversation has been skipped. Have it before committing.", horizon: .week),
            ],
            cautions: ["Don't sign or conclude anything that depends on the unexamined foundation."],
            luckyColor: LuckyColor(name: "Copper", hex: "#B87333"),
            luckyNumber: 7,
            favorableWindow: "Early evening",
            ritual: "Rinse the cup outdoors and let the grounds go into soil rather than the drain."
        )
    )

    static let samplePalm = AnalysisResponse(
        modality: .palm,
        confidence: 0.74,
        imageQuality: .acceptable,
        headline: "An air hand with a deep, sloping head line",
        summary: """
        A square palm with long fingers puts this hand firmly in the air family — thought, \
        language and exchange are the native medium here. The head line is both deep and \
        sloping, an unusual pairing: sustained focus applied to imaginative rather than \
        literal material. The heart line runs high and fairly straight, which reads as \
        contained, loyal affection rather than demonstrative warmth. The life line's arc is \
        wide and unbroken, giving the whole hand a steady base to work from.
        """,
        dominantElement: .air,
        elementBalance: [
            ElementScore(element: .fire, score: 17),
            ElementScore(element: .earth, score: 21),
            ElementScore(element: .air, score: 44),
            ElementScore(element: .water, score: 18),
        ],
        energyScore: 73,
        markers: [
            Marker(id: "air-hand", name: "Square palm, long fingers", zone: "palm-shape", observation: "The palm is approximately as wide as it is long, with fingers longer than the palm's height.", interpretation: "An air hand: analysis, language and exchange are where this hand does its best work.", element: .air, planet: .mercury, polarity: .supportive, intensity: 5, boundingBox: nil),
            Marker(id: "deep-sloping-head", name: "Deep, sloping head line", zone: "head-line", observation: "The head line is clearly incised and angles down toward the outer palm.", interpretation: "Focus applied to imaginative material. Depth says stamina of attention; the slope says the attention prefers the associative over the literal.", element: .air, planet: .mercury, polarity: .supportive, intensity: 4, boundingBox: NormalizedRect(x: 0.22, y: 0.42, width: 0.5, height: 0.14)),
            Marker(id: "high-heart", name: "High, straight heart line", zone: "heart-line", observation: "The heart line runs high across the palm with little upward curve.", interpretation: "Affection that is contained and steady rather than openly demonstrative. Loyalty over display.", element: .water, planet: .venus, polarity: .neutral, intensity: 3, boundingBox: nil),
            Marker(id: "wide-life-arc", name: "Wide, unbroken life line arc", zone: "life-line", observation: "The life line sweeps in a broad curve around the thumb ball with no visible breaks.", interpretation: "Expansive vitality and a wide field of circumstance. This says nothing about length of life — only about room to move.", element: .earth, planet: .sun, polarity: .supportive, intensity: 4, boundingBox: nil),
            Marker(id: "full-moon-mount", name: "Full mount of the Moon", zone: "mount-of-moon", observation: "The outer edge of the palm below the little finger is noticeably raised.", interpretation: "Strong imaginative and intuitive current, and a real pull toward travel or unfamiliar material.", element: .water, planet: .moon, polarity: .supportive, intensity: 3, boundingBox: nil),
        ],
        zones: [
            ZoneInsight(zone: "palm-shape", label: "Hand shape — Air", timeframe: "Disposition", summary: "Square palm, long fingers. Thought and language are the native tools.", score: 85, element: .air),
            ZoneInsight(zone: "head-line", label: "Head line — how you think", timeframe: "Current method", summary: "Deep and sloping: sustained attention on imaginative material.", score: 80, element: .air),
            ZoneInsight(zone: "heart-line", label: "Heart line — how you attach", timeframe: "Emotional season", summary: "Contained and loyal. Warmth is present but not performed.", score: 62, element: .water),
            ZoneInsight(zone: "life-line", label: "Life line — vitality and room", timeframe: "Constitution", summary: "Wide arc, unbroken. A steady base underneath the rest.", score: 78, element: .earth),
        ],
        guidance: DayGuidance(
            focus: "Give the air hand something worth thinking about.",
            affirmation: "My attention is a resource; today I spend it on what deserves depth.",
            actions: [
                ActionTip(title: "Write the thing down", detail: "The deep head line rewards sustained, single-subject attention. Pick one idea and give it a full page.", horizon: .today),
                ActionTip(title: "Say the warm thing out loud", detail: "The heart line is contained by nature. One explicit expression of affection today does more than usual.", horizon: .today),
                ActionTip(title: "Feed the Moon mount", detail: "Unfamiliar input — a new route, a new author, a different room to work in.", horizon: .week),
            ],
            cautions: ["Air hands over-research. At some point the reading says to decide."],
            luckyColor: LuckyColor(name: "Pale aqua", hex: "#5EE7DF"),
            luckyNumber: 5,
            favorableWindow: "Mid-morning",
            ritual: "Open and close the hand slowly ten times before starting focused work."
        )
    )

    static let sampleSpace = AnalysisResponse(
        modality: .space,
        confidence: 0.69,
        imageQuality: ImageQuality(
            usable: true,
            issues: ["The north-east corner is cropped out of frame"],
            suggestion: "Re-shoot from the doorway to include all four corners."
        ),
        headline: "Good light, wrong chair — the desk has no back support",
        summary: """
        The room has genuine wood and fire energy: plants near the window and warm lamp light \
        carry most of the vitality here. The critical issue is the workstation. The chair faces \
        a wall with the door behind it and a window at the occupant's back — the reverse of the \
        command position on both counts. The centre of the room is also carrying storage, which \
        Vastu reads as a stalled core. Metal is almost entirely absent, which is why the space \
        feels warm but slightly unresolved. Two furniture moves fix most of this.
        """,
        dominantElement: .earth,
        elementBalance: [
            ElementScore(element: .fire, score: 28),
            ElementScore(element: .earth, score: 34),
            ElementScore(element: .air, score: 16),
            ElementScore(element: .water, score: 22),
        ],
        energyScore: 58,
        markers: [
            Marker(id: "desk-back-to-door", name: "Desk faces wall, back to the door", zone: "workstation", observation: "The desk is pushed against the far wall; the chair's back is to the visible doorway with a window behind it.", interpretation: "The reverse of the command position. Reads as chronic low-grade vigilance and, with a window rather than a wall behind, missing solid backing for one's work.", element: .earth, planet: .saturn, polarity: .challenging, intensity: 5, boundingBox: NormalizedRect(x: 0.55, y: 0.34, width: 0.4, height: 0.4)),
            Marker(id: "center-storage", name: "Storage boxes at the room's centre", zone: "center", observation: "Two stacked boxes and a laundry basket occupy the middle of the floor.", interpretation: "The brahmasthan should stay open and light. A loaded centre reads as a stalled core — projects that start but do not circulate.", element: .earth, planet: .saturn, polarity: .challenging, intensity: 4, boundingBox: NormalizedRect(x: 0.36, y: 0.6, width: 0.24, height: 0.22)),
            Marker(id: "window-greenery", name: "Plants along the window", zone: "greenery", observation: "Three healthy potted plants sit on the sill in direct daylight.", interpretation: "Living wood energy, well placed. This is the strongest positive in the room and should be protected in any rearrangement.", element: .air, planet: .venus, polarity: .supportive, intensity: 4, boundingBox: nil),
            Marker(id: "warm-lamp", name: "Warm lamp light, no overhead glare", zone: "lighting", observation: "A single warm floor lamp lights the room; the ceiling fixture is off.", interpretation: "Balanced fire. Enough warmth to work by without over-firing the space.", element: .fire, planet: .sun, polarity: .supportive, intensity: 3, boundingBox: nil),
            Marker(id: "blocked-walkway", name: "Cable run across the walkway", zone: "airflow", observation: "A power cable crosses the main path between the door and the desk.", interpretation: "A literal and energetic bottleneck on the room's primary circulation path.", element: .air, planet: .mercury, polarity: .challenging, intensity: 2, boundingBox: nil),
        ],
        zones: [
            ZoneInsight(zone: "workstation", label: "Workstation — command position", timeframe: "Daily working state", summary: "Back to the door with a window behind. The single highest-value fix in the room.", score: 30, element: .earth),
            ZoneInsight(zone: "center", label: "Centre — the brahmasthan", timeframe: "The room's core", summary: "Loaded with storage. Clearing it changes how the whole space circulates.", score: 38, element: .earth),
            ZoneInsight(zone: "lighting", label: "Lighting — fire balance", timeframe: "Ambient tone", summary: "Warm and well-judged. Leave it alone.", score: 76, element: .fire),
            ZoneInsight(zone: "greenery", label: "Greenery — wood phase", timeframe: "Growth and air", summary: "Healthy and well-placed. The room's best asset.", score: 84, element: .air),
        ],
        guidance: DayGuidance(
            focus: "Turn the desk. Everything else in this room is already working.",
            affirmation: "I sit where I can see what is coming, with something solid behind me.",
            actions: [
                ActionTip(title: "Rotate the desk 90°", detail: "Put a solid wall behind the chair and the doorway in your peripheral vision. This addresses the strongest marker in the reading.", horizon: .today),
                ActionTip(title: "Clear the centre", detail: "Move the boxes to the south-west, the quadrant that wants weight. The middle of the floor should be empty.", horizon: .today),
                ActionTip(title: "Add one metal object", detail: "Metal is missing entirely — a round white or grey object near the workstation completes the five-phase cycle.", horizon: .week),
                ActionTip(title: "Reroute the cable", detail: "Take it out of the walkway; unblocking the main path is a small fix with an outsized effect.", horizon: .now),
            ],
            cautions: ["Don't move the plants — they are carrying the room."],
            luckyColor: LuckyColor(name: "Slate white", hex: "#E6E8EC"),
            luckyNumber: 8,
            favorableWindow: "Rearrange in daylight, before noon",
            ritual: "Open the window for ten minutes after moving anything, to let the room's air reset."
        )
    )
}
