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
- **Settings** — just metronome "keep tick"; scale management lives on
  the tuner tab itself (see below).
- **Scales** — the tuner always matches detected pitches against
  whichever scale is active; there's no separate "standard" scale or a
  toggle to turn matching on. A dropdown at the top of the tuner tab
  switches between your saved scales, with buttons right next to it to
  **New** (starting from the chromatic default), **Copy** the active
  scale, **Delete** it (as long as it isn't the last one), **Export** it
  to a `.json` file, or **Import** one — no extra screens or popups for
  any of that. Out of the box you get five scales: the default
  **Chromatic** one (C, C#, D, D#, E, F, F#, G, G#, A, A#, H — German
  naming, H = B; delete the sharps to get plain C-D-E-F-G-A-H), and the
  four genera of **Byzantine chant** theory (Modern Patriarchal
  Committee 72-moria system) — Diatonic, Soft Chromatic, Hard Chromatic,
  and Enharmonic — rooted on Νη (Ni), the *vasi* (base note).

  Editing a scale (the pencil button) opens its "cake" visualization:
  each tone's wedge runs from the midpoint with its previous neighbour
  to the midpoint with its next one. Duplicate a tone to split its wedge,
  then move the copy to redraw where the octave gets split — or delete
  tones to carve out a simpler scale.

  Each scale carries its **own base frequency** (in its editor, next to
  its root octave), rather than sharing one global concert pitch — so
  you can have several scales tuned to different references at once,
  and scales with no fixed concert pitch at all (like Byzantine chant,
  whose base note can be set to whatever the *vasi* happens to be) don't
  need to borrow another scale's A4.

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

## Project layout

```
lib/
  dsp/        pitch detection (autocorrelation, ported from DSP.java)
  models/     ScaleDegree / TuningScale, ScalePreset (chromatic +
              Byzantine chant starting points, also the initial seed data)
  services/   SettingsService (keep-tick + saved scales), TunerEngine
              (mic capture), MetronomeEngine, scale_io (export/import)
  screens/    Tuner (incl. the scale switcher bar), Metronome, Settings,
              Custom Scale Boundaries (per-scale editor)
  theme/      dark colour palette matching the original app
  widgets/    CentErrorBar (cents deviation indicator),
              ScaleCakeChart (octave-as-pie-chart editor visualization)
```
