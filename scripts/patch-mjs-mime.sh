#!/usr/bin/env bash
#
# The deploy host's nginx has no MIME mapping for .mjs, and browsers refuse
# ES modules served as application/octet-stream — which blanks the whole app,
# since main.dart.mjs is the dart2wasm build's JS support runtime. Renaming so
# the final extension is .js gets it served as JavaScript.
#
# Delete this and its workflow step once the server maps .mjs -> text/javascript.
#
# Usage: scripts/patch-mjs-mime.sh [build-dir]   (default: build/web)

set -euo pipefail

BUILD_DIR="${1:-build/web}"
cd "$BUILD_DIR"

if [ ! -f main.dart.mjs ]; then
  echo "::error::main.dart.mjs missing from $BUILD_DIR - not a --wasm build, or Flutter stopped emitting it (then delete this script)." >&2
  exit 1
fi
if ! grep -q 'main\.dart\.mjs' flutter_bootstrap.js; then
  echo "::error::flutter_bootstrap.js does not reference main.dart.mjs; renaming would orphan it." >&2
  exit 1
fi

mv main.dart.mjs main.dart.mjs.js
sed -i 's/main\.dart\.mjs/main.dart.mjs.js/g' flutter_bootstrap.js

if ! grep -q 'main\.dart\.mjs\.js' flutter_bootstrap.js; then
  echo "::error::rewrite failed - flutter_bootstrap.js no longer points at the renamed file." >&2
  exit 1
fi

echo "main.dart.mjs -> main.dart.mjs.js, reference updated."
