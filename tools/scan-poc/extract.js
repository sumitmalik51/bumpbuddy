#!/usr/bin/env node
/**
 * BumpBuddy scan-poc — AI ultrasound-report reader (proof of concept)
 *
 * Extracts per-baby biometry from a JPG/PNG photo of an obstetric growth-scan
 * report using vision + structured outputs on one of two providers:
 *
 *   - anthropic (default): the Claude API
 *   - azure:               Microsoft Azure AI Foundry (Azure OpenAI) Chat Completions
 *
 * Zero runtime dependencies — uses Node's built-in fetch.
 *
 * Usage:
 *   node extract.js <image-file> [--provider anthropic|azure] [--twins] [--dry-run]
 *
 * Env:
 *   SCAN_POC_PROVIDER          default for --provider (anthropic | azure)
 *   anthropic:  ANTHROPIC_API_KEY                       required (except with --dry-run)
 *   azure:      AZURE_OPENAI_ENDPOINT                   required (except with --dry-run)
 *               AZURE_OPENAI_DEPLOYMENT                 required (except with --dry-run)
 *               AZURE_OPENAI_API_KEY                    required (except with --dry-run)
 */

import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PROVIDERS = ["anthropic", "azure"];

// --- Anthropic (Claude API) ---
// Model choice: claude-opus-4-8 — the current recommended default Opus-tier
// model for the Claude API (strong vision + structured-output support).
const ANTHROPIC_MODEL = "claude-opus-4-8";
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_API_VERSION = "2023-06-01";

// --- Azure AI Foundry (Azure OpenAI) ---
// api-version choice: 2024-10-21 is the most recent STABLE (GA, non-preview)
// Azure OpenAI data-plane inference api-version. It supports everything this
// PoC needs — vision input via image_url content parts and strict structured
// outputs via response_format: json_schema — while preview versions churn and
// get retired. The model itself comes from the user's deployment name.
const AZURE_API_VERSION = "2024-10-21";

const MAX_TOKENS = 16000; // non-streaming safe default; extraction output is small

const MEDIA_TYPES = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
  ".gif": "image/gif",
};

// Threshold above which inter-twin EFW discordance is commonly considered
// clinically significant in obstetric practice.
const DISCORDANCE_THRESHOLD_PERCENT = 20;

// ---------------------------------------------------------------------------
// JSON schema for structured output — shared verbatim by BOTH providers.
// It is strict-mode compatible on both sides: additionalProperties:false on
// every object, every property listed in "required", and nullability expressed
// as union types (["number","null"]), which OpenAI/Azure strict json_schema
// mode explicitly allows.
// ---------------------------------------------------------------------------

const BABY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "label",
    "presentation",
    "efw_grams",
    "efw_raw",
    "hc_mm",
    "hc_raw",
    "ac_mm",
    "ac_raw",
    "fl_mm",
    "fl_raw",
    "bpd_mm",
    "bpd_raw",
    "fhr_bpm",
    "placenta",
    "placenta_grade",
    "liquor_afi_cm",
    "dvp_cm",
    "umbilical_doppler",
  ],
  properties: {
    label: {
      type: "string",
      description:
        'Normalized single-letter label in document order: "A", "B", ... (Twin A / Fetus 1 / F1 -> "A").',
    },
    presentation: {
      type: ["string", "null"],
      description: "Fetal presentation as printed (e.g. cephalic, breech, transverse).",
    },
    efw_grams: {
      type: ["number", "null"],
      description:
        "Estimated fetal weight in grams. If printed as a range or with a tolerance, the central value. Null if absent or not safely convertible.",
    },
    efw_raw: {
      type: ["string", "null"],
      description:
        "Verbatim EFW text from the report when it is a range, has a tolerance, uses non-gram units, or is otherwise ambiguous. Null when efw_grams is an unambiguous plain number.",
    },
    hc_mm: {
      type: ["number", "null"],
      description: "Head circumference in millimetres (convert cm -> mm). Null if only a week-equivalent is printed.",
    },
    hc_raw: {
      type: ["string", "null"],
      description: 'Verbatim HC text when ambiguous or week-based (e.g. "HC = 32w4d").',
    },
    ac_mm: {
      type: ["number", "null"],
      description: "Abdominal circumference in millimetres (convert cm -> mm).",
    },
    ac_raw: {
      type: ["string", "null"],
      description: "Verbatim AC text when ambiguous or week-based.",
    },
    fl_mm: {
      type: ["number", "null"],
      description: "Femur length in millimetres (convert cm -> mm).",
    },
    fl_raw: {
      type: ["string", "null"],
      description: "Verbatim FL text when ambiguous or week-based.",
    },
    bpd_mm: {
      type: ["number", "null"],
      description: "Biparietal diameter in millimetres (convert cm -> mm).",
    },
    bpd_raw: {
      type: ["string", "null"],
      description: "Verbatim BPD text when ambiguous or week-based.",
    },
    fhr_bpm: {
      type: ["number", "null"],
      description: "Fetal heart rate in beats per minute.",
    },
    placenta: {
      type: ["string", "null"],
      description: "Placental location/description as printed (e.g. anterior, posterior, fundal, low-lying).",
    },
    placenta_grade: {
      type: ["string", "null"],
      description: 'Placental maturity grade as printed (e.g. "Grade II", "Gr. 2").',
    },
    liquor_afi_cm: {
      type: ["number", "null"],
      description: "Amniotic fluid index (AFI / liquor) in centimetres.",
    },
    dvp_cm: {
      type: ["number", "null"],
      description: "Deepest vertical pocket (DVP / SDP / MVP) in centimetres.",
    },
    umbilical_doppler: {
      type: ["string", "null"],
      description:
        "Umbilical artery Doppler findings as printed (e.g. S/D ratio, PI, RI values, end-diastolic flow status). Verbatim, no interpretation.",
    },
  },
};

const OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "report_date",
    "gestational_age_on_report",
    "twins_detected",
    "babies",
    "printed_efw_discordance_percent",
    "impression",
    "flags",
    "confidence_notes",
  ],
  properties: {
    report_date: {
      type: ["string", "null"],
      description:
        "Date of the scan/report. ISO 8601 (YYYY-MM-DD) if unambiguous on the report; otherwise verbatim as printed. Null if not printed.",
    },
    gestational_age_on_report: {
      type: ["string", "null"],
      description:
        'Gestational age stated on the report, verbatim (e.g. "32 weeks 4 days", "32w4d"). Null if not printed.',
    },
    twins_detected: {
      type: "boolean",
      description: "True only if the report clearly documents more than one fetus.",
    },
    babies: {
      type: "array",
      description: "One entry per fetus documented on the report, in document order.",
      items: BABY_SCHEMA,
    },
    printed_efw_discordance_percent: {
      type: ["number", "null"],
      description:
        "EFW discordance percentage AS PRINTED on the report (e.g. in a fetal weight calculation box: 'EFW discordance 16.3 %'). Transcription only — never compute this yourself. Null if the report does not print one.",
    },
    impression: {
      type: ["string", "null"],
      description:
        "The report's own impression/conclusion section, transcribed (may be lightly abbreviated). NEVER the model's own assessment. Null if the report has no such section.",
    },
    flags: {
      type: "array",
      items: { type: "string" },
      description:
        "Short factual notes about documented findings or data-quality issues (no advice, no diagnosis).",
    },
    confidence_notes: {
      type: ["string", "null"],
      description:
        "Which fields were set to null (or are low-confidence) and why: illegible, cut off, blurry, ambiguous units, etc. Null if everything was clearly legible.",
    },
  },
};

