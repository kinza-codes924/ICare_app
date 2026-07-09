# iCare App — Meeting Notes Documentation
**Meeting Date: April 21, 2026**
**Prepared by: Development Team**

---

## SECTION 1: HOME PAGE CHANGES

### 1.1 Main Banner

**Main Heading:**
- Change from: "Consult Available Doctors"
- Change to: **"Consult a Doctor"**

**Sub-text below heading:**
- Change to: **"Consult trusted doctors, book appointments and access healthcare from home 24/7"**

**Buttons in Banner:**
- Keep both buttons as they are: "Connect to a Doctor Now" and "Book Appointment"
- No changes to button text

---

### 1.2 Banner Background Design

**Logo Watermark:**
- Remove the two white circles currently in the banner background
- Place the **iCare logo as a large faded watermark** behind the doctor image
- The doctor image stands in front — half the logo is visible, half hidden behind the doctor (like a logo printed on a wall)

**Doctor Image Badge:**
- Add the iCare logo as a small badge on the doctor's coat/shirt area (like a name badge)

**Navbar Logo Fix:**
- The iCare logo in the top navbar looks blurry/faded
- Crop the logo edge-to-edge (remove extra white space around it)
- Make it slightly larger and increase the navbar height by about 20% so the logo fits properly

---

### 1.3 Doctor Section

**Section Heading:** Change to **"Consult Available Doctors Now"**

**Layout order (top to bottom):**
1. Doctor cards
2. Browse by Specialty — search box to find doctors by specialty
3. Browse by Condition — search box to find doctors by symptom/condition
4. Main search bar with dropdown (Doctor Name / Specialty / Condition) — placed **below** the two browse sections

*(Note: The Browse by Specialty and Browse by Condition sections were removed after a color update — these must be restored)*

---

### 1.4 "Order Medicines" Section Color

- Change the **heading text color** from blue to **green**
- Use **Shopify green** (the same green as the Shopify logo)
- Only the heading color changes — everything else stays the same

---

### 1.5 "Book a Lab Test" Section Color

- Change the **heading text color** to orange-red
- Exact color code: **#FF4D00**
- Only the heading color changes — everything else stays the same

**Book Lab Test Button:**
- The button should have a **flashing/pulsing animation** to draw attention
- Make the button text **bold**

---

### 1.6 LMS / Courses Section

**Reduce from 4 tiles to 2 tiles:**

| Tile | Title | Sub-text | Icon |
|------|-------|----------|------|
| 1 | Diet Plan and Health Courses | For Patients — Learn to manage your health | Health/lifestyle related icon |
| 2 | Training Programs and Courses | For Healthcare Professionals | Graduation cap icon (currently on "General Courses") |

**Remove entirely:** "General Courses" tile and "Health Programs" tile

---

### 1.7 "How iCare Works" Section

**Change from 4 steps to 5 steps:**

| Step | Title | Description |
|------|-------|-------------|
| 1 | Search and Select | Find the right doctor by specialty, condition, or name |
| 2 | Book Appointment | Choose a convenient time slot and confirm your **appointment** *(change "booking" → "appointment")* |
| 3 | Video Consult | Connect via secure HD video call with **iCare's trusted doctor** |
| 4 | Get Prescription | Receive digital prescriptions and follow-up care plans |
| 5 | Get Medicines and Lab Tests | Get medicines and lab tests from the comfort of your home |

**After step 4, add two arrows branching out:**
- One arrow pointing toward **Lab Test booking**
- One arrow pointing toward **Pharmacy / Medicines**
*(Visually shows the two paths a patient can take after getting a prescription)*

**Update section heading:** "Get quality healthcare in **4** simple steps" → "Get quality healthcare in **5** simple steps"

---

### 1.8 Footer Changes

**Platform description text** (below iCare logo in footer):
- Change to: **"Pakistan's leading telehealth platform connecting patients with top specialists for secured online consultations, lab tests and digital prescription"**

**Google Play / App Store buttons in footer:**
- Change both store buttons to **black** (currently another color)

**Footer logo:** Fix the iCare logo display so it looks clean and sharp

---

### 1.9 Login Screen Changes

**Left side — Feature Boxes:**

- **Box 1:** Change text to **"Complete Digital Health Care Platform"**
- **Box 2:** Add **"HIPAA Compliant"** label *(HIPAA = US healthcare data security standard — do NOT use GDPR, that is Europe-only)*
- Make all feature icons/boxes **more colorful** (currently they look plain/dull)
- Add **"Data Protected and Secure"** label

**"Open for Everyone" Section — 2 Cards:**
- Card 1: **For Doctors** — with relevant icon and short description
- Card 2: **For Patients** — with relevant icon and short description

**Logo area (top left of login screen):**
- Remove the text "iCare by RM Health Solution"
- Replace with: **iCare logo** + the word **"By"** + **RM Health Solutions logo**
- Text is removed — logos only

---

## SECTION 2: LABORATORY ACCOUNT CHANGES

### 2.1 Sidebar Menu — Final Order

