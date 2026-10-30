# AuraScan — Privacy Policy

**Last updated:** 30 October 2026

AuraScan takes a photo you choose, has it interpreted, and shows you a reading.
This policy describes exactly what that involves. It is written to match what
the app and its server actually do; if the code changes, this changes with it.

AuraScan has no accounts. We never ask for your name, email or phone number,
and we have no way to identify you.

---

## What leaves your device

**The photo you choose to analyse.** When you tap to take a reading, that one
image is resized and sent over an encrypted connection to our server, which
passes it to Anthropic's Claude API for interpretation. The result comes back
and is shown to you.

The image is held only in memory for the length of that request. **We do not
store your photos.** Our database records only the time of the reading and how
many tokens it used, so we can meter usage and bill ourselves — never the
image, and never the reading's contents.

Anthropic processes the image to generate the reading. Their handling is
governed by their own commercial terms and privacy policy.

**A random per-install identifier.** When you first open AuraScan it generates a
random identifier. It is not your device's serial number, advertising
identifier, or anything Apple assigns — it is a value we make up, and it cannot
be connected to you or to any other app. Our server uses it to count how many
readings an install has taken and to remember whether it has a subscription.
Deleting and reinstalling the app produces a new one.

**Your subscription status.** If you subscribe, Apple gives the app a signed
receipt which is sent to our server to verify the purchase. We record only
whether the install is subscribed. We never receive your payment details,
Apple Account, or billing address — Apple handles all of that.

---

## What stays on your device

Every reading you take — the photo, the full interpretation, the date — is
stored **only on your iPhone**, in the app's private storage. It is not uploaded,
backed up to us, or readable by us. Deleting a reading in the app deletes it.
Deleting the app deletes all of them.

Your preferences (chosen provider, model, free readings used) are stored on the
device in standard iOS preferences.

---

## What we do not do

- We do not track you, across apps or anywhere else.
- We do not use any analytics, advertising or attribution service.
- We do not sell, rent or share your data with anyone, for any purpose.
- We do not build a profile of you. We could not — there is nothing to attach
  one to.
- We do not use your photos to train any model.

---

## Camera and photo access

AuraScan asks for camera access so you can photograph a face, palm, coffee cup
or room. It asks for photo library access only if you choose to pick an existing
photo instead. You can refuse either, or change your mind later in iOS Settings;
the app works with whichever you allow.

Only the single image you choose to analyse is ever sent anywhere. The app does
not read your photo library, and takes nothing in the background.

---

## Children

AuraScan is not directed at children and collects nothing that could identify
anyone of any age.

---

## Your choices

Because we hold nothing that identifies you, there is no account to close and no
personal data to request or correct. To remove everything AuraScan has about
you: delete the app. That erases every stored reading and the per-install
identifier together.

If you would like the usage rows for your install removed from our server,
email the address below with the install identifier shown in the app's Settings,
and we will delete them.

---

## Readings are not advice

AuraScan draws on physiognomy, tasseography, chiromancy, Feng Shui and Vastu
Shastra. These are interpretive traditions, offered for reflection and
entertainment. Readings are **not** medical, psychological, legal or financial
advice, and are never a substitute for a qualified professional.

---

## Changes

If this policy changes materially, the updated date above will change and the
new version will be published at this URL before the change takes effect.

---

## Contact

**Email:** meetjethwa3@gmail.com

<!--
  TO PUBLISH: host this at a stable public URL (GitHub Pages off this repo is
  enough), then put that URL in:
    1. AuraScan/Core/LegalLinks.swift  → privacyPolicy
    2. App Store Connect → App Privacy → Privacy Policy URL
  Replace the support URL in LegalLinks too, or point it at the same page.
-->