// ---------------------------------------------------------------------------
// Prompts — shared verbatim by BOTH providers.
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `You are a medical-report DATA EXTRACTION engine embedded in a pregnancy-tracking app. You will be shown a photograph or scan of an obstetric ultrasound growth-scan report.

Non-negotiable rules:

1. EXTRACTION ONLY. Transcribe and normalize values that are literally printed on the report. Do not diagnose, interpret, predict outcomes, or offer medical opinions of any kind.
2. NO REASSURANCE, NO ALARM. Never add commentary such as "this looks normal" or "this is concerning". The "impression" field must be a transcription of the report's own impression/conclusion section — never your assessment. If the report has no impression section, set it to null.
3. NEVER GUESS. If a value is absent, illegible, cut off, blurred, overexposed, or ambiguous, set that field to null and explain which fields were affected and why in "confidence_notes". A null with an explanation is always better than a plausible guess.
4. NORMALIZE UNITS. EFW in grams; HC/AC/FL/BPD in millimetres; AFI (liquor) and DVP in centimetres; FHR in beats per minute. If the report prints a length in cm for a mm field, convert (1 cm = 10 mm) and keep the verbatim text in the matching *_raw field. If a biometry value is printed ONLY as a gestational-age equivalent (e.g. "HC = 32w4d") or in a unit you cannot safely convert, put the verbatim text in the *_raw field and set the numeric field to null — do not convert weeks to millimetres.
5. INDIAN RADIOLOGY CONVENTIONS are common: EFW usually in grams, sometimes with a tolerance or range ("1897 +/- 277 gm") — use the central value for efw_grams and keep the full text in efw_raw. Biometry tables often show a measurement column AND a week-equivalent column — extract the measurement, and use *_raw only if the measurement column is missing or unreadable. "Liquor" means amniotic fluid. Placental grading appears as Grade 0-III (or 1-3).
6. TWIN LABELS. Babies may be labelled "Twin A/Twin B", "Fetus 1/Fetus 2", "F1/F2", "Baby A/Baby B", or similar. Normalize to "A", "B", "C"... in document order (Twin A / Fetus 1 / F1 -> "A"). Set twins_detected to true only if the report clearly documents more than one fetus. Never invent a second fetus.
7. FLAGS are short, factual, and derived only from what the report documents or from data-quality issues (e.g. "AFI recorded for only one fetus", "biometry table partially cut off"). No advice, no severity judgements.
8. MULTI-FETUS COMPLETENESS. Twin reports repeat an identical table or block per fetus — commonly stacked vertically (Fetus 1's table directly above Fetus 2's) or in consecutive sections; a photo may also begin mid-way through one fetus's section. Extract EVERY fetus's values with equal care. Before finalizing, self-check: if twins_detected is true but one fetus has all-null biometry while another is fully populated, RE-EXAMINE the image for the sparse fetus's table or block — it is usually present and just as legible as the first. Attribute each clinical value (FHR, presentation, placenta, amniotic fluid) to the fetus in whose labelled section it is printed — never attach the first values you encounter to Fetus A by default. If attribution is genuinely unclear, leave the field null and record the ambiguity in flags.
9. STRUCTURE/FLAGS CONSISTENCY. Never mention a numeric value in flags or confidence_notes (for example a printed discordance percentage or an EFW) while leaving the corresponding structured field null. If it is legible enough to mention, it is legible enough to extract.

Your entire output must conform to the provided JSON schema.`;

function buildUserPrompt(twinsHint) {
  let prompt = `Extract the structured data from this ultrasound growth-scan report photo.

Steps:
1. Read the report header for the scan/report date and the stated gestational age.
2. Identify how many fetuses the report documents and their labels.
3. For each fetus, extract: presentation, EFW, HC, AC, FL, BPD, FHR, placenta location and grade, liquor/AFI, DVP, and umbilical artery Doppler findings — normalizing units per the system rules and using the *_raw fields for verbatim text whenever a value is ambiguous, ranged, or week-based.
4. If the report prints an EFW discordance percentage, transcribe it into printed_efw_discordance_percent.
5. Transcribe the report's impression/conclusion section if present.
6. Record any documented notable findings or data-quality problems in "flags", and explain every null / low-confidence field in "confidence_notes".`;

  if (twinsHint) {
    prompt += `

Note: the user has indicated this is a TWIN pregnancy. Look carefully for a second fetus — twin reports often present per-fetus data in side-by-side columns, sequential blocks, or a shared table with Twin A / Twin B (or Fetus 1 / Fetus 2, F1 / F2) columns. If the report nevertheless documents only one fetus, do NOT invent a second baby: return the single baby, set twins_detected accordingly, and record the mismatch in flags and confidence_notes.`;
  }

  return prompt;
}

// ---------------------------------------------------------------------------
// CLI parsing
// ---------------------------------------------------------------------------

