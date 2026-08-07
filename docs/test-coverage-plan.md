# Test coverage: diagnosis and plan

> **Status.** Causes ①, ③ and ⑤ are **done** — see "What landed" at the bottom.
> Coverage went from **57.7% → 83.6%** overall, or **88.5%** as CI now measures
> it (generated files excluded), and the test count from 42 to 120. Causes ②
> (`scale_io`) and ④ (the two mic-facing screens) remain open.

Line coverage sat at **57.7%** (790 / 1368 lines, `flutter test --concurrency=1
--coverage` on `main` @ `be96590`). This document explains *why* it was stuck
there, which of that is a testing gap versus a **testability** gap in the source,
and what to change to fix each.

Nothing here proposes faking a microphone. Synthesizing audio into a virtual
input device to test the tuner end-to-end is not worth the machinery, and CI has
no audio backend to point it at. The recurring theme below is the opposite move:
pull the pure logic *out* of the code that touches the audio plugin, so the
interesting parts can be tested as plain functions with no device at all.

## Baseline, per file

The state at diagnosis time, sorted by coverage; the right-hand column is the
cause, expanded on below. Kept as the "before" picture — see "What landed" for
current numbers on the files that have since moved.

| File | Hit | Total | Miss | % | Why |
|---|---:|---:|---:|---:|---|
| `dsp/pitch_detector.dart` | 0 | 66 | 66 | 0.0% | ① no test at all |
| `services/scale_io.dart` | 0 | 24 | 24 | 0.0% | ② static I/O, no seam |
| `l10n/app_localizations_de.dart` | 3 | 79 | 76 | 3.8% | ⑤ generated noise |
| `services/tuner_engine.dart` | 9 | 56 | 47 | 16.1% | ③ logic inside a stream closure |
| `services/metronome_engine.dart` | 18 | 57 | 39 | 31.6% | ③ `await`s the audio plugin |
| `screens/tuner_screen.dart` | 25 | 52 | 27 | 48.1% | ④ engine constructed internally |
| `models/scale_degree.dart` | 5 | 10 | 5 | 50.0% | ① |
| `screens/settings_screen.dart` | 80 | 145 | 65 | 55.2% | ① no interaction tests |
| `screens/custom_scale_screen.dart` | 128 | 227 | 99 | 56.4% | ① no interaction tests |
| `theme/semitone_theme.dart` | 6 | 10 | 4 | 60.0% | ① |
| `screens/calibration_screen.dart` | 44 | 71 | 27 | 62.0% | ④ engine constructed internally |
| `widgets/scale_cake_chart.dart` | 55 | 84 | 29 | 65.5% | ① hit-testing untested |
| `main.dart` | 9 | 13 | 4 | 69.2% | ⑤ `main()` itself |
| `l10n/app_localizations_en.dart` | 56 | 79 | 23 | 70.9% | ⑤ generated noise |
| `services/tone_player.dart` | 29 | 38 | 9 | 76.3% | ③ fade/stop path |
| `services/settings_service.dart` | 59 | 75 | 16 | 78.7% | ① |
| `screens/home_screen.dart` | 51 | 58 | 7 | 87.9% | ① |
| `l10n/app_localizations.dart` | 15 | 17 | 2 | 88.2% | ⑤ generated noise |
| `screens/metronome_screen.dart` | 44 | 49 | 5 | 89.8% | ① |
| `widgets/cent_error_bar.dart` | 34 | 36 | 2 | 94.4% | — |
| `models/tuning_scale.dart` | 72 | 74 | 2 | 97.3% | — |
| `models/scale_presets.dart` | 10 | 10 | 0 | 100% | — |
| `services/wav_synth.dart` | 38 | 38 | 0 | 100% | — |
| **Total** | **790** | **1368** | **578** | **57.7%** | |

## The five root causes

### ① Untested pure code — no refactoring needed, just missing tests

