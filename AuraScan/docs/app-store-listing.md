# App Store Connect — listing copy

Paste-ready. Character limits are Apple's; counts are verified in
`docs/check-listing-lengths.py`.

The whole listing deliberately leads with **four distinct traditions**, and with
the space/Feng Shui reading in particular, because that is what separates
AuraScan from the hundreds of horoscope apps. Guideline 4.3 (spam) is the main
rejection risk in this category, and a listing that opens with "astrology app"
invites it.

---

## App name (30 max)

```
AuraScan: Palm & Face Reading
```

If taken, in order of preference:

```
AuraScan — Readings You Can See
AuraScan: Four Readings
AuraScan Readings
```

> Check availability first. The name must be unique across the App Store, and a
> rejected name costs a full review cycle.

## Subtitle (30 max)

```
Face, palm, cup and space
```

## Promotional text (170 max — editable without a new build)

```
Four traditions, one camera. Read a face, a palm, the grounds in a coffee cup, or the energy of a room — with guidance you can actually act on today.
```

## Keywords (100 max, comma-separated, no spaces after commas)

```
palmistry,palm reading,face reading,tasseography,coffee cup,feng shui,vastu,chiromancy,aura,fortune
```

> Do not repeat words already in the name or subtitle — Apple indexes those
> separately, so repeating them wastes the 100 characters.

## Description (4000 max)

```
AuraScan reads what is actually in front of you.

Point your camera at a face, an open palm, the grounds left in a coffee cup, or the room you work in. AuraScan interprets what it sees through the tradition that belongs to it, and gives you back something specific — not a horoscope that would fit anyone.

FOUR TRADITIONS, NOT ONE

Face reading — physiognomy and its planetary correspondences. The breadth of a forehead reads as Jupiter's field; a held jaw reads as Mars storing effort. Zone by zone, from brow to chin.

Palm reading — chiromancy. The four major lines, the mounts of Venus, Moon and Jupiter, and the elemental shape of the hand itself. Depth, slope and crossing all carry meaning.

Coffee cup reading — tasseography. The cup is a clock as well as a map: the rim is the next few days, the walls the coming weeks, the base the roots of the matter, the handle you yourself.

Space and energy — Feng Shui and Vastu Shastra. Your desk, bedroom or living room read for command position, flow, natural light, clutter and the balance of the five phases. This one is genuinely useful: most readings end with furniture you can move today.

WHAT YOU GET BACK

• A dominant element — fire, earth, air or water — with the full balance between them
• Every marker found, with what is visible in the image kept separate from what the tradition makes of it
• A spatial breakdown, zone by zone, scored and explained
• Guidance tied to specific markers, not generic advice — things to do now, today, and this week
• Your full reading history, kept on your device

OBSERVATION BEFORE INTERPRETATION

Every marker names something actually visible in your photo. AuraScan tells you what it saw, then what the tradition says about it, and keeps the two apart. If the light is poor or the subject is unclear, it says so and lowers its confidence rather than inventing detail.

PRIVATE BY DEFAULT

There are no accounts. AuraScan never asks your name or email. Your readings and photos are stored only on your iPhone — we cannot see them. The single image you choose to analyse is sent for interpretation and is never retained.

AuraScan is for reflection and entertainment. Readings are not medical, psychological, legal or financial advice, and are never a substitute for a qualified professional.
```

## What's New (first version)

```
First release. Four readings — face, palm, coffee cup, and the space around you.
```

---

## In-app purchases

Display name (30 max) and description (45 max) for each.

| Product ID | Display name | Description |
|---|---|---|
| `ai.aurascan.pro.monthly` | `AuraScan Pro — Monthly` | `Unlimited readings in every tradition.` |
| `ai.aurascan.pro.annual` | `AuraScan Pro — Yearly` | `Unlimited readings. Best value.` |
| `ai.aurascan.pro.lifetime` | `AuraScan Pro — Lifetime` | `Pay once. Unlimited readings, forever.` |

Each needs a review screenshot of the paywall. Use shot 9 below.

---

## App Review notes

**Paste this into "Notes" on the submission.** A reviewer who does not know
they need to photograph something may conclude the app does nothing and reject
it for completeness. This is the single highest-value field in the submission.

```
No account or login is required — the app works immediately on launch.

HOW TO TEST A READING
1. Tap any of the four cards on the home screen.
2. The camera opens with an alignment guide. Point it at the matching subject:
   • Face Reading — any face, including your own with the front camera
   • Palm Reading — an open palm, fingers slightly spread
   • Coffee Cup — any cup; a drained cup with grounds gives the richest result
   • Space & Energy — any desk, office or room, shot wide
   You can also tap the photo icon to pick an existing photo from the library
   instead of using the camera.
3. Tap the shutter, then "Read this image".
4. The reading takes about 20 seconds and is saved to history automatically.

Any photo works. The app will produce a reading from a face, hand, cup or room
even in poor lighting — it simply reports lower confidence and says what was
wrong with the image.

ABOUT THE CONTENT
AuraScan interprets images through four traditional practices: physiognomy,
chiromancy, tasseography, and Feng Shui / Vastu Shastra. It is presented as
reflection and entertainment. The app explicitly states on the results screen
and in Settings that readings are not medical, psychological, legal or
financial advice. The model is instructed never to infer age, gender,
ethnicity or health, and never to predict illness, death, or legal or
financial outcomes.

PRIVACY
There are no accounts and no personal data is collected. The single image
chosen for a reading is sent over HTTPS to our server for interpretation and
is not retained there; only a token count and timestamp are recorded. Readings
and photos are stored locally on the device.

IN-APP PURCHASE
The paywall appears after the free readings are used, and is also reachable any
time from Settings → AuraScan Pro → See plans.
```

---

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | *host `docs/privacy-policy.md`, then paste here and into `LegalLinks.swift`* |
| Support URL | *same page is acceptable if it carries a contact address* |
| Marketing URL | optional — leave blank |
| EULA | Use Apple's standard EULA (matches `LegalLinks.termsOfUse`) |

## Category and rating

- **Primary category:** Lifestyle
- **Secondary category:** Entertainment
- **Age rating:** answer the questionnaire honestly. There is no violence,
  no sexual content, no gambling and no horror. Expect 4+.

> Lifestyle over Entertainment as primary because the space/Feng Shui reading is
> genuinely actionable. If Lifestyle review proves hostile to the fortune-telling
> framing, Entertainment is the safer resubmission.

---

## Screenshots — required set

Nine shots. See `LAUNCH.md` §1 for capture instructions; these need real
photographs of a real person and a real cup.

| # | Screen | Suggested caption |
|---|---|---|
| 1 | Dashboard, history populated | Four traditions. One camera. |
| 2 | Face capture, guide aligned | Line up, and hold still. |
| 3 | Face reading result | Zone by zone, brow to chin. |
| 4 | Palm capture | Your dominant hand, fingers open. |
| 5 | Palm reading result | Lines, mounts, and the shape of the hand. |
| 6 | Coffee cup capture | Shoot straight down into the cup. |
| 7 | Coffee reading, zones expanded | The rim is days. The base is roots. |
| 8 | Space reading result | Move the furniture, change the room. |
| 9 | Paywall | — (also used as the IAP review screenshot) |
