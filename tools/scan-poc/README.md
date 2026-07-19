# BumpBuddy scan-poc — AI ultrasound-report reader (proof of concept)

A standalone proof of concept for BumpBuddy's twins-first differentiator: given a
**photo or scan of an obstetric growth-scan (ultrasound) report**, extract structured,
**per-baby** biometry — EFW, HC, AC, FL, BPD, FHR, placenta, liquor/AFI, DVP,
umbilical Doppler — and compute the **inter-twin EFW discordance**.

It is a single zero-dependency Node.js script that calls the Claude API
(`claude-opus-4-8`, vision + structured outputs) via the built-in `fetch`.
No SDK, no `npm install`.

**This tool only transcribes what is printed on a report. It performs no diagnosis,
gives no medical advice, and adds no reassurance or alarm.** Values that are absent
or illegible come back as `null` with an explanation in `confidence_notes` — never a guess.

## Requirements

- Node.js 20+ (tested on Node 24)
- A Claude API key (get one at <https://platform.claude.com/> → API Keys)

## Setup

Set the API key in your shell:

**Windows PowerShell**

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."
```

(That sets it for the current session only. To persist it for your user account:
`[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")` — then open a new terminal.)

**bash / zsh**

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

If the key is missing, the script prints these instructions and exits with code 1.

## Usage

```text
node extract.js <image-file> [--twins] [--dry-run]
```

| Argument | Meaning |
|---|---|
| `<image-file>` | Photo/scan of the report. `.jpg` / `.jpeg` / `.png` / `.webp` / `.gif` |
| `--twins` | Hint that this is a twin pregnancy. The model then searches specifically for a second fetus (side-by-side columns, Twin A/B, Fetus 1/2, F1/F2 blocks) — but it will **not** invent a second baby if the report documents only one. |
| `--dry-run` | Print the exact API request (URL, headers, JSON body) with the base64 image bytes redacted, then exit without calling the API. Works without an API key. |

Examples:

```powershell
node extract.js .\scans\growth-scan-32w.jpg --twins
node extract.js .\scans\anomaly-report.png
node extract.js .\scans\growth-scan-32w.jpg --twins --dry-run
```

## Expected output

1. **Pretty-printed JSON** — the extraction result plus a locally computed `derived` block:

```json
{
  "report_date": "2026-06-30",
  "gestational_age_on_report": "32 weeks 4 days",
  "twins_detected": true,
  "babies": [
    {
      "label": "A",
      "presentation": "cephalic",
      "efw_grams": 1897,
      "efw_raw": "1897 +/- 277 gm",
      "hc_mm": 298, "hc_raw": null,
      "ac_mm": 281, "ac_raw": null,
      "fl_mm": 61,  "fl_raw": null,
      "bpd_mm": 82, "bpd_raw": null,
      "fhr_bpm": 142,
      "placenta": "anterior",
      "placenta_grade": "Grade II",
      "liquor_afi_cm": 12.4,
      "dvp_cm": null,
      "umbilical_doppler": "S/D 2.4, PI 0.89, RI 0.58"
    },
    {
      "label": "B",
      "presentation": "breech",
      "efw_grams": 1712,
      "...": "..."
    }
  ],
  "impression": "Dichorionic diamniotic twin gestation of 32w4d ...",
  "flags": ["AFI recorded per sac"],
  "confidence_notes": "DVP not printed for either fetus.",
  "derived": {
    "efw_discordance_percent": 9.8,
    "efw_discordance_clinically_significant": false,
    "efw_discordance_note": "below the 20% threshold commonly used for clinically significant discordance",
    "discordance_threshold_percent": 20
  }
}
```

2. **A human-readable summary table** — one column per baby, one row per metric,
   followed by the discordance line, the report's own impression (verbatim), any
   flags, and confidence notes.

### Discordance calculation

Computed locally by the script (never by the model), when at least two babies have
a numeric EFW:

```
discordance % = (larger EFW − smaller EFW) / larger EFW × 100
```

Values **≥ 20%** are labelled `clinically significant discordance — discuss with doctor`.
The 20% threshold is a commonly used clinical convention, not a diagnosis.

### Field conventions

- Units are normalized: EFW → grams, HC/AC/FL/BPD → mm, AFI/DVP → cm, FHR → bpm.
- Indian radiology conventions are handled: EFW ranges/tolerances ("1897 ± 277 gm"),
  biometry printed as week-equivalents ("HC = 32w4d"), "liquor" for amniotic fluid,
  placental Grade 0–III.
- When a value is ambiguous, ranged, or week-based, the verbatim report text is kept
  in the matching `*_raw` field (`efw_raw`, `hc_raw`, `ac_raw`, `fl_raw`, `bpd_raw`);
  the numeric field is `null` unless a safe unit conversion (cm → mm) was possible.
- Baby labels are normalized to `"A"`, `"B"`, ... in document order regardless of
  whether the report says Twin A/B, Fetus 1/2, F1/F2, or Baby A/B.
- Anything not printed on the report is `null`, with the reason recorded in
  `confidence_notes`.

## How it works

One request to `POST https://api.anthropic.com/v1/messages`:

- **Model:** `claude-opus-4-8` with adaptive thinking (`thinking: {type: "adaptive"}`)
  and `output_config.effort: "high"`.
- **Vision:** the image is sent as a base64 content block ahead of the text prompt.
- **Structured outputs:** `output_config.format` carries a strict JSON schema
  (`additionalProperties: false`, all fields required and nullable), so the response
  is guaranteed schema-valid JSON — no regex scraping of prose.
- **Safety guardrails** live in the system prompt: extraction only; no diagnosis,
  interpretation, reassurance, or alarm; unclear/illegible → `null` + a note in
  `confidence_notes`; the `impression` field must transcribe the report's own
  impression section, never the model's opinion.

Use `--dry-run` to inspect the exact request body.

## Known limitations

- **Proof of concept, not a medical device.** Output is a machine transcription of a
  photo and can contain errors (OCR-style misreads, mis-attributed columns in dense
  twin tables). Every value must be verified against the original report by a human.
  No clinical decisions should be based on this output.
- Handwritten reports, very low-resolution photos, glare, and skewed camera angles
  degrade accuracy; the model is instructed to return `null` rather than guess, so
  poor photos yield sparse results.
- Single-image input only; multi-page reports need one run per page (no merging yet).
- No PDF input in this PoC (the API supports PDFs; this script only wires up images).
- Discordance uses EFW only; other discordance definitions (e.g. AC-based) are not computed.
- Layouts vary enormously across labs. The prompt is tuned for Indian radiology
  conventions; other formats should mostly work but are untested.
- The 20% discordance threshold is hard-coded; clinical practice varies (some use 18%,
  some 25%).
- One API call per run; no batching, caching, retry, or cost controls.

## Test images

Use **real, de-identified ultrasound reports** for testing — synthetic mockups don't
reproduce the messy layouts, stamps, fonts, and photo artifacts that make this problem
hard. Before using any real report, remove or mask all patient-identifying information
(name, ID/MRN, address, phone, hospital barcode, doctor's registration number). Never
commit identifiable patient data to the repository, and never send it to the API.