**`dsp/pitch_detector.dart` is 0% across 66 lines and is the single biggest,
cheapest win in the repo.** It is the largest uncovered file, and it has no
dependencies at all: an FFT, an autocorrelation, and peak-picking with quadratic
interpolation over a `Float64List`. There is no plugin, no `await`, no
`BuildContext` — nothing standing between a test and the code. It's simply never
been called from a test.

Testing it needs no microphone in any form: build a `Float64List` from
`sin(2πft/sr)` and assert `frequency()` returns `f` back within a tolerance. That
is arithmetic, not audio capture.

This was verified against the current code rather than assumed — a throwaway test
feeding 4096-sample sine buffers at 44.1 kHz straight into `PitchDetector`, with
no production change of any kind:

| Input | Detected | Error |
|---:|---:|---:|
| 110 Hz | 108.44 Hz | 1.42% |
| 220 Hz | 219.29 Hz | 0.32% |
| 440 Hz | 441.42 Hz | 0.32% |
| 880 Hz | 881.96 Hz | 0.22% |

So the file is testable *today*, and 66 lines are sitting there for the cost of
writing the test. Note the error grows toward the low end, where a period is a
larger fraction of the window — a ~2% tolerance covers the musical range, and
tightening it further would mean asserting on the interpolator's precision rather
than on pitch detection.

The same "just write the test" category covers `scale_degree.dart`,
`semitone_theme.dart`, the rest of `settings_service.dart`, the two screens with
no interaction tests (`settings_screen`, `custom_scale_screen` — 164 missed lines
between them, addressed by the UI tests below), and `scale_cake_chart`'s
`_sliceForCents` hit-testing.

### ② `scale_io.dart` — static I/O with no seam (0%, 24 lines)

`exportScale`/`importScale` call `FileSaver.instance.saveFile` and
`FilePicker.pickFiles` directly as statics. There is no injection point, so a
test cannot reach the interesting parts — JSON parsing, the `ScaleIoException`
path, fresh-id assignment on import, filename sanitization — without opening a
real file picker.

**Change:** split pure from impure. Extract and export:

- `TuningScale parseScaleJson(List<int> bytes)` — decode + validate, throwing
  `ScaleIoException`; this is where the error path and the fresh-id rule live.
- `Uint8List encodeScaleJson(TuningScale scale)`
- `sanitizeFileName(String)` — currently private `_sanitizeFileName`; make it
  library-public (or `@visibleForTesting`).

`exportScale`/`importScale` shrink to a few lines of picker/saver plumbing around
those. ~18 of the 24 lines become testable; the untestable remainder is the two
plugin calls themselves, which is the correct amount of untestable.

### ③ Logic trapped behind an audio plugin

Three files put real logic where the test environment can't reach it. Per
`AGENTS.md`, `flutter test` has no `AudioPlayer`/`AudioRecorder`, and awaiting one
**hangs rather than fails** — so these aren't merely untested, they're currently
untestable.

**`tuner_engine.dart` (16.1%, 47 missed).** The entire DSP pipeline lives inside
the anonymous `stream.listen((chunk) { ... })` closure in `start()`: byte-buffer
accumulation, the runtime effective-sample-rate measurement, PCM→`Float64List`
conversion, the calibration-offset subtraction, log-frequency conversion, and the
16-slot moving-median smoother. All ~50 lines of it run only when a real
`AudioRecorder` delivers bytes.

**Change:** extract that closure body into its own class, e.g.

```dart
class PitchPipeline {
  PitchPipeline({required int bufferSize, required int nominalSampleRate});
  double calibrationOffsetHz;
  /// Returns a smoothed reading once enough samples have accumulated.
  PitchReading? feed(Uint8List chunk, {Duration? elapsed});
}
```

`TunerEngine.start()` then becomes wiring: recorder stream → `pipeline.feed` →
`_controller.add`. Tests feed `PitchPipeline` synthetic PCM bytes directly and
assert the detected frequency, the calibration offset being applied, the median
smoother rejecting a single outlier, and the effective-sample-rate correction
kicking in after 500 ms. **This is not a fake microphone** — it's calling a
function with a `Uint8List`, the same way `wav_synth_test.dart` already works.

