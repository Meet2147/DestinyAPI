# AuraScan — launch checklist

State as of 2 Oct 2026. Grouped by what actually stops you, in order.

Legend: ☐ not done · ☑ done · ⚠ decision needed

---

## 0. Unblock your own use first

The client-side paywall is off (`BillingMode.unlimitedReadings = true`), **but the
relay enforces the same seven-reading limit server-side**, keyed by device. You
will get HTTP 402 "Free readings used" from the relay even with the app flag on.

- ☐ On Render → `aurascan-relay` → Environment, set `FREE_READINGS` to `1000000`.
  Takes effect on restart, no deploy. Set it back to `7` at launch.
- ☐ Note `RATE_LIMIT_PER_HOUR=20` and `RATE_LIMIT_PER_DAY=60` also apply to you.
  Raise them if you are testing in bursts.

---

## 1. Blocks submission

Things that stop the build uploading, or get it bounced before a human looks.

- ☑ **Privacy manifest** — `AuraScan/Resources/PrivacyInfo.xcprivacy` added and
  wired into the Resources build phase. Declares `UserDefaults` (`CA92.1`),
  file timestamp (`C617.1`), disk space (`E174.1`), and the three collected
  data types. **Its answers must match the App Privacy form in App Store
  Connect exactly** — see section 2.
- ☐ **App record in App Store Connect** for bundle ID `ai.aurascan.app`.
  `DEVELOPMENT_TEAM` is already set to `C9NLF34677`, so the account exists.
- ☐ **Paid Apps agreement, banking and tax forms.** In-app purchases cannot be
  reviewed or sold until these are accepted and complete. This is the step that
  most often silently blocks a first paid launch — do it early, bank
  verification is not instant.
- ☐ **Create the three IAP products** in App Store Connect with IDs matching
  `Entitlements.SubscriptionProduct` exactly:
  - `ai.aurascan.pro.monthly` — auto-renewable, $4.99/mo
  - `ai.aurascan.pro.annual` — auto-renewable, $49.99/yr
  - `ai.aurascan.pro.lifetime` — non-consumable, $149
  Each needs a display name, description, review screenshot, and must be
  submitted **with** the first build, not after it.
- ☐ **Privacy policy URL** and **support URL** — both required fields.
  A policy drafted against what the code actually does is at
  `docs/privacy-policy.md`; host it and paste the URL in both places.
- ☐ **Real screenshots, with real faces, hands and cups.** ← *you flagged this*

  `Design/Screens/*.png` are design mockups with illustrated subjects. They are
  a layout reference only — shipping them misrepresents the app and is
  rejectable. **Only you can produce these**, because they need genuine photos
  of a real person, and nobody here can generate those.

  What to capture, on a real iPhone (not the simulator — the camera path and
  real photos are the point):

  | # | Screen | Subject |
  |---|--------|---------|
  | 1 | Dashboard with 3–4 real readings in history | — |
  | 2 | Face capture, oval guide aligned | a real face, well lit |
  | 3 | Face reading result, scrolled to the summary | same face |
  | 4 | Palm capture, hand guide aligned | a real open palm |
  | 5 | Palm reading result | same palm |
  | 6 | Coffee capture, shot down into the cup | a real drained cup with grounds |
  | 7 | Coffee reading result, zone breakdown expanded | same cup |
  | 8 | Space reading result | a real desk or room |

  Practical notes:
  - **Get written permission** from anyone whose face or hands appear. Apple
    does not ask for it, but you are publishing their likeness commercially.
    Your own face and hands are the simplest answer.
  - Shoot in good even light; the reading quality visibly depends on it, and a
    poor capture produces a low-confidence reading that reads badly in a
    screenshot.
  - Take the readings first so history is populated for shot 1.
  - Capture with Volume Up + Side button, then AirDrop to the Mac.
  - Sizes: App Store Connect lists the currently required iPhone display sizes.
    A 6.9" set (1320×2868 or 1290×2796) generally covers the rest by scaling.
  - Check each shot for anything personal in the status bar or reflected in the
    cup before uploading.

  Once you have the raw captures, I can crop, size and add caption frames if
  you want a polished set — send them over.

---

## 2. Blocks approval

Things a reviewer will reject.

