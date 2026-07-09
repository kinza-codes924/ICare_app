# iCare App — Client Meeting Changes

**Meeting Date:** 13 April 2026  
**Status:** Pending Implementation  
**Priority:** Urgent

## TABLE OF CONTENTS

1\. Home Page Changes

2\. Find Doctors / Doctor Listing Page

3\. Patient Module Changes

4\. Doctor Dashboard Changes

5\. Health Tracker Redesign

6\. Settings Page Redesign

7\. Priority Summary

8\. Developer Notes

## 1\. HOME PAGE CHANGES

**File:** lib/screens/home.dart and lib/screens/public_home.dart

### 1.1 Banner Section

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 1   | Update heading text | Change to: **"Talk to a verified Specialist Doctor"** _(superseded by April 21: "Consult a Doctor" — now live)_ | <span style="color:green">**[DONE]**</span> Done |
| 2   | Remove video consultation fee | Remove any fee/price text from the banner area | <span style="color:green">**[DONE]**</span> Done |
| 3   | Add search bar in banner | Below the "Connect to a Doctor" button — single search bar that searches doctors, specialities, and conditions | <span style="color:red">**[PENDING]**</span> Pending |
| 4   | "Connect to a Doctor" button — pulsing animation | Add a glowing/pulsing border animation to this button (black border, flash effect) | <span style="color:green">**[DONE]**</span> Done |
| 5   | Two buttons in header | Header should have: **"Connect to a Doctor Now"** + **"Book Appointment"** | <span style="color:green">**[DONE]**</span> Done |

### 1.2 Browse By Speciality Section

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 7   | Rename button | "View More" → **"See All Speciality"** | <span style="color:red">**[PENDING]**</span> Pending |
| 8   | Center-align that button | The "See All Speciality" button should be centered on the page | <span style="color:red">**[PENDING]**</span> Pending |
| 9   | Move speciality section up | Speciality browser should appear before Pharmacy and Labs sections | <span style="color:green">**[DONE]**</span> Done |
| 10  | Make speciality cards clickable | Each speciality card should navigate to the doctors list filtered by that speciality | <span style="color:green">**[DONE]**</span> Done |
| 11  | Add "Search by Condition" field | Inside the speciality section, add a search field where the user can type a condition (e.g., "diabetes") - completed | <span style="color:green">**[DONE]**</span> Done |

### 1.3 Doctors Search Bar — 3 Options

The search bar for doctors should have three search modes:

1\. <span style="color:green">**[DONE]**</span> Search by Doctor Name

2\. <span style="color:green">**[DONE]**</span> Search by Speciality

3\. <span style="color:green">**[DONE]**</span> Search by Condition

Additional buttons near the search bar:

- <span style="color:red">**[PENDING]**</span> **"Search All Doctors"** — goes to the full doctors listing page Not needed now as client asked for new changes

(lib/screens/doctors_list.dart)

- <span style="color:red">**[PENDING]**</span> **"Connect Now"** — goes to the available/online doctors page

### 1.4 Courses Section (New Section)

**Position:** <span style="color:green">**[DONE]**</span> Above the "How iCare Works" section

**Heading:** <span style="color:green">**[DONE]**</span> "Join Pakistan's First 360° Health Care Platform"  
**Sub-heading:** <span style="color:green">**[DONE]**</span> "Open for Everyone"  
**Bottom text:** <span style="color:green">**[DONE]**</span> "Live Skill Academy for Everyone"

