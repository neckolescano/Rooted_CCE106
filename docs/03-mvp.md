# 03 — MVP

> **Important:** the owner never wrote an explicit "MVP list" in the
> conversation. This document **derives** the MVP from three things the
> owner did state:
>
> 1. the course title: *"An AI-Assisted Pomodoro and Active Recall Mobile
>    Application for Independent Student Learning"*;
> 2. the handoff success statement: *"A fully functional, polished app that
>    matches the Figma design and the pixel-art cottagecore look"*;
> 3. the core loop the owner defined (study → complete session → grow a plant
>    → add to garden → collect/unlock → build a garden).
>
> Anything labelled **(derived)** is an interpretation, not an owner quote.
> If the owner or the teacher defines a stricter list, that list wins —
> record it here and in [12-decision-log.md](12-decision-log.md).

---

## MVP definition (derived)

The MVP is the smallest version that honestly delivers all three words of
the title (**Pomodoro**, **AI-assisted**, **active recall**) inside the
garden loop, with the polished pixel look.

### Must have

| # | Capability | Why it's MVP | Status |
|---|---|---|---|
| M1 | Sign in (Google / email / guest) and per-user cloud save | Data survives reinstalls; course project uses Firebase | ✅ |
| M2 | Focus timer with a user-chosen length, pause, give up (with confirmation) | "Pomodoro" | ✅ |
| M3 | Completing a session grows the plant one stage; giving up wilts it | Core loop | ✅ |
| M4 | Harvest a fully grown plant into the garden, with a celebration | Core loop / reward | ✅ |
| M5 | Garden shows grown plants and progress | "Build a virtual garden" | ✅ |
| M6 | Take notes during a session without stopping the timer | Links studying to the timer | ✅ |
| M7 | Generate questions + flashcards from notes with AI | "AI-assisted" + "active recall" | ✅ |
| M8 | Answer questions / flip flashcards with feedback | "Active recall" | ✅ (per-question ✓/✗; no score screen) |
| M9 | Consistent pixel look on every screen, no overflow, no black boot screen | "Polished, matches the design" | ✅ |
| M10 | App shows the kuwaGO name and owl icon | Teacher asked for the icon change | ✅ |
| M11 | The app never crashes on AI failure; clear, friendly errors | Reliability on slow mobile data | ✅ |

### Should have (make the MVP feel complete — derived)

| # | Capability | Status |
|---|---|---|
| S1 | Several plant species unlocked by studying + seed picker | ✅ |
| S2 | XP / garden level / badges | ✅ |
| S3 | Profile with photo and editable name | ✅ |
| S4 | Study options (counts, style, difficulty) | ✅ |
| S5 | Player Card designs with quests **and a way to choose one** | ✅ |
| S6 | The timer keeps correct time if the app is backgrounded | ❌ |

### Not in the MVP (derived)

Everything in [04-future-roadmap.md](04-future-roadmap.md): rounds and
breaks, full quiz flow with score, summaries/explanations, multiple
notebooks, push reminders, garden decorations, sound, daily streak, and so
on.

---

## Gap to MVP (as of 2026-09-29)

All **must-haves** are implemented. What remains before the app could be
called "MVP-complete and polished" (derived):

1. **Timer persistence** (S6): the countdown uses `Timer.periodic`; if
   Android pauses or kills the app, time is lost. Plan: store an `endsAt`
   timestamp. See [04-future-roadmap.md](04-future-roadmap.md).
2. **Device checks the owner hasn't confirmed yet:** smoothness of the
   window-zoom transition on the phone (use the profile build).
3. **Release readiness** (only if a release/APK is to be graded): register
   Play Integrity for App Check and consider enforcement — see
   [10-ai-and-firebase.md](10-ai-and-firebase.md) and
   [05-open-questions.md](05-open-questions.md).
