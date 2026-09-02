#!/bin/bash
# Pre-built deployment — Flutter web is built locally and uploaded.
# This script only applies the CanvasKit path patch so assets load correctly.

echo "=== iCare Web Deploy Script ==="

BOOTSTRAP="build/web/flutter_bootstrap.js"

if [ ! -f "$BOOTSTRAP" ]; then
  echo "ERROR: build/web/flutter_bootstrap.js not found — build locally first."
  exit 1
fi

# Patch: tell Flutter to load CanvasKit from the local /canvaskit/ path
# instead of the gstatic CDN. Without this patch Flutter hangs on cold
# starts because the CDN URL is not in the Content-Security-Policy.
# Detect on OUR marker, not on the bare word: Flutter's own engine code always
# contains `canvasKitBaseUrl` (in the function that falls back to the gstatic
# CDN), so grepping for it alone always matched and silently skipped the patch.
if grep -q 'config: { canvasKitBaseUrl:' "$BOOTSTRAP"; then
  echo "CanvasKit patch already applied — skipping."
else
  # The load() call spans multiple lines in current Flutter builds, so sed's
  # line-at-a-time matching misses it — perl -0 slurps the whole file instead.
  perl -0pi -e 's/_flutter\.loader\.load\(\{/_flutter.loader.load({
  config: { canvasKitBaseUrl: "\/canvaskit\/" },/' "$BOOTSTRAP"
  if grep -q 'config: { canvasKitBaseUrl:' "$BOOTSTRAP"; then
    echo "CanvasKit patch applied."
  else
    echo "ERROR: CanvasKit patch FAILED to apply — loader.load({ not found."
    echo "The bootstrap format probably changed; fix this before deploying."
    exit 1
  fi
fi

# Cache-busting. flutter_bootstrap.js asks for "main.dart.js" with no version
# on it, so a browser holding an older copy keeps serving that one after a
# deploy — which is why users kept being told to clear their cache by hand.
# Stamping a fresh build id onto every entry-point URL makes each deploy a URL
# the browser has never seen, so it must fetch it.
BUILD_ID="$(date +%Y%m%d%H%M%S)"

# Strip any stamp from a previous run first, so re-running never doubles up.
perl -pi -e 's/\?v=\d{14}//g' "$BOOTSTRAP"

# Only the entry points need this — everything else is pulled in by them.
perl -pi -e "s/(main\.dart\.js|flutter\.js|main\.dart\.mjs)(?![\w.\?])/\$1?v=$BUILD_ID/g" "$BOOTSTRAP"

STAMPED="$(grep -o 'main\.dart\.js?v=[0-9]*' "$BOOTSTRAP" | head -1)"
if [ -n "$STAMPED" ]; then
  echo "Cache-buster applied: $STAMPED"
else
  echo "ERROR: cache-buster FAILED — main.dart.js not found in bootstrap."
  exit 1
fi

# index.html points at flutter_bootstrap.js the same unversioned way, so stamp
# that reference too — otherwise the browser keeps the old bootstrap and never
# sees the new main.dart.js URL inside it.
INDEX="build/web/index.html"
if [ -f "$INDEX" ]; then
  perl -pi -e 's/flutter_bootstrap\.js\?v=\d{14}/flutter_bootstrap.js/g' "$INDEX"
  perl -pi -e "s/flutter_bootstrap\.js(?![\w.\?])/flutter_bootstrap.js?v=$BUILD_ID/g" "$INDEX"
  if grep -q "flutter_bootstrap.js?v=$BUILD_ID" "$INDEX"; then
    echo "index.html bootstrap reference stamped."
  else
    echo "ERROR: could not stamp flutter_bootstrap.js in index.html."
    exit 1
  fi
fi

echo "=== Deploy ready ==="
exit 0
