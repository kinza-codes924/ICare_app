# iCare Video Consultation - Complete Implementation Plan
**Date:** May 7, 2026  
**Based on:** Client Meeting Documentation (May 4, 2026)

## Table of Contents
1. [Overview](#overview)
2. [Chat-First Consultation Flow](#chat-first-consultation-flow)
3. [In-Consultation Prescription](#in-consultation-prescription)
4. [History Form Integration](#history-form-integration)
5. [Lifestyle Advice Feature](#lifestyle-advice-feature)
6. [Implementation Steps](#implementation-steps)
7. [File Structure](#file-structure)
8. [API Endpoints Required](#api-endpoints-required)

---

## Overview

### Key Changes from Client Meeting:
1. **Chat-First Approach**: Video call will NOT start automatically - consultation starts with chat
2. **In-Consultation Prescription**: Prescription must be created DURING consultation, not after
3. **History Form**: Comprehensive patient history form to be integrated
4. **Lifestyle Advice**: New section to be added in prescription
5. **Minimum Duration**: 10 minutes (cannot end before this)
6. **Maximum Duration**: 30 minutes (auto-ends after this)
7. **Consent Message**: Auto-sent when chat starts

---

## Chat-First Consultation Flow

### 1.1 Consultation Initiation
**Current State:** Video call starts directly  
**Required Change:** Start with chat screen first

#### Chat Screen Components:
```
┌─────────────────────────────────────┐
│  Dr. [Name]          Timer: 05:23   │
│  Patient: [Name]                    │
├─────────────────────────────────────┤
│                                     │
│  [Chat Messages Area]               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Hi, I am Dr. [Name]. I      │   │
│  │ confirm that telehealth...  │   │
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│  📎  [Type message...]    📤 Send  │
│                                     │
│  🎤 Voice  📹 Video  📋 Prescription│
│                                     │
│  ⏹️ End Consultation                │
└─────────────────────────────────────┘
```

### 1.2 Consent Message
**Auto-send when chat starts (Doctor side only):**
```
"Hi, I am Dr. [Name]. I confirm that telehealth has limitations and some emergencies require in-person visits."
```

### 1.3 Video Call Controls
**Two Buttons Required:**

1. **Red Button (Leave Video)**
   - Function: Temporarily leave video call
   - Behavior: Shows "Rejoin" option
   - Confirmation: "Do you want to leave video?"
   - Icon: Camera icon (not stop icon)

2. **Purple Button (End Consultation)**
   - Function: Permanently end consultation
   - Behavior: Cannot rejoin after this
   - Confirmation: "Do you want to end consultation?"
   - Validation: Check if prescription is complete

### 1.4 Consultation Duration
- **Minimum**: 10 minutes (cannot end before)
- **Maximum**: 30 minutes (auto-ends)
- **Timer**: Display at top of screen
- **Format**: MM:SS

---

## In-Consultation Prescription

### 2.1 Critical Changes
**BEFORE:** Prescription created after consultation ends  
**NOW:** Prescription must be created DURING consultation

### 2.2 Prescription Button Location
- Add "Prescription" button in video/chat interface
- Opens prescription form in same view (side panel or modal)
- Doctor can fill while consulting

### 2.3 Prescription Form Structure (In Order):

#### Tab 1: Patient History
```dart
// Use the comprehensive history form provided by client
- Chief Complaint(s)
- History of Present Illness (HPI)
- Past Medical History
- Past Surgical History
- Drug History & Allergies
- Family History
- Personal and Social History
- Gynecological/Obstetric History (if applicable)
- Review of Systems
- Virtual General Physical Examination
```

#### Tab 2: SOAP Notes
```dart
- Subjective
- Objective
- Assessment
- Plan
```

#### Tab 3: Doctor Notes
```dart
// Renamed from "Diagnosis Notes"
- Free text field for doctor's observations
```

#### Tab 4: Diagnosis
```dart
- ICD-10 codes integrated
- Searchable dropdown
- Multiple diagnoses can be added
- Each diagnosis clickable heading
```

#### Tab 5: Medications
```dart
- Medicine name (searchable dropdown - British Pharmacopoeia)
- Dose options: BD, TDS, QID, etc. (dropdown)
- Duration: dropdown with days/weeks/months
- Notes (optional)
- "+ Add Medicine" button
- Each medicine shows as separate line with minus (-) button
```

#### Tab 6: Lab Tests
```dart
- Search bar for test names
- Common tests with checkboxes:
  * CBC
  * Blood Glucose Fasting
  * Lipid Profile
  * LFTs (Liver Function Tests)
  * RFTs (Renal Function Tests)
- Selected tests appear in list
- REMOVE "Use Template" option
```

#### Tab 7: Lifestyle Advice (NEW)
```dart
- Diet recommendations
- Exercise guidelines
- Sleep hygiene
- Stress management
- Smoking cessation
- Alcohol moderation
- Weight management
- Other lifestyle modifications
```

#### Tab 8: Referral & Follow-up
```dart
- Refer to Emergency/Hospital
- Refer to Specialist
- Follow-up options: 15 days, 1 month, etc. (dropdown)
```

#### Tab 9: Course Assignment
```dart
- Option to assign health awareness videos/courses to patient
```

### 2.4 Prescription Completion Rules
1. **Save button**: Saves draft (can edit later during consultation)
2. **Cannot end consultation** until prescription is complete
3. **If doctor tries to end without completing** → Show error popup
4. **Once consultation ends** → Prescription auto-publishes to patient

### 2.5 Prescription Display (Patient Side)
**Format:** Single-page PDF-style view

```
┌─────────────────────────────────────────────┐
│  PRESCRIPTION                               │
│                                             │
│  Patient: [Name], [Age], [Gender]          │
│  MR Number: [Number]                        │
│  Date & Time: [DateTime]                    │
│                                             │
│  Doctor: Dr. [Name]                         │
│  PMDC License: [Number]                     │
│  Phone: [Number]                            │
│                                             │
├─────────────────────────────────────────────┤
│  DIAGNOSIS:                                 │
│  - [Diagnosis 1]                            │
│  - [Diagnosis 2]                            │
│                                             │
│  MEDICATIONS:                               │
│  1. [Medicine] - [Dose] - [Duration]       │
│  2. [Medicine] - [Dose] - [Duration]       │
│                                             │
│  LAB TESTS:                                 │
│  - [Test 1]                                 │
│  - [Test 2]                                 │
│                                             │
│  LIFESTYLE ADVICE:                          │
│  - [Advice 1]                               │
│  - [Advice 2]                               │
│                                             │
│  DOCTOR NOTES/INSTRUCTIONS:                 │
│  [Notes text]                               │
│                                             │
├─────────────────────────────────────────────┤
│  [Order Medicine]  [Order Lab Tests]       │
└─────────────────────────────────────────────┘
```

---

## History Form Integration

### 3.1 Complete History Form Structure
Based on client-provided form, create comprehensive data model:

```dart
class PatientHistoryForm {
  // 1. Chief Complaint(s)
  List<ChiefComplaint> chiefComplaints;
  
  // 2. History of Present Illness
  HistoryOfPresentIllness hpi;
  
  // 3. Past Medical History
  PastMedicalHistory pastMedicalHistory;
  
  // 4. Past Surgical History
  List<SurgicalHistory> surgicalHistory;
  
  // 5. Drug History
  DrugHistory drugHistory;
  
  // 6. Family History
  FamilyHistory familyHistory;
  
  // 7. Personal and Social History
  PersonalSocialHistory personalSocialHistory;
  
  // 8. Gynecological/Obstetric History
  GynecologicalHistory? gynecologicalHistory;
  
  // 9. Review of Systems
  ReviewOfSystems reviewOfSystems;
  
  // 10. Virtual General Physical Examination
  VirtualPhysicalExamination virtualExamination;
}

class ChiefComplaint {
  String complaint;
  String duration;
}

class HistoryOfPresentIllness {
  String onset;
  String duration;
  String progression;
  String location;
  String radiation;
  String character;
  String severity;
  String aggravatingFactors;
  String relievingFactors;
  String associatedSymptoms;
  String previousEpisodes;
  String treatmentTaken;
  String additionalNotes;
}

class PastMedicalHistory {
  bool hypertension;
  String? hypertensionDetails;
  bool diabetesMellitus;
  String? diabetesDetails;
  bool ischemicHeartDisease;
  String? ihdDetails;
  bool asthma;
  String? asthmaDetails;
  bool tuberculosis;
  String? tbDetails;
  bool hepatitis;
  String? hepatitisDetails;
  bool thyroidDisease;
  String? thyroidDetails;
  bool renalDisease;
  String? renalDetails;
  bool epilepsy;
  String? epilepsyDetails;
  bool psychiatricIllness;
  String? psychiatricDetails;
  List<OtherChronicIllness> otherIllnesses;
}

class SurgicalHistory {
  String surgeryProcedure;
  int year;
  String? hospitalRemarks;
}

class DrugHistory {
  List<CurrentMedication> currentMedications;
  List<Allergy> allergies;
}

class CurrentMedication {
  String medication;
  String dose;
  String frequency;
  String duration;
}

class Allergy {
  AllergyType type;
  String allergen;
  String reaction;
}

enum AllergyType {
  drug,
  food,
  other,
}

class FamilyHistory {
  FamilyMemberHistory? father;
  FamilyMemberHistory? mother;
  List<FamilyMemberHistory> siblings;
  List<FamilyMemberHistory> children;
  String? otherRelevantHistory;
}

class FamilyMemberHistory {
  String? diseaseCondition;
  int? ageAtDiagnosis;
}

class PersonalSocialHistory {
  String diet;
  String appetite;
  String sleep;
  String bowelHabits;
  String bladderHabits;
  SmokingStatus smoking;
  AlcoholStatus alcoholUse;
  bool substanceAbuse;
  String? substanceDetails;
  String exercise;
  String? sexualHistory;
  String? occupationalExposure;
  String? travelHistory;
  String? vaccinationHistory;
}

enum SmokingStatus {
  never,
  former,
  current,
}

enum AlcoholStatus {
  never,
  occasional,
  regular,
}

class GynecologicalHistory {
  int? menarche;
  DateTime? lastMenstrualPeriod;
  String menstrualCycle;
  int gravida;
  int para;
  int abortions;
  int livingChildren;
  String? contraceptiveUse;
  bool menopause;
  int? menopauseAge;
}

class ReviewOfSystems {
  String general;
  String cardiovascular;
  String respiratory;
  String gastrointestinal;
  String genitourinary;
  String neurological;
  String musculoskeletal;
  String endocrine;
  String skin;
  String psychiatric;
}

class VirtualPhysicalExamination {
  VitalSigns vitalSigns;
  GeneralExaminationFindings generalFindings;
  String notes;
}

class VitalSigns {
  String? bloodPressure;
  String? pulseRate;
  String? respiratoryRate;
  String? temperature;
  String? oxygenSaturation;
  String? weight;
  String? height;
  String? bmi;
}

class GeneralExaminationFindings {
  String generalAppearance;
  String levelOfConsciousness;
  String orientation;
  String hydration;
  bool pallor;
  bool icterus;
  bool cyanosis;
  bool clubbing;
  bool edema;
  bool lymphadenopathy;
  String nutritionalStatus;
  String mobilityGait;
}
```

---

## Lifestyle Advice Feature

### 4.1 Lifestyle Advice Categories
```dart
class LifestyleAdvice {
  DietAdvice? diet;
  ExerciseAdvice? exercise;
  SleepAdvice? sleep;
  StressManagement? stress;
  SmokingCessation? smoking;
  AlcoholModeration? alcohol;
  WeightManagement? weight;
  List<String> otherAdvice;
}

class DietAdvice {
  String recommendations;
  List<String> foodsToAvoid;
  List<String> foodsToInclude;
  String mealTiming;
  String hydration;
}

class ExerciseAdvice {
  String type;
  String frequency;
  String duration;
  String intensity;
  List<String> precautions;
}

class SleepAdvice {
  String recommendedHours;
  String sleepSchedule;
  List<String> sleepHygieneTips;
}

class StressManagement {
  List<String> techniques;
  String recommendations;
}

class SmokingCessation {
  String plan;
  List<String> resources;
  String timeline;
}

class AlcoholModeration {
  String recommendations;
  String limits;
}

class WeightManagement {
  double? targetWeight;
  String plan;
  String timeline;
}
```

### 4.2 Lifestyle Advice UI
```dart
// In prescription form
Widget _buildLifestyleAdviceTab() {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        _buildAdviceSection('Diet', Icons.restaurant),
        _buildAdviceSection('Exercise', Icons.fitness_center),
        _buildAdviceSection('Sleep', Icons.bedtime),
        _buildAdviceSection('Stress Management', Icons.spa),
        _buildAdviceSection('Smoking Cessation', Icons.smoke_free),
        _buildAdviceSection('Alcohol Moderation', Icons.local_bar),
        _buildAdviceSection('Weight Management', Icons.monitor_weight),
        _buildAdviceSection('Other', Icons.add),
      ],
    ),
  );
}
```

---

## Implementation Steps

### Phase 1: Chat-First Flow (Priority 1)
**Files to Create/Modify:**

1. **Create: `lib/screens/consultation_chat_screen_v2.dart`**
   - Chat interface with timer
   - Voice call button
   - Video call button
   - Prescription button
   - End consultation button
   - Attachment support
   - Auto-send consent message

2. **Modify: `lib/screens/consultation_workflow.dart`**
   - Change "Start Video" to "Start Chat"
   - Navigate to chat screen instead of video call

3. **Create: `lib/models/consultation_timer.dart`**
   - Timer logic
   - Min/max duration validation
   - Auto-end functionality

### Phase 2: In-Consultation Prescription (Priority 1)
**Files to Create/Modify:**

1. **Create: `lib/screens/in_consultation_prescription_form.dart`**
   - Tabbed interface
   - All prescription sections
   - Save draft functionality
   - Validation logic

2. **Create: `lib/models/in_consultation_prescription.dart`**
   - Complete prescription data model
   - Validation methods
   - Completion status

3. **Modify: `lib/screens/consultation_chat_screen_v2.dart`**
   - Add prescription button
   - Open prescription form as side panel/modal
   - Check prescription completion before ending

### Phase 3: History Form Integration (Priority 2)
**Files to Create:**

1. **Create: `lib/models/patient_history_form.dart`**
   - Complete history form data model
   - All classes as defined above

2. **Create: `lib/screens/patient_history_form_screen.dart`**
   - Multi-step form UI
   - 10 sections as per client form
   - Save/continue functionality

3. **Create: `lib/widgets/history_form_sections/`**
   - `chief_complaint_section.dart`
   - `hpi_section.dart`
   - `past_medical_history_section.dart`
   - `surgical_history_section.dart`
   - `drug_history_section.dart`
   - `family_history_section.dart`
   - `personal_social_history_section.dart`
   - `gynecological_history_section.dart`
   - `review_of_systems_section.dart`
   - `virtual_examination_section.dart`

### Phase 4: Lifestyle Advice (Priority 2)
**Files to Create:**

1. **Create: `lib/models/lifestyle_advice.dart`**
   - Complete lifestyle advice data model

2. **Create: `lib/widgets/lifestyle_advice_form.dart`**
   - UI for lifestyle advice input
   - Pre-defined templates
   - Custom advice option

3. **Modify: `lib/screens/in_consultation_prescription_form.dart`**
   - Add lifestyle advice tab

### Phase 5: Video Call Controls (Priority 3)
**Files to Modify:**

1. **Modify: `lib/screens/video_call_mobile.dart`**
   - Add "Leave Video" button (red, camera icon)
   - Add "End Consultation" button (purple)
   - Add confirmation dialogs
   - Add rejoin functionality

2. **Modify: `lib/screens/video_call_web.dart`**
   - Same changes as mobile

### Phase 6: Prescription Display (Priority 3)
**Files to Create/Modify:**

1. **Create: `lib/widgets/prescription_pdf_view.dart`**
   - PDF-style prescription display
   - Include lifestyle advice section
   - Order buttons (active for 30 days)

2. **Modify: `lib/screens/patient_prescriptions.dart`**
   - 30-day active window logic
   - View-only mode for old prescriptions

---

## File Structure

```
lib/
├── models/
│   ├── patient_history_form.dart (NEW)
│   ├── lifestyle_advice.dart (NEW)
│   ├── in_consultation_prescription.dart (NEW)
│   ├── consultation_timer.dart (NEW)
│   └── consultation.dart (MODIFY)
│
├── screens/
│   ├── consultation_chat_screen_v2.dart (NEW)
│   ├── in_consultation_prescription_form.dart (NEW)
│   ├── patient_history_form_screen.dart (NEW)
│   ├── consultation_workflow.dart (MODIFY)
│   ├── video_call_mobile.dart (MODIFY)
│   ├── video_call_web.dart (MODIFY)
│   └── patient_prescriptions.dart (MODIFY)
│
├── widgets/
│   ├── history_form_sections/ (NEW FOLDER)
│   │   ├── chief_complaint_section.dart
│   │   ├── hpi_section.dart
│   │   ├── past_medical_history_section.dart
│   │   ├── surgical_history_section.dart
│   │   ├── drug_history_section.dart
│   │   ├── family_history_section.dart
│   │   ├── personal_social_history_section.dart
│   │   ├── gynecological_history_section.dart
│   │   ├── review_of_systems_section.dart
│   │   └── virtual_examination_section.dart
│   │
│   ├── lifestyle_advice_form.dart (NEW)
│   ├── prescription_pdf_view.dart (NEW)
│   └── consultation_timer_widget.dart (NEW)
│
└── services/
    ├── consultation_service.dart (MODIFY)
    └── prescription_service.dart (MODIFY)
```

---

## API Endpoints Required

### Consultation Endpoints
```
POST   /api/consultations/start-chat
POST   /api/consultations/:id/send-message
GET    /api/consultations/:id/messages
POST   /api/consultations/:id/upload-attachment
POST   /api/consultations/:id/start-video
POST   /api/consultations/:id/leave-video
POST   /api/consultations/:id/end
GET    /api/consultations/:id/timer
```

### Prescription Endpoints
```
POST   /api/prescriptions/create-draft
PUT    /api/prescriptions/:id/update-draft
POST   /api/prescriptions/:id/complete
GET    /api/prescriptions/:id
GET    /api/prescriptions/patient/:patientId
POST   /api/prescriptions/:id/generate-pdf
```

### History Form Endpoints
```
POST   /api/patient-history/create
PUT    /api/patient-history/:id/update
GET    /api/patient-history/patient/:patientId
GET    /api/patient-history/consultation/:consultationId
```

### Lifestyle Advice Endpoints
```
GET    /api/lifestyle-advice/templates
POST   /api/lifestyle-advice/create
PUT    /api/lifestyle-advice/:id/update
```

---

## Testing Checklist

### Chat-First Flow
- [ ] Chat screen opens when consultation starts
- [ ] Consent message auto-sends from doctor
- [ ] Timer starts and displays correctly
- [ ] Voice call button works
- [ ] Video call button works
- [ ] Attachment upload works
- [ ] Messages send and receive correctly

### Prescription
- [ ] Prescription button opens form
- [ ] All tabs are accessible
- [ ] History form saves correctly
- [ ] SOAP notes save correctly
- [ ] Medications can be added/removed
- [ ] Lab tests can be selected
- [ ] Lifestyle advice can be added
- [ ] Referral options work
- [ ] Course assignment works
- [ ] Save draft works
- [ ] Cannot end consultation without completing prescription
- [ ] Prescription auto-publishes on consultation end

### Video Call
- [ ] Leave video button shows confirmation
- [ ] Leave video allows rejoin
- [ ] End consultation button shows confirmation
- [ ] End consultation checks prescription completion
- [ ] Camera icon used (not stop icon)
- [ ] Buttons have correct colors (red/purple)

### Duration
- [ ] Timer displays correctly
- [ ] Cannot end before 10 minutes
- [ ] Auto-ends at 30 minutes
- [ ] Warning shown before auto-end

### Prescription Display
- [ ] PDF-style view displays correctly
- [ ] All sections visible
- [ ] Lifestyle advice section included
- [ ] Order buttons active for 30 days
- [ ] Order buttons disabled after 30 days
- [ ] Can print/download PDF

---

## Next Steps

1. **Backend Team**: Implement required API endpoints
2. **Frontend Team**: Start with Phase 1 (Chat-First Flow)
3. **Design Team**: Create mockups for:
   - Chat interface
   - Prescription form
   - History form
   - Lifestyle advice UI
4. **Client**: Provide:
   - Exact consent message text
   - British Pharmacopoeia medicine database
   - Lab tests catalogue
   - Screenshots for chat interface design

---

## Notes

- All changes must maintain backward compatibility
- Existing consultation flow should still work
- Migration plan needed for existing consultations
- Performance testing required for 30-minute video calls
- Security audit needed for prescription data

---

**Document Version:** 1.0  
**Last Updated:** May 7, 2026  
**Prepared By:** Development Team  
**Status:** Ready for Implementation