function printUsage() {
  console.error(`Usage: node extract.js <image-file> [--provider anthropic|azure] [--twins] [--dry-run]

  <image-file>        Photo/scan of an ultrasound growth-scan report (.jpg/.jpeg/.png/.webp/.gif)
  --provider <name>   AI provider: "anthropic" (Claude API, default) or "azure" (Azure AI Foundry / Azure OpenAI).
                      Falls back to $env:SCAN_POC_PROVIDER when the flag is omitted.
  --twins             Hint that this is a twin pregnancy (the model searches harder for a second fetus)
  --dry-run           Print the exact API request payload (image bytes redacted) and exit without calling the API

Environment:
  SCAN_POC_PROVIDER   Default provider when --provider is not given (anthropic | azure)

  --provider anthropic:
    ANTHROPIC_API_KEY   Your Claude API key (not required for --dry-run)
      PowerShell:  $env:ANTHROPIC_API_KEY = "sk-ant-..."
      bash/zsh:    export ANTHROPIC_API_KEY="sk-ant-..."

  --provider azure (none required for --dry-run):
    AZURE_OPENAI_ENDPOINT     e.g. https://myresource.openai.azure.com  (or https://myresource.services.ai.azure.com)
    AZURE_OPENAI_DEPLOYMENT   Your deployment NAME — must be a vision-capable model (e.g. gpt-4o)
    AZURE_OPENAI_API_KEY      Key from Azure portal -> your resource -> Keys and Endpoint
      PowerShell:  $env:AZURE_OPENAI_ENDPOINT = "https://myresource.openai.azure.com"
                   $env:AZURE_OPENAI_DEPLOYMENT = "gpt-4o"
                   $env:AZURE_OPENAI_API_KEY = "<key>"`);
}

function parseArgs(argv) {
  const args = {
    imageFile: null,
    twins: false,
    dryRun: false,
    help: false,
    invalid: false,
    provider: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--twins") args.twins = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--help" || a === "-h") args.help = true;
    else if (a === "--provider") {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith("--")) {
        console.error(`--provider requires a value: ${PROVIDERS.join(" | ")}\n`);
        args.invalid = true;
      } else {
        args.provider = value;
        i++;
      }
    } else if (a.startsWith("--provider=")) {
      args.provider = a.slice("--provider=".length);
    } else if (a.startsWith("--")) {
      console.error(`Unknown option: ${a}\n`);
      args.invalid = true;
    } else if (!args.imageFile) args.imageFile = a;
    else {
      console.error(`Unexpected extra argument: ${a}\n`);
      args.invalid = true;
    }
  }
  return args;
}

function resolveProvider(cliProvider) {
  const raw = cliProvider ?? process.env.SCAN_POC_PROVIDER ?? "anthropic";
  const provider = String(raw).trim().toLowerCase();
  if (!PROVIDERS.includes(provider)) {
    console.error(
      `Unknown provider "${raw}" (from ${cliProvider != null ? "--provider" : "SCAN_POC_PROVIDER"}). ` +
        `Valid providers: ${PROVIDERS.join(", ")}\n`
    );
    return null;
  }
  return provider;
}

// ---------------------------------------------------------------------------
// Provider request builders
// ---------------------------------------------------------------------------

function getAzureConfig({ allowMissing }) {
  const endpoint = (process.env.AZURE_OPENAI_ENDPOINT ?? "").trim().replace(/\/+$/, "");
  const deployment = (process.env.AZURE_OPENAI_DEPLOYMENT ?? "").trim();
  const apiKey = (process.env.AZURE_OPENAI_API_KEY ?? "").trim();

  const missing = [];
  if (!endpoint) missing.push("AZURE_OPENAI_ENDPOINT");
  if (!deployment) missing.push("AZURE_OPENAI_DEPLOYMENT");
  if (!apiKey) missing.push("AZURE_OPENAI_API_KEY");

  if (missing.length > 0 && !allowMissing) {
    console.error(`Missing environment variable(s) for --provider azure: ${missing.join(", ")}

Set them and re-run:
  PowerShell:
    $env:AZURE_OPENAI_ENDPOINT   = "https://myresource.openai.azure.com"   # or https://myresource.services.ai.azure.com
    $env:AZURE_OPENAI_DEPLOYMENT = "gpt-4o"                                # your deployment NAME (must be a vision-capable model)
    $env:AZURE_OPENAI_API_KEY    = "<key>"

  bash/zsh:
    export AZURE_OPENAI_ENDPOINT="https://myresource.openai.azure.com"
    export AZURE_OPENAI_DEPLOYMENT="gpt-4o"
    export AZURE_OPENAI_API_KEY="<key>"

Find the endpoint and key in the Azure portal under your Azure OpenAI resource
-> "Keys and Endpoint", and the deployment name in Azure AI Foundry under
"Deployments". The deployment must be a vision-capable model (e.g. gpt-4o,
gpt-4o-mini, gpt-4.1, or the gpt-5 family).
Tip: use --dry-run to inspect the request payload without credentials.`);
    process.exit(1);
  }

  return {
    endpoint: endpoint || "https://<AZURE_OPENAI_ENDPOINT-not-set>",
    deployment: deployment || "<AZURE_OPENAI_DEPLOYMENT-not-set>",
    apiKey,
  };
}

