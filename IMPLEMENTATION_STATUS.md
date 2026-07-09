# iCare App — Implementation Status Report
**Client Meeting Date:** 13 April 2026  
**Report Updated:** 14 April 2026  
**Branch:** `wajahat`  
**Live URL:** https://icare-app-ten.vercel.app  

---

## Overall Progress Summary

| Section | Done | Remaining | % Complete |
|---------|------|-----------|------------|
| 1. Home Page | 13 / 16 items | 3 items | 81% |
| 2. Find Doctors Page | 0 / 13 items | 13 items | 0% |
| 3. Patient Module | 12 / 28 items | 16 items | 43% |
| 4. Doctor Dashboard | 7 / 8 items | 1 item | 88% |
| 5. Health Tracker Redesign | 0 / 7 features | 7 features | 0% |
| 6. Settings Page Redesign | 0 / 16 sections | 16 sections | 0% |
| **TOTAL** | **32 / 88** | **56 items** | **~36%** |

---

## Section 1 — Home Page
**Files:** `lib/screens/public_home.dart`

### ✅ Completed

| # | Change | Details |
|---|--------|---------|
| 1 | Banner heading updated | Changed to "Talk to a verified Specialist Doctor" |
| 2 | Video fee removed | Removed "Video Fee: Rs. X" row from all doctor cards |
| 3 | Search bar in banner | Added below the two CTA buttons |
| 4 | Pulsing animation on Connect button | AnimatedBuilder scale pulse (1.0 → 1.06) on "Connect to a Doctor" |
| 5 | Two CTA buttons in banner | "Connect to a Doctor" + "Book Appointment" both present |
| 6 | Speciality section moved up | Now appears BEFORE Pharmacy and Labs sections |
| 7 | "See All Speciality" button | Centered, outlined, below the specialty grid |
| 8 | Specialty cards clickable | Each card navigates to `DoctorsList()` |
| 9 | Search by Condition field | Added inside specialty section |
| 10 | Pharmacy renamed | "Pharmacies" → "Order Medicines" |
| 11 | Medicine search bar | Added in pharmacy section |
| 12 | Pharmacy ratings | Star ratings shown on each pharmacy card |
| 13 | Lab renamed | "Laboratories" → "Book a Lab Test" |
| 14 | Lab search bar | Added in lab section |
| 15 | Lab ratings | Star ratings shown on each lab card |
| 16 | "Book Lab" button | Purple button added below lab grid |
| 17 | Courses section | 2×2 grid above "How iCare Works" with heading "Join Pakistan's First 360° Health Care Platform" |
| 18 | Footer redesigned | White background, blue text/titles, removed "For Doctors" column and "Analytics" link |
| 19 | WhatsApp floating button | Real `WhatsAppFloatingButton` widget — bottom-right, green gradient, opens wa.me link |

### ❌ Remaining

| # | Change | Details |
|---|--------|---------|
| 1 | "Treated" text not replaced | Needs to change to "Certified Doctor Access — Complete Health Care" |
| 2 | 3-mode doctor search bar | Search bar needs 3 tabs: by Doctor Name / by Speciality / by Condition |
| 3 | "Search All Doctors" + "Connect Now" buttons | Extra buttons near the search bar linking to doctors list and online doctors |
| 4 | Courses section — correct tiles | Current tiles are generic. Should be: Patients (Diet & Health Programs) + Doctors (General Courses + Training Programs). Link to `lib/screens/courses.dart` |
| 5 | Courses sub-heading | Add "Open for Everyone" and "Live Skill Academy for Everyone" text |

---

## Section 2 — Find Doctors / Doctor Listing Page
**Files:** `lib/screens/doctors_list.dart`, `lib/screens/doctor_detail.dart`, `lib/screens/book_appointment.dart`

### ✅ Completed
_Nothing done in this section yet._

### ❌ Remaining — All Items

| # | Change | Details |
|---|--------|---------|
| 1 | Speciality search bar | Filter doctor list by speciality |
| 2 | General Practitioner as default | First option in speciality filter |
| 3 | Search by Condition | Type a condition → see matching doctors |
| 4 | Online doctors count | Show "X doctors online right now" at top of list |
| 5 | Remove 3 filter tabs | Remove "All", "General", and similar tab filters |
| 6 | Doctor card — profile picture | Photo must appear on card |
| 7 | Doctor card — PMDC Number | Show PMDC registration number *(needs backend)* |
| 8 | Doctor card — years of experience | Show e.g. "8 years experience" *(needs backend)* |
| 9 | Remove contact info from booking | No phone/email in book appointment screen |
| 10 | "Consult Now" → Payment screen | After clicking Consult Now, show basic info then go to payment |
| 11 | After booking confirmation → Payment | Payment screen after confirming booking |
| 12 | Remove messaging + voice call options | Not shown on booking details screen |
| 13 | Remove all contact info from flow | No phone, email, or any contact in booking flow |