| Position | Item |
|----------|------|
| 1 | Home / Dashboard |
| 2 | New Requests |
| 3 | Records |
| 4 | Orders |
| 5 | Test Catalog |
| 6 | Invoices |
| 7 | Revenue and Analytics |
| 8 | Settings |
| 9 | iCare Lab Support |

**Changes:**
- Remove **"Awaiting Fulfillment"** from sidebar (merged into "New Requests")
- Remove **"Result Entry"** from sidebar (accessible from within each order instead)
- Rename **"Upload Reports"** → **"Records"**

---

### 2.2 Lab Order Status Flow

When an order is placed, it goes through these stages in order:

```
New Request
    ↓
Accepted by Lab  (or Declined)
    ↓
Sample Collected  ← lab staff marks this; timestamp recorded automatically
    ↓
Awaiting Reports  ← sample sent to processing/testing
    ↓
Reporting Done    ← results uploaded and verified
    ↓
(Cancelled — can be applied at any stage if needed)
```

**Rules:**
- "New Requests" and "Awaiting Fulfillment" were doing the same job — keep only **New Requests**
- The "Orders" page shows all orders regardless of status
- "New Requests" shows only new/pending orders
- New Requests list must be sorted **by date** — oldest first (date-wise priority)
- Add **filter options** on the New Requests page (by date, test type, collection type, etc.)
- Remove the word **"Appointment"** from anywhere in the lab order flow — these are test orders, not appointments

**"Sample Collected" button:**
- This action button should also be accessible directly from the main order list/booking management view — not only from inside the order detail

---

### 2.3 Lab Booking Detail View

When a lab staff member clicks on an order, the detail page must show:

