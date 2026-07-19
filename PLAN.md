# BumpBuddy — Pregnancy Companion (working title)

> Working title only. Candidate names: BumpBuddy AI, Pregna AI, TwinNest AI.
> Positioning: **"Upload your scan. Understand your pregnancy."**
> Differentiator: first-class **twins support driven by chorionicity**, not just two baby icons.

## Guardrails (apply to every feature)

- The app is **educational and organizational, never diagnostic**. Every clinical-adjacent
  screen carries a "discuss with your doctor" note. AI (later phases) must never reassure
  or alarm on clinical judgment calls.
- Medical records are sensitive personal data (India DPDP Act). Local-first storage in v1;
  encryption + explicit consent before any cloud sync ships.

## Phase 1 scope (this build)

1. **Pregnancy setup** — singleton / twins; if twins → chorionicity (DCDA / MCDA / MCMA /
   not sure yet); LMP or EDD (each computes the other, EDD = LMP + 280d); optional IVF flag
   (direct EDD entry); doctor + hospital; baby nicknames (A/B).
2. **Dashboard** — gestational age (W+D), fruit-size comparison, per-baby cards for twins,
   next appointment, today's medicines, water tracker, weight quick-log.
3. **Timeline** — weeks 4–40: development, tests due, symptoms, nutrition, questions for
   the doctor. **Twins-aware scan schedule** (see below).
4. **Symptom journal** — date, auto-computed week, severity (1–5), duration, medicine
   taken, doctor informed.
5. **Medicine reminders** — name, dose, time slots; surfaced on dashboard. (Real push
   notifications land with the Android toolchain; web preview shows in-app.)
6. **Records vault** — manual upload organized by category (ultrasound, blood test,
   prescription, vaccination, bill, photo, other). No AI yet — AI extraction is Phase 2.
7. **Hospital bag** — separate checklists for singleton vs twins (extra of everything,
   NICU-contingency items, two car seats).
8. **Trackers** — weight history, daily water glasses.

## Twins clinical logic (the moat)

| | DCDA | MCDA | MCMA |
|---|---|---|---|
| Scan cadence | ~q4w from 24w (growth) | **q2w from 16w** (TTTS surveillance) | q2w from 16w, intensive monitoring from ~26w |
| Typical delivery window | 37–38w | 36–37w | 32–34w |
| Growth comparison flag (Phase 2+) | EFW discordance ≥ 20–25% | discordance + liquor/DVP asymmetry (TTTS) | as MCDA + cord entanglement context |

All shown as *typical schedules — your doctor's plan takes precedence*.

Timeline horizon also shortens for twins (content framed to ~37w, not 40w).

## Data model (local-first, JSON via shared_preferences behind a repository interface; swap to drift/SQLite later)

- `PregnancyProfile`: type, chorionicity?, lmp?, edd, ivf, babies[{label, nickname}], doctor, hospital
- `SymptomEntry`: date, symptom, severity, duration, medicineTaken, doctorInformed, notes
- `Medicine`: name, dose, timeSlots[], active
- `Appointment`: date, title, type, notes, done
- `RecordItem`: category, date, title, notes (+file ref on mobile)
- `WeightEntry`: date, kg · `WaterLog`: date, glasses
- `ChecklistItem`: listId, text, checked

## Later phases (unchanged from original roadmap)

- **P2**: AI scan OCR (Azure Document Intelligence) — per-baby biometry extraction (HC, AC, FL, EFW, placenta grade, liquor/AFI), growth comparison with discordance %.
- **P3**: AI explanations + report comparison (context-aware, guardrailed).
- **P4**: Partner mode, cloud sync, premium (₹499–999/yr).
- **P5**: Doctor dashboard (web).

## Stack decisions

- **Flutter** (mobile-first; web build used for dev preview).
- v1 storage: local only (no auth, no backend) — sync/auth chosen in P4 (pick ONE ecosystem; if Azure backend, prefer Entra External ID over mixing Firebase in).
- State: `provider` + ChangeNotifier. Simple by design.
