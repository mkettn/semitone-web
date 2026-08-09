{{flutter_js}}
{{flutter_build_config}}

// Serves the engine renderer (CanvasKit / skwasm) from our own host rather
// than Google's CDN. The URL must hold the CanvasKit build matching this
// build's engineRevision, so it needs re-uploading on a Flutter upgrade.
const canvasKitBaseUrl = '{{CANVASKIT_BASE_URL}}';

// Empty (variable unset) or unsubstituted (no --web-define at all) both
// mean "not configured" — fall back to Flutter's default.
const useCustomCanvasKit =
  canvasKitBaseUrl !== '' && !canvasKitBaseUrl.startsWith('{{');

_flutter.loader.load({
  config: useCustomCanvasKit ? { canvasKitBaseUrl: canvasKitBaseUrl } : {},
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