- **Lab Name** — clickable (clicking opens the lab's full profile page)
- **Ordered By:** Dr. [Name] — with a clear "Ordered by" heading
- **Patient Name** — with a clear "Patient Name" heading
- **Test Prescription Date**
- **Referred By** — doctor who referred the test *(replace the current "Price" field in this spot)*
- **Collection Type** — Home Collection or In-Lab
- **Doctor's Notes** — any notes attached by the referring doctor
- **Sample Collected By** — visible once sample is marked as collected

---

### 2.4 Create Walk-In Order Form

When lab staff manually creates an order for a walk-in patient:

**Patient Details:**
- Patient Name *(label must say "Patient Name" — currently missing)*
- Age
- Gender
- Location
- MR Number *(Medical Record Number — unique ID assigned to a patient, never changes)*
- Test Prescription Date

**Referred By:**
- Doctor's name who sent/referred this patient

**Specimen Information:**
- Specimen ID *(unique ID on the test tube or sample container)*
- **"Add Row" / "Add More" button** — so multiple specimens can be added, each with its own ID

**Collection Type:**
- Two options only: **Home Collection** or **In-Lab**
- Remove "In-House" — replace with "In-Lab"

**Urgency:**
- Toggle: "Is this test urgent?" — Yes / No
- If Yes: Show **"Urgent Turnaround Time"** field (dropdown — select hours or days, no free typing)
- Normal Turnaround Time field is always visible

**Pricing:**
- Remove all **$** (dollar) signs
- Use **PKR** everywhere

---

### 2.5 Test Catalog — Add New Test

When a lab adds a test to their catalog, the form includes:

- **Test Name** — selected from a **standardized dropdown** (no free typing allowed)
  - Search bar inside dropdown: type partial name → matching tests appear
  - Format: Full name + short form in brackets, e.g., "Complete Blood Count (CBC)"
  - All labs must use the same test names — master list loaded by iCare team
- **Price** — in PKR (no $ sign)
- **Sample Collection Type:**
  - Home Only
  - Lab Only
  - Home and Lab
- **Normal Turnaround Time** — dropdown (select hours or days — no free typing)
- **Urgent Test Available:** Yes / No
  - If Yes: Show **"Urgent Turnaround Time"** field (dropdown — hours or days)

---

### 2.6 Result Entry (from within the Order)

Result entry is accessed by opening an order — it is **not** a separate sidebar item.

**Step-by-step flow:**
1. Open order → Click **"Mark Sample Collected"** → Timestamp saved automatically
2. Sample Collected status is confirmed — collection is timestamp-controlled
3. **"Enter Results"** button appears after sample is marked collected
4. Lab staff fills in test parameters and values (or uploads PDF report)
5. Before saving, select **"Approved by Doctor"** from dropdown
6. Mark **"Reporting Done"** when complete

**Result Entry form includes:**
- Test parameters with values, units, and normal reference ranges
  *(Units vary per lab — e.g., blood sugar can be mmol/L or mg/dL — each lab sets their own)*
- **"Sample Collected By"** — dropdown of registered collectors (from lab's staff list)
- **"Approved by Doctor"** — dropdown of registered lab doctors — placed **before** the Notes field
- Doctor's Notes field
- Upload PDF report option

**Report footer on every downloaded PDF:**
> *"This is an electronically generated report verified by [Doctor Name, MBBS, FCPS, Designation]"*

- All registered doctors' names appear at the bottom of every report
- "Sample Collected By: [Name]" shown separately on the report

---

### 2.7 Records Page (formerly "Upload Reports")

**Renamed to:** "Records" in the sidebar

**Search bar with the following options:**
- Patient Name
- MR Number (Medical Record Number)
- Doctor Name
- Patient Contact Number

**Payment rule:**
- Patient must pay **before** sample is collected
- Payment is made at booking time — not after the test is done
- No payment = no sample collection

---

### 2.8 Revenue and Analytics

**Two separate revenue fields:**
1. **Total Revenue Paid by Card** — money received directly by iCare platform
2. **Total Revenue Paid by Cash** — money held with the laboratory (patient paid cash on site)

**Calculation breakdown shown to lab:**
```
Total Revenue:            PKR 100,000
Platform Fee (20%):     - PKR  20,000
──────────────────────────────────────
Remaining Balance:        PKR  80,000
Cash Held with Lab:     - PKR  XX,XXX
──────────────────────────────────────
Amount Payable to Lab:    PKR  XX,XXX
```

**Platform fee** shown clearly below the Performance Metrics section

**Actual revenue figures** must also be displayed — not just analytics/charts

**Calendar / Date Range Picker:**
- Add a proper calendar widget so lab can filter analytics by any date range
- Options: daily, weekly, monthly, or custom dates

**Ratings and Reviews:**
- Star rating (1–5) already present
- Add **written review / comment** below the stars (like Google reviews)

---

### 2.9 Payment Invoices

- Remove **"Pending"** status from invoice list — no pending invoices shown
- Remove **"Overdue"** status from invoice list
- Show only confirmed/completed payment records

---

### 2.10 Lab Profile Setup

**Basic Information:**
- Lab Name
- Owner Name / Company Name *(single combined field)*
- License Number *(mandatory)*
- Contact Numbers *(add "+" button to allow multiple phone numbers)*
- Email Address
- Working Hours *(include days — e.g., Mon–Sat, 9am–6pm)*
- Home Sample Collection: Yes / No toggle
- Profile Picture / Lab Logo upload *(mandatory on all profile settings pages)*

**Document Uploads:**
- Upload Registration Certificate
- Upload License
- Upload Compliance Documents
- Multiple documents allowed per upload

**Verification:**
- Email: verified via OTP sent to email
- Phone: verified via SMS OTP
- *(No WhatsApp OTP — too expensive and Meta policy restrictions)*

**Document upload section** appears **before** the compliance agreement checkbox

**Compliance:**
- DRAP agreement checkbox at the bottom

---

### 2.11 Doctors Panel (in Lab Profile)

Located inside Edit Profile, **below the "About Laboratory" section:**

**Doctors Panel:**
- Add up to **4–6 doctors** registered at the lab
- Each entry: **Name + Education (MBBS, FCPS, etc.) + Designation**
- "+" button to add more doctors
- These names appear on every report PDF as "Verified by"
- The "Approved by Doctor" dropdown in Result Entry pulls from this list

**Sample Collectors Panel** (separate heading):
- Add lab technicians and sample collectors
- Each entry: **Name + Designation** (e.g., Lab Technician)
- The "Sample Collected By" dropdown in Result Entry pulls from this list
- Sample collector records are linked to each sample collection entry

---

### 2.12 Lab Notifications Settings

**Keep these:**
- New Booking Alert
- Urgent Test Alert

**Remove these:**
- Booking Cancellation
- Payment Received
- Low Supply Alert
- Daily Summary Report

---

### 2.13 iCare Lab Support (Help Center)

- Add a **WhatsApp button** in the Help Center / Support section
- This connects directly to the iCare support team
- Future plan: dedicated support manager per module

---

## SECTION 3: PHARMACY ORDER DISPLAY FIXES

- Add a clear **"Patient Name"** label/heading above the patient's name in the order detail
- Change **"Doctor Ordered by Doctor"** → simply **"Ordered by"** (remove the duplicate "Doctor" word)
- Replace all **$** signs with **PKR / Rs**

---

## SECTION 4: GENERAL DECISIONS

| Topic | Decision |
|-------|----------|
| Data compliance label | **HIPAA Compliant** — not GDPR (GDPR is Europe only) |
| WhatsApp OTP | Not feasible — use SMS OTP only |
| Lab test names | Standardized dropdown list — no free text allowed |
| Payment timing | Paid at booking, BEFORE sample is collected |
| Cash vs Card revenue | Tracked and displayed separately |
| Platform commission | 20% of total revenue |
| Invoice statuses | Remove "Pending" and "Overdue" — show completed records only |
| Store buttons in footer | Black color for both Google Play and App Store |
| Lab order priority | Date-wise sorting in New Requests |
| Doctor approval on reports | Mandatory — electronically verified report statement on every PDF |

---

*Documentation prepared from meeting transcript and notes — April 21, 2026*
*Development Team: iCare by RM Health Solution*