- ☑ **Paywall disclosures** — Terms of Use and Privacy Policy links now sit on
  the purchase screen, and each plan states its name, period length and price
  per period (`SubscriptionProduct.disclosure`).
- ☐ **…but the URLs are still placeholders.** `Core/LegalLinks.swift` points at
  `example.com`. A dead link here is a guaranteed rejection. Host
  `docs/privacy-policy.md` (GitHub Pages off this repo is enough), then set
  `privacyPolicy` and `support`. A DEBUG build prints a warning at launch while
  they are unset. Terms of Use already points at Apple's standard EULA, which
  is valid — select that same EULA in App Store Connect.
- ☑ **Restore purchases** — present and required.
- ☐ **App Privacy "nutrition label."** Declare honestly:
  - Photos → *collected, not linked to identity, used for App Functionality.*
    The relay does not retain images (`relay/app/models.py` stores only token
    counts and timestamps) — say so in the policy, but the photo is still
    transmitted, so it is still "collected" in Apple's sense.
  - Device ID → *collected, linked, App Functionality* (the relay keys
    entitlement off a per-install identifier).
  - Purchases → *collected, linked.*
  - Nothing is used for tracking. Confirm no analytics SDK gets added later.
- ☐ **Age rating questionnaire.** Answer for the fortune-telling framing.
- ☐ **App Store description** should carry the same entertainment framing the
  app does ("for reflection and entertainment, not advice"), to pre-empt a
  false-claims reading under 1.1.6.
- ⚠ **Guideline 4.3 (spam) risk.** Astrology/fortune-telling is a crowded
  category and 4.3 rejections are common there. The four-modality span —
  especially the Feng Shui/Vastu room analysis — is the genuine differentiator;
  lead the description with it rather than with "astrology app."
- ☑ Account deletion — not applicable, there are no accounts.
- ☑ Export compliance — `ITSAppUsesNonExemptEncryption` is `false`, correct for
  standard HTTPS.
- ☑ App icon — 1024 primary has no alpha channel; dark and tinted variants are
  correctly RGBA.

---

## 3. Production readiness

Works today, breaks after launch.

- ☐ **Render Postgres is on `plan: free`** (`relay/render.yaml`), which expires
  after ~30 days. When it goes, you lose the device table: every user's free
  count resets and every subscriber flag is lost until their next receipt check.
  Upgrade before you take real users.
- ☐ **No backup** of the device/entitlement table.
- ☐ **`region: singapore`** — fine for you, adds latency elsewhere. Decide based
  on where you launch.
- ☐ **Daily spend cap is $50**, at an assumed $0.0092/reading ≈ 5,400
  readings/day. Sanity-check that ceiling against what you can afford to lose
  in a bad day, because it is the only thing between you and a runaway bill.
- ☐ **Test on a real device** and ship a **TestFlight** build before submitting.
  The camera path in particular has never run on real hardware.
- ☐ **Run the test suite** (`./bootstrap.sh --test`). Current pass state unknown
  to me; there is no CI.

---

## 4. Decisions to make

- ⚠ **Model: the relay pins `claude-haiku-4-5`.** Nuanced multimodal
  interpretation is the product — Haiku will do it, Opus will do it better. At
  ~$0.0092/reading on Haiku, Opus is roughly 5× that. Worth A/B-ing on your own
  readings before launch, because reading quality is the whole retention story.
- ⚠ **Pricing.** $149 lifetime against $49.99/yr means lifetime pays back in
  three years. That is a fine ratio, but lifetime on a product with a per-use
  server cost is a permanent liability — every lifetime user costs you Anthropic
  spend forever. Consider dropping lifetime, or pricing it higher.
- ⚠ **Free tier size.** Seven readings is generous for a product with a real
  marginal cost (~7¢ of API spend per free user, more if they are not converted).

---

## 5. Who does what

**Only you can do:** everything in App Store Connect (app record, agreements,
banking, IAP products, privacy label, age rating, screenshots upload), the
Render dashboard changes, device/TestFlight testing, and the pricing decisions.

**I can do, on request:** the privacy manifest, the paywall disclosure fix,
a privacy policy draft, App Store description and keyword copy, the relay
config changes, and raising the model back to Opus.
