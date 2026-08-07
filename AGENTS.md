# AGENTS.md

Instructions for any AI coding agent working in this repository — Claude,
Codex, Copilot, Cursor, or otherwise. Nothing here is tool-specific.

## Quick start

```sh
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter build web --release      # this repo's primary target
flutter build linux --release    # needs libgtk-3-dev, libgstreamer1.0-dev,
                                  # libgstreamer-plugins-base1.0-dev
```

Run `flutter analyze` and `flutter test` locally before pushing — CI runs
exactly these, and a red run is a slow way to learn something a laptop
would've told you in seconds. See `README.md` for feature context and
project layout; this file is about *how* to work in the repo, not *what*
it does.

## Test environment constraints

`flutter test` has no real audio plugin (`AudioPlayer`, `AudioRecorder`)
or Chrome available, so:

- Any test that `await`s a real `AudioPlayer`/`AudioRecorder` call
  (`start()`, `toggle()`, mic capture) will hang, not fail. Test only
  synchronous state (e.g. a `playingKey` getter that updates before the
  async I/O resolves), or leave the call `unawaited()` and assert
  immediately after.
- Widget tests that pump a screen requiring mic capture (`TunerScreen`)
  can hang `pumpWidget` itself — test localization/layout against a bare
  `MaterialApp`, not the full app, when you don't need the tuner's mic
  path.
- `rootBundle` caches assets across tests in the same run; if a test
  depends on fresh asset state, clear it in `tearDown` (see
  `test/flutter_test_config.dart`).

## Formatting and linting

- `dart format` and `flutter analyze` both run in CI, but the existing
  tree isn't 100% `dart format`-clean and nobody's doing a bulk
  reformat. **Never run `dart format` (or any auto-fixer) across the
  whole repo as a side effect of an unrelated change** — scope any
  formatting fix to the files you actually touched. CI's own format
  check does the same: it diffs against the PR base and only checks
  files that changed in the PR, not the whole tree.
- `analysis_options.yaml` uses stock `flutter_lints` with no local
  additions. If you're proposing new lint rules, check what's already
  enabled before assuming a gap — some things you'd expect (e.g.
  `use_build_context_synchronously`, `avoid_print`) are already on by
  default via that package.

## CI workflow conventions (`.github/workflows/`)

- `_test.yml`, `_web-deploy.yml`, `_flutter-build.yml` are reusable
  workflows (`workflow_call`); other files under `.github/workflows/`
  are the actual triggers (`pull-request.yml`, `main-push.yml`,
  `release.yml`, `dependency-scan.yml`).
- A job that declares `secrets:` in a reusable-workflow call has **all**
  of its `outputs:` stripped by GitHub, even outputs that never touch a
  secret. `_web-deploy.yml`'s `compute`/`deploy` split exists solely so
  the (secret-free) `compute` job's `url` output can actually leave the
  job — don't merge that back into one job.
- `android`/`ios` builds must stay separate jobs: `ios` needs
  `macos-latest`, a different runner than everything else; a job runs on
  exactly one OS, and reusable workflows are the only way to parallelize
  across runner types.
- When pinning a third-party action, **verify the tag actually exists**
  rather than assuming a floating major-version tag like `@v2` is
  published — some actions only publish patch-level tags
  (`google/osv-scanner-action` is `@v2.3.8`, not `@v2`). An unresolvable
  ref fails the job at "Set up job," before any of your own steps run,
  which reads like something else broke.
- Avoid the `cond && a || b` ternary idiom in GitHub Actions expressions
  (and anywhere else with the same falsy-zero footgun as JS): if `a` can
  be `0` or `''`, the whole expression silently collapses to `b`
  regardless of `cond`. This exact bug made a format-check step run
  forever without ever actually checking anything, because the
  "shallow-vs-full clone" ternary always picked shallow.

## General principles, earned the hard way this session

1. **Verify claims empirically, not from documentation alone.** An
   action's README can describe intended behavior that isn't what the
   bundled code does (e.g. a coverage-report action was assumed to write
   a GitHub Actions job summary; grepping its bundled JS showed it never
   calls `core.summary` at all — only a PR comment or artifact). When a
   step's actual behavior matters, read the source or run it and look at
   the log, don't take the description on faith.
2. **A CI job can go green without ever executing what you think it
   did.** A `git diff` that failed inside a shell step still let the
   script's `if [ -z ... ]` fall through to a benign-looking "nothing
   changed" message — the step "succeeded" while silently checking
   nothing. Read the actual log output for a step, not just its
   pass/fail status, especially for anything you just wrote.
3. **Understand object lifecycle before assuming who owns / disposes
   what.** A `TabBarView`'s `PageView` disposes off-screen tab content by
   default; an engine owned by a screen inside that view gets torn down
   on every tab switch whether or not you intended that. Lift ownership
   to whatever survives the disposal boundary you actually need.
4. **Match the size of the fix to the size of the ask.** Don't bundle a
   repo-wide reformat, a lint-rule sweep, or an unrelated refactor into a
   PR about one specific bug — even if a tool flagged the extra issues
   while you were in there. Note them, ask, or file a follow-up; keep
   the diff reviewable.
5. **Chasing a "nice to have" past a couple of dead ends is a signal to
   stop, not dig deeper.** Branch-coverage reporting turned into
   several layers of tool-internals archaeology (Dart's lcov output
   missing summary counters lcov 2.x expects) for a number that was
   secondary to the actual goal. Recognize when you're debugging the
   tool instead of the problem, say so, and offer the simpler path.
6. **Before committing on top of a long-lived working branch, check
   whether the branch's PR already merged.** If it has, restart the
   branch from the new base (`git fetch` + `git checkout -B <branch>
   origin/<default>`) rather than stacking new commits on now-merged
   history — a push will otherwise be rejected as non-fast-forward, or
   worse, silently diverge.
7. **Destructive git operations need a real reason and a narrow blast
   radius.** Prefer `push --force-with-lease=<branch>:<expected-sha>`
   over a bare `--force`, so a push fails loudly instead of clobbering
   work you didn't expect to be there.
