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

- ☐ **Privacy manifest.** There is no `PrivacyInfo.xcprivacy` in the target.
  Required because the app uses required-reason APIs — `UserDefaults`
  (`CA92.1`) in `DefaultsEntitlementStore`, plus file-timestamp and disk-space
  APIs via SwiftData's store. Must also declare that no data is used for
  tracking. *I can write this file — ask.*
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
- ☐ **Privacy policy URL** and **support URL**. Both are required fields.
  The privacy policy must cover: photos sent to your relay for analysis, the
  per-install device identifier, and purchase status.
- ☐ **Real screenshots** at the required iPhone sizes (App Store Connect lists
  the current set). `Design/Screens/*.png` are design mockups, not captures —
  usable as a layout reference, but shipping them as screenshots misrepresents
  the app and is rejectable. Capture real ones from a device or simulator.

---

## 2. Blocks approval

Things a reviewer will reject.

- ☐ **Paywall is missing Apple's required subscription disclosures**
  (guideline 3.1.2). `PaywallView` has the auto-renew sentence but **no links to
  Terms of Use (EULA) and Privacy Policy**, which must be on the paywall screen
  itself. Also show, per plan: subscription name, length, and price per period.
  This is one of the most common IAP rejections. *I can fix the view — ask.*
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
