# BumpBuddy scan-poc — AI ultrasound-report reader (proof of concept)

A standalone proof of concept for BumpBuddy's twins-first differentiator: given a
**photo or scan of an obstetric growth-scan (ultrasound) report**, extract structured,
**per-baby** biometry — EFW, HC, AC, FL, BPD, FHR, placenta, liquor/AFI, DVP,
umbilical Doppler — and compute the **inter-twin EFW discordance**.

It is a single zero-dependency Node.js script (built-in `fetch`, no SDK, no
`npm install`) that supports **two providers**:

- **`anthropic`** (default) — the Claude API (`claude-opus-4-8`, vision + structured outputs)
- **`azure`** — Microsoft **Azure AI Foundry (Azure OpenAI)** Chat Completions, using
  your own vision-capable deployment (e.g. `gpt-4o`)

Both providers share the **same** system prompt, JSON schema, output format, and
locally computed discordance — only the transport differs.

**This tool only transcribes what is printed on a report. It performs no diagnosis,
gives no medical advice, and adds no reassurance or alarm.** Values that are absent
or illegible come back as `null` with an explanation in `confidence_notes` — never a guess.

## Provider matrix

| | `--provider anthropic` (default) | `--provider azure` |
|---|---|---|
| Service | Claude API | Azure AI Foundry (Azure OpenAI) |
| Request | `POST https://api.anthropic.com/v1/messages` | `POST {endpoint}/openai/deployments/{deployment}/chat/completions?api-version=2024-10-21` |
| Model | `claude-opus-4-8` (hard-coded) | whatever your **deployment** is — must be vision-capable |
| Auth | `x-api-key` + `anthropic-version` headers | `api-key` header |
| Env vars | `ANTHROPIC_API_KEY` | `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT`, `AZURE_OPENAI_API_KEY` |
| Image input | base64 `image` content block | `image_url` content part with a base64 `data:` URL (`detail: high`) |
| Structured output | `output_config.format` (json_schema) | `response_format: { type: "json_schema", json_schema: { strict: true, ... } }` |
| Token cap | `max_tokens` | `max_completion_tokens` (auto-falls back to `max_tokens` once if rejected) |

The provider can also be selected with the `SCAN_POC_PROVIDER` environment variable
(`anthropic` or `azure`); an explicit `--provider` flag always wins.

## Requirements

