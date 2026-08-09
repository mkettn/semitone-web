#!/usr/bin/env bash
#
# Rename main.dart.mjs so the deploy host serves it as JavaScript.
#
# The host runs nginx, which has no MIME mapping for .mjs and serves it as
# application/octet-stream. Browsers apply strict MIME checking to ES
# modules and refuse to import such a file:
#
#   Failed to load module script: Expected a JavaScript-or-Wasm module
#   script but the server responded with a MIME type of
#   "application/octet-stream".
#
# main.dart.mjs is the dart2wasm build's JS support runtime, so that one
# refusal takes the whole app down — a blank page. The JS-only build never
# hit this because it has no .mjs file, which is why it appeared only once
# the build moved to --wasm.
#
# Renaming so the *final* extension is .js gets it served as
# application/javascript. flutter_bootstrap.js is the only file that names
# it, so one substitution is enough.
#
# This patches build output, which is not somewhere we should normally be
# writing. It is a workaround for a server-side gap, not for anything
# Flutter does wrong: the real fix is one line of nginx config mapping
# .mjs -> text/javascript, after which this script and its workflow step
# should both be deleted.
#
# Usage: scripts/patch-mjs-mime.sh [build-dir]   (default: build/web)

set -euo pipefail

BUILD_DIR="${1:-build/web}"

if [ ! -d "$BUILD_DIR" ]; then
  echo "::error::$BUILD_DIR does not exist - run a web build first." >&2
  exit 1
fi

cd "$BUILD_DIR"

if [ ! -f main.dart.mjs ]; then
  echo "::error::main.dart.mjs is missing from $BUILD_DIR. Either this is not a --wasm build, or Flutter no longer emits that file - in which case delete this script." >&2
  exit 1
fi

if ! grep -q 'main\.dart\.mjs' flutter_bootstrap.js; then
  echo "::error::flutter_bootstrap.js does not reference main.dart.mjs; renaming it would orphan the file." >&2
  exit 1
fi

mv main.dart.mjs main.dart.mjs.js
sed -i 's/main\.dart\.mjs/main.dart.mjs.js/g' flutter_bootstrap.js

# Fail loudly rather than shipping a bootstrap pointing at a file that is
# no longer there.
if ! grep -q 'main\.dart\.mjs\.js' flutter_bootstrap.js; then
  echo "::error::rewrite failed - flutter_bootstrap.js no longer references the renamed file." >&2
  exit 1
fi

echo "main.dart.mjs -> main.dart.mjs.js, reference in flutter_bootstrap.js updated."