Additionally, make `AudioRecorder` injectable (constructor parameter defaulting
to `AudioRecorder()`) so `hasPermission()`, the `captureFailed` catch, and
`stop()`/`dispose()` are reachable.

**`metronome_engine.dart` (31.6%, 39 missed).** `start()` awaits
`_init()` → `AudioPlayer.setSourceBytes`, which never resolves in tests. So
`start`, `_tick`, `_restartTimer`, the beat-cycling modulo, and the
restart-on-bpm-change path are all dark. Only the synchronous `bpm`/`beatsPerBar`
setters are covered.

**Change:** introduce a narrow seam for click playback:

```dart
abstract class ClickPlayer {
  Future<void> load(Uint8List strong, Uint8List weak);
  void play({required bool strong});
  void dispose();
}
```

Default implementation wraps the two `AudioPlayer`s; tests inject a fake that
records calls. With that, `tester.pump(Duration(...))` (or `fakeAsync`) drives
the timer and asserts beats advance at the right interval, wrap at
`beatsPerBar`, that changing bpm while running restarts the timer, and that
bpm clamps at 20/300.

**`tone_player.dart` (76.3%, 9 missed).** Better off than the other two because
the existing tests deliberately assert synchronous state only, but
`_fadeOutAndStop`'s 8-step ramp is unreachable for the same reason. The same
`ClickPlayer`-style seam (or reusing it) closes the gap.

### ④ Screens that construct their own engine (`tuner_screen`, `calibration_screen`)

`_TunerScreenState` has `final _engine = TunerEngine();` and
`_CalibrationScreenState` the same. Because the engine is hardcoded, a widget
test can't put the screen into any of its interesting states, so the
permission-denied branch, the `captureFailed` branch, `_onReading`, and
`_requestPermission` are all uncovered — 54 missed lines across the two.

This is also the cause of the `AGENTS.md` warning that pumping `TunerScreen` can
hang `pumpWidget` itself, which is why `widget_test.dart` tests localization
against a bare `MaterialApp` instead of the real app.

**Change:** accept an optional injected engine —
`TunerScreen({TunerEngine? engine})`, defaulting to `TunerEngine()` — behind a
small interface or with the injectable-recorder change from ③. Tests then push a
fake through all three states and drive the readings stream to assert the note
name and cent bar update. Fixing this also unblocks testing the full app shell
end-to-end rather than around it.

### ⑤ Generated code inflating the denominator

`lib/l10n/app_localizations*.dart` contributes **175 lines, of which only 74 are
hit** — and it's `flutter gen-l10n` output, gitignored (`.gitignore:38`) and
regenerated on every `pub get`. Nobody will ever hand-write a test for it, and
`app_localizations_de.dart` at 3.8% drags the total down purely because tests
mostly run in English.

**Change:** exclude it from the coverage measurement — `very_good_coverage@v3`
takes an `exclude` input ("list of files you would like to exclude from
coverage", confirmed against the action's own `action.yml`, whose only three
inputs are `path`, `min_coverage`, and `exclude`):

```yaml
- name: Enforce coverage threshold
  uses: VeryGoodOpenSource/very_good_coverage@v3
  with:
    path: coverage/lcov.info
    exclude: '**/l10n/**'
    min_coverage: 50
```

