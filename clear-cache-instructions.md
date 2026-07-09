# Clear Browser Cache - iCare Website

## Problem
Changes deployed to https://icare-diix1jkcv-wajahatfrontdev-8765s-projects.vercel.app are not showing because of aggressive browser caching and service workers.

## Solution - Complete Cache Clear

### Method 1: Chrome DevTools (BEST METHOD)
1. Open https://icare-diix1jkcv-wajahatfrontdev-8765s-projects.vercel.app
2. Press **F12** to open DevTools
3. Go to **Application** tab (top menu)
4. In left sidebar, click **Service Workers**
5. Click **Unregister** for all service workers
6. In left sidebar, click **Storage**
7. Click **Clear site data** button
8. Close DevTools
9. Press **Ctrl + Shift + Delete**
10. Select "All time" and check all boxes
11. Click "Clear data"
12. Close browser completely
13. Reopen and visit site

### Method 2: Incognito/Private Mode
1. Close all browser windows
2. Open new **Incognito/Private** window (Ctrl + Shift + N)
3. Visit: https://icare-diix1jkcv-wajahatfrontdev-8765s-projects.vercel.app
4. Test the features

### Method 3: Different Browser
Try opening in a browser you haven't used before (Edge, Firefox, etc.)

## What to Test After Clearing Cache

### 1. Payment Confirmation ✅
- Book appointment → Pay Now
- Should show green success dialog: "Appointment Confirmed!"
- "Go to Home" button should appear

### 2. Certificate Download ✅
- Doctor login → Certificates
- Click any certificate
- "Download as PDF" button should download PDF file

### 3. Jitsi Login Removed ✅
- Join LMS live session
- Should enter video call DIRECTLY (no login screen)
- Should see "iCare" branding (not "Jitsi")

## If Still Not Working
The service worker is very aggressive. Try this:
1. Open DevTools (F12)
2. Go to Application → Service Workers
3. Check "Update on reload"
4. Keep DevTools open
5. Refresh page multiple times (Ctrl + Shift + R)
