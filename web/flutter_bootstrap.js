{{flutter_js}}
{{flutter_build_config}}

// Where the Flutter engine's renderer (CanvasKit / skwasm) is fetched from.
//
// By default Flutter loads it from
// https://www.gstatic.com/flutter-canvaskit/<engineRevision>/ — a
// third-party request to Google on every first load, before the user has
// interacted with anything. Passing
//
//   flutter build web --web-define=CANVASKIT_BASE_URL=https://example.com/ck/
//
// substitutes the placeholder below so the engine is served from there
// instead, and nothing leaves our own host. The deploy workflow passes the
// CANVASKIT_BASE_URL repository variable through; leave it unset and the
// app keeps using Google's CDN.
//
// A self-hosted URL must serve the CanvasKit build matching the
// engineRevision in the buildConfig above — a mismatch fails at runtime.
// Those files are in `build/web/canvaskit/` after any `flutter build web`.
const canvasKitBaseUrl = '{{CANVASKIT_BASE_URL}}';

// Two ways this can legitimately be "not configured": the workflow passed
// an empty value because the repository variable isn't set, or nobody
// passed --web-define at all (a plain local `flutter build web`), which
// leaves the placeholder untouched. Treat both as "use Flutter's default"
// rather than requesting a nonsense URL.
const useCustomCanvasKit =
  canvasKitBaseUrl !== '' && !canvasKitBaseUrl.startsWith('{{');

_flutter.loader.load({
  config: useCustomCanvasKit ? { canvasKitBaseUrl: canvasKitBaseUrl } : {},
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
