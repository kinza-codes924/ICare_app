# Connect Now Fix V2 - Patient/Doctor ID Issue

## Problem
Backend returns 400 error: "Patient ID and Doctor ID are required"

## Root Cause
We're passing empty strings for `patientId` or `doctorId` when calling `startConsultationV2()`.

## Solution
For Connect Now, we need to:
1. Get patientId from logged-in patient user
2. Get doctorId from logged-in doctor user
3. Pass proper IDs to startConsultationV2

## Current Flow Issues:

### Patient Side (connect_now_waiting_screen.dart):
- ✅ Gets patientId from userData.id
- ❌ Passes empty doctorId (should get from acceptRequest response)

### Doctor Side (doctor_connect_now_listener.dart):
- ✅ Gets doctorId from userData.id
- ❌ Passes empty patientId (should get from request)

### Doctor Side (doctor_connect_now_screen.dart):
- ✅ Gets doctorId from userData.id
- ❌ Passes empty patientId (should get from request)

## Fix Required:
The Connect Now backend creates an appointment with patient_id and doctor_id. We need to:
1. Extract patientId from ConnectNow request
2. Extract doctorId from logged-in doctor
3. Pass both to startConsultationV2

## Backend Flow:
```
1. Patient initiates → patientId stored in ConnectNow request
2. Doctor accepts → doctorId stored in acceptedBy
3. Appointment created with both IDs
4. Frontend should use appointment to get IDs
```

## Frontend Fix Needed:
Instead of passing empty strings, we should:
- Get appointment details from backend
- Extract patient_id and doctor_id from appointment
- Pass to startConsultationV2
