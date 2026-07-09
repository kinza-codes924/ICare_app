# Lab & Pharmacy Booking Debug Guide

## Issue Summary
Patient books lab test but it doesn't appear in lab dashboard. Same issue with pharmacy orders.

## Debug Logging Added

I've added comprehensive debug logging throughout the entire booking flow to trace exactly what's happening:

### Frontend Logging (Flutter)

1. **Laboratory Service** (`lib/services/laboratory_service.dart`):
   - `getAllLaboratories()`: Logs each lab's ID extraction
   - `createBooking()`: Logs the lab ID and booking data being sent
   - `getBookings()`: Logs the lab ID used to fetch bookings

2. **Fill Lab Form** (`lib/screens/fill_lab_form.dart`):
   - Logs the complete `labData` object received
   - Logs the extracted `labId`
   - Logs the booking data being sent

3. **Laboratory Dashboard** (`lib/screens/laboratory_dashboard.dart`):
   - Logs the profile loading
   - Logs the lab ID used to fetch bookings
   - Logs the stats received

### Backend Logging (Node.js)

1. **Lab Profile Endpoint** (`icare-backend/routes/labs.js`):
   - Logs the user ID
   - Logs the profile found
   - Logs the final `_id` being returned

2. **Create Booking Endpoint**:
   - Logs patient ID, lab ID, test type
   - Logs the created booking with its `lab_id`

3. **Get Bookings Endpoint**:
   - Logs the lab ID used in query
   - Logs the number of bookings found
   - Logs the first booking's `lab_id` if any exist

## Testing Steps

### Step 1: Patient Books Lab Test

1. **Login as Patient**
2. **Go to Medical Records** → View a prescription with lab tests
3. **Click "Find Labs"** button
4. **Select a lab** from the list
5. **Fill the booking form** and submit

**Watch Console Logs:**
```
🔍 LAB SERVICE - Fetching all laboratories...
🔍 LAB SERVICE - Received X laboratories from backend
🔍 LAB SERVICE - Processing lab: [Lab Name]
🔍 LAB SERVICE - Raw _id: [USER_ID]
🔍 LAB SERVICE - Extracted userId: [USER_ID]
🔍 LAB SERVICE - Final lab object _id: [USER_ID]

🔍 LAB BOOKING DEBUG - Full labData: {...}
🔍 LAB BOOKING DEBUG - Extracted labId: [USER_ID]
🔍 LAB BOOKING DEBUG - Calling createBooking with labId: [USER_ID]

🔍 LAB SERVICE - createBooking called with labId: [USER_ID]
🔍 LAB SERVICE - Making POST to: /laboratories/[USER_ID]/bookings
✅ LAB SERVICE - Booking created successfully
```

**Watch Backend Logs (Vercel):**
```
🔍 LAB BOOKING - Patient ID: [PATIENT_ID]
🔍 LAB BOOKING - Lab ID from URL: [LAB_USER_ID]
🔍 LAB BOOKING - Test type: [TEST_NAME]
✅ LAB BOOKING - Created booking: [BOOKING_ID]
✅ LAB BOOKING - Booking lab_id: [LAB_USER_ID]
✅ LAB BOOKING - Booking patient_id: [PATIENT_ID]
```

### Step 2: Lab Views Dashboard

1. **Login as Lab** (use the same lab account that was selected)
2. **Go to Dashboard**

**Watch Console Logs:**
```
🔍 LAB DASHBOARD - Loading profile...
🔍 LAB DASHBOARD - Profile loaded: [Lab Name]
🔍 LAB DASHBOARD - Profile _id: [USER_ID]
🔍 LAB DASHBOARD - Fetching dashboard stats for labId: [USER_ID]

🔍 LAB SERVICE - getBookings called with labId: [USER_ID]
🔍 LAB SERVICE - Fetching from: /laboratories/[USER_ID]/bookings
✅ LAB SERVICE - Received X bookings
```

**Watch Backend Logs (Vercel):**
```
🔍 LAB PROFILE - User ID: [USER_ID]
🔍 LAB PROFILE - User found: [Lab Name]
✅ LAB PROFILE - Returning lab with _id: [USER_ID]

🔍 LAB BOOKINGS FETCH - Lab ID: [USER_ID]
🔍 LAB BOOKINGS FETCH - Query: { lab_id: [USER_ID] }
✅ LAB BOOKINGS FETCH - Found X bookings
```

