# Urgent Fixes - May 8, 2026

## Issues to Fix

### 1. White Screen on Consultation Start from Book Appointment ❌
**Problem**: When starting consultation from "Book Appointment" → "Start Consultation", white screen appears.

**Root Cause**: The `consultationId` from the API response is not being passed to `ConsultationChatScreenV2`.

**Location**: `lib/widgets/boooking_card.dart` line 134

**Fix**:
```dart
// BEFORE (line 134):
builder: (_) => ConsultationChatScreenV2(
  appointment: appointment,
  isDoctor: isDoctor,
  currentUserId: currentUserId,
  currentUserName: currentUserName,
),

// AFTER:
builder: (_) => ConsultationChatScreenV2(
  appointment: appointment,
  isDoctor: isDoctor,
  currentUserId: currentUserId,
  currentUserName: currentUserName,
  consultationId: result['consultationId']?.toString(), // ADD THIS LINE
),
```

### 2. Prescription Not Showing After "Connect to Doctor Now" ❌
**Problem**: After consultation ends via "Connect to Doctor Now", patient doesn't see prescription.

**Root Cause**: 
1. Prescription might not be linked to consultation properly
2. Prescription display screen might not be showing after consultation ends
3. Navigation flow issue

**Locations to Check**:
- `lib/screens/end_consultation_workflow.dart`
- `lib/screens/consultation_chat_screen_v2.dart` (endConsultation method)
- `lib/screens/patient_prescriptions.dart`

**Fix Strategy**:
1. Ensure prescription is saved with consultationId
2. After consultation ends, navigate to prescription display
3. Add prescription to patient's prescription list

### 3. Prescription Display Format ❌
**Problem**: Prescription needs to be displayed as single-page PDF-style view with proper format.

**Required Format**:

**Header Section**:
- Patient Information: Name, Age, Gender, MR Number, Date & Time
- Doctor Information: Name, PMDC License Number, Phone Number

**Body Section**:
- Diagnosis (with ICD-10 codes)
- Medications (with dose and duration)
- Lab Tests
- Doctor Notes/Instructions

**Footer Section**:
- "Order Medicine" button (links to pharmacy)
- "Order Lab Tests" button (links to lab)

**Standards**:
- Medicine Database: British Pharmacopoeia
- Lab Tests: Standard catalogue
- ICD-10 Codes: Already integrated

**Location**: Create new screen `lib/screens/prescription_pdf_view_screen.dart`

## Implementation Plan

### Step 1: Fix White Screen Issue (5 minutes)
- Update `boooking_card.dart` to pass consultationId
- Test consultation start from book appointment

### Step 2: Fix Prescription Missing Issue (15 minutes)
- Update end consultation flow to show prescription
- Ensure prescription is linked to consultation
- Add navigation to prescription view after consultation ends

### Step 3: Create Prescription PDF View (30 minutes)
- Create new screen with PDF-style layout
- Implement header, body, footer sections
- Add "Order Medicine" and "Order Lab Tests" buttons
- Style according to requirements

### Step 4: Test Complete Flow (10 minutes)
- Book appointment → Start consultation → End consultation → View prescription
- Connect to Doctor Now → End consultation → View prescription
- Verify prescription display format

## Testing Checklist

- [ ] Book appointment flow works without white screen
- [ ] Consultation starts properly
- [ ] Video/audio calls work during consultation
- [ ] Prescription form can be filled by doctor
- [ ] Consultation can be ended
- [ ] Prescription shows after consultation ends
- [ ] Prescription has correct format (PDF-style)
- [ ] "Order Medicine" button works
- [ ] "Order Lab Tests" button works
- [ ] Connect to Doctor Now flow works
- [ ] Prescription shows after Connect Now consultation

## Priority
🔴 **CRITICAL** - Must be fixed today

## Estimated Time
1 hour total
