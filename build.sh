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
if grep -q 'canvasKitBaseUrl' "$BOOTSTRAP"; then
  echo "CanvasKit patch already applied — skipping."
else
  # Insert config block into the loader.load() call
  sed -i 's/_flutter\.loader\.load({/_flutter.loader.load({config:{canvasKitBaseUrl:"\/canvaskit\/"},/' "$BOOTSTRAP"
  echo "CanvasKit patch applied."
fi

echo "=== Deploy ready ==="
exit 0