function buildAnthropicPayload(mediaType, imageBase64, twinsHint) {
  return {
    model: ANTHROPIC_MODEL,
    max_tokens: MAX_TOKENS,
    thinking: { type: "adaptive" },
    output_config: {
      effort: "high",
      format: {
        type: "json_schema",
        schema: OUTPUT_SCHEMA,
      },
    },
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: mediaType,
              data: imageBase64,
            },
          },
          { type: "text", text: buildUserPrompt(twinsHint) },
        ],
      },
    ],
  };
}

function buildAzurePayload(mediaType, imageBase64, twinsHint) {
  return {
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      {
        role: "user",
        content: [
          {
            type: "image_url",
            image_url: {
              url: `data:${mediaType};base64,${imageBase64}`,
              detail: "high",
            },
          },
          { type: "text", text: buildUserPrompt(twinsHint) },
        ],
      },
    ],
    max_completion_tokens: MAX_TOKENS,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "scan_extraction",
        strict: true,
        schema: OUTPUT_SCHEMA,
      },
    },
  };
}

/**
 * Builds the full request for the chosen provider:
 * { label, url, headers, maskedHeaders, payload }
 */
function buildRequest(provider, mediaType, imageBase64, twinsHint, dryRun) {
  if (provider === "azure") {
    const cfg = getAzureConfig({ allowMissing: dryRun });
    return {
      label: "Azure OpenAI",
      url: `${cfg.endpoint}/openai/deployments/${cfg.deployment}/chat/completions?api-version=${AZURE_API_VERSION}`,
      headers: {
        "content-type": "application/json",
        "api-key": cfg.apiKey,
      },
      maskedHeaders: {
        "content-type": "application/json",
        "api-key": cfg.apiKey
          ? "<redacted (AZURE_OPENAI_API_KEY is set)>"
          : "<AZURE_OPENAI_API_KEY not set>",
      },
      payload: buildAzurePayload(mediaType, imageBase64, twinsHint),
    };
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  return {
    label: "the Claude API",
    url: ANTHROPIC_API_URL,
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey ?? "",
      "anthropic-version": ANTHROPIC_API_VERSION,
    },
    maskedHeaders: {
      "content-type": "application/json",
      "anthropic-version": ANTHROPIC_API_VERSION,
      "x-api-key": apiKey ? "<redacted (ANTHROPIC_API_KEY is set)>" : "<ANTHROPIC_API_KEY not set>",
    },
    payload: buildAnthropicPayload(mediaType, imageBase64, twinsHint),
  };
}

function redactImageForDryRun(provider, payload, mediaType, rawByteLength, base64Length) {
  const redacted = structuredClone(payload);
  const note = `<base64 ${mediaType} data omitted: ${rawByteLength} bytes raw, ${base64Length} chars base64>`;
  if (provider === "azure") {
    // messages[0] is the system prompt; messages[1] is the user turn.
    redacted.messages[1].content[0].image_url.url = `data:${mediaType};base64,${note}`;
  } else {
    redacted.messages[0].content[0].source.data = note;
  }
  return redacted;
}

// ---------------------------------------------------------------------------
// Provider response handling
// ---------------------------------------------------------------------------

