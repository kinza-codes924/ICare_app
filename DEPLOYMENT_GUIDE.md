# iCare Deployment Guide

## Overview
This project has two separate Vercel deployments:
1. **Frontend (Flutter Web)**: https://icare-app-ten.vercel.app/
2. **Backend (Node.js API)**: https://icare-backend-inky.vercel.app/

## Deployment Process

### Frontend Deployment
Frontend automatically deploys when you push to the `wajahat` branch:
```bash
git add .
git commit -m "your message"
git push origin wajahat
```

Vercel will automatically:
1. Run `build.sh` script
2. Install Flutter
3. Build the web app
4. Deploy to production

### Backend Deployment
Backend requires **manual deployment** using Vercel CLI:

```bash
# Option 1: Use the deployment script
bash deploy_backend.sh

# Option 2: Manual command
vercel deploy icare-backend --prod --yes
```

**Why manual?** The backend is in a subdirectory (`icare-backend/`) and has a separate Vercel project. GitHub pushes don't automatically trigger backend deployments.

## Recent Fixes Applied

### 1. Build Script Line Endings (FIXED ✅)
- **Problem**: `build.sh` had Windows CRLF line endings causing bash errors on Linux
- **Solution**: Converted to LF, added `.gitattributes` to enforce LF for `.sh` files

### 2. Flutter Web Renderer Flag (FIXED ✅)
- **Problem**: `--web-renderer html` flag removed in Flutter 3.41+
- **Solution**: Updated build command to `flutter build web --release`

### 3. CORS Error - ngrok Header (FIXED ✅)
- **Problem**: App was sending `ngrok-skip-browser-warning` header causing CORS rejection
- **Solution**: Removed the header from `api_service.dart`

### 4. Lab Booking API Schema Mismatch (FIXED ✅)
- **Problem**: Frontend sending wrong fields (`patientName`, `tests[]`) but backend expects `testType`
- **Solution**: Updated `fill_lab_form.dart` to send correct schema

### 5. Lab ID Mapping Issue (FIXED ✅)
- **Problem**: Frontend looking for nested `user._id` but backend returns flat `_id`
- **Solution**: Fixed `getAllLaboratories()` to read `_id` from top level

### 6. Missing Lab Supplies Endpoints (FIXED ✅)
- **Problem**: 404 errors on `/api/lab-supplies/low-stock` - endpoint didn't exist
- **Solution**: Created stub endpoints in `icare-backend/routes/lab-supplies.js`

## Current Status

### ✅ Working Features
- User authentication (login/signup)
- Lab booking creation (patient side)
- Lab bookings visible in lab dashboard
- Pharmacy dashboard loads without errors
- Lab dashboard loads without errors

### 🔄 Stub Features (Placeholders)
- Lab supplies management (returns empty data)
- Low stock alerts (returns count: 0)

## Testing Checklist

After deployment, verify:
- [ ] Frontend loads at https://icare-app-ten.vercel.app/
- [ ] Backend API responds at https://icare-backend-inky.vercel.app/api
- [ ] Login works without CORS errors
- [ ] Lab booking creation succeeds (no 400 error)
- [ ] Lab dashboard shows new bookings
- [ ] No 404 errors in browser console for `/api/lab-supplies/low-stock`

## Troubleshooting

### Frontend not updating?
1. Check Vercel dashboard: https://vercel.com/wajahatfrontdev-8765s-projects
2. Verify build logs for errors
3. Clear browser cache (Ctrl+Shift+R)

### Backend not updating?
1. Run: `bash deploy_backend.sh`
2. Check deployment logs
3. Verify at: https://icare-backend-inky.vercel.app/api

### Still seeing 404 errors?
1. Ensure backend was deployed after adding new routes
2. Check browser console for exact failing endpoint
3. Verify route is registered in `icare-backend/index.js`

## Important Notes

- **Always deploy backend manually** after making backend changes
- Frontend auto-deploys on git push
- Use `wajahat` branch for all changes
- Backend and frontend are separate Vercel projects
