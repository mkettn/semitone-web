# Semitone Web

A Flutter tuner and metronome app, built in the spirit of the original
[Semitone](https://github.com/mkettn/semitone) Android app: same dark,
minimal look and feel, same cents-based pitch measurement — without the
piano (for now).

## Features

- **Tuner** — listens to the microphone, estimates the fundamental
  frequency via autocorrelation (ported from the original app's DSP), and
  displays the detected note along with a cents-error bar, just like the
  original `CentErrorView`.
- **Metronome** — adjustable BPM (20-300), beat indicator, synthesized
  click sounds (no bundled audio assets required).
- **Settings** — just metronome "keep tick"; scale management is its own
  first-class area (see below), not buried in settings.
- **Scales** — the tuner always matches detected pitches against
  whichever scale is active; there's no separate "standard" scale or a
  toggle to turn matching on. The app bar's title is a live dropdown for
  switching the active scale from anywhere. The **tune icon** next to it
  opens **My Scales**, a full list with buttons to **New** (starting from
  the chromatic default), **Copy**, **Delete** (as long as it isn't the
  last one), **Export** a scale to a `.json` file, or **Import** one —
  tapping a scale opens its editor directly, no extra popups for any of
  it. Out of the box you get five scales, loaded from
  `assets/scales/*.json` (see below): the default **Chromatic** one (C,
  C#, D, D#, E, F, F#, G, G#, A, A#, H — German naming, H = B; delete the
  sharps to get plain C-D-E-F-G-A-H), and the four genera of **Byzantine
  chant** theory (Modern Patriarchal Committee 72-moria system) —
  Diatonic, Soft Chromatic, Hard Chromatic, and Enharmonic — rooted on Νη
  (Ni), the *vasi* (base note).

  A scale's editor shows its "cake" visualization: each tone's wedge runs
  from the midpoint with its previous neighbour to the midpoint with its
  next one. Duplicate a tone to split its wedge, then move the copy to
  redraw where the octave gets split — or delete tones to carve out a
  simpler scale.

  Each scale carries its **own base frequency** (in its editor, next to
  its root octave), rather than sharing one global concert pitch — so
  you can have several scales tuned to different references at once,
  and scales with no fixed concert pitch at all (like Byzantine chant,
  whose base note can be set to whatever the *vasi* happens to be) don't
  need to borrow another scale's A4.

  **Adding a new pre-configured scale** is just dropping another `.json`
  file into `assets/scales/` (same shape as `TuningScale.toJson()` —
  `name`, `degrees` [`name`/`cents` pairs], `rootIndex`, `rootOctave`,
  `baseFrequency`; `id` is optional, auto-generated) — no code changes.
  Presets load in filename order (hence the `NN_` prefixes), which is
  also seeding order, so `01_chromatic.json` stays first/active by
  default.

## Getting started

```sh
flutter pub get
flutter run            # any connected device / configured platform
flutter run -d linux   # Linux desktop
flutter run -d chrome  # Web
```

### Linux desktop build requirements

```sh
sudo apt install libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
flutter config --enable-linux-desktop
flutter build linux --release
```

## Git hooks

A `pre-commit` hook lives in `.githooks/` (checked into the repo, unlike
`.git/hooks/`) and runs `flutter analyze` plus a `dart format
--set-exit-if-changed` check scoped to just the `.dart` files staged in
that commit. It won't touch files you haven't staged, so it won't flag the
codebase's existing formatting drift. CI runs the same three checks
(analyze, scoped format, test) on every PR regardless, so the hook is
purely a faster local heads-up, not a substitute.

Point git at it once per clone:

```sh
git config core.hooksPath .githooks
```

This is a local git config setting, not something the repo can enforce on
its own — every contributor needs to run it after cloning.

## Project layout

```
lib/
  dsp/        pitch detection (autocorrelation, ported from DSP.java)
  models/     ScaleDegree / TuningScale, scale_presets.dart (loads the
              assets/scales/*.json presets via AssetManifest)
  services/   SettingsService (keep-tick + saved scales), TunerEngine
              (mic capture), MetronomeEngine, scale_io (export/import)
  screens/    Tuner, Metronome, Settings, My Scales (list), Custom Scale
              Boundaries (per-scale editor)
  theme/      dark colour palette matching the original app
  widgets/    CentErrorBar (cents deviation indicator),
              ScaleCakeChart (octave-as-pie-chart editor visualization)

assets/
  scales/     pre-configured scales, one .json file per scale
```