/** Prints provider-specific hints for a non-2xx response, then exits 1. */
function reportHttpError(provider, res, bodyText) {
  const label = provider === "azure" ? "Azure OpenAI" : "Claude API";
  console.error(`${label} returned HTTP ${res.status}:`);
  console.error(bodyText);

  if (provider === "azure") {
    let apiError = null;
    try {
      apiError = JSON.parse(bodyText)?.error ?? null;
    } catch {
      /* non-JSON error body */
    }
    if (res.status === 401) {
      console.error(
        "\nHTTP 401: check that AZURE_OPENAI_API_KEY is a valid key for THIS resource " +
          "(Azure portal -> your Azure OpenAI resource -> Keys and Endpoint). " +
          "Keys are per-resource — a key from a different resource is rejected."
      );
    } else if (res.status === 403) {
      console.error(
        "\nHTTP 403: the key was recognized but access was denied — check the resource's " +
          "network/firewall rules and that key-based auth is not disabled (Entra ID-only)."
      );
    } else if (res.status === 404) {
      console.error(`\nHTTP 404: usually a wrong deployment name or endpoint.
  - AZURE_OPENAI_DEPLOYMENT must be the deployment NAME you chose in Azure AI Foundry
    (it is not always the same as the model name).
  - AZURE_OPENAI_ENDPOINT must be the bare resource endpoint
    (https://<resource>.openai.azure.com) with no extra path.
  - A newly created deployment can take a few minutes to become routable.`);
    } else if (res.status === 429) {
      const retryAfter = res.headers.get("retry-after");
      console.error(
        "\nHTTP 429: rate limited — the deployment's tokens-per-minute (TPM) quota is exhausted." +
          (retryAfter ? ` Retry after ${retryAfter} s.` : " Wait and retry.") +
          "\nYou can raise the deployment's TPM allocation in Azure AI Foundry."
      );
    }
    if (apiError?.code === "content_filter") {
      console.error(
        "\nAzure's content filter blocked the INPUT (prompt/image) — the request never reached the model."
      );
      const filterResult = apiError?.innererror?.content_filter_result;
      if (filterResult) {
        console.error("content_filter_result: " + JSON.stringify(filterResult, null, 2));
      }
      console.error(
        "An ultrasound report photo should not normally trip the filter; if this recurs, " +
          "review the deployment's content-filter configuration in Azure AI Foundry."
      );
    }
  } else {
    if (res.status === 401) console.error("\nCheck that ANTHROPIC_API_KEY is valid.");
    if (res.status === 429) console.error("\nRate limited — wait and retry.");
  }
  process.exit(1);
}

/** Anthropic Messages API response -> { resultText, usageLine }. Exits 1 on fatal problems. */
function parseAnthropicMessage(bodyText) {
  let message;
  try {
    message = JSON.parse(bodyText);
  } catch {
    console.error("Could not parse API response as JSON:");
    console.error(bodyText.slice(0, 2000));
    process.exit(1);
  }

  // --- Handle stop reasons before touching content ---
  if (message.stop_reason === "refusal") {
    console.error(
      "The model declined to process this request (stop_reason: refusal). " +
        "Verify the image is an ultrasound report and try again."
    );
    process.exit(1);
  }
  if (message.stop_reason === "max_tokens") {
    console.error(
      "Warning: response was truncated (stop_reason: max_tokens); extraction may be incomplete."
    );
  }

  const textBlock = (message.content ?? []).find((b) => b.type === "text");
  if (!textBlock) {
    console.error("No text content in API response:");
    console.error(JSON.stringify(message, null, 2).slice(0, 2000));
    process.exit(1);
  }

  const usageLine = message.usage
    ? `\n[tokens] input=${message.usage.input_tokens} output=${message.usage.output_tokens}`
    : null;
  return { resultText: textBlock.text, usageLine };
}

/** Azure OpenAI Chat Completions response -> { resultText, usageLine }. Exits 1 on fatal problems. */
function parseAzureCompletion(bodyText) {
  let completion;
  try {
    completion = JSON.parse(bodyText);
  } catch {
    console.error("Could not parse API response as JSON:");
    console.error(bodyText.slice(0, 2000));
    process.exit(1);
  }

  const choice = completion.choices?.[0];
  if (!choice) {
    console.error("No choices in Azure OpenAI response:");
    console.error(JSON.stringify(completion, null, 2).slice(0, 2000));
    process.exit(1);
  }

  if (choice.finish_reason === "content_filter") {
    console.error(
      "Azure's content filter suppressed the model OUTPUT (finish_reason: content_filter)."
    );
    if (choice.content_filter_results) {
      console.error(
        "content_filter_results: " + JSON.stringify(choice.content_filter_results, null, 2)
      );
    }
    console.error(
      "If this recurs for a legitimate report photo, review the deployment's " +
        "content-filter configuration in Azure AI Foundry."
    );
    process.exit(1);
  }
  if (choice.message?.refusal) {
    console.error(
      `The model declined to process this request (refusal): ${choice.message.refusal}\n` +
        "Verify the image is an ultrasound report and try again."
    );
    process.exit(1);
  }
  if (choice.finish_reason === "length") {
    console.error(
      "Warning: response was truncated (finish_reason: length); extraction may be incomplete."
    );
  }

  const resultText = choice.message?.content;
  if (typeof resultText !== "string" || resultText.length === 0) {
    console.error("No message content in Azure OpenAI response:");
    console.error(JSON.stringify(completion, null, 2).slice(0, 2000));
    process.exit(1);
  }

  const usageLine = completion.usage
    ? `\n[tokens] input=${completion.usage.prompt_tokens} output=${completion.usage.completion_tokens}`
    : null;
  return { resultText, usageLine };
}

