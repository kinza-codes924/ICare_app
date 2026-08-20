# ICare App - Vercel Deploy Script
# Usage: .\deploy.ps1
# Builds Flutter web and deploys to icare-app Vercel project

Write-Host "=== Building Flutter Web ===" -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
    Write-Host "Flutter build failed" -ForegroundColor Red
    exit 1
}

Write-Host "=== Pulling Vercel Settings ===" -ForegroundColor Cyan
vercel pull --yes --environment=production

Write-Host "=== Building Vercel Output ===" -ForegroundColor Cyan
vercel build --prod

# Copy missing directories that vercel build doesn't include
Write-Host "=== Copying asset directories ===" -ForegroundColor Cyan
Copy-Item -Recurse -Force "build\web\assets"    ".vercel\output\static\assets"
Copy-Item -Recurse -Force "build\web\canvaskit"  ".vercel\output\static\canvaskit"

# Write correct config.json with SPA fallback.
# NOTE: this OVERWRITES whatever `vercel build` generated from vercel.json,
# so any header/route rule must be duplicated here or it simply won't ship —
# vercel.json alone has no effect on the deployed output.
#
# The no-store rule below is why: without it every SPA route (/student/dashboard,
# /instructor/dashboard, ...) was served with Vercel's default
# "max-age=0, must-revalidate", so browsers kept replaying a stale index.html
# after a deploy and users ran old JS against a new backend. Hashed assets
# under /assets, /canvaskit and /icons are excluded so they stay cacheable.
#
# main.dart.js / flutter.js / flutter_bootstrap.js are a THIRD category:
# unlike index.html (no cache — must always reflect the latest deploy) and
# /assets|/canvaskit|/icons (content-hashed filenames — cache forever), these
# keep the SAME filename across deploys but their content changes every time.
# They were caught by the index.html catch-all above (no-store), which meant
# every single page navigation re-downloaded the ~10MB main.dart.js bundle
# from scratch with zero browser caching — this was the main cause of the
# "every tab takes forever to load" complaint. A short max-age with
# must-revalidate lets the browser reuse it within a session/across quick
# navigations while still picking up a new deploy's version within minutes
# (never indefinitely stale, unlike a long/immutable cache would be).
$config = @'
{
  "version": 3,
  "routes": [
    {
      "src": "^/manifest\\.json$",
      "headers": { "Content-Type": "application/manifest+json" },
      "continue": true
    },
    {
      "src": "^(?:/(.*))$",
      "headers": {
        "Cross-Origin-Opener-Policy": "unsafe-none",
        "Cross-Origin-Embedder-Policy": "unsafe-none"
      },
      "continue": true
    },
    {
      "src": "^/(?:main\\.dart\\.js|flutter\\.js|flutter_bootstrap\\.js|flutter_service_worker\\.js)$",
      "headers": {
        "Cache-Control": "public, max-age=300, must-revalidate"
      },
      "continue": true
    },
    {
      "src": "^(?!/(?:assets|canvaskit|icons|main\\.dart\\.js|flutter\\.js|flutter_bootstrap\\.js|flutter_service_worker\\.js)).*$",
      "headers": {
        "Cache-Control": "no-store, no-cache, must-revalidate"
      },
      "continue": true
    },
    { "handle": "filesystem" },
    { "src": "/(.*)", "dest": "/index.html" }
  ],
  "crons": []
}
'@
$config | Set-Content ".vercel\output\config.json" -Encoding UTF8

Write-Host "=== Deploying to Vercel ===" -ForegroundColor Cyan
vercel deploy --prod --yes --prebuilt

Write-Host "=== Done! ===" -ForegroundColor Green
