# Week-by-week baby art

Generated once with `tools/baby-art/generate.js` (Azure GPT-image-1) and
bundled here. The app (`lib/widgets/baby_visual.dart`) maps each
gestational week to the nearest stage image; if none is present it falls back
to the built-in procedural illustration.

Expected files:
- `week_08.png` … `week_40.png` (singleton set)
- optional `twin_week_08.png` … `twin_week_40.png` (twin set)

These are friendly illustrations, not medical images.
