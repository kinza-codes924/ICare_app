# Health Tracker & Health Journey Implementation Plan

**Date:** May 5, 2026  
**Based on:** Client Meeting May 4, 2026  
**Priority:** HIGH - Complete before next meeting

---

## Current State Analysis

### Existing Files
1. **`lib/screens/health_tracker.dart`**
   - ✅ Has: BP, Heart Rate, Blood Glucose, Weight, Temperature, Oxygen Level
   - ❌ Missing: Steps, Sleep, Medication Adherence, Water Intake
   - ❌ Missing: Unit selection (kg/pounds)
   - ❌ Missing: Historical data view (table/graph)
   - ✅ Has: Indefinite storage with timestamps

2. **`lib/screens/health_journey_screen.dart`**
   - ❌ WRONG: Currently shows consultation history (medical records)
   - ❌ Should show: Health Tracker data filtered by Health Mode
   - ❌ Missing: Health Mode integration

3. **`lib/screens/settings.dart`**
   - ✅ Has: Basic tracker toggles
   - ✅ Has: Health mode toggles (partial)
   - ❌ Missing: Most sections from client requirements

---

## Implementation Plan

### Phase 1: Update Health Tracker (Priority 1)

#### 1.1 Add Missing Vitals
- [ ] **Steps** (daily step count)
  - Icon: `Icons.directions_walk_rounded`
  - Unit: steps
  - Color: `0xFF06B6D4` (cyan)
  
- [ ] **Sleep** (hours of sleep)
  - Icon: `Icons.bedtime_rounded`
  - Unit: hours
  - Color: `0xFF6366F1` (indigo)
  
- [ ] **Water Intake** (glasses/liters)
  - Icon: `Icons.local_drink_rounded`
  - Unit: glasses
  - Color: `0xFF0EA5E9` (sky blue)
  
- [ ] **Medication Adherence** (taken/missed)
  - Icon: `Icons.medication_liquid_rounded`
  - Unit: status (Taken/Missed)
  - Color: `0xFF10B981` (green)

#### 1.2 Add Unit Selection
- [ ] Weight: Toggle between kg/pounds
- [ ] Blood Sugar: Toggle between mg/dL and mmol/L
- [ ] Store user preference in settings

#### 1.3 Add Historical View
- [ ] Create "View History" button for each vital
- [ ] Show data in table format with timestamps
- [ ] Add simple line chart for trends
- [ ] Filter by date range (7 days, 30 days, 90 days, All)

#### 1.4 Update Data Entry Dialog
- [ ] Add date/time picker (allow backdating entries)
- [ ] Add notes field (optional)
- [ ] Improve validation

---

### Phase 2: Redesign Health Journey (Priority 1)

#### 2.1 Core Functionality
**IMPORTANT:** Health Journey should show Health Tracker data, NOT consultation history

- [ ] Remove current medical records display
- [ ] Fetch data from Health Tracker (vitals)
- [ ] Display based on Health Mode settings
- [ ] Show trends and insights

#### 2.2 Health Mode Integration
- [ ] Read Health Mode settings from user preferences
- [ ] Filter vitals based on selected conditions:
  - **Diabetes Mode** → Show: Blood Sugar, Weight, Medication
  - **BP Mode** → Show: Blood Pressure, Heart Rate, Medication
  - **Heart Mode** → Show: Heart Rate, BP, Steps, Weight
  - **Weight Mode** → Show: Weight, Steps, Water, Sleep
  - **General Mode** → Show: All vitals

#### 2.3 UI Design
- [ ] Dashboard cards for each tracked vital
- [ ] Show latest reading + trend (up/down/stable)
- [ ] Quick add button for each vital
- [ ] Weekly/Monthly summary
- [ ] Insights and recommendations