---

## Section 3 — Patient Module
**Files:** `lib/screens/`, `lib/navigators/drawer.dart`

### ✅ Completed

| # | Change | File | Details |
|---|--------|------|---------|
| 1 | "Role" field removed | `view_profile.dart` | Role badge hidden for Patient role |
| 2 | CNIC Number field added | `create_profile.dart` | New required field added to both mobile and web forms |
| 3 | Height + Weight fields added | `create_profile.dart` | Added to patient profile form |
| 4 | Address field added | `create_profile.dart` | Added to patient profile form |
| 5 | "My Care Plans" removed | `drawer.dart` | Removed "Your Care Plans" from patient sidebar |
| 6 | "Pharmacies" renamed | `drawer.dart` | → "Order Medicines" |
| 7 | "Laboratories" renamed | `drawer.dart` | → "Book a Lab Test" |
| 8 | "My Appointments" moved to top | `drawer.dart` | First item in patient sidebar |
| 9 | Booking History — "Book Appointment Now" button | `bookings_history.dart` | Large button at top, navigates to DoctorsList |
| 10 | Booking History — pending at top | `bookings_history.dart` | Section order: Pending → Confirmed → Completed → Cancelled |
| 11 | Booking History — cancel button | `bookings_history.dart` | Cancel button at bottom of pending booking cards |
| 12 | Booking History — completed notes | `bookings_history.dart` | Shows "prescription and notes on file" for completed appointments |

### ❌ Remaining

| # | Change | File | Details |
|---|--------|------|---------|
| 1 | Profile icon → dropdown | App bar (patient) | Clicking profile icon → dropdown: Edit Profile + Logout |
| 2 | Remove "My Profile" from sidebar | `drawer.dart` | Profile moves to top-right icon only |
| 3 | Remove "Messages" from sidebar | `drawer.dart` | Messaging accessible elsewhere |
| 4 | Book a Lab Test — 3-step flow | `book_lab.dart` | Step 1: Home/Lab Sample. Step 2: Search & select tests. Step 3: Nearby labs (geo-tagged). Lab Reports: Completed/Pending/Advised |
| 5 | Order Medicines flow | `pharmacy_home.dart` | Search bar, medicine list, clicking → Payment screen |
| 6 | Reminders — 2 types | `create_reminder.dart` | Doctor-assigned + Self-created reminders |
| 7 | Reminders — Google Calendar sync | `create_reminder.dart` | OAuth integration needed |
| 8 | Reminders — simple form | `create_reminder.dart` | Date, Time, Label only. Replace "Select time and day" with "Add Reminder" button |
| 9 | My Health Journey — "Coming Soon" | `health_journey_screen.dart` | Add Coming Soon banner. Auto-populate from doctor prescriptions |
| 10 | Booking detail — "View Full Details" | `bookings.dart` | Rename "View Full Profile" → "View Full Details" |
| 11 | Booking detail — Confirmed in green | `bookings.dart` | Confirmed status shown in green color |
| 12 | Booking detail — remove voice/msg/contact | `bookings.dart` | No messaging, voice call, or contact info shown |
| 13 | Booking detail — Back → Home | `bookings.dart` | Back button goes to Home, not Booking History |
| 14 | Health Community — Like + Comment | `health_community.dart` | Posts need Like button and Comment option |
| 15 | Health Community — iCare logo | `health_community.dart` | App logo visible on this screen |
| 16 | Patient Settings — remove Privacy Policy | `settings.dart` | Remove Privacy Policy link |
| 17 | Patient Settings — remove About Us | `settings.dart` | Remove About Us link |
| 18 | Patient Settings — remove Terms & Conditions | `settings.dart` | Remove Terms & Conditions link |
| 19 | Notification Settings cleanup | `notification_settings.dart` | Remove "Patient Messages", rename "Admin Announcement" → "Promotions", add sound toggle, rename heading → "Notification Settings", add email prescription toggle |
| 20 | SOAP Notes hidden from patient | `view_profile.dart` | SOAP Notes must NOT appear in patient profile view |
| 21 | Emergency Numbers (2 fields) | `drawer.dart` / patient profile | Emergency Number 1 + Emergency Number 2 fields |