// ---------------------------------------------------------------------------
// Derived metrics (computed locally, never by the model) — provider-agnostic
// ---------------------------------------------------------------------------

function computeDiscordance(babies) {
  const withEfw = (babies ?? []).filter(
    (b) => typeof b.efw_grams === "number" && b.efw_grams > 0
  );
  if (withEfw.length < 2) {
    return {
      efw_discordance_percent: null,
      clinically_significant: null,
      note: "Not computed: EFW available for fewer than two babies.",
    };
  }
  const efws = withEfw.map((b) => b.efw_grams);
  const larger = Math.max(...efws);
  const smaller = Math.min(...efws);
  const pct = ((larger - smaller) / larger) * 100;
  const significant = pct >= DISCORDANCE_THRESHOLD_PERCENT;
  return {
    efw_discordance_percent: Math.round(pct * 10) / 10,
    clinically_significant: significant,
    note: significant
      ? "clinically significant discordance — discuss with doctor"
      : `below the ${DISCORDANCE_THRESHOLD_PERCENT}% threshold commonly used for clinically significant discordance`,
  };
}

// ---------------------------------------------------------------------------
// Human-readable summary table — provider-agnostic
// ---------------------------------------------------------------------------

function fmt(v, unit = "") {
  if (v === null || v === undefined || v === "") return "—";
  return unit ? `${v} ${unit}` : String(v);
}

