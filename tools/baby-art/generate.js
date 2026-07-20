#!/usr/bin/env node
/**
 * BumpBuddy baby-art generator.
 *
 * Generates a consistent set of "baby this week" illustrations with Azure
 * OpenAI GPT-image-1 and saves them into ../../assets/baby/. Run ONCE at dev
 * time; the PNGs are bundled, so there is no per-user cost and the app works
 * offline. (DALL·E 3 was retired May 2026 — GPT-image-1 is its successor.)
 *
 * Usage:
 *   node generate.js               # singleton set
 *   node generate.js --twins       # twin set (assets/baby/twin_week_XX.png)
 *   node generate.js --only 20     # regenerate a single stage
 *
 * Env (reuse your Foundry values):
 *   AZURE_OPENAI_ENDPOINT           e.g. https://<res>.services.ai.azure.com
 *   AZURE_OPENAI_IMAGE_DEPLOYMENT   your gpt-image-1 deployment name
 *   AZURE_OPENAI_API_KEY
 *   AZURE_OPENAI_IMAGE_API_VERSION  optional; defaults below
 */

import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const API_VERSION =
  process.env.AZURE_OPENAI_IMAGE_API_VERSION || "2025-04-01-preview";
// Stages to generate; each app week maps to the nearest of these.
const STAGES = [8, 12, 16, 20, 24, 28, 32, 36, 40];

// One locked art style so the whole set looks cohesive.
const STYLE =
  "Tasteful educational medical illustration of fetal development, soft " +
  "3D-rendered and wholesome, of a healthy unborn baby curled peacefully in " +
  "a stylised womb. The baby is in a modest curled pose with knees drawn up " +
  "and arms tucked in, limbs covering the torso; smooth skin with no explicit " +
  "anatomical detail. Warm rosy-and-cream palette, soft studio lighting, " +
  "gentle rim light, smooth clay-like shading, plain soft-pink vignette " +
  "background. Tender, calm, non-graphic, no text, no watermark, no medical " +
  "instruments. Centered.";

function stagePrompt(week, twins) {
  // Near-term stages: keep the baby nude-in-womb for visual consistency with
  // the earlier weeks, but render it GENDER-NEUTRAL and featureless with the
  // lower body softly veiled in shadow / out of focus, so there is no explicit
  // anatomy for the moderation system to flag.
  if (week >= 30) {
    const who = twins
      ? "two peaceful full-term babies curled together in a stylised womb, facing each other, knees drawn up"
      : "a peaceful full-term baby curled in the fetal position in a stylised womb, knees drawn up to the chest";
    return `${STYLE} Show ${who}, rounded with chubby cheeks (about ${week} weeks). ` +
      "The baby is gender-neutral, smooth and featureless with absolutely no genitalia or anatomical detail; " +
      "the lower body is softly veiled in gentle shadow and soft focus (blurred), while the face, chest and hands stay in focus.";
  }
  const who = twins
    ? "two small twin babies curled together in a stylised womb, facing each other, knees tucked, modest pose, no explicit anatomy"
    : "one baby curled in the fetal position in a stylised womb, knees tucked to the chest, modest pose, no explicit anatomy";
  let size;
  if (week <= 10) size = "very small and delicate, large head relative to body, tiny limb buds";
  else if (week <= 18) size = "small, big head, forming little arms and legs, slender";
  else size = "clearly baby-like, rounded, hands near the face";
  return `${STYLE} Show ${who}, at about ${week} weeks of pregnancy: ${size}.`;
}

function getConfig() {
  const endpoint = (process.env.AZURE_OPENAI_IMAGE_ENDPOINT ||
          process.env.AZURE_OPENAI_ENDPOINT ||
          "")
      .replace(/\/+$/, "");
  const deployment = process.env.AZURE_OPENAI_IMAGE_DEPLOYMENT || "";
  const key =
      process.env.AZURE_OPENAI_IMAGE_KEY || process.env.AZURE_OPENAI_API_KEY || "";
  if (!endpoint || !deployment || !key) {
    console.error(
      "Set AZURE_OPENAI_IMAGE_ENDPOINT, AZURE_OPENAI_IMAGE_DEPLOYMENT and " +
        "AZURE_OPENAI_IMAGE_KEY.\nPowerShell:\n" +
        "  $env:AZURE_OPENAI_IMAGE_DEPLOYMENT = 'gpt-image-2'\n"
    );
    process.exit(1);
  }
  // The modern "/openai/v1" surface takes the model in the body and needs no
  // deployment path segment; the classic surface uses /deployments/<d>/...
  const isV1 = /\/openai\/v1\/?$/.test(endpoint) || endpoint.includes("/openai/v1/");
  return { endpoint, deployment, key, isV1 };
}

async function generateOne(cfg, week, twins) {
  const payload = {
    prompt: stagePrompt(week, twins),
    n: 1,
    size: "1024x1024",
    quality: "high",
    output_format: "jpeg",
    output_compression: 85,
  };
  const url = cfg.isV1
    ? `${cfg.endpoint}/images/generations`
    : `${cfg.endpoint}/openai/deployments/${cfg.deployment}/images/generations?api-version=${API_VERSION}`;
  if (cfg.isV1) payload.model = cfg.deployment;

  // The safety filter is non-deterministic on borderline (nude infant) prompts
  // — the same request may block once and pass on a retry. Retry a few times.
  let body;
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json", "api-key": cfg.key },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      body = await res.json();
      break;
    }
    const text = await res.text();
    const blocked = res.status === 400 && text.includes("moderation_blocked");
    if (blocked && attempt < 5) {
      console.log(`  week ${week}: moderation retry ${attempt}…`);
      continue;
    }
    throw new Error(`week ${week}: HTTP ${res.status} ${text}`);
  }
  const b64 = body.data?.[0]?.b64_json;
  if (!b64) throw new Error(`week ${week}: no image in response`);
  const outDir = path.join(import.meta.dirname, "..", "..", "assets", "baby");
  await mkdir(outDir, { recursive: true });
  const name = `${twins ? "twin_" : ""}week_${String(week).padStart(2, "0")}.jpg`;
  await writeFile(path.join(outDir, name), Buffer.from(b64, "base64"));
  console.log(`✓ ${name}`);
}

async function main() {
  const twins = process.argv.includes("--twins");
  const onlyIdx = process.argv.indexOf("--only");
  const only = onlyIdx >= 0 ? Number(process.argv[onlyIdx + 1]) : null;
  const cfg = getConfig();
  const weeks = only ? [only] : STAGES;
  for (const w of weeks) {
    try {
      await generateOne(cfg, w, twins);
    } catch (e) {
      console.error(`✗ ${e.message}`);
    }
  }
  console.log("Done. Review assets/baby/ and keep the ones you like.");
}

main();
