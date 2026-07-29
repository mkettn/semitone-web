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
- **Settings** — concert pitch (A4, default 440 Hz), metronome "keep tick".
- **Custom scale boundaries** *(new)* — define your own named tone heights
  (in cents within an octave) instead of standard 12-tone equal
  temperament, and have the tuner match detected pitches against them.
  Useful for microtonal or alternative tuning systems. You can save
  multiple named scales (e.g. "myscale1", "myscale2") under **Settings →
  My scales** and switch which one is active at any time. Each is
  visualized as a "cake": each tone's wedge runs from the midpoint with
  its previous neighbour to the midpoint with its next one. Duplicate a
  tone to split its wedge, then move the copy to redraw where the octave
  gets split — or delete tones to carve out a simpler scale. When
  creating a new scale you pick a starting point:
    - the default chromatic scale (C, C#, D, D#, E, F, F#, G, G#, A, A#,
      H — German naming, H = B; delete the sharps to get plain
      C-D-E-F-G-A-H), or
    - one of the four genera of **Byzantine chant** theory (Modern
      Patriarchal Committee 72-moria system) — Diatonic, Soft Chromatic,
      Hard Chromatic, and Enharmonic — rooted on Νη (Ni), the *vasi*
      (base note). Byzantine chant has no fixed concert pitch: set the
      tuner's concert pitch (Settings → Global) to whatever frequency you
      want Νη to be, and every other degree (Πα, Βου, Γα, Δι, Κε, Ζω) is
      expressed relative to it.

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
  models/     ScaleDegree / TuningScale (12-TET default + custom scales),
              ScalePreset (chromatic + Byzantine chant starting points)
  services/   SettingsService, TunerEngine (mic capture), MetronomeEngine
  screens/    Tuner, Metronome, Settings, My Scales (list), Custom Scale
              Boundaries (per-scale editor)
  theme/      dark colour palette matching the original app
  widgets/    CentErrorBar (cents deviation indicator),
              ScaleCakeChart (octave-as-pie-chart editor visualization)
```
