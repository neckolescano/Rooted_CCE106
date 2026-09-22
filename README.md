# Rooted — Setup Guide

## 1. Extract & open
Unzip this folder anywhere, then open it in VS Code / Android Studio as a
Flutter project (it already has a `pubspec.yaml`, so your IDE should
recognize it automatically).

## 2. Install packages
In the terminal, inside the project folder, run:

```
flutter pub get
```

## 3. Your Piskel art is already in
Your 5 stage sprites and 4 growth-transition animations are already
placed and wired up:

```
assets/images/plant/stages/   seed.png, sprout.png, grow.png, bloom.png, fullgrown.png
assets/images/plant/frames/   seed_sprout_00..09.png, sprout_grow_00..09.png,
                               grow_bloom_00..09.png, bloom_fullgrown_00..09.png
```

There's no separate "wilted" art — when a session is given up on, the
app just desaturates/darkens the current stage's sprite in code
(`PlantDisplay`), so you don't need to draw extra wilted frames.

If you redraw or add more art later, keep these exact names (or update
the paths in `plant_model.dart`), and remember Flutter only picks up
files placed **directly inside** `stages/` or `frames/` — not in new
subfolders — unless you also add that subfolder to `pubspec.yaml`.

## 4. Button art
Every `PixelButton` in the app (Continue with Google, Create Cozy Account,
Start Study Session, Pause/Resume, Give Up) now uses your hand-drawn
wooden plaque instead of the old flat rectangle:

```
assets/images/buttons/button_plaque.png
```

It's a single 96×48 image reused everywhere — only the plain wood-grain
gap in the middle (roughly x=50–79 in the source art) stretches to fit
each button's width, so the flower details on both ends stay crisp and
undistorted no matter how long the label is. If you redraw the art
later with a plainer/wider middle section, widen `_stretchZone` in
`lib/widgets/pixel_button.dart` to match.

The "Give Up" button gets a reddish color wash over the same plaque
(via the `tint` parameter) instead of a separate image, so it still
reads as the "danger" action.

## 5. Harvest popup frame
The congrats popup now uses your wooden scroll art instead of a plain
box:

```
assets/images/popups/harvest_frame.png
```

Its baked-in "CONGRATULATIONS!" banner is kept as-is; the plant image,
message, and buttons are positioned in the open parchment area below
it using percentage-based padding (see the `Padding` inside
`lib/widgets/harvest_celebration_dialog.dart`) — if you redraw the
frame with the parchment area in a different spot, adjust those
percentages to match.

## 6. Background scene (Timer screen)
The Timer screen now supports a full-bleed background behind the plant.
Drop your pixel-art meadow/garden image in as:

```
assets/images/backgrounds/garden_meadow.png
```

Until that file exists, it falls back to a soft gradient so the screen
doesn't go back to plain black. The `BackgroundScene` widget in
`lib/widgets/background_scene.dart` is reusable — Home screen could get
the same treatment later if you want a consistent look across screens,
just wrap its body in `BackgroundScene(child: ...)` too.

## 4. Run it

```
flutter run
```

## What's included in this batch
- Login/Register screen (buttons work, but there's no real Google/account
  auth yet — they just take you into the app)
- Home screen with the current plant + Start Study Session button
- Timer screen with a real 25-minute countdown, Pause/Resume, and Give Up
- **Fixed:** bottom nav bar was stretching to fill the whole screen
  (missing height constraint) — it's now a normal fixed-height bar
- **Fixed:** Timer screen was missing its own `Scaffold`, so it rendered
  on plain black instead of your theme background
- All buttons now use your hand-drawn wooden plaque art (9-slice
  stretched) instead of the flat rectangle style
- **Fixed:** finishing a session while the plant was already fully
  grown used to silently do nothing useful (no next stage to grow
  into). Now it triggers a proper harvest: the plant is recorded to
  the Garden, a congrats popup appears, and the student chooses to
  either go home or start a new session (which resets to a fresh seed)
- **Fixed:** a real "fast forward" bug — opening the Timer screen could
  briefly see a leftover `"completed"` status from the *previous*
  session (since `SessionModel` lives at the app root) and instantly
  fire the growth/finish sequence before the new countdown even
  started
- **Fixed a crash introduced by that first fix:** calling
  `SessionModel.start()` synchronously in `initState` threw
  `setState() or markNeedsBuild() called during build`, since
  `notifyListeners()` can't fire while Flutter is still building this
  same widget tree. The real fix keeps `start()` inside
  `addPostFrameCallback` (safe timing) and instead adds a local
  `_sessionStarted` flag that only trusts a `"completed"` status once
  *this* screen has confirmed its own session actually started —
  closing the original race without reintroducing the crash
- Harvest popup now uses your hand-drawn wooden scroll frame art
- Plant art on Home, Timer, and in the harvest popup is bigger/more
  visible (was rendering smaller than it needed to)
- **Fixed:** bottom nav overflowed by 3px on whichever tab was
  selected — only the selected tab had a border, which shrank that
  one item's available content height compared to the others. Every
  tab now reserves the same border space (transparent when unselected)
- Timer screen now supports a full-bleed background scene behind the
  plant (falls back to a soft gradient until you add the art)
- Your real Piskel art wired in for all 5 stages
- A short growth animation plays on the Timer screen when a session
  completes (using your 10-frame transition art), before returning home
- Giving up desaturates/darkens the plant in place — no wilted art needed
- Garden screen (streak, total sessions, and the fully-grown planted
  row are all real and saved now; the "unlocked species" list below it
  is still placeholder data — see Known simplifications)
- Profile screen (push reminders toggle is local UI only for now)
- Streak, total sessions, and plant progress are saved on-device and
  survive closing the app

## Known simplifications (flagged in code with comments)
- The timer doesn't yet account for the app being backgrounded/killed
  mid-session (your Chapter 1 doc calls this out as an anticipated
  challenge — worth tackling once the core flow feels good)
- Garden screen's "unlocked species" list (Wild Sunflower, Desert
  Cactus, etc.) is still hardcoded placeholder data — there's only one
  plant/species in the app so far, so this is waiting on that feature
- The harvest popup (`lib/widgets/harvest_celebration_dialog.dart`) is a
  placeholder design matching the app's look — swap in your own
  Figma/Piskel popup art whenever it's ready; it only needs to keep
  returning `true` (start new session) / `false` (go home) from its two
  buttons for the logic underneath to keep working
- No AI flashcard/notes feature yet — that's next once this batch feels
  solid