#### 2.4 Rename Current Health Journey
- [ ] Rename `health_journey_screen.dart` → `consultation_history_screen.dart`
- [ ] Update navigation references
- [ ] Keep functionality intact (it's useful for consultation history)

---

### Phase 3: Comprehensive Settings Update (Priority 2)

#### 3.1 Profile & Account Section
- [x] Name, Age, Gender (already exists)
- [x] Phone, Email (already exists)
- [ ] Profile photo upload
- [ ] Emergency contact (add/edit)
- [ ] Blood group selection
- [ ] Existing conditions (multi-select)

#### 3.2 Health Profile Section (NEW)
- [ ] Medical conditions (Diabetes, Hypertension, etc.)
- [ ] Allergies (list with add/remove)
- [ ] Current medications (list)
- [ ] Health goals (weight loss, BP control, etc.)

#### 3.3 Tracker Settings Section (NEW)
**Personalization:**
- [ ] What to track (toggles):
  - BP
  - Sugar
  - Weight
  - Water
  - Medication
  - Steps
  - Sleep
  - Heart Rate

**Daily Goals:**
- [ ] Water goal (glasses) - slider/input
- [ ] Steps goal (number) - slider/input
- [ ] Sleep goal (hours) - slider/input

#### 3.4 Health Mode Toggle (NEW - CRITICAL)
- [ ] Add prominent "Health Mode" toggle
- [ ] When ON: Show condition selection
- [ ] Conditions:
  - Diabetes Mode
  - BP Mode (Hypertension)
  - Heart Mode
  - Weight Management Mode
  - General Mode
- [ ] Allow multiple selections
- [ ] Save to user preferences
- [ ] Affects Health Journey display

#### 3.5 Reminders & Notifications Section (NEW)
- [ ] Medication reminders (time-based)
- [ ] Water reminders (interval-based)
- [ ] Health check reminders
- [ ] Appointment reminders

#### 3.6 Rewards & Points Section (NEW)
- [ ] Points balance display
- [ ] Rewards history
- [ ] Redemption history
- [ ] Link to gamification system

#### 3.7 Privacy & Data Section (NEW)
- [ ] Download health data (export as PDF/CSV)
- [ ] Delete account (with confirmation)

#### 3.8 Payments & Subscriptions Section (NEW)
- [ ] Saved payment methods
- [ ] Subscription plans
- [ ] Billing history

#### 3.9 Support & Help Section
- [x] Contact support (exists)
- [x] FAQs (exists)
- [x] Report issue (exists)

#### 3.10 About & Legal Section
- [x] Terms & conditions (exists)
- [x] Privacy policy (exists)
- [x] App version (exists)

#### 3.11 Consultation Settings Section (NEW)
- [ ] Preferred language (Urdu/English)
- [ ] Preferred doctor type (male/female)
- [ ] Consultation history access toggle
- [ ] Medical records upload
- [ ] Video/audio preferences

#### 3.12 Pharmacy Settings Section (NEW)
- [ ] Saved delivery addresses
- [ ] Preferred pharmacy
- [ ] Order history link
- [ ] Delivery preferences

#### 3.13 Diagnostics Settings Section (NEW)
- [ ] Test history link
- [ ] Home sample preferences
- [ ] Report delivery method

#### 3.14 Learning Settings Section (NEW)
- [ ] Enrolled courses link
- [ ] Certificates link
- [ ] Progress tracking
- [ ] Notifications for new courses

#### 3.15 Family Profiles Section (NEW)
- [ ] Add family members
- [ ] Manage children/parents
- [ ] Track their health separately

#### 3.16 Security Section
- [x] Change password (exists)
- [x] 2FA toggle (exists)
- [ ] Login activity log
- [ ] Active sessions

#### 3.17 Language & Region Section (NEW)
- [ ] Language selection (English/Urdu)
- [ ] Country/region selection

---

## Database Schema Updates

### New Collections/Tables Needed

#### 1. `health_tracker_entries`
```javascript
{
  _id: ObjectId,
  userId: ObjectId,
  vitalType: String, // "BP", "Sugar", "Weight", etc.
  value: String, // "120/80", "95", "70.5", etc.
  unit: String, // "mmHg", "mg/dL", "kg", etc.
  notes: String, // Optional notes
  timestamp: Date, // When reading was taken
  createdAt: Date, // When entry was created
  updatedAt: Date
}
```

#### 2. `user_health_settings`
```javascript
{
  _id: ObjectId,
  userId: ObjectId,
  
  // Health Mode
  healthModeEnabled: Boolean,
  selectedConditions: [String], // ["Diabetes", "Hypertension"]
  
  // Tracker Settings
  trackedVitals: {
    bp: Boolean,
    sugar: Boolean,
    weight: Boolean,
    water: Boolean,
    medication: Boolean,
    steps: Boolean,
    sleep: Boolean,
    heartRate: Boolean
  },
  
  // Daily Goals
  dailyGoals: {
    water: Number, // glasses
    steps: Number,
    sleep: Number // hours
  },
  
  // Unit Preferences
  unitPreferences: {
    weight: String, // "kg" or "lbs"
    bloodSugar: String // "mg/dL" or "mmol/L"
  },
  
  // Reminders
  reminders: {
    medication: [{ time: String, enabled: Boolean }],
    water: { interval: Number, enabled: Boolean },
    healthCheck: { time: String, enabled: Boolean }
  },
  
  createdAt: Date,
  updatedAt: Date
}
```

#### 3. `user_health_profile`
```javascript
{
  _id: ObjectId,
  userId: ObjectId,
  bloodGroup: String,
  medicalConditions: [String],
  allergies: [String],
  currentMedications: [{
    name: String,
    dosage: String,
    frequency: String
  }],
  healthGoals: [String],
  emergencyContact: {
    name: String,
    phone: String,
    relation: String
  },
  createdAt: Date,
  updatedAt: Date
}
```

---

## API Endpoints Needed

### Health Tracker APIs
- `POST /api/health-tracker/entry` - Add new vital entry
- `GET /api/health-tracker/entries` - Get all entries (with filters)
- `GET /api/health-tracker/entries/:vitalType` - Get entries for specific vital
- `PUT /api/health-tracker/entry/:id` - Update entry
- `DELETE /api/health-tracker/entry/:id` - Delete entry
- `GET /api/health-tracker/summary` - Get summary/stats

### Health Settings APIs
- `GET /api/health-settings` - Get user health settings
- `PUT /api/health-settings` - Update health settings
- `PUT /api/health-settings/health-mode` - Toggle health mode
- `PUT /api/health-settings/tracker-toggles` - Update tracker toggles
- `PUT /api/health-settings/daily-goals` - Update daily goals

### Health Profile APIs
- `GET /api/health-profile` - Get user health profile
- `PUT /api/health-profile` - Update health profile
- `POST /api/health-profile/emergency-contact` - Add emergency contact
- `PUT /api/health-profile/emergency-contact/:id` - Update emergency contact

---

## File Structure

```
lib/
├── screens/
│   ├── health_tracker.dart (UPDATE)
│   ├── health_journey_screen.dart (REDESIGN)
│   ├── consultation_history_screen.dart (RENAME from health_journey)
│   ├── vital_history_screen.dart (NEW - shows history for one vital)
│   ├── settings.dart (MAJOR UPDATE)
│   ├── health_profile_settings.dart (NEW)
│   ├── tracker_settings_screen.dart (NEW)
│   └── health_mode_settings.dart (NEW)
│
├── models/
│   ├── vital_entry.dart (NEW)
│   ├── health_settings.dart (NEW)
│   └── health_profile.dart (NEW)
│
├── services/
│   ├── health_tracker_service.dart (NEW)
│   ├── health_settings_service.dart (NEW)
│   └── health_profile_service.dart (NEW)
│
└── widgets/
    ├── vital_card.dart (NEW - reusable vital display)
    ├── vital_chart.dart (NEW - line chart for trends)
    ├── health_mode_selector.dart (NEW)
    └── daily_goal_slider.dart (NEW)
```

---

## Implementation Order

### Day 1 (Today)
1. ✅ Create implementation plan (this document)
2. Create backend models and APIs
3. Create frontend models
4. Create services

### Day 2
5. Update Health Tracker screen
6. Add missing vitals
7. Add historical view

### Day 3
8. Redesign Health Journey screen
9. Implement Health Mode filtering
10. Create dashboard UI

### Day 4
11. Update Settings screen
12. Add all new sections
13. Implement Health Mode toggle

### Day 5
14. Testing and bug fixes
15. UI/UX improvements
16. Documentation

---

## Testing Checklist

### Health Tracker
- [ ] Can add entry for each vital type
- [ ] Can view history for each vital
- [ ] Can edit/delete entries
- [ ] Unit conversion works correctly
- [ ] Data persists correctly
- [ ] Timestamps are accurate

### Health Journey
- [ ] Shows correct vitals based on Health Mode
- [ ] Updates when Health Mode changes
- [ ] Shows trends correctly
- [ ] Quick add works
- [ ] Insights are relevant

### Settings
- [ ] All toggles work
- [ ] Health Mode saves correctly
- [ ] Daily goals save correctly
- [ ] All sections are accessible
- [ ] Navigation works

---

## Notes

1. **Health Journey vs Consultation History:**
   - Current "Health Journey" shows consultation history
   - This is valuable, so rename it to "Consultation History"
   - Create NEW "Health Journey" for tracker data

2. **Health Mode is Critical:**
   - This is the key differentiator
   - Must be prominent in Settings
   - Must affect Health Journey display

3. **Data Privacy:**
   - All health data is sensitive
   - Ensure proper encryption
   - Allow data export/deletion

4. **Gamification:**
   - Keep existing gamification features
   - Add points for daily tracking
   - Add badges for consistency

---

**Status:** Ready to implement  
**Next Step:** Create backend models and APIs