Layout: <span style="color:green">**[DONE]**</span> 2x2 grid of tiles (They were further changed by client and now the correct content is live on home page as per client's requirement)

| **Tile** | **Audience** | **Content** | **Status** |
| --- | --- | --- | --- |
| 1   | Patients | Diet Plan & Health Related Courses | <span style="color:green">**[DONE]**</span> Done |
| 2   | Patients | Health Programs | <span style="color:green">**[DONE]**</span> Done |
| 3   | Doctors | General Courses | <span style="color:green">**[DONE]**</span> Done |
| 4   | Doctors | Training Programs for Healthcare | <span style="color:green">**[DONE]**</span> Done |

<span style="color:green">**[DONE]**</span> These tiles should link to the courses/programs sections of the app (lib/screens/courses.dart).

### 1.5 Pharmacy Section

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 12  | Section heading | Change to: **"Order Medicines"** | <span style="color:green">**[DONE]**</span> Done |
| 13  | Add medicine search bar | A search bar to search medicines by name | <span style="color:green">**[DONE]**</span> Done |
| 14  | Show pharmacy ratings | Display star ratings on pharmacy cards | <span style="color:green">**[DONE]**</span> Done |

### 1.6 Laboratory Section

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 15  | Section heading | Change to: **"Book a Lab Test"** | <span style="color:green">**[DONE]**</span> Done |
| 16  | Add "Book Lab Test" button | Visible button to go to the lab booking flow | <span style="color:green">**[DONE]**</span> Done |
| 17  | Add lab test search bar | A search bar to search lab tests by name | <span style="color:green">**[DONE]**</span> Done |
| 18  | Show lab ratings | Display star ratings on laboratory cards | <span style="color:green">**[DONE]**</span> Done |

Each section (Doctors, Pharmacy, Labs) has its own separate search bar. <span style="color:green">**[DONE]**</span> Done

### 1.7 Footer Changes

**File:** Footer widget (likely inside lib/screens/home.dart or a shared footer widget)

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 19  | Remove "Analytics" link | Delete it from footer links | <span style="color:green">**[DONE]**</span> Done |
| 20  | Remove "For Doctors" link | Delete it from footer links | <span style="color:green">**[DONE]**</span> Done |
| 21  | Theme change | Footer background: white. Text and accent: blue and grey theme | <span style="color:red">**[PENDING]**</span> Pending |

### 1.8 WhatsApp Floating Button

<span style="color:green">**[DONE]**</span> Add a WhatsApp floating action button on the home page.

- <span style="color:green">**[DONE]**</span> Position: Bottom-right corner
- <span style="color:green">**[DONE]**</span> Standard WhatsApp green icon, links to the business WhatsApp number
- <span style="color:green">**[DONE]**</span> Should be visible without scrolling

## 2\. FIND DOCTORS / DOCTOR LISTING PAGE

**File:** lib/screens/doctors_list.dart, lib/screens/doctor_detail.dart

### 2.1 Search and Filter Changes

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 22  | Add speciality search bar | Users can filter the doctor list by speciality | <span style="color:red">**[PENDING]**</span> Pending |
| 23  | Add "General Practitioner" as default | It should appear as the first option in the speciality filter | <span style="color:red">**[PENDING]**</span> Pending |
| 24  | Add "Search by Condition" | Users can type a condition and see matching doctors | <span style="color:red">**[PENDING]**</span> Pending |
| 25  | Show online doctors count | Display a line like: **"X doctors online right now"** at the top of the list | <span style="color:red">**[PENDING]**</span> Pending |
| 26  | Remove the 3 filter tabs | Remove "All", "General", and any similar tab filters from the top of the page | <span style="color:red">**[PENDING]**</span> Pending |

### 2.2 Doctor Card — Information to Show

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 27  | Show profile picture | Doctor's photo must appear on their card | <span style="color:red">**[PENDING]**</span> Pending |
| 28  | Show PMDC Number | Display PMDC registration number on the doctor card (Confirm again with client if this needs to be visible on home page) | <span style="color:red">**[PENDING]**</span> Pending |
| 29  | Show years of experience | Display experience (e.g., "8 years experience") on the card | <span style="color:red">**[PENDING]**</span> Pending |
| 30  | Remove contact info from booking | When opening book appointment, do not show the doctor's phone or contact details | <span style="color:red">**[PENDING]**</span> Pending |

Note: PMDC number and years of experience fields need backend support — coordinate with backend team.

### 2.3 Consult Now / Book Appointment Flow

**File:** lib/screens/book_appointment.dart, lib/screens/confirm_booking.dart, lib/screens/confirm_details.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 31  | "Consult Now" click → Payment screen | After clicking "Consult Now", show doctor's basic info then go directly to payment screen | <span style="color:green">**[DONE]**</span> Done (changed to fill details first, per client) |
| 32  | After booking confirmation → Payment screen | After confirming a booking, payment screen should appear | <span style="color:red">**[PENDING]**</span> Pending |
| 33  | Remove messaging and voice call options | Do not show messaging or voice call options on the booking details screen | <span style="color:red">**[PENDING]**</span> Pending |
| 34  | Remove all contact info | No phone number, email, or any contact info should appear in booking flow | <span style="color:red">**[PENDING]**</span> Pending |

### 2.4 Pharmacy and Lab Ratings on Listing Pages

- <span style="color:red">**[PENDING]**</span> Show star ratings on pharmacy cards (lib/screens/pharmacies.dart)
- <span style="color:red">**[PENDING]**</span> Show star ratings on laboratory cards (lib/screens/laboratories.dart)

## 3\. PATIENT MODULE CHANGES

### 3.1 Patient Profile

**File:** lib/screens/patient_profile.dart, lib/screens/profile_edit.dart, lib/screens/profile.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 35  | Remove "Role" field | Do not display the role field on the patient profile | <span style="color:red">**[PENDING]**</span> Pending |
| 36  | Add CNIC Number field | New required field: CNIC number | <span style="color:red">**[PENDING]**</span> Pending |
| 37  | Profile fields to show | Age, Height, Weight, CNIC Number, Address | <span style="color:red">**[PENDING]**</span> Pending |
| 38  | Profile icon click → dropdown | Clicking the profile icon should show a dropdown with two options: **Edit Profile** and **Logout** | <span style="color:red">**[PENDING]**</span> Pending |

Note: CNIC field needs a backend schema update.

### 3.2 Patient Sidebar Changes

**File:** lib/navigators/drawer.dart (Patient section)

| **#** | **Action** | **Details** | **Status** |
| --- | --- | --- | --- |
| 39  | Remove "My Profile" from sidebar | Profile access moves to the top-right profile icon | <span style="color:green">**[DONE]**</span> Done |
| 40  | Remove "Messages" from sidebar | Messaging will be accessible from elsewhere | <span style="color:green">**[DONE]**</span> Done |
| 41  | Remove "My Care Plans" | Keep only "Health Programs" — remove the Care Plans link | <span style="color:green">**[DONE]**</span> Done |
| 42  | Rename "Pharmacies" | Change to **"Order Medicines"** | <span style="color:green">**[DONE]**</span> Done |
| 43  | Rename "Laboratories" | Change to **"Book a Lab Test"** | <span style="color:green">**[DONE]**</span> Done |
| 44  | Rename "My Appointment" + move to top | Change to **"My Appointments"** and make it the first item in the sidebar | <span style="color:green">**[DONE]**</span> Done |

### 3.3 My Appointments / Booking History

**File:** lib/screens/bookings_history.dart, lib/screens/bookings.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 45  | Rename section | "Progressive Booking" → **"Booking History"** | <span style="color:green">**[DONE]**</span> Done |
| 46  | Add "Book Appointment Now" button | A large button at the top of this screen | <span style="color:red">**[PENDING]**</span> Pending |
| 47  | Pending bookings at top | Show pending/upcoming bookings before past ones | <span style="color:red">**[PENDING]**</span> Pending |
| 48  | Cancel button at bottom | The cancel action/button should be at the bottom of the booking card | <span style="color:red">**[PENDING]**</span> Pending |
| 49  | Card layout | Each booking should display all info in one clean card/box (not split across sections) | <span style="color:red">**[PENDING]**</span> Pending |
| 50  | Completed appointment history | Show prescription and doctor notes for completed appointments | <span style="color:red">**[PENDING]**</span> Pending |

### 3.4 Book a Lab Test (New Flow)

**File:** lib/screens/book_lab.dart, lib/screens/laboratories.dart, lib/screens/lab_list.dart

This is a new multi-step booking flow when the patient clicks "Book a Lab Test" from the sidebar.

<span style="color:red">**[PENDING]**</span> **Step 1 — Sample Type (required, shown as two equal columns):**

- Home Sample
- Sample at Lab

<span style="color:red">**[PENDING]**</span> **Step 2 — Search and Select Tests:**

- Search bar to search lab test by name
- List of tests with checkboxes to select multiple
- If a doctor has prescribed tests, they should appear here automatically

<span style="color:red">**[PENDING]**</span> **Step 3 — Nearby Lab Selection (geo-tagged):**

- Show labs within:
    - 5 km radius
    - 10 km radius
    - 15 km radius
- When a test is selected, the nearest labs that offer that test should appear

**Lab Reports Section — 3 categories:**

| **Category** | **Meaning** | **Status** |
| --- | --- | --- |
| Completed | Report is ready and available | <span style="color:red">**[PENDING]**</span> Pending |
| Pending | Test is booked, result not yet available | <span style="color:red">**[PENDING]**</span> Pending |
| Advised | Doctor recommended this test, not yet booked - Completed | <span style="color:green">**[DONE]**</span> Done |

Note: Geo-tagging requires location permission from the user's device.

### 3.5 Order Medicines (Pharmacy)

**File:** lib/screens/pharmacies.dart, lib/screens/pharmacy_home.dart

- <span style="color:green">**[DONE]**</span> Search bar to find medicines by name
- <span style="color:green">**[DONE]**</span> Show a list of available medicines with ecommerce functionality
- <span style="color:green">**[DONE]**</span> Clicking a medicine goes to the medicine details as popup - Completed
- <span style="color:green">**[DONE]**</span> Add quantity option on medicines - Completed

### 3.6 Reminders

**File:** lib/screens/create_reminder.dart, lib/screens/notifications.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 51  | Two types of reminders | 1\. Doctor-assigned reminders (added automatically when doctor prescribes) 2. Self-created reminders (patient adds manually). Also make notification section. | <span style="color:red">**[PENDING]**</span> Pending |
| 52  | Create Reminder form fields | Date, Time, Label — keep it simple | <span style="color:red">**[PENDING]**</span> Pending |
| 53  | Google Calendar sync | Option to sync reminders with Google Calendar (Consult with client as reminders should be in-app only) | <span style="color:red">**[PENDING]**</span> Pending |
| 54  | Replace "Select time and day" | Remove that UI element — replace with a simple **"Add Reminder"** button | <span style="color:red">**[PENDING]**</span> Pending |

Note: Google Calendar sync requires OAuth integration.

### 3.7 My Health Journey (Not needed as client changed it to show health tracker details linked to patient's issues in this section)

**File:** lib/screens/health_journey_screen.dart, lib/screens/health_journey_timeline.dart

- <span style="color:red">**[PENDING]**</span> Add a **"Coming Soon"** banner on this screen
- <span style="color:red">**[PENDING]**</span> When a doctor adds a prescription or suggestion, it should automatically appear here
- <span style="color:red">**[PENDING]**</span> Entries should be shown in chronological order (oldest to newest or as a timeline)

### 3.8 My Appointments — Booking Detail View

**File:** lib/screens/bookings.dart, lib/screens/confirm_details.dart, lib/screens/profile_or_appointement_view.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 55  | Rename "View Full Profile" | Change to **"View Full Details"** or **"Appointment Details"** | <span style="color:red">**[PENDING]**</span> Pending |
| 56  | Confirmed status in green | When status is "Confirmed", show it in green color | <span style="color:red">**[PENDING]**</span> Pending |
| 57  | Remove messaging, voice call, contact info | Do not show these options in the appointment detail screen | <span style="color:red">**[PENDING]**</span> Pending |
| 58  | Back button goes to Home | From any appointment detail screen, pressing Back should go to Appointment Page — not back to Home Page | <span style="color:red">**[PENDING]**</span> Pending |

### 3.9 Health Community

**File:** lib/screens/health_community.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 59  | Add Like and Comment | Posts must have a Like button and a Comment option | <span style="color:red">**[PENDING]**</span> Pending |
| 60  | Show iCare logo | The iCare app logo should appear on the Health Community page - completed | <span style="color:green">**[DONE]**</span> Done |

### 3.10 Patient Settings — Items to Remove

**File:** lib/screens/settings.dart

Remove the following items from patient Settings:

- <span style="color:red">**[PENDING]**</span> Privacy Policy (also lib/screens/privacy_policy.dart)
- <span style="color:red">**[PENDING]**</span> About Us (lib/screens/about_us.dart)
- <span style="color:red">**[PENDING]**</span> Terms and Conditions

### 3.11 Notification Preferences (This section was part of setting page but now it is changed upon clients request so this is not needed is settings and a new notification tab has been made right beside profile name and picture)

**File:** lib/screens/notification_settings.dart

| **#** | **Change** | **Details** | **Status** |
| --- | --- | --- | --- |
| 64  | Remove "Patient Messages" | Delete this notification option | <span style="color:green">**[DONE]**</span> Done (section replaced by new notification tab) |
| 65  | Rename "Admin Announcement" | Change to **"Promotions"** | <span style="color:green">**[DONE]**</span> Done (section replaced by new notification tab) |
| 66  | Add sound toggle | Option to enable/disable notification sound | <span style="color:green">**[DONE]**</span> Done (section replaced by new notification tab) |
| 67  | Rename section heading | Change to **"Notification Settings"** | <span style="color:green">**[DONE]**</span> Done (section replaced by new notification tab) |
| 68  | Add email prescription toggle | Add a toggle: "Send prescription to email automatically" | <span style="color:red">**[PENDING]**</span> Pending |

### 3.12 Patient View Profile — SOAP Notes (SOAP note were changed to Doctor's notes within consultation and are now part of prescription as doctor's note) - Completed

**File:** lib/screens/patient_profile_view.dart, lib/screens/patient_history_view.dart

- <span style="color:green">**[DONE]**</span> SOAP Notes must NOT be visible when a patient views their own profile.
- <span style="color:green">**[DONE]**</span> SOAP Notes are doctor-facing only and should stay hidden from patients.

### 3.13 Emergency Numbers

**File:** Patient profile section — lib/screens/patient_profile.dart or lib/navigators/drawer.dart

- <span style="color:green">**[DONE]**</span> Add two emergency contact fields to the patient profile or sidebar:
    - Emergency Number 1
    - Emergency Number 2

Note: lib/screens/emergency_contacts.dart may already exist — check if it can be extended.

## 4\. DOCTOR DASHBOARD CHANGES

**File:** lib/screens/doctor_dashboard.dart

### 4.1 Dashboard Layout — New Order

The dashboard should display content in this order, top to bottom:

- <span style="color:red">**[PENDING]**</span> 1\. Welcome message: "Welcome back, Dr. \[Name\]" with rating and satisfaction score

- <span style="color:red">**[PENDING]**</span> 2\. Appointment Requests (pending, with Accept/Decline buttons)

- <span style="color:red">**[PENDING]**</span> 3\. Today's Appointments

- <span style="color:red">**[PENDING]**</span> 4\. Number of consultations

- <span style="color:green">**[DONE]**</span> 5\. Take off revenue section from home page - completed

### 4.2 Remove from Doctor Dashboard

| **#** | **Remove** | **Status** |
| --- | --- | --- |
| 69  | "Secure Health" card/widget | <span style="color:green">**[DONE]**</span> Done |
| 70  | Revenue amount display (It was discussed with client and revenue will remain in app for doctor, Lab and Pharmacy) | <span style="color:green">**[DONE]**</span> Done (revenue kept as per client) |
| 71  | "View All" button on the Today's Appointments heading - completed | <span style="color:green">**[DONE]**</span> Done |

### 4.3 Appointment Requests Widget

- <span style="color:green">**[DONE]**</span> Replace the "Pending Appointments" section with **"Appointment Requests"** — completed
- <span style="color:red">**[PENDING]**</span> Show 5 requests at a time with a "View All" link
- <span style="color:red">**[PENDING]**</span> Each request card must have:
    - Accept button (green checkmark)
    - Decline button (red X)
- <span style="color:green">**[DONE]**</span> Replace the Revenue card with: **Pending Appointments count** (just a number) - **completed**

### 4.4 Today's Appointments Display

- <span style="color:red">**[PENDING]**</span> Show appointments as square cards arranged by time
- <span style="color:red">**[PENDING]**</span> Show "Total Patients Today" count + list
- <span style="color:red">**[PENDING]**</span> "View All" link for the full list
- <span style="color:red">**[PENDING]**</span> Quick Actions section should show appointments grouped by day (This option has been taken off on client's request)

### 4.5 Doctor Stats — What to Show vs Remove (Shifted to Revenue and Analytics)

| **Show** | **Remove** |
| --- | --- |
| Rating + Satisfaction score | Revenue amount |
| Number of consultations | "Secure Health" section |
| Pending appointments count | —   |

### 4.6 Doctor Sidebar — Logout Location

**File:** lib/navigators/drawer.dart (Doctor section)

| **#** | **Change** | **Status** |
| --- | --- | --- |
| 72  | Move "Logout" inside Edit Profile | <span style="color:red">**[PENDING]**</span> Pending |
| 73  | Edit Profile → dropdown | <span style="color:red">**[PENDING]**</span> Pending |

## 5\. HEALTH TRACKER REDESIGN

**Files:** lib/screens/health_tracker.dart, lib/screens/lifestyle_tracker.dart, lib/screens/lifestyle_tracker_screen.dart, lib/screens/gamification_screen.dart

The health tracker needs a full redesign based on the UI reference image shared by the client. The new design includes a personalized dashboard, multiple tracking categories, a points/rewards system, and progress charts.

### 5.1 Main Dashboard Screen (Health Tracker)

When the patient opens the Health Tracker, they should see: (Check again, log history function is not added)

- <span style="color:red">**[PENDING]**</span> **Greeting at top:** "Hello, \[Patient Name\] — Your Health Today"
- <span style="color:red">**[PENDING]**</span> **Daily Goal progress bar:** Shows percentage complete (e.g., "Daily Goal: 60% Complete") with a checkmark when done
- <span style="color:red">**[PENDING]**</span> **Points earned today:** A gold star icon with "You earned X points today"
- <span style="color:red">**[PENDING]**</span> **Metric tiles (grid layout):** Quick-view tiles for each tracked item, for example:
    - BP: 120/80 mmHg
    - Blood Sugar: 110 mg/dL
    - Weight: 70.4 kg
    - Water: 5 glasses
    - Medication (taken/missed)
    - Steps: 2,500
- <span style="color:red">**[PENDING]**</span> **"+ Log More" button** at the bottom to add a new entry (Not needed as every value is clickable and user can add their own value through clicking any option)

### 5.2 Tracking Categories

The tracker must support all of the following. Each category can be turned ON or OFF per patient (see Settings section 6.3).

#### Vitals

- <span style="color:red">**[PENDING]**</span> Blood Pressure (BP) — Systolic + Diastolic in mmHg
- <span style="color:red">**[PENDING]**</span> Blood Sugar / Glucose — mg/dL, with option to mark fasting or post-meal
- <span style="color:red">**[PENDING]**</span> Weight — kg
- <span style="color:red">**[PENDING]**</span> Heart Rate — bpm
- <span style="color:red">**[PENDING]**</span> Oxygen Saturation (SpO2) — percentage

#### Lifestyle

- <span style="color:red">**[PENDING]**</span> Water intake — glasses per day with a circular progress indicator (e.g., 5/8 glasses)
- <span style="color:red">**[PENDING]**</span> Steps / Physical activity — daily step count
- <span style="color:red">**[PENDING]**</span> Sleep — hours per night
- <span style="color:red">**[PENDING]**</span> Diet / Meals — meal log

#### Medication & Compliance

- <span style="color:red">**[PENDING]**</span> Medication taken: Yes/No toggle per medication
- <span style="color:red">**[PENDING]**</span> Medication reminders (tied to reminder system)
- <span style="color:red">**[PENDING]**</span> Missed dose tracking — flag when a dose is skipped
- <span style="color:red">**[PENDING]**</span> Prescription tracking — link to current prescriptions from doctor

#### Condition-Specific Tracking

The tracker adapts based on the patient's selected "Health Mode" (see section 5.5):

| **Condition** | **What to Track** |
| --- | --- |
| Diabetes | Blood sugar (fasting + post-meal), diet |
| Hypertension | Blood pressure, salt intake |
| General Wellness | Weight, activity, sleep |

#### Mental & Other Health

- <span style="color:red">**[PENDING]**</span> Mood tracking — emoji selector (happy / neutral / sad or similar scale)
- <span style="color:red">**[PENDING]**</span> Stress level — numeric or emoji scale
- <span style="color:red">**[PENDING]**</span> Menstrual cycle tracking (for women)
- <span style="color:red">**[PENDING]**</span> Hydration reminders
- <span style="color:red">**[PENDING]**</span> Calories / macronutrients

### 5.3 Logging a Metric

<span style="color:red">**[PENDING]**</span> When a patient taps on a metric tile (e.g., "Log Blood Pressure"):

- Show input fields for that specific metric (e.g., Systolic + Diastolic for BP)
- Show a numeric keypad on screen
- Show a **"Save Entry"** button
- After saving: show **"+X points earned"** message (gamification reward)

### 5.4 Progress Charts

<span style="color:red">**[PENDING]**</span> A "Your Progress" screen accessible from the main tracker, with:

- **Tabs:** Daily / Weekly / Monthly
- **Line charts** for each tracked metric (e.g., BP over the last 7 days, Blood Sugar trend)
- **Achievement badges** below the charts:
    - "Logged X days in a row"
    - "Avg BP improving"
    - etc.
- **"View Detailed Report"** link at the bottom

### 5.5 "Health Mode" Toggle (New Feature) (Controlled through profile settings of patient)- completed

<span style="color:green">**[DONE]**</span> On the tracker home or in settings, the patient selects their health mode. This changes which metrics are shown by default on the dashboard.

| **Mode** | **Default Metrics Shown** |
| --- | --- |
| Diabetes Mode | Blood sugar (fasting/post-meal), diet, medication |
| BP Mode | Blood pressure, salt intake, medication |
| General Wellness Mode | Weight, steps, sleep, water |

- <span style="color:green">**[DONE]**</span> Only one mode active at a time
- <span style="color:green">**[DONE]**</span> Patient can switch modes anytime
- <span style="color:red">**[PENDING]**</span> Custom mode can also be allowed (manual toggle of each metric)

### 5.6 Rewards / Points System (Gamification will be completed once all application is complete and finalized by client)

**File:** lib/screens/gamification_screen.dart

<span style="color:red">**[PENDING]**</span> The tracker includes a points system to encourage daily logging.

**Earning points:**

- <span style="color:red">**[PENDING]**</span> Log a metric → earn points (e.g., +5 per entry)
- <span style="color:red">**[PENDING]**</span> Reach daily goal → bonus points
- <span style="color:red">**[PENDING]**</span> Log multiple days in a row → streak bonus

**Your Rewards screen:**

- <span style="color:red">**[PENDING]**</span> Show total points balance at the top (e.g., "Total Points: 240")
- <span style="color:red">**[PENDING]**</span> Activity feed: list of recent point-earning actions with time (e.g., "BP logged today 8:45am — +5 points")
- <span style="color:red">**[PENDING]**</span> **"Redeem Points"** button

**Redeem Rewards screen:**

- <span style="color:red">**[PENDING]**</span> List of reward options with their point cost, for example:
    - Free Consultation — 100 points
    - Lab Test Discount — 150 points
- <span style="color:red">**[PENDING]**</span> Charts showing redemption history
- <span style="color:red">**[PENDING]**</span> "More rewards coming" placeholder for future rewards

### 5.7 Consultation Summary Integration

<span style="color:red">**[PENDING]**</span> When the patient starts a consultation from the tracker:

- Show a **Consultation Summary** card before connecting to the doctor
- Summary includes recent tracker data: Medication status, Water intake, Steps (last 7 days)
- Doctor's notes from last visit (if any)
- **"Start Consultation"** button at the bottom

## 6\. SETTINGS PAGE REDESIGN

**File:** lib/screens/settings.dart

The current settings page is minimal. The client wants a fully restructured settings page with multiple organized sections. Each section listed below should be a collapsible group or a separate sub-screen.

### 6.1 Profile & Account

| **Field** | **Details** | **Status** |
| --- | --- | --- |
| Name | Editable | <span style="color:red">**[PENDING]**</span> Pending |
| Age / Gender | Editable | <span style="color:red">**[PENDING]**</span> Pending |
| Phone / Email | Editable | <span style="color:red">**[PENDING]**</span> Pending |
| Profile photo | Upload/change photo | <span style="color:red">**[PENDING]**</span> Pending |
| Emergency contact | Emergency phone number | <span style="color:green">**[DONE]**</span> Done |
| Blood group | Dropdown selection | <span style="color:red">**[PENDING]**</span> Pending |
| Existing conditions | Multi-select: Diabetes, BP, etc. | <span style="color:red">**[PENDING]**</span> Pending |

### 6.2 Health Profile

<span style="color:red">**[PENDING]**</span> This section links the patient's medical background to their tracker and doctor.

| **Field** | **Details** |
| --- | --- |
| Medical conditions | Diabetes, Hypertension, etc. (multi-select) |
| Allergies | Free text or tag input |
| Current medications | List of current medicines |
| Health goals | Weight loss, BP control, etc. (multi-select) |

### 6.3 Tracker Settings (Sequence break, please add option as per sequence)

**Personalization — Toggle what to track:**

- <span style="color:red">**[PENDING]**</span> BP — ON/OFF toggle
- <span style="color:red">**[PENDING]**</span> Blood Sugar — ON/OFF toggle
- <span style="color:red">**[PENDING]**</span> Weight — ON/OFF toggle
- <span style="color:red">**[PENDING]**</span> Water intake — ON/OFF toggle
- <span style="color:red">**[PENDING]**</span> Medication — ON/OFF toggle

**Set daily goals:**

- <span style="color:red">**[PENDING]**</span> Water goal (e.g., 8 glasses per day)
- <span style="color:red">**[PENDING]**</span> Steps goal (e.g., 10,000 steps)

### 6.4 Reminders & Notifications

| **Option** | **Details** | **Status** |
| --- | --- | --- |
| Medication reminders | Set time(s) for each medication | <span style="color:red">**[PENDING]**</span> Pending |
| Water reminders | Periodic reminders throughout day | <span style="color:red">**[PENDING]**</span> Pending |
| Health check reminders | Reminder to log vitals | <span style="color:red">**[PENDING]**</span> Pending |
| Appointment reminders | Alert before upcoming appointment | <span style="color:red">**[PENDING]**</span> Pending |

### 6.5 Rewards & Points

| **Item** | **Details** | **Status** |
| --- | --- | --- |
| Points balance | Current total shown | <span style="color:red">**[PENDING]**</span> Pending |
| Rewards history | List of how points were earned | <span style="color:red">**[PENDING]**</span> Pending |
| Redemption history | List of rewards redeemed | <span style="color:red">**[PENDING]**</span> Pending |

### 6.6 Privacy & Data

| **Option** | **Details** | **Status** |
| --- | --- | --- |
| Download health data | Export all personal health data | <span style="color:red">**[PENDING]**</span> Pending |
| Delete account | Permanent account deletion with confirmation | <span style="color:red">**[PENDING]**</span> Pending |

### 6.7 Payments & Subscriptions

| **Item** | **Details** | **Status** |
| --- | --- | --- |
| Saved payment methods | Add/remove cards | <span style="color:red">**[PENDING]**</span> Pending |
| Subscription plans | View active plan, upgrade/downgrade | <span style="color:red">**[PENDING]**</span> Pending |
| Billing history | Past payment records | <span style="color:red">**[PENDING]**</span> Pending |

### 6.8 Support & Help

**File:** lib/screens/help_and_support.dart

| **Option** | **Details** | **Status** |
| --- | --- | --- |
| Contact support | Open a support chat or form | <span style="color:green">**[DONE]**</span> Done |
| FAQs | Frequently asked questions | <span style="color:green">**[DONE]**</span> Done |
| Report issue | Bug/issue report form | <span style="color:red">**[PENDING]**</span> Pending |

### 6.9 About & Legal

| **Item** | **Details** | **Status** |
| --- | --- | --- |
| Terms & Conditions | Link to terms | <span style="color:red">**[PENDING]**</span> Pending |
| Privacy Policy | Link to privacy policy | <span style="color:red">**[PENDING]**</span> Pending |
| App version | Display current app version (Take off app version. It is not needed) - completed | <span style="color:green">**[DONE]**</span> Done |

Note: These were previously removed from patient Settings (change #61–63 in section 3.10). Confirm with client whether they want these back here or removed entirely. Based on this new list, they want them under "About & Legal" — keep them.

### 6.10 Consultation Settings (Client requested to not add it)

| **Setting** | **Details** |
| --- | --- |
| Preferred language | Language for consultations |
| Preferred doctor type | Male / Female / No preference |
| Consultation history access | Toggle to allow doctor to view past consultations |
| Medical records upload | Upload documents for doctor reference |
| Video/audio preferences | Camera + mic default settings for video calls |

### 6.11 Pharmacy Settings

| **Setting** | **Details** | **Status** |
| --- | --- | --- |
| Saved delivery addresses | Add/edit delivery addresses | <span style="color:red">**[PENDING]**</span> Pending |
| Preferred pharmacy | Set a default pharmacy (Not needed as ordering from pharmacies has a different logic and preferred pharmacy cannot be done with it) - Completed | <span style="color:green">**[DONE]**</span> Done |
| Order history | View past medicine orders | <span style="color:red">**[PENDING]**</span> Pending |
| Delivery preferences | Home delivery or pickup (Same issue as preferred pharmacy)- Completed | <span style="color:green">**[DONE]**</span> Done |

### 6.12 Diagnostics Settings

| **Setting** | **Details** | **Status** |
| --- | --- | --- |
| Test history | View past lab test bookings | <span style="color:red">**[PENDING]**</span> Pending |
| Home sample preferences | Default to home sample or walk-in | <span style="color:red">**[PENDING]**</span> Pending |
| Report delivery method | Email, in-app, or both | <span style="color:red">**[PENDING]**</span> Pending |

### 6.13 Learning Settings

**File:** lib/screens/courses.dart

| **Setting** | **Details** | **Status** |
| --- | --- | --- |
| Enrolled courses | List of courses the patient joined | <span style="color:green">**[DONE]**</span> Done |
| Certificates | View/download earned certificates | <span style="color:green">**[DONE]**</span> Done |
| Progress tracking | Course completion percentage | <span style="color:red">**[PENDING]**</span> Pending |
| Notifications for new courses | ON/OFF toggle | <span style="color:red">**[PENDING]**</span> Pending |

### 6.14 Family Profiles (We have previously discussed with client that we will not do it, alternatively we have added emergency contacts in profile. We can add fields for Family as well in profile but new/additional Patient's MR Number or serial number is not possible) - Not Required

| **Feature** | **Details** |
| --- | --- |
| Add family member | Add children, parents, or dependents |
| Manage profiles | Edit or remove a family member's profile |
| Track their health | Each family member has their own tracker data |

This is a new feature — needs backend support for linked family accounts.

### 6.15 Security

| **Setting** | **Details** | **Status** |
| --- | --- | --- |
| Change password | Current password + new password form | <span style="color:red">**[PENDING]**</span> Pending |
| Two-Factor Authentication (2FA) | OTP via SMS or email | <span style="color:red">**[PENDING]**</span> Pending |
| Login activity | List of recent login sessions/devices | <span style="color:red">**[PENDING]**</span> Pending |

### 6.16 Language & Region

| **Setting** | **Details** | **Status** |
| --- | --- | --- |
| Language selection | Choose app language (for global users) | <span style="color:red">**[PENDING]**</span> Pending |
| Country / Region | Set region for relevant content | <span style="color:red">**[PENDING]**</span> Pending |

## 7\. PRIORITY SUMMARY

### High Priority (Client Emphasized)

1\. <span style="color:red">**[PENDING]**</span> Doctor dashboard redesign — remove revenue (this option will not be taken-off as per client's request), add appointment requests with accept/decline

2\. <span style="color:red">**[PENDING]**</span> Patient profile — add CNIC, remove role field

3\. <span style="color:green">**[DONE]**</span> "Consult Now" → goes directly to payment screen (Option changed as per client, this will now take to fill details first) – completed

4\. <span style="color:red">**[PENDING]**</span> Book a Lab Test — complete new multi-step flow

5\. <span style="color:green">**[DONE]**</span> Patient sidebar renames: Order Medicines, Book a Lab Test, My Appointments at top

6\. <span style="color:red">**[PENDING]**</span> Booking History redesign — card layout, pending at top, completed history with notes

7\. <span style="color:red">**[PENDING]**</span> Health Tracker redesign — dashboard with metric tiles, points system, progress charts

8\. <span style="color:red">**[PENDING]**</span> Settings page full restructure — all new sections (Health Profile, Tracker Settings, Family Profiles, etc.)

### Medium Priority

9\. <span style="color:green">**[DONE]**</span> Home page search bars (doctors, pharmacy, lab — each separate)

10\. <span style="color:green">**[DONE]**</span> New Courses section on home page

11\. <span style="color:green">**[DONE]**</span> "Connect to a Doctor" button pulsing animation

12\. <span style="color:red">**[PENDING]**</span> Footer changes (white background, remove Analytics and For Doctors links)

13\. <span style="color:red">**[PENDING]**</span> Reminders with Google Calendar sync

14\. <span style="color:green">**[DONE]**</span> Health Mode toggle in tracker (Diabetes / BP / General Wellness)

15\. <span style="color:red">**[PENDING]**</span> Rewards redemption screen (Free Consultation, Lab Test Discount)

### Lower Priority

16\. <span style="color:green">**[DONE]**</span> WhatsApp floating button on home page

17\. <span style="color:red">**[PENDING]**</span> Pharmacy and lab ratings on listing pages

18\. <span style="color:red">**[PENDING]**</span> Health Community like and comment feature

19\. <span style="color:red">**[PENDING]**</span> Notification settings cleanup

20\. <span style="color:red">**[PENDING]**</span> Family Profiles feature (linked accounts)

21\. <span style="color:red">**[PENDING]**</span> Language & Region settings

## 8\. DEVELOPER NOTES

| **Task** | **Requirement** | **Status** |
| --- | --- | --- |
| PMDC Number on doctor card | Backend needs to add PMDC number to doctor profile schema | <span style="color:red">**[PENDING]**</span> Pending |
| CNIC field for patients | Backend needs to add CNIC field to patient profile schema | <span style="color:red">**[PENDING]**</span> Pending |
| Years of experience | Backend needs to expose this on doctor profile endpoint | <span style="color:red">**[PENDING]**</span> Pending |
| Geo-tagging for labs | Device location permission required, calculate distance from user | <span style="color:red">**[PENDING]**</span> Pending |
| Google Calendar sync | Requires Google OAuth integration | <span style="color:red">**[PENDING]**</span> Pending |
| Payment flow | Payment gateway integration needed for "Consult Now" and medicine purchase | <span style="color:red">**[PENDING]**</span> Pending |
| LMS / Courses section | Client said completing the courses/LMS module is the first priority | <span style="color:red">**[PENDING]**</span> In Progress |
| Doctor-assigned reminders | When doctor saves prescription, trigger reminder creation for patient | <span style="color:red">**[PENDING]**</span> Pending |
| Doctor-prescribed lab tests | Prescribed tests should auto-populate in the patient's "Book a Lab Test" step 2 | <span style="color:red">**[PENDING]**</span> Pending |
| Health Tracker — vitals data storage | Backend needs endpoints to save/retrieve BP, blood sugar, weight, SpO2, heart rate per patient per date | <span style="color:red">**[PENDING]**</span> Pending |
| Health Tracker — points/rewards system | Backend needs points balance, earning history, and reward redemption endpoints | <span style="color:red">**[PENDING]**</span> Pending |
| Health Tracker — streak tracking | Backend or local logic to count consecutive logging days | <span style="color:red">**[PENDING]**</span> Pending |
| Health Mode setting | Backend or local preference to store patient's selected health mode (Diabetes / BP / Wellness) | <span style="color:green">**[DONE]**</span> Done |
| Tracker toggle preferences | Save patient's ON/OFF toggle state for each metric (BP, sugar, water, etc.) | <span style="color:red">**[PENDING]**</span> Pending |
| Family Profiles | Backend needs linked-account support — one user can manage multiple family member profiles | <span style="color:red">**[PENDING]**</span> Not Required |
| 2FA / Two-Factor Authentication | SMS OTP or email OTP integration needed | <span style="color:red">**[PENDING]**</span> Pending |
| Login activity tracking | Backend needs to log sessions/devices per user | <span style="color:red">**[PENDING]**</span> Pending |
| Billing history | Backend needs subscription and payment history endpoints | <span style="color:red">**[PENDING]**</span> Pending |
| Health data export | Backend needs to generate a downloadable health data file per patient | <span style="color:red">**[PENDING]**</span> Pending |
| Report delivery method (Diagnostics) | Backend needs to store and use patient's preferred delivery method for lab reports | <span style="color:red">**[PENDING]**</span> Pending |
