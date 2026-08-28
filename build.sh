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

echo "=== Deploy ready ==="
exit 0