function printSummary(result, derived) {
  const babies = result.babies ?? [];
  const rows = [
    ["Metric", ...babies.map((b) => `Baby ${b.label ?? "?"}`)],
    ["Presentation", ...babies.map((b) => fmt(b.presentation))],
    ["EFW", ...babies.map((b) => fmt(b.efw_grams, "g"))],
    ["HC", ...babies.map((b) => fmt(b.hc_mm, "mm"))],
    ["AC", ...babies.map((b) => fmt(b.ac_mm, "mm"))],
    ["FL", ...babies.map((b) => fmt(b.fl_mm, "mm"))],
    ["BPD", ...babies.map((b) => fmt(b.bpd_mm, "mm"))],
    ["FHR", ...babies.map((b) => fmt(b.fhr_bpm, "bpm"))],
    ["Placenta", ...babies.map((b) => fmt(b.placenta))],
    ["Placenta grade", ...babies.map((b) => fmt(b.placenta_grade))],
    ["AFI (liquor)", ...babies.map((b) => fmt(b.liquor_afi_cm, "cm"))],
    ["DVP", ...babies.map((b) => fmt(b.dvp_cm, "cm"))],
    ["UA Doppler", ...babies.map((b) => fmt(b.umbilical_doppler))],
  ];

  const widths = rows[0].map((_, col) =>
    Math.max(...rows.map((r) => String(r[col] ?? "").length))
  );
  const line = (r) => r.map((c, i) => String(c ?? "").padEnd(widths[i])).join("  |  ");
  const sep = widths.map((w) => "-".repeat(w)).join("--+--");

  console.log("");
  console.log("=== Scan summary ===");
  console.log(`Report date:      ${fmt(result.report_date)}`);
  console.log(`Gestational age:  ${fmt(result.gestational_age_on_report)}`);
  console.log(`Twins detected:   ${result.twins_detected ? "yes" : "no"}`);
  console.log("");
  if (babies.length === 0) {
    console.log("(no per-baby data extracted)");
  } else {
    console.log(line(rows[0]));
    console.log(sep);
    for (const r of rows.slice(1)) console.log(line(r));
  }
  console.log("");
  if (derived.efw_discordance_percent !== null) {
    console.log(
      `Inter-twin EFW discordance: ${derived.efw_discordance_percent}%` +
        (derived.clinically_significant ? `  << ${derived.note.toUpperCase()} >>` : ` (${derived.note})`)
    );
  } else {
    console.log(`Inter-twin EFW discordance: ${derived.note}`);
  }
  if (result.impression) console.log(`\nReport impression (verbatim): ${result.impression}`);
  if (result.flags?.length) console.log(`\nFlags: ${result.flags.map((f) => `\n  - ${f}`).join("")}`);
  if (result.confidence_notes) console.log(`\nConfidence notes: ${result.confidence_notes}`);
  console.log(
    "\nNote: this tool only transcribes what is printed on the report. It provides no medical advice. Always review results with your doctor."
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printUsage();
    process.exit(0);
  }
  if (args.invalid || !args.imageFile) {
    printUsage();
    process.exit(1);
  }

  const provider = resolveProvider(args.provider);
  if (!provider) {
    printUsage();
    process.exit(1);
  }

  // --- Load the image ---
  const ext = path.extname(args.imageFile).toLowerCase();
  const mediaType = MEDIA_TYPES[ext];
  if (!mediaType) {
    console.error(
      `Unsupported image extension "${ext}". Supported: ${Object.keys(MEDIA_TYPES).join(", ")}`
    );
    process.exit(1);
  }

  let imageBuffer;
  try {
    imageBuffer = await readFile(args.imageFile);
  } catch (err) {
    console.error(`Could not read image file "${args.imageFile}": ${err.message}`);
    process.exit(1);
  }
  const imageBase64 = imageBuffer.toString("base64");

  // --- Build the request (validates Azure env vars unless --dry-run) ---
  const request = buildRequest(provider, mediaType, imageBase64, args.twins, args.dryRun);

  // --- Dry run: show the exact request shape, minus image bytes ---
  if (args.dryRun) {
    console.log(`POST ${request.url}`);
    console.log("Headers: " + JSON.stringify(request.maskedHeaders, null, 2));
    console.log(
      "Body: " +
        JSON.stringify(
          redactImageForDryRun(provider, request.payload, mediaType, imageBuffer.length, imageBase64.length),
          null,
          2
        )
    );
    process.exit(0);
  }

  // --- API key check (Azure env vars were already validated in buildRequest) ---
  if (provider === "anthropic" && !process.env.ANTHROPIC_API_KEY) {
    console.error(`ANTHROPIC_API_KEY is not set.

Set it and re-run:
  PowerShell:   $env:ANTHROPIC_API_KEY = "sk-ant-..."
  cmd.exe:      set ANTHROPIC_API_KEY=sk-ant-...
  bash/zsh:     export ANTHROPIC_API_KEY="sk-ant-..."

Get a key at https://platform.claude.com/ (API Keys).
Tip: use --dry-run to inspect the request payload without a key.`);
    process.exit(1);
  }

  // --- Call the API ---
  let res;
  try {
    res = await fetch(request.url, {
      method: "POST",
      headers: request.headers,
      body: JSON.stringify(request.payload),
    });
  } catch (err) {
    console.error(`Network error calling ${request.label}: ${err.message}`);
    process.exit(1);
  }
  let bodyText = await res.text();

  // Azure compatibility fallback: some older api-version/model combinations
  // reject max_completion_tokens ("Unrecognized request argument"); retry once
  // with the legacy max_tokens parameter.
  if (
    provider === "azure" &&
    res.status === 400 &&
    /max_completion_tokens/i.test(bodyText) &&
    /(unrecognized|unsupported|unknown)/i.test(bodyText)
  ) {
    console.error(
      "Note: this deployment/api-version rejected max_completion_tokens — retrying once with max_tokens."
    );
    const fallbackPayload = { ...request.payload, max_tokens: MAX_TOKENS };
    delete fallbackPayload.max_completion_tokens;
    try {
      res = await fetch(request.url, {
        method: "POST",
        headers: request.headers,
        body: JSON.stringify(fallbackPayload),
      });
    } catch (err) {
      console.error(`Network error calling ${request.label}: ${err.message}`);
      process.exit(1);
    }
    bodyText = await res.text();
  }

  if (!res.ok) reportHttpError(provider, res, bodyText);

  const { resultText, usageLine } =
    provider === "azure" ? parseAzureCompletion(bodyText) : parseAnthropicMessage(bodyText);

  let result;
  try {
    result = JSON.parse(resultText);
  } catch (err) {
    console.error(`Model output was not valid JSON (${err.message}):`);
    console.error(resultText.slice(0, 2000));
    process.exit(1);
  }

  // --- Derived metrics (computed here, never by the model) ---
  const derived = computeDiscordance(result.babies);

  const output = {
    ...result,
    derived: {
      efw_discordance_percent: derived.efw_discordance_percent,
      efw_discordance_clinically_significant: derived.clinically_significant,
      efw_discordance_note: derived.note,
      discordance_threshold_percent: DISCORDANCE_THRESHOLD_PERCENT,
    },
  };

  console.log(JSON.stringify(output, null, 2));
  printSummary(result, derived);

  if (usageLine) console.error(usageLine);
}

main().catch((err) => {
  console.error(`Unexpected error: ${err?.stack ?? err}`);
  process.exit(1);
});
