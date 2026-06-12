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

# Write correct config.json with SPA fallback
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
