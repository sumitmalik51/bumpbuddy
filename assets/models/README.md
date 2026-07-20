# 3D baby models

Drop a mobile-optimized glTF binary here named **`baby.glb`** and it will be
bundled and shown in the app's "3D baby" screen (native Google Filament
rendering, drag to orbit / pinch to zoom).

Requirements for the model:
- Format: `.glb` (binary glTF), ideally Draco-compressed, PBR textures baked in.
- Keep it mobile-sized (a few MB); high-poly medical scans should be decimated.
- License **must** permit redistribution inside a shipped commercial app.

Sourcing options (best → fastest):
1. Commission a medical 3D artist for staged models (e.g. 12/20/28/36 weeks).
2. License from Sketchfab / TurboSquid / CGTrader (verify the commercial +
   redistribution license).

Optional: add an image-based lighting environment `env.ktx` for nicer studio
lighting, and wire `iblPath` in `lib/screens/baby_3d_screen.dart`.

Until a model is present, the app falls back to the built-in 2D illustration.
