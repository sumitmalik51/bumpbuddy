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
  "Soft 3D-rendered digital illustration, wholesome and cute, of a healthy " +
  "unborn baby curled peacefully in a stylised womb. Warm rosy-and-cream " +
  "palette, soft studio lighting, gentle rim light, smooth clay-like shading, " +
  "plain soft-pink vignette background. Tender, calm, non-graphic, " +
  "non-clinical, no text, no watermark, no medical instruments. Centered.";

function stagePrompt(week, twins) {
  const who = twins
    ? "two small twin babies curled together, facing each other"
    : "one baby curled in the fetal position";
  let size;
  if (week <= 10) size = "very small and delicate, large head relative to body, tiny limb buds";
  else if (week <= 18) size = "small, big head, forming little arms and legs, slender";
  else if (week <= 27) size = "clearly baby-like, rounded, hands near the face";
  else if (week <= 34) size = "plump and full, chubby cheeks, fills much of the womb";
  else size = "full-term size, very round and chubby, snug in the womb";
  return `${STYLE} Show ${who}, at about ${week} weeks of pregnancy: ${size}.`;
}

function getConfig() {
  const endpoint = (process.env.AZURE_OPENAI_ENDPOINT || "").replace(/\/+$/, "")
    .replace(/\/api\/projects.*$/, "");
  const deployment = process.env.AZURE_OPENAI_IMAGE_DEPLOYMENT || "";
  const key = process.env.AZURE_OPENAI_API_KEY || "";
  if (!endpoint || !deployment || !key) {
    console.error(
      "Set AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_IMAGE_DEPLOYMENT and " +
        "AZURE_OPENAI_API_KEY.\nPowerShell:\n" +
        "  $env:AZURE_OPENAI_IMAGE_DEPLOYMENT = 'gpt-image-1'\n"
    );
    process.exit(1);
  }
  return { endpoint, deployment, key };
}

async function generateOne(cfg, week, twins) {
  const url =
    `${cfg.endpoint}/openai/deployments/${cfg.deployment}/images/generations` +
    `?api-version=${API_VERSION}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", "api-key": cfg.key },
    body: JSON.stringify({
      prompt: stagePrompt(week, twins),
      n: 1,
      size: "1024x1024",
      quality: "high",
      output_format: "png",
    }),
  });
  if (!res.ok) {
    throw new Error(`week ${week}: HTTP ${res.status} ${await res.text()}`);
  }
  const body = await res.json();
  const b64 = body.data?.[0]?.b64_json;
  if (!b64) throw new Error(`week ${week}: no image in response`);
  const outDir = path.join(import.meta.dirname, "..", "..", "assets", "baby");
  await mkdir(outDir, { recursive: true });
  const name = `${twins ? "twin_" : ""}week_${String(week).padStart(2, "0")}.png`;
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