---

## Section 4 — Doctor Dashboard
**File:** `lib/screens/doctor_dashboard.dart`, `lib/navigators/drawer.dart`

### ✅ Completed

| # | Change | Details |
|---|--------|---------|
| 1 | Dashboard section order | Welcome → Appointment Requests → Today's Appointments → Stats → Quick Actions |
| 2 | Welcome header | Shows "Welcome back, Dr. [Name]" with rating + satisfaction score below name |
| 3 | Appointment Requests widget | Shows pending appointments (up to 5) with green Accept ✓ and red Decline ✗ buttons |
| 4 | "View All" link on requests | Appears below requests if more than 5 exist |
| 5 | Revenue card removed | Replaced with Pending Appointments count |
| 6 | "Secure Health" removed | Widget removed from dashboard |
| 7 | "View All" removed from Today's Appointments heading | Removed from that section header |
| 8 | Stats cards | Shows: Consultations + Pending + Rating + Satisfaction (no revenue) |
| 9 | Doctor sidebar — Edit Profile dropdown | PopupMenuButton with Edit Profile + Logout options |

### ❌ Remaining

| # | Change | Details |
|---|--------|---------|
| 1 | Today's appointments as square cards by time | Currently shown as list — should be square cards arranged by time slot |

---

## Section 5 — Health Tracker Redesign
**Files:** `lib/screens/health_tracker.dart`, `lib/screens/lifestyle_tracker.dart`, `lib/screens/lifestyle_tracker_screen.dart`, `lib/screens/gamification_screen.dart`

### ✅ Completed
_Nothing done in this section yet._

### ❌ Remaining — All Items

| Feature | Details |
|---------|---------|
| Main dashboard | Greeting, Daily Goal progress bar, Points earned today, Metric tiles grid (BP, Sugar, Weight, Water, Medication, Steps), "+ Log More" button |
| Tracking categories | Vitals (BP, Sugar, Weight, HR, SpO2), Lifestyle (Water, Steps, Sleep, Diet), Medication compliance, Mood tracking, Stress level, Menstrual cycle, Calories |
| Log metric screen | Input fields per metric, numeric keypad, Save button, "+X points earned" message |
| Progress charts | Daily/Weekly/Monthly tabs, line charts per metric, achievement badges, "View Detailed Report" link |
| Health Mode toggle | Diabetes Mode / BP Mode / General Wellness Mode — each shows different default metrics |
| Rewards/Points system | Points per log, daily goal bonus, streak bonus. Rewards screen: total balance, activity feed, Redeem button. Redemption: Free Consultation (100 pts), Lab Test Discount (150 pts) |
| Consultation Summary integration | Summary card before connecting to doctor — shows recent tracker data + doctor's last notes + "Start Consultation" button |

---

## Section 6 — Settings Page Redesign
**File:** `lib/screens/settings.dart`

### ✅ Completed
_Nothing done in this section yet._

### ❌ Remaining — All Sections

| Section | Fields / Options |
|---------|-----------------|
| 6.1 Profile & Account | Name, Age/Gender, Phone/Email, Profile photo, Emergency contact, Blood group, Existing conditions |
| 6.2 Health Profile | Medical conditions, Allergies, Current medications, Health goals — linked to Health Tracker |
| 6.3 Tracker Settings | ON/OFF toggles: BP, Blood Sugar, Weight, Water, Medication. Daily goals: Water (glasses) + Steps |
| 6.4 Reminders & Notifications | Medication reminders, Water reminders, Health check reminders, Appointment reminders |
| 6.5 Rewards & Points | Points balance, Rewards history, Redemption history |
| 6.6 Privacy & Data | Download health data, Delete account (with confirmation) |
| 6.7 Payments & Subscriptions | Saved payment methods, Subscription plans, Billing history |
| 6.8 Support & Help | Contact support, FAQs, Report issue |
| 6.9 About & Legal | Terms & Conditions, Privacy Policy, App version |
| 6.10 Consultation Settings | Preferred language, Preferred doctor type, Consultation history access toggle, Medical records upload, Video/audio preferences |
| 6.11 Pharmacy Settings | Saved delivery addresses, Preferred pharmacy, Order history, Delivery preferences |
| 6.12 Diagnostics Settings | Test history, Home sample preferences, Report delivery method |
| 6.13 Learning Settings | Enrolled courses, Certificates, Progress tracking, New course notifications toggle |
| 6.14 Family Profiles | Add/manage/track family members *(needs backend — linked accounts)* |
| 6.15 Security | Change password, 2FA (OTP via SMS/email), Login activity log |
| 6.16 Language & Region | Language selection, Country/Region setting |

