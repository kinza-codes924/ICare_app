# iCare App — Client Meeting Changes
**Meeting Date:** 13 April 2026
**Last Reviewed:** 21 May 2026
**Status:** In Progress

> **Legend:** ✅ DONE | 🔄 PARTIAL | ⚫ CANCELLED BY CLIENT | 🔴 PENDING

---

## TABLE OF CONTENTS
1. [Home Page Changes](#1-home-page-changes)
2. [Find Doctors / Doctor Listing Page](#2-find-doctors--doctor-listing-page)
3. [Patient Module Changes](#3-patient-module-changes)
4. [Doctor Dashboard Changes](#4-doctor-dashboard-changes)
5. [Health Tracker Redesign](#5-health-tracker-redesign)
6. [Settings Page Redesign](#6-settings-page-redesign)
7. [Priority Summary](#7-priority-summary)
8. [Developer Notes](#8-developer-notes)

---

## 1. HOME PAGE CHANGES
**File:** `lib/screens/home.dart` and `lib/screens/public_home.dart`

---

### 1.1 Banner Section

| # | Change | Details |
|---|--------|---------|
| 1 | Update heading text | Change to: **"Talk to a verified Specialist Doctor"** |
| 2 | Remove video consultation fee | Remove any fee/price text from the banner area |
| 3 | Add search bar in banner | Below the "Connect to a Doctor" button — single search bar that searches doctors, specialities, and conditions |
| 4 | "Connect to a Doctor" button — pulsing animation | Add a glowing/pulsing border animation to this button (black border, flash effect) |
| 5 | Two buttons in header | Header should have: **"Connect to a Doctor Now"** + **"Book Appointment"** |
| 6 | Replace "Treated" button text | Change to: **"Certified Doctor Access — Complete Health Care"** |

---

### 1.2 Browse By Speciality Section

| # | Change | Details |
|---|--------|---------|
| 7 | Rename button | "View More" → **"See All Speciality"** |
| 8 | Center-align that button | The "See All Speciality" button should be centered on the page |
| 9 | Move speciality section up | Speciality browser should appear before Pharmacy and Labs sections |
| 10 | Make speciality cards clickable | Each speciality card should navigate to the doctors list filtered by that speciality |
| 11 | Add "Search by Condition" field | Inside the speciality section, add a search field where the user can type a condition (e.g., "diabetes") |

---

### 1.3 Doctors Search Bar — 3 Options

The search bar for doctors should have three search modes:
1. Search by Doctor Name
2. Search by Speciality
3. Search by Condition

Additional buttons near the search bar:
- **"Search All Doctors"** — goes to the full doctors listing page (`lib/screens/doctors_list.dart`)
- **"Connect Now"** — goes to the available/online doctors page

---

### 1.4 Courses Section (New Section)

**Position:** Above the "How iCare Works" section

**Heading:** "Join Pakistan's First 360° Health Care Platform"
**Sub-heading:** "Open for Everyone"
**Bottom text:** "Live Skill Academy for Everyone"

Layout: 2x2 grid of tiles

| Tile | Audience | Content |
|------|----------|---------|
| 1 | Patients | Diet Plan & Health Related Courses |
| 2 | Patients | Health Programs |
| 3 | Doctors | General Courses |
| 4 | Doctors | Training Programs for Healthcare |

These tiles should link to the courses/programs sections of the app (`lib/screens/courses.dart`).

---

### 1.5 Pharmacy Section

| # | Change | Details |
|---|--------|---------|
| 12 | Section heading | Change to: **"Order Medicines"** |
| 13 | Add medicine search bar | A search bar to search medicines by name |
| 14 | Show pharmacy ratings | Display star ratings on pharmacy cards |

---

### 1.6 Laboratory Section

| # | Change | Details |
|---|--------|---------|
| 15 | Section heading | Change to: **"Book a Lab Test"** |
| 16 | Add "Book Lab" button | Visible button to go to the lab booking flow |
| 17 | Add lab test search bar | A search bar to search lab tests by name |
| 18 | Show lab ratings | Display star ratings on laboratory cards |

> Each section (Doctors, Pharmacy, Labs) has its own separate search bar.

---

### 1.7 Footer Changes ✅ DONE
**File:** Footer widget (likely inside `lib/screens/home.dart` or a shared footer widget)

| # | Change | Details | Status |
|---|--------|---------|--------|
| 19 | Remove "Analytics" link | Delete it from footer links | ✅ DONE |
| 20 | Remove "For Doctors" link | Delete it from footer links | ✅ DONE |
| 21 | Theme change | Footer background: white. Text and accent: blue theme | ✅ DONE |

---

### 1.8 WhatsApp Floating Button ✅ DONE

Add a WhatsApp floating action button on the home page.
- Position: Bottom-right corner
- Standard WhatsApp green icon, links to the business WhatsApp number
- Should be visible without scrolling

---

## 2. FIND DOCTORS / DOCTOR LISTING PAGE
**File:** `lib/screens/doctors_list.dart`, `lib/screens/doctor_detail.dart`

---

### 2.1 Search and Filter Changes

| # | Change | Details |
|---|--------|---------|
| 22 | Add speciality search bar | Users can filter the doctor list by speciality |
| 23 | Add "General Practitioner" as default | It should appear as the first option in the speciality filter |
| 24 | Add "Search by Condition" | Users can type a condition and see matching doctors |
| 25 | Show online doctors count | Display a line like: **"X doctors online right now"** at the top of the list |
| 26 | Remove the 3 filter tabs | Remove "All", "General", and any similar tab filters from the top of the page |

---

### 2.2 Doctor Card — Information to Show

| # | Change | Details |
|---|--------|---------|
| 27 | Show profile picture | Doctor's photo must appear on their card |
| 28 | Show PMDC Number | Display PMDC registration number on the doctor card |
| 29 | Show years of experience | Display experience (e.g., "8 years experience") on the card |
| 30 | Remove contact info from booking | When opening book appointment, do not show the doctor's phone or contact details |

> Note: PMDC number and years of experience fields need backend support — coordinate with backend team.

---

### 2.3 Consult Now / Book Appointment Flow
**File:** `lib/screens/book_appointment.dart`, `lib/screens/confirm_booking.dart`, `lib/screens/confirm_details.dart`

| # | Change | Details |
|---|--------|---------|
| 31 | "Consult Now" click → Payment screen | After clicking "Consult Now", show doctor's basic info then go directly to payment screen |
| 32 | After booking confirmation → Payment screen | After confirming a booking, payment screen should appear |
| 33 | Remove messaging and voice call options | Do not show messaging or voice call options on the booking details screen |
| 34 | Remove all contact info | No phone number, email, or any contact info should appear in booking flow |

---

### 2.4 Pharmacy and Lab Ratings on Listing Pages

- Show star ratings on pharmacy cards (`lib/screens/pharmacies.dart`)
- Show star ratings on laboratory cards (`lib/screens/laboratories.dart`)

---

## 3. PATIENT MODULE CHANGES

---

### 3.1 Patient Profile
**File:** `lib/screens/patient_profile.dart`, `lib/screens/profile_edit.dart`, `lib/screens/profile.dart`

| # | Change | Details | Status |
|---|--------|---------|--------|
| 35 | Remove "Role" field | Do not display the role field on the patient profile | ✅ DONE |
| 36 | Add CNIC Number field | New required field: CNIC number | ✅ DONE |
| 37 | Profile fields to show | Age, Height, Weight, CNIC Number, Address | ✅ DONE |
| 38 | Profile icon click → dropdown | Clicking the profile icon should show a dropdown with two options: **Edit Profile** and **Logout** | ✅ DONE |

> Note: CNIC field needs a backend schema update.

---

### 3.2 Patient Sidebar Changes ✅ DONE
**File:** `lib/navigators/drawer.dart` (Patient section)

| # | Action | Details | Status |
|---|--------|---------|--------|
| 39 | Remove "My Profile" from sidebar | Profile access moves to the top-right profile icon | ✅ DONE |
| 40 | Remove "Messages" from sidebar | Messaging will be accessible from elsewhere | ✅ DONE |
| 41 | Remove "My Care Plans" | Keep only "Health Programs" — remove the Care Plans link | ✅ DONE |
| 42 | Rename "Pharmacies" | Change to **"Order Medicines"** | ✅ DONE |
| 43 | Rename "Laboratories" | Change to **"Book a Lab Test"** | ✅ DONE |
| 44 | Rename "My Appointment" + move to top | Change to **"My Appointments"** and make it the first item in the sidebar | ✅ DONE |

---

### 3.3 My Appointments / Booking History
**File:** `lib/screens/bookings_history.dart`, `lib/screens/bookings.dart`

| # | Change | Details |
|---|--------|---------|
| 45 | Rename section | "Progressive Booking" → **"Booking History"** |
| 46 | Add "Book Appointment Now" button | A large button at the top of this screen |
| 47 | Pending bookings at top | Show pending/upcoming bookings before past ones |
| 48 | Cancel button at bottom | The cancel action/button should be at the bottom of the booking card |
| 49 | Card layout | Each booking should display all info in one clean card/box (not split across sections) |
| 50 | Completed appointment history | Show prescription and doctor notes for completed appointments |

---

### 3.4 Book a Lab Test (New Flow)
**File:** `lib/screens/book_lab.dart`, `lib/screens/laboratories.dart`, `lib/screens/lab_list.dart`

This is a new multi-step booking flow when the patient clicks "Book a Lab Test" from the sidebar.

**Step 1 — Sample Type (required, shown as two equal columns):**
- Home Sample
- Sample at Lab

**Step 2 — Search and Select Tests:**
- Search bar to search lab test by name
- List of tests with checkboxes to select multiple
- If a doctor has prescribed tests, they should appear here automatically

**Step 3 — Nearby Lab Selection (geo-tagged):**
- Show labs within:
  - 5 km radius
  - 10 km radius
  - 15 km radius
- When a test is selected, the nearest labs that offer that test should appear

**Lab Reports Section — 3 categories:**

| Category | Meaning |
|----------|---------|
| Completed | Report is ready and available |
| Pending | Test is booked, result not yet available |
| Advised | Doctor recommended this test, not yet booked |

> Note: Geo-tagging requires location permission from the user's device.

---

### 3.5 Order Medicines (Pharmacy)
**File:** `lib/screens/pharmacies.dart`, `lib/screens/pharmacy_home.dart`

- Search bar to find medicines by name
- Show a list of available medicines
- Clicking a medicine goes to the Payment screen

---

### 3.6 Reminders
**File:** `lib/screens/create_reminder.dart`, `lib/screens/notifications.dart`

| # | Change | Details |
|---|--------|---------|
| 51 | Two types of reminders | 1. Doctor-assigned reminders (added automatically when doctor prescribes) 2. Self-created reminders (patient adds manually) |
| 52 | Create Reminder form fields | Date, Time, Label — keep it simple |
| 53 | Google Calendar sync | Option to sync reminders with Google Calendar |
| 54 | Replace "Select time and day" | Remove that UI element — replace with a simple **"Add Reminder"** button |

> Note: Google Calendar sync requires OAuth integration.

---

### 3.7 My Health Journey
**File:** `lib/screens/health_journey_screen.dart`, `lib/screens/health_journey_timeline.dart`

- Add a **"Coming Soon"** banner on this screen
- When a doctor adds a prescription or suggestion, it should automatically appear here
- Entries should be shown in chronological order (oldest to newest or as a timeline)

---

### 3.8 My Appointments — Booking Detail View
**File:** `lib/screens/bookings.dart`, `lib/screens/confirm_details.dart`, `lib/screens/profile_or_appointement_view.dart`

| # | Change | Details |
|---|--------|---------|
| 55 | Rename "View Full Profile" | Change to **"View Full Details"** or **"Appointment Details"** |
| 56 | Confirmed status in green | When status is "Confirmed", show it in green color |
| 57 | Remove messaging, voice call, contact info | Do not show these options in the appointment detail screen |
| 58 | Back button goes to Home | From any appointment detail screen, pressing Back should go to Home Page — not back to booking history |

---

### 3.9 Health Community
**File:** `lib/screens/health_community.dart`

| # | Change | Details | Status |
|---|--------|---------|--------|
| 59 | Add Like and Comment | Posts must have a Like button and a Comment option | ✅ DONE |
| 60 | Show iCare logo | The iCare app logo should appear on the Health Community page | ✅ DONE |

---

### 3.10 Patient Settings — Items to Remove ✅ DONE
**File:** `lib/screens/settings.dart`

Remove the following items from patient Settings:
- Privacy Policy (also `lib/screens/privacy_policy.dart`) ✅ DONE
- About Us (`lib/screens/about_us.dart`) ✅ DONE
- Terms and Conditions ✅ DONE

> Note: These were moved to "About & Legal" section (section 6.9) as requested.

---

### 3.11 Notification Preferences
> ⚫ **NOTE (Client Update):** This section was part of settings page but client requested it be moved to a new separate notification tab beside the profile icon in the AppBar.

**File:** `lib/screens/notification_settings.dart`

| # | Change | Details | Status |
|---|--------|---------|--------|
| 64 | Remove "Patient Messages" | Delete this notification option | ✅ DONE |
| 65 | Rename "Admin Announcement" | Change to **"Promotions"** | ✅ DONE |
| 66 | Add sound toggle | Option to enable/disable notification sound | ✅ DONE |
| 67 | Rename section heading | Change to **"Notification Settings"** | ✅ DONE |
| 68 | Add email prescription toggle | Add a toggle: "Send prescription to email automatically" | ✅ DONE |

---

### 3.12 Patient View Profile — SOAP Notes ✅ DONE
> ⚫ **NOTE (Client Update):** SOAP Notes were renamed to "Doctor's Notes" and are now part of the prescription (within consultation) — not shown on patient profile view.

**File:** `lib/screens/patient_profile_view.dart`, `lib/screens/patient_history_view.dart`

- SOAP Notes must NOT be visible when a patient views their own profile. ✅ DONE
- SOAP Notes are doctor-facing only and should stay hidden from patients. ✅ DONE

---

### 3.13 Emergency Numbers
**File:** Patient profile section — `lib/screens/patient_profile.dart` or `lib/navigators/drawer.dart`

- Add two emergency contact fields to the patient profile or sidebar:
  - Emergency Number 1
  - Emergency Number 2

> Note: `lib/screens/emergency_contacts.dart` may already exist — check if it can be extended.

---

## 4. DOCTOR DASHBOARD CHANGES
**File:** `lib/screens/doctor_dashboard.dart`

---

### 4.1 Dashboard Layout — New Order ✅ DONE

The dashboard should display content in this order, top to bottom:
1. Welcome message: "Welcome back, Dr. [Name]" with rating and satisfaction score ✅ DONE
2. Appointment Requests (pending, with Accept/Decline buttons) ✅ DONE
3. Today's Appointments ✅ DONE
4. Number of consultations (not revenue) ✅ DONE
5. ~~Take off revenue section from home page~~ ⚫ **CANCELLED BY CLIENT** — Revenue remains in app for Doctor, Lab, and Pharmacy accounts

---

### 4.2 Remove from Doctor Dashboard

| # | Remove | Status |
|---|--------|--------|
| 69 | "Secure Health" card/widget | ✅ DONE |
| 70 | Revenue amount display | ⚫ **CANCELLED BY CLIENT** — Discussed with client; revenue stays in app for Doctor, Lab & Pharmacy |
| 71 | "View All" button on the Today's Appointments heading | ✅ DONE |

---

### 4.3 Appointment Requests Widget ✅ DONE

- Replace the "Pending Appointments" section with **"Appointment Requests"** ✅ DONE
- Show 5 requests at a time with a "View All" link ✅ DONE
- Each request card must have:
  - Accept button (green checkmark) ✅ DONE
  - Decline button (red X) ✅ DONE
- Replace the Revenue card with: **Pending Appointments count** (just a number) ✅ DONE

---

### 4.4 Today's Appointments Display ✅ DONE

- Show appointments as square cards arranged by time ✅ DONE
- Show "Total Patients Today" count + list ✅ DONE
- "View All" link for the full list ✅ DONE
- ~~Quick Actions section should show appointments grouped by day~~ ⚫ **CANCELLED BY CLIENT**

---

### 4.5 Doctor Stats — What to Show vs Remove

| Show | Remove |
|------|--------|
| Rating + Satisfaction score | Revenue amount |
| Number of consultations | "Secure Health" section |
| Pending appointments count | — |

---

### 4.6 Doctor Sidebar — Logout Location
**File:** `lib/navigators/drawer.dart` (Doctor section)

| # | Change |
|---|--------|
| 72 | Move "Logout" inside Edit Profile | Logout should not be a standalone sidebar item |
| 73 | Edit Profile → dropdown | Clicking Edit Profile shows: **Edit Profile** + **Logout** as a 2-item dropdown |

---

## 5. HEALTH TRACKER REDESIGN
**Files:** `lib/screens/health_tracker.dart`, `lib/screens/lifestyle_tracker.dart`, `lib/screens/lifestyle_tracker_screen.dart`, `lib/screens/gamification_screen.dart`

The health tracker needs a full redesign based on the UI reference image shared by the client. The new design includes a personalized dashboard, multiple tracking categories, a points/rewards system, and progress charts.

---

### 5.1 Main Dashboard Screen ✅ DONE
> Note: Log history function is not yet added (for future iteration)

When the patient opens the Health Tracker, they should see:

- **Greeting at top:** "Hello, [Patient Name] — Your Health Today" ✅ DONE
- **Daily Goal progress bar:** Shows percentage complete (e.g., "Daily Goal: 60% Complete") with a checkmark when done ✅ DONE
- **Points earned today:** A gold star icon with "You earned X points today" ✅ DONE
- **Metric tiles (grid layout):** Quick-view tiles for each tracked item ✅ DONE
  - BP: 120/80 mmHg ✅
  - Blood Sugar: 110 mg/dL ✅
  - Weight: 70.4 kg ✅
  - Water: 5 glasses ✅
  - Medication (taken/missed) ✅
  - Steps: 2,500 ✅
- **"+ Log More" button** at the bottom to add a new entry ✅ DONE

---

### 5.2 Tracking Categories ✅ DONE

The tracker must support all of the following. Each category can be turned ON or OFF per patient (see Settings section 6.3).

#### Vitals
- Blood Pressure (BP) — Systolic + Diastolic in mmHg
- Blood Sugar / Glucose — mg/dL, with option to mark fasting or post-meal
- Weight — kg
- Heart Rate — bpm
- Oxygen Saturation (SpO2) — percentage

#### Lifestyle
- Water intake — glasses per day with a circular progress indicator (e.g., 5/8 glasses)
- Steps / Physical activity — daily step count
- Sleep — hours per night
- Diet / Meals — meal log

#### Medication & Compliance
- Medication taken: Yes/No toggle per medication
- Medication reminders (tied to reminder system)
- Missed dose tracking — flag when a dose is skipped
- Prescription tracking — link to current prescriptions from doctor

#### Condition-Specific Tracking
The tracker adapts based on the patient's selected "Health Mode" (see section 5.5):

| Condition | What to Track |
|-----------|--------------|
| Diabetes | Blood sugar (fasting + post-meal), diet |
| Hypertension | Blood pressure, salt intake |
| General Wellness | Weight, activity, sleep |

#### Mental & Other Health
- Mood tracking — emoji selector (happy / neutral / sad or similar scale)
- Stress level — numeric or emoji scale
- Menstrual cycle tracking (for women)
- Hydration reminders
- Calories / macronutrients

---

### 5.3 Logging a Metric

When a patient taps on a metric tile (e.g., "Log Blood Pressure"):
- Show input fields for that specific metric (e.g., Systolic + Diastolic for BP)
- Show a numeric keypad on screen
- Show a **"Save Entry"** button
- After saving: show **"+X points earned"** message (gamification reward)

---

### 5.4 Progress Charts ✅ DONE

A "Your Progress" screen accessible from the main tracker, with:
- **Tabs:** Daily / Weekly / Monthly ✅ DONE
- **Line charts** for each tracked metric (e.g., BP over the last 7 days, Blood Sugar trend) ✅ DONE
- **Achievement badges** below the charts ✅ DONE
- **"View Detailed Report"** link at the bottom ✅ DONE

---

### 5.5 "Health Mode" Toggle (New Feature) ✅ DONE
> Note: Controlled through Patient Profile Settings (not on tracker home directly) — as confirmed with client

On the tracker home or in settings, the patient selects their health mode. This changes which metrics are shown by default on the dashboard.

| Mode | Default Metrics Shown |
|------|-----------------------|
| Diabetes Mode | Blood sugar (fasting/post-meal), diet, medication |
| BP Mode | Blood pressure, salt intake, medication |
| General Wellness Mode | Weight, steps, sleep, water |

- Only one mode active at a time
- Patient can switch modes anytime
- Custom mode can also be allowed (manual toggle of each metric)

---

### 5.6 Rewards / Points System 🔄 PARTIAL
> ⚫ **NOTE:** Gamification/Rewards screen will be completed once all other application features are finalized by client. Points tracking is implemented; full redemption screen pending.

**File:** `lib/screens/gamification_screen.dart`

The tracker includes a points system to encourage daily logging.

**Earning points:**
- Log a metric → earn points (e.g., +5 per entry)
- Reach daily goal → bonus points
- Log multiple days in a row → streak bonus

**Your Rewards screen:**
- Show total points balance at the top (e.g., "Total Points: 240")
- Activity feed: list of recent point-earning actions with time (e.g., "BP logged today 8:45am — +5 points")
- **"Redeem Points"** button

**Redeem Rewards screen:**
- List of reward options with their point cost, for example:
  - Free Consultation — 100 points
  - Lab Test Discount — 150 points
- Charts showing redemption history
- "More rewards coming" placeholder for future rewards

---

### 5.7 Consultation Summary Integration

When the patient starts a consultation from the tracker:
- Show a **Consultation Summary** card before connecting to the doctor
- Summary includes recent tracker data: Medication status, Water intake, Steps (last 7 days)
- Doctor's notes from last visit (if any)
- **"Start Consultation"** button at the bottom

---

## 6. SETTINGS PAGE REDESIGN
**File:** `lib/screens/settings.dart`

The current settings page is minimal. The client wants a fully restructured settings page with multiple organized sections. Each section listed below should be a collapsible group or a separate sub-screen.

---

### 6.1 Profile & Account

| Field | Details |
|-------|---------|
| Name | Editable |
| Age / Gender | Editable |
| Phone / Email | Editable |
| Profile photo | Upload/change photo |
| Emergency contact | Emergency phone number |
| Blood group | Dropdown selection |
| Existing conditions | Multi-select: Diabetes, BP, etc. |

---

### 6.2 Health Profile

This section links the patient's medical background to their tracker and doctor.

| Field | Details |
|-------|---------|
| Medical conditions | Diabetes, Hypertension, etc. (multi-select) |
| Allergies | Free text or tag input |
| Current medications | List of current medicines |
| Health goals | Weight loss, BP control, etc. (multi-select) |

> This information connects to the health tracker (auto-configures Health Mode) and is visible to the patient's doctor.

---

### 6.3 Tracker Settings ✅ DONE

**Personalization — Toggle what to track:**
- BP — ON/OFF toggle ✅ DONE
- Blood Sugar — ON/OFF toggle ✅ DONE
- Weight — ON/OFF toggle ✅ DONE
- Water intake — ON/OFF toggle ✅ DONE
- Medication — ON/OFF toggle ✅ DONE

**Set daily goals:**
- Water goal (e.g., 8 glasses per day) 🔴 PENDING
- Steps goal (e.g., 10,000 steps) 🔴 PENDING

---

### 6.4 Reminders & Notifications

| Option | Details |
|--------|---------|
| Medication reminders | Set time(s) for each medication |
| Water reminders | Periodic reminders throughout day |
| Health check reminders | Reminder to log vitals |
| Appointment reminders | Alert before upcoming appointment |

---

### 6.5 Rewards & Points

| Item | Details |
|------|---------|
| Points balance | Current total shown |
| Rewards history | List of how points were earned |
| Redemption history | List of rewards redeemed |

---

### 6.6 Privacy & Data

| Option | Details |
|--------|---------|
| Download health data | Export all personal health data |
| Delete account | Permanent account deletion with confirmation |

---

### 6.7 Payments & Subscriptions

| Item | Details |
|------|---------|
| Saved payment methods | Add/remove cards |
| Subscription plans | View active plan, upgrade/downgrade |
| Billing history | Past payment records |

---

### 6.8 Support & Help
**File:** `lib/screens/help_and_support.dart`

| Option | Details |
|--------|---------|
| Contact support | Open a support chat or form |
| FAQs | Frequently asked questions |
| Report issue | Bug/issue report form |

---

### 6.9 About & Legal ✅ DONE

| Item | Details | Status |
|------|---------|--------|
| Terms & Conditions | Link to terms | ✅ DONE |
| Privacy Policy | Link to privacy policy | ✅ DONE |
| App version | ~~Display current app version~~ | ⚫ **CANCELLED BY CLIENT** — App version display is not needed, removed |

> Note: These were previously removed from patient Settings (change #61–63 in section 3.10). Client confirmed they want Terms & Conditions and Privacy Policy under "About & Legal". App version display removed per client request.

---

### 6.10 Consultation Settings ⚫ CANCELLED BY CLIENT
> **Client requested NOT to add this section.**

| Setting | Details | Status |
|---------|---------|--------|
| Preferred language | Language for consultations | ⚫ CANCELLED |
| Preferred doctor type | Male / Female / No preference | ⚫ CANCELLED |
| Consultation history access | Toggle to allow doctor to view past consultations | ⚫ CANCELLED |
| Medical records upload | Upload documents for doctor reference | ⚫ CANCELLED |
| Video/audio preferences | Camera + mic default settings for video calls | ⚫ CANCELLED |

---

### 6.11 Pharmacy Settings

| Setting | Details | Status |
|---------|---------|--------|
| Saved delivery addresses | Add/edit delivery addresses | ✅ DONE |
| Preferred pharmacy | ~~Set a default pharmacy~~ | ⚫ **CANCELLED BY CLIENT** — Ordering from pharmacies has different logic; preferred pharmacy not applicable |
| Order history | View past medicine orders | ✅ DONE |
| Delivery preferences | ~~Home delivery or pickup~~ | ⚫ **CANCELLED BY CLIENT** — Same reason as preferred pharmacy |

---

### 6.12 Diagnostics Settings

| Setting | Details |
|---------|---------|
| Test history | View past lab test bookings |
| Home sample preferences | Default to home sample or walk-in |
| Report delivery method | Email, in-app, or both |

---

### 6.13 Learning Settings
**File:** `lib/screens/courses.dart`

| Setting | Details |
|---------|---------|
| Enrolled courses | List of courses the patient joined |
| Certificates | View/download earned certificates |
| Progress tracking | Course completion percentage |
| Notifications for new courses | ON/OFF toggle |

---

### 6.14 Family Profiles 🔴 PENDING
> This is a new feature — needs backend support for linked family accounts. MR Number per family member is not possible. Family contacts can be added in profile but full linked accounts feature is not yet built.

| Feature | Details | Status |
|---------|---------|--------|
| Add family member | Add children, parents, or dependents | 🔴 PENDING (needs backend) |
| Manage profiles | Edit or remove a family member's profile | 🔴 PENDING (needs backend) |
| Track their health | Each family member has their own tracker data | 🔴 PENDING (needs backend) |

---

### 6.15 Security

| Setting | Details |
|---------|---------|
| Change password | Current password + new password form |
| Two-Factor Authentication (2FA) | OTP via SMS or email |
| Login activity | List of recent login sessions/devices |

---

### 6.16 Language & Region

| Setting | Details |
|---------|---------|
| Language selection | Choose app language (for global users) |
| Country / Region | Set region for relevant content |

---

## 7. PRIORITY SUMMARY

### High Priority (Client Emphasized)
1. Doctor dashboard redesign — ~~remove revenue~~ (⚫ CANCELLED, revenue stays), add appointment requests with accept/decline ✅ DONE
2. Patient profile — add CNIC, remove role field ✅ DONE
3. ~~"Consult Now" → goes directly to payment screen~~ ⚫ **CHANGED BY CLIENT** — "Consult Now" now takes to fill details first before payment
4. Book a Lab Test — complete new multi-step flow ✅ DONE
5. Patient sidebar renames: Order Medicines, Book a Lab Test, My Appointments at top ✅ DONE
6. Booking History redesign — card layout, pending at top, completed history with notes ✅ DONE
7. Health Tracker redesign — dashboard with metric tiles, points system, progress charts ✅ DONE
8. Settings page full restructure — all new sections (Health Profile, Tracker Settings, etc.) ✅ DONE

### Medium Priority
9. Home page search bars (doctors, pharmacy, lab — each separate) ✅ DONE
10. New Courses section on home page ✅ DONE
11. "Connect to a Doctor" button pulsing animation ✅ DONE
12. Footer changes (white background, remove Analytics and For Doctors links) ✅ DONE
13. Reminders with Google Calendar sync 🔴 PENDING
14. Health Mode toggle in tracker (Diabetes / BP / General Wellness) ✅ DONE
15. Rewards redemption screen (Free Consultation, Lab Test Discount) 🔄 PARTIAL (points done, redemption pending)

### Lower Priority
16. WhatsApp floating button on home page ✅ DONE
17. Pharmacy and lab ratings on listing pages 🔴 PENDING
18. Health Community like and comment feature ✅ DONE
19. Notification settings cleanup ✅ DONE
20. Family Profiles feature (linked accounts) 🔴 PENDING (needs backend)
21. Language & Region settings ✅ DONE

---

## 8. DEVELOPER NOTES

| Task | Requirement |
|------|------------|
| PMDC Number on doctor card | Backend needs to add PMDC number to doctor profile schema |
| CNIC field for patients | Backend needs to add CNIC field to patient profile schema |
| Years of experience | Backend needs to expose this on doctor profile endpoint |
| Geo-tagging for labs | Device location permission required, calculate distance from user |
| Google Calendar sync | Requires Google OAuth integration |
| Payment flow | Payment gateway integration needed for "Consult Now" and medicine purchase |
| LMS / Courses section | Client said completing the courses/LMS module is the first priority |
| Doctor-assigned reminders | When doctor saves prescription, trigger reminder creation for patient |
| Doctor-prescribed lab tests | Prescribed tests should auto-populate in the patient's "Book a Lab Test" step 2 |
| Health Tracker — vitals data storage | Backend needs endpoints to save/retrieve BP, blood sugar, weight, SpO2, heart rate per patient per date |
| Health Tracker — points/rewards system | Backend needs points balance, earning history, and reward redemption endpoints |
| Health Tracker — streak tracking | Backend or local logic to count consecutive logging days |
| Health Mode setting | Backend or local preference to store patient's selected health mode (Diabetes / BP / Wellness) |
| Tracker toggle preferences | Save patient's ON/OFF toggle state for each metric (BP, sugar, water, etc.) |
| Family Profiles | Backend needs linked-account support — one user can manage multiple family member profiles |
| 2FA / Two-Factor Authentication | SMS OTP or email OTP integration needed |
| Login activity tracking | Backend needs to log sessions/devices per user |
| Billing history | Backend needs subscription and payment history endpoints |
| Health data export | Backend needs to generate a downloadable health data file per patient |
| Report delivery method (Diagnostics) | Backend needs to store and use patient's preferred delivery method for lab reports |

---

*Documentation prepared from client meeting notes — 13 April 2026*
*Updated with Health Tracker and Settings requirements — 14 April 2026*