## What to Check

### Critical ID Matching

The **USER_ID** must be the SAME in all these places:

1. ✅ Lab object `_id` when patient selects lab
2. ✅ `labId` parameter when creating booking
3. ✅ `lab_id` field in created `LabTestRequest` document
4. ✅ Lab profile `_id` when lab logs in
5. ✅ `labId` parameter when fetching bookings
6. ✅ Query `{ lab_id: ... }` when searching bookings

### If Bookings Don't Show

**Compare these IDs:**

1. **From patient booking logs:**
   - `🔍 LAB BOOKING DEBUG - Extracted labId: [ID_A]`
   - `✅ LAB BOOKING - Booking lab_id: [ID_B]`

2. **From lab dashboard logs:**
   - `🔍 LAB DASHBOARD - Profile _id: [ID_C]`
   - `🔍 LAB BOOKINGS FETCH - Lab ID: [ID_D]`

**If ID_A ≠ ID_B ≠ ID_C ≠ ID_D**, that's the problem!

## Common Issues

### Issue 1: Lab Profile ID vs User ID

**Problem:** Patient is using lab's **profile ID** instead of **user ID**

**Solution:** The `getAllLaboratories()` endpoint must return the user's `_id`, not the profile's `_id`

**Check:** Backend `/laboratories/get_all_laboratories` should return:
```javascript
{
  _id: user._id,  // ← USER ID (from users collection)
  lab_name: profile.lab_name,
  // ... other fields
}
```

### Issue 2: Multiple Lab Accounts

**Problem:** Patient books with Lab A's ID, but you're checking Lab B's dashboard

**Solution:** Make sure you're logging into the SAME lab account that the patient selected

**Check:** Compare lab names in logs:
- Patient side: `🔍 LAB SERVICE - Processing lab: [Lab Name]`
- Lab side: `🔍 LAB DASHBOARD - Profile loaded: [Lab Name]`

### Issue 3: Database Collection Mismatch

**Problem:** Bookings are being created in wrong collection or with wrong field names

**Solution:** Verify the `LabTestRequest` model schema

**Check:** Backend should create documents with:
```javascript
{
  patient_id: ObjectId,  // ← Patient's user ID
  lab_id: ObjectId,      // ← Lab's user ID
  test_type: String,
  status: String,
  // ...
}
```

## Pharmacy Issue

The pharmacy booking flow has the SAME architecture as labs:

1. Patient selects pharmacy → uses pharmacy's **user ID**
2. Booking created with `pharmacy_id: [USER_ID]`
3. Pharmacy dashboard fetches with `pharmacy_id: [USER_ID]`

Apply the same debugging steps for pharmacy orders.

## How to View Logs

### Frontend Logs (Flutter Web)
1. Open browser DevTools (F12)
2. Go to Console tab
3. Look for logs starting with 🔍, ✅, or ❌

### Backend Logs (Vercel)
1. Go to https://vercel.com/wajahatfrontdev-8765s-projects/icare-backend
2. Click on the latest deployment
3. Click "Functions" tab
4. Click on any function to see logs
5. Or use Vercel CLI: `vercel logs https://icare-backend-inky.vercel.app`

## Next Steps

1. **Test the complete flow** following the steps above
2. **Copy all console logs** (both frontend and backend)
3. **Share the logs** so I can identify the exact mismatch
4. **Check the database** directly if needed:
   ```javascript
   // In MongoDB, check:
   db.users.find({ role: 'lab' })  // Get lab user IDs
   db.labtests.find({})  // Check lab_id values in bookings
   ```

## Expected Behavior

When everything works correctly:

1. Patient books → Creates `LabTestRequest` with `lab_id: [USER_ID]`
2. Lab logs in → Gets profile with `_id: [USER_ID]`
3. Lab dashboard → Queries `LabTestRequest.find({ lab_id: [USER_ID] })`
4. Bookings appear in dashboard ✅

The USER_ID must match at every step!