---

## Backend Tasks Required (Not Frontend Dependent)

| Task | Section | Status |
|------|---------|--------|
| PMDC Number field on doctor profile | Section 2 | ❌ Pending |
| CNIC field on patient profile schema | Section 3 | ❌ Pending |
| Years of experience on doctor endpoint | Section 2 | ❌ Pending |
| Geo-tagging for lab distance calculation | Section 3.4 | ❌ Pending |
| Google Calendar OAuth integration | Section 3.6 | ❌ Pending |
| Payment gateway (Consult Now + medicines) | Section 2.3 | ❌ Pending |
| Doctor-assigned reminders from prescription | Section 3.6 | ❌ Pending |
| Prescribed tests → auto-fill lab booking | Section 3.4 | ❌ Pending |
| Health Tracker vitals endpoints (save/retrieve per date) | Section 5 | ❌ Pending |
| Points/rewards balance + earning history endpoints | Section 5.6 | ❌ Pending |
| Streak tracking (consecutive logging days) | Section 5.6 | ❌ Pending |
| Health Mode preference storage | Section 5.5 | ❌ Pending |
| Tracker toggle preferences per patient | Section 6.3 | ❌ Pending |
| Family Profiles — linked accounts | Section 6.14 | ❌ Pending |
| 2FA — SMS/email OTP | Section 6.15 | ❌ Pending |
| Login activity log per user/device | Section 6.15 | ❌ Pending |
| Billing + payment history endpoints | Section 6.7 | ❌ Pending |
| Health data export (downloadable file) | Section 6.6 | ❌ Pending |
| Lab report delivery method preference | Section 6.12 | ❌ Pending |

---

## Files Changed So Far

| File | Changes Made |
|------|-------------|
| `lib/screens/public_home.dart` | Full home page redesign — banner, sections, courses, footer, WhatsApp FAB |
| `lib/screens/doctor_dashboard.dart` | Full dashboard redesign — new order, appointment requests, stats, removed revenue |
| `lib/screens/bookings_history.dart` | Full redesign — card layout, pending first, cancel button, completed notes, Book Now button |
| `lib/screens/create_profile.dart` | Added CNIC, Height, Weight, Address fields (mobile + web) |
| `lib/screens/view_profile.dart` | Role badge hidden for Patient |
| `lib/navigators/drawer.dart` | Patient sidebar renamed/reordered. Doctor sidebar Edit Profile → PopupMenuButton with Logout |
| `CLIENT_CHANGES_REQUIRED.md` | Full documentation of client requirements |

---

## Next Priority Order (Recommended)

| Priority | Task | Effort |
|----------|------|--------|
| 🔴 High | Patient profile icon → dropdown (Edit Profile + Logout) | Small |
| 🔴 High | Remove Messages from patient sidebar | Small |
| 🔴 High | Booking detail fixes (Confirmed green, remove voice/msg, View Full Details, Back→Home) | Medium |
| 🔴 High | Find Doctors page — search/filter/card info changes | Medium |
| 🟡 Medium | Health Community — Like, Comment, iCare logo | Small |
| 🟡 Medium | Patient Settings cleanup (remove Privacy/About/Terms) | Small |
| 🟡 Medium | Notification settings cleanup | Small |
| 🟡 Medium | SOAP Notes hidden from patient | Small |
| 🟡 Medium | My Health Journey — Coming Soon banner | Small |
| 🟡 Medium | Emergency Numbers fields | Small |
| 🔵 Large | Home page 3-mode search bar + correct courses tiles | Medium |
| 🔵 Large | Book a Lab Test — full 3-step flow | Large |
| 🔵 Large | Health Tracker full redesign | Very Large |
| 🔵 Large | Settings page full restructure | Very Large |

---

*Report generated: 14 April 2026*  
*GitHub Branch: `wajahat` — https://github.com/KinzaKhurram123/ICare_app*