- Node.js 20+ (tested on Node 24)
- **Either** a Claude API key (get one at <https://platform.claude.com/> → API Keys),
  **or** an Azure OpenAI / Azure AI Foundry resource with a **vision-capable model
  deployment** and its API key.

## Setup

### Anthropic (default provider)

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

### Azure AI Foundry (Azure OpenAI)

You need three values:

1. **Endpoint** — Azure portal → your Azure OpenAI resource → *Keys and Endpoint*.
   Looks like `https://myresource.openai.azure.com` (or, for AI Foundry resources,
   `https://myresource.services.ai.azure.com`). Base URL only, no path.
2. **Deployment name** — Azure AI Foundry → *Deployments*. This is the **name you gave
   the deployment** (often but not necessarily the model name, e.g. `gpt-4o`).
3. **API key** — same *Keys and Endpoint* blade (KEY 1 or KEY 2).

**Windows PowerShell**

```powershell
$env:AZURE_OPENAI_ENDPOINT   = "https://myresource.openai.azure.com"
$env:AZURE_OPENAI_DEPLOYMENT = "gpt-4o"
$env:AZURE_OPENAI_API_KEY    = "<your key>"
```

(Session-only. To persist per-user:
`[Environment]::SetEnvironmentVariable("AZURE_OPENAI_ENDPOINT", "https://myresource.openai.azure.com", "User")`
etc., then open a new terminal.)

**bash / zsh**

```bash
export AZURE_OPENAI_ENDPOINT="https://myresource.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-4o"
export AZURE_OPENAI_API_KEY="<your key>"
```

If any required variable for the selected provider is missing, the script prints
these instructions and exits with code 1 (`--dry-run` works without credentials).

> **The deployment must be a vision-capable model.** This PoC sends the report photo
> as an image, so the Azure deployment must be a model with vision input:
> **`gpt-4o`**, **`gpt-4o-mini`**, **`gpt-4.1`** (incl. `-mini` / `-nano`), or the
> **`gpt-5` family**. Text-only deployments (e.g. `gpt-35-turbo`) will reject the
> image content part. The model must also support strict structured outputs
> (`response_format: json_schema`) — all of the models above do.

## Usage

```text
node extract.js <image-file> [--provider anthropic|azure] [--twins] [--dry-run]
```

| Argument | Meaning |
|---|---|
| `<image-file>` | Photo/scan of the report. `.jpg` / `.jpeg` / `.png` / `.webp` / `.gif` |
| `--provider <name>` | `anthropic` (Claude API, default) or `azure` (Azure AI Foundry / Azure OpenAI). Falls back to `SCAN_POC_PROVIDER` when omitted. |
| `--twins` | Hint that this is a twin pregnancy. The model then searches specifically for a second fetus (side-by-side columns, Twin A/B, Fetus 1/2, F1/F2 blocks) — but it will **not** invent a second baby if the report documents only one. |
| `--dry-run` | Print the exact API request (URL, headers with the key masked, JSON body) with the base64 image bytes redacted, then exit without calling the API. Works for both providers, without credentials. |

Examples:

```powershell
# Claude API (default provider)
node extract.js .\scans\growth-scan-32w.jpg --twins
node extract.js .\scans\anomaly-report.png
node extract.js .\scans\growth-scan-32w.jpg --twins --dry-run

# Azure AI Foundry
$env:AZURE_OPENAI_ENDPOINT   = "https://myresource.openai.azure.com"
$env:AZURE_OPENAI_DEPLOYMENT = "gpt-4o"
$env:AZURE_OPENAI_API_KEY    = "<your key>"
node extract.js .\scans\growth-scan-32w.jpg --twins --provider azure
node extract.js .\scans\growth-scan-32w.jpg --provider azure --dry-run

# Make azure the default for this session
$env:SCAN_POC_PROVIDER = "azure"
node extract.js .\scans\growth-scan-32w.jpg --twins
```

## Expected output

Identical for both providers:

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

One request per run. The **system prompt, JSON schema, discordance computation, and
output printing are shared** between providers; only the request/response wire format
differs.

### Anthropic path (default)

`POST https://api.anthropic.com/v1/messages`:

- **Model:** `claude-opus-4-8` with adaptive thinking (`thinking: {type: "adaptive"}`)
  and `output_config.effort: "high"`.
- **Vision:** the image is sent as a base64 content block ahead of the text prompt.
- **Structured outputs:** `output_config.format` carries a strict JSON schema
  (`additionalProperties: false`, all fields required and nullable), so the response
  is guaranteed schema-valid JSON — no regex scraping of prose.

### Azure path

`POST {AZURE_OPENAI_ENDPOINT}/openai/deployments/{AZURE_OPENAI_DEPLOYMENT}/chat/completions?api-version=2024-10-21`
with the key in the `api-key` header:

- **api-version `2024-10-21`:** the most recent *stable* (GA, non-preview) Azure
  OpenAI data-plane inference version. It supports both vision input and
  `response_format: json_schema`; preview versions churn and get retired.
- **Vision:** the image goes in the user message as an `image_url` content part with
  a base64 `data:` URL (`detail: "high"` for dense report text).
- **Structured outputs:** `response_format: {type: "json_schema", json_schema:
  {name: "scan_extraction", strict: true, schema: ...}}` — the *same* schema object
  as the Anthropic path. It is already strict-mode compatible
  (`additionalProperties: false` everywhere, every property required, nullability via
  union types like `["number","null"]`, which strict mode allows).
- **Token cap:** `max_completion_tokens` (the current parameter, required by the
  `gpt-5` family). If a deployment/api-version combination rejects it, the script
  automatically retries once with the legacy `max_tokens`.
- **Error handling:** targeted hints for `401` (key doesn't match the resource),
  `404` (wrong deployment name or endpoint), `429` (TPM quota exhausted, honors
  `Retry-After`), input blocked by Azure's content filter (`error.code:
  "content_filter"` with the `content_filter_result` breakdown), and output
  suppressed by the filter (`finish_reason: "content_filter"`).

### Safety guardrails

Live in the shared system prompt: extraction only; no diagnosis, interpretation,
reassurance, or alarm; unclear/illegible → `null` + a note in `confidence_notes`;
the `impression` field must transcribe the report's own impression section, never
the model's opinion.

Use `--dry-run` to inspect the exact request body for either provider.

## Known limitations

- **Proof of concept, not a medical device.** Output is a machine transcription of a
  photo and can contain errors (OCR-style misreads, mis-attributed columns in dense
  twin tables). Every value must be verified against the original report by a human.
  No clinical decisions should be based on this output.
- Handwritten reports, very low-resolution photos, glare, and skewed camera angles
  degrade accuracy; the model is instructed to return `null` rather than guess, so
  poor photos yield sparse results.
- Single-image input only; multi-page reports need one run per page (no merging yet).
- No PDF input in this PoC (both APIs support PDFs; this script only wires up images).
- Extraction quality differs by model. The prompt was tuned against `claude-opus-4-8`;
  on Azure it depends on which model you deployed (`gpt-4o-mini` will be weaker than
  `gpt-4o` / `gpt-4.1` / `gpt-5` on dense twin tables).
- Azure's content filter can occasionally flag medical imagery; the script surfaces
  the filter result rather than retrying.
- Discordance uses EFW only; other discordance definitions (e.g. AC-based) are not computed.
- Layouts vary enormously across labs. The prompt is tuned for Indian radiology
  conventions; other formats should mostly work but are untested.
- The 20% discordance threshold is hard-coded; clinical practice varies (some use 18%,
  some 25%).
- One API call per run; no batching, caching, retry (beyond the Azure
  `max_completion_tokens` → `max_tokens` fallback), or cost controls.

## Test images

Use **real, de-identified ultrasound reports** for testing — synthetic mockups don't
reproduce the messy layouts, stamps, fonts, and photo artifacts that make this problem
hard. Before using any real report, remove or mask all patient-identifying information
(name, ID/MRN, address, phone, hospital barcode, doctor's registration number). Never
commit identifiable patient data to the repository, and never send it to the API —
that applies to both providers.
