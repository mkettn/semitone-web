{{flutter_js}}
{{flutter_build_config}}

// Where the Flutter engine's renderer (CanvasKit / skwasm) is fetched from.
//
// By default Flutter loads it from
// https://www.gstatic.com/flutter-canvaskit/<engineRevision>/ — a
// third-party request to Google on every first load, before the user has
// interacted with anything. Setting the CANVASKIT_BASE_URL repository
// variable makes the deploy workflow rewrite the placeholder below so the
// engine is served from our own host instead, and no request leaves it.
//
// Leaving the variable unset keeps Google's CDN, which is also what a plain
// local `flutter build web` gets: nothing rewrites the placeholder, the
// guard below sees it, and Flutter's own default applies. So this file
// never needs the workflow to have run.
//
// If you do set it, the URL must serve the CanvasKit build matching the
// engineRevision in the buildConfig above — a mismatch fails at runtime.
// Those files are in `build/web/canvaskit/` after any `flutter build web`.
const canvasKitBaseUrl = '__CANVASKIT_BASE_URL__';

// A placeholder that still starts with "__" means "not configured" — pass
// no override at all rather than requesting a nonsense URL.
const engineConfig = canvasKitBaseUrl.startsWith('__')
  ? {}
  : { canvasKitBaseUrl: canvasKitBaseUrl };

_flutter.loader.load({
  config: engineConfig,
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
