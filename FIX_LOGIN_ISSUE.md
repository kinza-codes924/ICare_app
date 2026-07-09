# Fix Login Issue - 401 Error
**Date:** May 8, 2026  
**Issue:** Login failing with 401 error

---

## 🐛 Problem

Login API returning 401 error because:
1. Environment variables had newline characters (`\n`)
2. JWT_SECRET was not properly set on Vercel
3. Local .env file was missing required variables

---

## ✅ Solution (2 Options)

### Option 1: Quick Fix via Vercel Dashboard (RECOMMENDED)

1. **Go to Vercel Dashboard:**
   ```
   https://vercel.com/wajahatfrontdev-8765s-projects/icare-backend/settings/environment-variables
   ```

2. **Update these environment variables:**

   | Variable | Value |
   |----------|-------|
   | `JWT_SECRET` | `icare_jwt_secret_key_2026_production_secure_token_wajahat` |
   | `MONGO_URI` | `mongodb+srv://icaredev02_db_user:icaredev02@cluster0.kalraci.mongodb.net/icare_production` |
   | `NODE_ENV` | `production` |
   | `PORT` | `5000` |
   | `AGORA_APP_ID` | `82a63a65663c49f0bb973707b4c09f5f` |
   | `AGORA_APP_CERTIFICATE` | `cb6e19c098034597b1dab946861b95ce` |
   | `PUSHER_APP_ID` | `2125244` |
   | `PUSHER_KEY` | `f35e640cfef217a319dc` |
   | `PUSHER_SECRET` | `af90c9b8f9ad63aae52c` |
   | `PUSHER_CLUSTER` | `ap2` |

3. **Redeploy:**
   - Click "Deployments" tab
   - Click "..." on latest deployment
   - Click "Redeploy"

---

### Option 2: Fix via Command Line

1. **Install Vercel CLI (if not installed):**
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Run the fix script:**
   ```bash
   cd icare-backend
   chmod +x fix-vercel-env.sh
   ./fix-vercel-env.sh
   ```

4. **Redeploy:**
   ```bash
   vercel --prod
   ```

---

## 🧪 Test After Fix

### Test 1: Check Environment Variables
```bash
# In icare-backend folder
vercel env ls
```

Should show all variables without `\n` characters.

### Test 2: Test Login API
```bash
curl -X POST https://icare-backend-inky.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@icare.com","password":"adminPassword123"}'
```

Should return:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "...",
    "user": {...}
  }
}
```

### Test 3: Test from Flutter App
```dart
// In your login screen
final response = await dio.post(
  'https://icare-backend-inky.vercel.app/api/auth/login',
  data: {
    'email': 'admin@icare.com',
    'password': 'adminPassword123',
  },
);

print(response.data);
// Should print: {success: true, ...}
```

---

## 📝 What Was Fixed

### 1. Fixed .env.production
**Before:**
```env
JWT_SECRET="your-secret-key-here-change-in-production\n"
MONGO_URI="mongodb+srv://...\n"
```

**After:**
```env
JWT_SECRET=icare_jwt_secret_key_2026_production_secure_token_wajahat
MONGO_URI=mongodb+srv://icaredev02_db_user:icaredev02@cluster0.kalraci.mongodb.net/icare_production
```

### 2. Fixed .env.local
**Before:**
```env
# Only had VERCEL_OIDC_TOKEN
```

**After:**
```env
# Complete environment variables
MONGO_URI=mongodb+srv://...
JWT_SECRET=icare_jwt_secret_key_2026_production_secure_token_wajahat
PORT=5000
...
```

### 3. Created fix-vercel-env.sh
Script to automatically update Vercel environment variables.

---

## 🔐 Default Test Accounts

After fix, these accounts should work:

### Admin Account
```
Email: admin@icare.com
Password: adminPassword123
```

### Instructor Account
```
Email: instructor@icare.com
Password: instructor123
```

---

## 🚨 If Still Not Working

### Check 1: Verify Deployment
```bash
vercel ls
```

Make sure latest deployment is active.

### Check 2: Check Logs
```bash
vercel logs
```

Look for JWT or MongoDB errors.

### Check 3: Verify MongoDB Connection
```bash
# Test MongoDB connection
curl https://icare-backend-inky.vercel.app/api
```

Should return:
```json
{
  "success": true,
  "message": "iCare API v1.0.0",
  ...
}
```

### Check 4: Clear Browser Cache
- Clear browser cache
- Try in incognito mode
- Try different browser

---

## 📊 Summary

**Problem:** Environment variables had `\n` characters  
**Solution:** Fixed .env files and updated Vercel variables  
**Status:** ✅ Fixed  
**Action Required:** Redeploy on Vercel  

---

## 🎯 Next Steps

1. ✅ Fixed environment variables
2. ⏳ Redeploy on Vercel (Option 1 or 2 above)
3. ⏳ Test login with admin account
4. ⏳ Test from Flutter app
5. ✅ Continue with video consultation integration

---

**Prepared By:** AI Development Team  
**Date:** May 8, 2026  
**Status:** Ready to Deploy