This alone moves the reported number from **57.7% → 60.0%** (716 / 1193) without
a single new test, and — more importantly — makes every subsequent number
reflect hand-written code. `main()` in `main.dart` is a lesser instance of the
same thing (it calls `runApp`; there's nothing to assert).

## UI tests

Inferred navigation graph, from `home_screen.dart`, `settings_screen.dart`,
`custom_scale_screen.dart`, and `calibration_screen.dart`:

```
HomeScreen  ── AppBar: [scale dropdown ▾] [⚙]
 ├── tab TUNER      → TunerScreen      (cent bar + note readout)
 ├── tab METRONOME  → MetronomeScreen  (− bpm +, slider, beat dots, ▶/⏸)
 └── ⚙ → SettingsScreen
      ├── SCALES     [⬆ import]  per row: [✎ edit] [⬇ export] [⧉ copy] [🗑 delete]
      │              row tap / "New scale" → CustomScaleScreen
      ├── METRONOME  [keep tick ⏻]
      ├── LANGUAGE   [dropdown ▾]
      ├── ADVANCED   Mic calibration → CalibrationScreen
      └── "Reset settings to defaults" → AlertDialog [Cancel] [Reset]

CustomScaleScreen ── AppBar: [↻ reset to chromatic]
      name / base frequency / root octave fields
      cake chart (tap wedge → selects degree)
      per degree: [name] [cents] [▶/⏹] [★ root] [⧉ copy] [🗑 delete]
      FAB [+] add tone
```

Sixteen widget tests covering the bulk of that surface. Tests 1–13 need no
production change; **14–16 depend on the refactors in ③ and ④**.

**Navigation and app shell**

1. **Full navigation round-trip.** Home → ⚙ → Settings → Mic calibration →
   back → back. Asserts each screen's title appears and each pop returns to the
   previous screen. Broad, cheap coverage of the routing in three files.
2. **Scale switching from the app-bar dropdown.** Invoke the
   `DropdownButton<String>`'s `onChanged` with another seeded preset's id;
   assert `settings.activeScaleId` updates and the title text follows.
   (Invoking `onChanged` directly rather than opening the overlay menu — the
   pattern `settings_screen_test.dart` already uses.)

**Settings screen** (targets the 65 missed lines)

3. **Create a scale.** Tap "New scale" → asserts a `CustomScaleScreen` is
   pushed, the scale is persisted, and it becomes active.
4. **Copy a scale.** Tap ⧉ → a duplicate appears in the list and the editor
   opens on the *copy*, not the original.
5. **Delete a scale.** Tap 🗑 → the row disappears and a snackbar names it.
6. **Deleting the last scale is refused** — with only one scale left, 🗑 shows
   the "can't delete last scale" snackbar and the list is unchanged.
7. **Reset-to-defaults dialog, both branches.** Cancel leaves user scales
   intact; Reset restores the bundled presets and shows the confirmation
   snackbar. (Two `showDialog` outcomes, currently zero.)
8. **Keep-tick switch** toggles `settings.keepTick` and persists.

**Custom scale editor** (targets the 99 missed lines — the largest UI gap)

9. **Rename a scale** → persisted to `SettingsService`, and after popping, the
   Home app-bar dropdown shows the new name.
10. **Add / duplicate / delete a tone** → degree count changes and persists;
    the duplicate lands at the wedge midpoint (`_duplicateDegree`'s modulo
    arithmetic, incl. the wrap-around case where the next tone's cents are
    lower).
11. **Set root** — tap ★ on a non-root row → `rootIndex` moves and the filled
    star follows.
12. **Edit cents, incl. normalization** — entering `1300` stores `100`, and a
    negative value wraps positive (`_DegreeRowState`'s `% 1200` branch).
13. **Tap a cake wedge selects the matching degree row** — drives
    `ScaleCakeChart`'s `_sliceForCents` and the `onSelect` callback, including
    a tap outside the circle being ignored. This is the untested half of
    `scale_cake_chart.dart`.

**Depends on the refactors**

14. **Metronome transport** (needs ③'s `ClickPlayer`). ▶ starts, beat dots
    advance on pumped time, wrap at `beatsPerBar`, ⏸ stops; − / + and the
    slider clamp at 20 and 300.
15. **Tuner screen states** (needs ④'s injectable engine). Permission denied →
    prompt, and tapping it disables the retry button; capture failed → "no
    audio device"; a reading pushed through the stream → correct note name,
    octave, and cent-bar offset.
16. **Calibration flow** (needs ④). Feed a reading → "Set offset" enables →
    tap → `micOffsetHz == raw − reference` and the snackbar reports it; then
    "Reset to 0 Hz" enables and clears it. Currently only the inert
    initial state is covered.

## Suggested sequencing

Ordered by payoff per unit of effort — each phase is independently shippable.

| Phase | Work | Est. total | Actual | |
|---|---|---|---|---|
| 0 | Exclude `lib/l10n/**` from coverage (config only, no tests) | ~60% | — | **done** |
| 1 | ③ engine extraction + tests (covers `pitch_detector` too) | ~72% | 72.4% | **done** |
| 2 | UI tests 1–13 (no refactor) | ~80% | 88.5% | **done** |
| 3 | Refactor ② `scale_io`, with tests | ~90% | | open |
| 4 | Refactor ④ screens + UI tests 14–16 | ~94% | | open |

Percentages are projections from the missed-line counts above, assuming the
tests land the lines they target; treat them as direction, not a contract.

Raise `min_coverage` in `.github/workflows/_test.yml` as each phase lands, so
the ratchet only ever goes up.

## What landed

Phases 0 and 1. Coverage **57.7% → 68.6%** (969 / 1412); as CI now measures it,
excluding generated files, **72.4%** (895 / 1237). Tests: 42 → 90.

| File | Before | After |
|---|---:|---:|
| `dsp/pitch_detector.dart` | 0% | **94%** |
| `services/tuner_engine.dart` | 16% | **100%** |
| `services/metronome_engine.dart` | 32% | **100%** |
| `services/tone_player.dart` | 76% | **100%** |
| `dsp/pitch_pipeline.dart` *(new)* | — | **100%** |

Three seams were introduced, each a plain interface with a real implementation
that wraps the plugin and a fake that tests inject: `AudioCapture` (the
recorder), `ClickPlayer` (metronome clicks), `TonePlayback` (preview notes).
`PitchPipeline` took over everything that used to live inside `TunerEngine`'s
`stream.listen` callback — buffering, sample-rate correction, calibration,
median smoothing — and knows nothing about plugins or streams.

**`pitch_detector.dart` needed no test of its own.** Driving `PitchPipeline`
with PCM bytes runs the FFT, autocorrelation and peak-picking as a side effect,
which took it from 0% to 94% without a line of detector-specific test code — and
tests it with more of the real path connected than a unit test would have.

The residue is deliberate: `audio_capture.dart`, `click_player.dart` and
`tone_playback.dart` sit at 25–44%, because the uncovered lines are the real
plugin calls. That is the correct shape — roughly 33 lines of untestable
adapter, instead of untestable code threaded through 150 lines of engine logic.

No microphone is faked anywhere. Tests build PCM byte arrays with `sin()` and
hand them to a function; the fakes record calls rather than producing sound.

### Phase 2 — the UI tests

All 13 that needed no production change, in `app_navigation_test.dart` (the
shell and routing), `settings_screen_test.dart` and
`custom_scale_screen_test.dart`.

| File | Before | After |
|---|---:|---:|
| `screens/custom_scale_screen.dart` | 56% | **98%** |
| `widgets/scale_cake_chart.dart` | 65% | **98%** |
| `screens/settings_screen.dart` | 55% | **88%** |
| `services/settings_service.dart` | 79% | **97%** |
| `screens/home_screen.dart` | 88% | **98%** |
| `models/scale_degree.dart` | 50% | **80%** |

Two things worth knowing for anyone writing more of these:

- **The editor page needs a taller test surface.** Its content is one lazily
  built `ListView`, and at the default 800px height the cake chart and the
  scale-level fields push every degree row but the first out of the viewport —
  where it isn't merely invisible but never mounted, so finders don't see it
  and taps land on nothing. `pumpEditor` sets a 1000×1600 surface.
- **The degree rows' text fields are addressed by index** (`3 + row * 2` for
  the name, `+1` for the cents), because nothing in the tree distinguishes
  them. Adding `Key`s would make that sturdier and is worth doing next time
  the file is open anyway.
