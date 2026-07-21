# My Pregnancy 💗💜

**An AI pregnancy companion with scan reading — and best-in-class twin support.**
*"Photograph your scan. Understand your pregnancy."*

My Pregnancy is a local-first Flutter app for expecting parents — with a
standout feature no mainstream pregnancy app does properly: **twins**. Chorionicity
(DCDA / MCDA / MCMA) drives the whole app — scan schedules, arrival windows,
growth comparison and discordance flags — and an AI scan reader turns photos of
ultrasound reports into structured, per-baby data.

## Features (v2.0)

**Tracking**
- Pregnancy setup for singletons and twins, with chorionicity-aware timeline,
  scan schedule and typical arrival window
- Dashboard: gestational age, per-baby cards, weekly development & tips
- Symptom journal, weight, water, blood pressure (with high-reading flags)
- Kick counter (count-to-10, per baby for twins) with a daily reminder
- Contraction timer with 5-1-1 pattern awareness
- Medicine & appointment reminders (local notifications)
- Hospital bag checklist (twin-specific variant), warning-signs reference
- "Babies have arrived" mode — winds down reminders, keeps every record

**AI scan reading (bring your own Azure key)**
- One tap from home: photograph report pages (multi-page supported) → per-baby
  biometry (EFW, HC, AC, FL, BPD, FHR), placenta, liquor, Doppler
- Auto-tiling defeats Azure's image downscaling; pages read in parallel and
  merged in code with weight-fingerprint label reconciliation
- Twin EFW discordance computed locally (never by the model), 20% guardrail
- Growth view: per-baby weight curves across scans, deltas, discordance trend
- Extraction-only guardrails: no diagnosis, no reassurance, null-over-guess

**Data**
- 100% local-first: no accounts, no backend, nothing leaves the phone except
  AI calls to *your own* Azure endpoint (key stored in the platform keystore)
- Full backup export/import (JSON via share sheet)
- Doctor-visit summary: latest scan, weights, BP, meds as shareable text

## Getting started

```bash
flutter pub get
flutter run                     # device/emulator
flutter test                    # 15 tests; live AI tests need env vars
flutter build apk --release     # signed via android/key.properties
```

AI setup (in-app): **More → AI scan reading** — paste your Azure AI Foundry
endpoint, a vision-capable deployment name (gpt-4o / gpt-5 family), and an API
key. Verify with *Test connection*.

Live AI regression tests:

```powershell
$env:AZURE_OPENAI_ENDPOINT   = "https://<resource>.services.ai.azure.com"
$env:AZURE_OPENAI_DEPLOYMENT = "gpt-5"
$env:AZURE_OPENAI_API_KEY    = "<key>"
$env:SCAN_TEST_IMAGE  = "path\to\report-page1.jpg"
$env:SCAN_TEST_IMAGE2 = "path\to\report-page2.jpg"
flutter test test/tools/live_scan_reader_test.dart
```

`tools/scan-poc/` holds the standalone Node prototype of the extractor
(Anthropic + Azure providers) used to validate prompts before the Dart port.

## Medical disclaimer

BumpBuddy is educational and organizational software. It transcribes what your
reports print and computes arithmetic on it — it does not diagnose, treat, or
replace medical advice. All schedules shown are typical patterns; the treating
doctor's plan always takes precedence.

## Roadmap

Backend proxy + premium tier (keys server-side, metered AI reads), partner
mode, AI explanations of report terminology, doctor dashboard. See
[PLAN.md](PLAN.md).
