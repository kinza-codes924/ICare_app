# iCare App — Design & Feature Changes
## Client Meeting: April 18, 2026

---

## Table of Contents

1. [Login Screen Changes](#1-login-screen-changes)
2. [Home Page Changes](#2-home-page-changes)
3. [Pharmacy Account Changes](#3-pharmacy-account-changes)
   - 3.1 Dashboard & Analytics
   - 3.2 Sidebar Structure
   - 3.3 Order Management Flow
   - 3.4 Controlled Medicines & Quantity Limits
   - 3.5 Delivery System
   - 3.6 Inventory Management
   - 3.7 Notifications & Ratings
   - 3.8 Profile & Settings
   - 3.9 Onboarding
4. [Laboratory Account Changes](#4-laboratory-account-changes)
   - 4.1 Dashboard & Sidebar
   - 4.2 Test Catalog & Orders
   - 4.3 Result Entry & Reports
   - 4.4 API Integration
   - 4.5 Revenue & Analytics
   - 4.6 Settings & Notifications
5. [Cross-Cutting Changes (All Accounts)](#5-cross-cutting-changes-all-accounts)

---

## 1. Login Screen Changes

- Add tagline: **"Your Trusted Healthcare Platform"** on the login screen.
- Display branding: **"iCare by RM Health Solution"** on the login screen.
- Add **RM Health Solutions logo** to the login screen.

---

## 2. Home Page Changes

### 2.1 Logo Placement
- Revert to the **original logo** (logo with iCare text at the bottom).
- The modified version (iCare name placed beside the circle) is not acceptable — it causes the name to appear twice.
- **Center-align** the logo on the home screen.

### 2.2 Clickable Section Headings
All three primary action headings on the home page must be fully **clickable buttons** that navigate the user forward:

| Heading | Action on Click |
|---|---|
| **Order Medicine** | Opens a search bar — patient types a medicine name, pharmacies stocking it are listed |
| **Book a Lab Test** | Opens a search bar — patient types a test name, labs offering it are listed |
| **Connect to a Doctor** | Opens doctor search / listing page |

- The entire heading area must be tappable — not just a small icon or text portion.

### 2.3 Doctor Section on Home Page
- Change the heading **"Talk to a Verified Specialist Doctor"** → **"Consult Available Doctors"**
  - Remove the word "Specialist" — general practitioners (GPs) are also listed.
- Doctors shown on the home page are those who are **currently online**.
- Place the **search bar below the doctor listing**, not above it.
- Below the search bar, include two browse sections:
  - **Browse by Specialty** — search box to filter by doctor specialty
  - **Search by Condition** — search box to find doctors by patient condition/symptom
  - (These sections were lost during color-change updates — restore them.)

### 2.4 App Store Buttons
- The Google Play and Apple Store download buttons must be **non-clickable** until the app is officially published.
- Preferred approach: Leave them visually present but non-interactive (no "Coming Soon" label needed).
- Once the app is live, activate the buttons.

### 2.5 LMS Section on Home Page
- The LMS block label can be renamed to any appropriate title.
- While the platform is not yet live, the LMS block should be non-clickable or show a minimal "Coming Soon" state.

---

## 3. Pharmacy Account Changes

### 3.1 Dashboard & Analytics

#### Dashboard Stats — Display Order
1. **Today** (orders received today)
2. **Total** (all-time orders)
3. **Pending**
4. **Completed**

#### Revenue & Analytics Section
Rename to **"Revenue & Analytics"** — consistent across all account types.

Must include:
- Total orders submitted
- Total orders accepted
- Total orders completed
- Average process / fulfillment time
- Response time
- Failed deliveries count
- Out-of-stock item count
- Complaints count
- Average star rating

#### Recent Activity
- Add a **Recent Activity** bar/widget to the pharmacy dashboard showing the latest actions (order received, order dispatched, etc.).

### 3.2 Sidebar Structure

#### Final Sidebar Order
1. Dashboard
2. Awaiting Fulfillment *(new incoming orders)*
3. Orders *(active / in-progress)*
4. Inventory
5. Invoices
6. Revenue & Analytics
7. Settings
8. iCare Pharmacist Support *(chat with iCare team)*

#### Items to Remove from Sidebar
| Item | Action |
|---|---|
| My Profile | Remove from sidebar — move to **right-side icon** (top-right of screen) |
| My Task | Remove entirely — not applicable to pharmacy |
| Supplies | Remove — not applicable |
| Analytical Archives | Remove — duplicate of Revenue & Analytics |
| Diagnostic Queue | Remove — not applicable to pharmacy |
| Clinical Auditing | Remove — not applicable to pharmacy |
| Prescriptions | **Rename to "Orders"** — then place below "Awaiting Fulfillment" |

#### "Prescriptions" → "Orders"
- The current sidebar item labeled **"Prescriptions"** must be renamed to **"Orders"**.
- Under the Orders section, add a **"Create Order"** button at the bottom.

#### My Profile — Right Side Icon
- My Profile is removed from the left sidebar.
- It moves to a **profile icon on the right side** (top-right corner of the screen), consistent with how it is handled in other account types.
- Tapping this icon opens the pharmacy profile / edit profile page.

### 3.3 Order Management Flow

The pharmacy order lifecycle, modeled on Foodpanda:

```
Patient Places Order
        ↓
Awaiting Fulfillment  →  Pharmacy receives notification
        ↓
Pharmacy Accepts Order  →  Patient status: "Processing"
        ↓
Pharmacist Prepares Order
        ↓
Pharmacist Clicks "Dispatch"
  └─ Must enter Expected Delivery Time  ← mandatory field, cannot skip
        ↓
Status: "Out for Delivery"
  └─ Patient receives notification with expected delivery time
        ↓
Pharmacist marks "Delivered"
  └─ Patient receives "Order Delivered" notification
  └─ Rating prompt sent to patient immediately
```

#### Order Details — Required Fields
Every incoming order visible to the pharmacist must display:
- Patient full name
- Phone / contact number
- Delivery address
- Email *(optional — auto-filled from login if available)*
- Order items with quantities
- Prescription reference (if applicable)
- Delivery fee
- Total amount

#### Key Rules
- **Customer does NOT confirm delivery.** The pharmacist marks the order as delivered. Allowing customers to confirm/deny delivery creates fraud risk (customers falsely claiming non-delivery).
- **Expected delivery time** is a mandatory field. The pharmacist cannot dispatch an order without entering this.
- Rating notification is sent **immediately** after the pharmacist marks delivered — not after a delay.

#### Order Invoice / Print
- Every completed order must have a **printable PDF invoice**.
- Currency displayed: **PKR**
- Invoice must carry **iCare branding** prominently (logo + "Your Trusted Healthcare Platform").
- Pharmacy name / branding appears in a secondary position (bottom or smaller).
- Invoice contains: patient name, items, quantities, unit prices, delivery fee, total (PKR), date.

### 3.4 Controlled Medicines & Quantity Limits

#### Medicine Categories
All medicines in the system are classified into three categories:

| Category | Label in System | Description |
|---|---|---|
| **Over-the-Counter (OTC)** | OTC | Freely purchasable |
| **Controlled / Restricted** | `Controlled (Restricted — sleeping pills)` | Requires iCare-issued prescription |
| **Vaccines** | Vaccines | Requires prior consultation |

> **Team note:** When labeling controlled medicines, add the colloquial name in brackets for internal clarity, e.g., `Controlled (Restricted — neend ki goliyan / sleeping pills)`. No sub-categories within the Controlled group.

#### Controlled Medicine — Patient Flow
When a patient searches for or taps a controlled medicine (e.g., Alprazolam):

```
Patient taps controlled medicine
        ↓
System message:
"This medicine can only be purchased online after consultation
with our doctor. It is mandatory to have a consultation with
our doctor."
        ↓
Button: "Connect to a Doctor Now"  /  "Book Now"
        ↓
Patient consults iCare doctor
        ↓
Doctor issues prescription (with quantity) via platform
        ↓
Prescription auto-sent to pharmacy — quantity as prescribed, no further restriction
```

#### Quantity Limiter — Self-Purchase (No Prescription)
- Any customer purchasing **without a prescription** is capped at **30 units maximum** per medicine per order.
  - Basis: 3 doses/day × 10 days = 30 tablets.
- Attempting to order more than 30 units without a prescription blocks the order and redirects to the consultation flow.

#### Doctor Prescription — No Quantity Restriction
- When a doctor issues a prescription via the iCare platform, **the prescribed quantity passes directly to the pharmacy** with no system-imposed limit.
- Example: Psychiatrist prescribes 90 tablets (1/day × 3 months) — passes through freely because it originates from a verified iCare prescription.
- The prescription quantity is automatically reflected in the patient's pharmacy cart.
- The customer cannot increase the quantity beyond what the doctor prescribed.

#### Vaccines
- Listed under: **"Get Vaccines at Your Doorstep"**
- Ordering any vaccine requires **prior consultation** — same flow as controlled medicines.

### 3.5 Delivery System

#### Delivery Fee
- Each pharmacy has its own **fixed delivery fee**.
- Delivery fees are **set by iCare admin** (not editable by the pharmacist in the current phase).
  - Future phase: Allow pharmacists to manage their own delivery fee.
- Delivery fee is included in and displayed with the order total before the patient confirms checkout.

#### No Third-Party Delivery API (Current Phase)
- Integration with Bykea, InDrive, Careem, or similar services is **out of scope for the current phase**.
- Delivery is the pharmacy's own operational responsibility.
- Future partnership with a delivery service may be explored separately.

#### Delivery Tracking
- Full GPS live tracking is **not in scope** for the current phase.
- Replacement: Pharmacist enters an **expected delivery time** before dispatching. This time is shown to the patient in the order status screen.

### 3.6 Inventory Management

#### Bulk Upload (Import / Export)
- Pharmacists can upload their full medicine inventory via an **Excel/CSV bulk import**.
- The system provides a **downloadable template file** pre-formatted with all required fields.
- Pharmacist fills the template and uploads — all entries auto-populate the inventory.
- An **Export** option is also available so pharmacists can download their current inventory.

#### E-Mareez Compatibility
- Many pharmacies use **E-Mareez** for local inventory management.
- Where feasible, align iCare's import template fields to match E-Mareez's export format so pharmacists can export from E-Mareez and upload directly without reformatting.
- Obtain a sample E-Mareez export file to verify field alignment.

#### Inventory Fields per Medicine Entry
- Brand name
- Generic name (INN)
- Category (OTC / Controlled / Vaccine)
- Price (PKR)
- Stock quantity
- Unit (tablets, ml, vials, etc.)

#### Pharmacist-Initiated New Order
- Pharmacists can **manually create a new order** (for walk-in patients or known contacts).
- Located under **Orders → Create Order**.
- Controlled drugs: If the pharmacist attempts to add a controlled medicine to a manual order, the system checks the controlled-drug list. The order can only proceed if a valid iCare-generated prescription is linked.
- The controlled-drug classification list is **maintained by iCare admin** using generic/INN names. Pharmacists cannot reclassify medicines.

### 3.7 Notifications & Ratings

#### Rating System
After every completed order, a rating prompt is sent **immediately** to the patient:

> "How was your experience with this order?"

- Star rating (1–5) + optional written comment.
- Applied to all three service types:

| Service | Prompt |
|---|---|
| Consultation | "How was your consultation with Dr. [Name]?" |
| Pharmacy order | "How was your experience with this order?" |
| Lab test | "How was your experience with this lab?" |

- Ratings are **publicly visible** on the pharmacy/lab/doctor profile.

#### Pharmacy Notification Sub-Categories
- **New Orders** — mandatory, cannot be turned off
- **Order dispatched / Out for Delivery**
- **Delivery status updates**
- System alerts
- Remove: Booking updates (patient-facing, not applicable here)

### 3.8 Profile & Settings

#### Pharmacy Profile (Accessed via Right-Side Icon)
Required fields:
- Pharmacy name
- **Drug Sale License number** — mandatory
- Branch address
- Contact number
- Operating hours
- DRAP compliance checkbox (linked to DRAP policy page)
- No "Health Details" section — not applicable to pharmacy

#### Bank / Account Details
- Not editable within the app.
- To update banking details, pharmacist must contact iCare head office.
- Reason: Prevents accidental or unauthorized payment misdirection.

#### Change Password
- Flow: **Old password → New password → Confirm new password**

#### Settings Page — Items to Remove
The following patient-facing items must be removed from the pharmacy settings page:
- Health profile / health details
- Consultation settings
- Test history
- Learning / LMS settings
- Booking updates (notification)

#### Items to Keep / Add
- Change Password (updated flow as above)
- Notification preferences (pharmacy-specific, as described in 3.7)
- Language preferences
- About / Legal — placed **at the bottom** of settings
- DRAP & drug policy links

#### Support — Report an Issue
- A **"Report an Issue"** form in the help/support section.
- On submission, the report is sent directly to the iCare admin email.
- Help center questions must be **pharmacy-specific** — remove all patient/consultation-related FAQ entries.

#### iCare Pharmacist Support Chat
- A messaging channel for direct communication with the iCare support team.
- Label: **"iCare Pharmacist Support"**
- Simple chat thread (like WhatsApp) — not a task system.

### 3.9 Onboarding (Work With Us)

The "Work With Us" registration page:

**Step 1 — Basic Info:**
- Full name
- Phone number
- Email address
- City

**Step 2 — Role Selection:**
> "Do you want to work with us as?"

Three buttons:
> **[ Doctor ]     [ Pharmacy ]     [ Laboratory ]**

- Tapping a button opens the **role-specific onboarding form**.
- Doctor form: Already prepared by client.
- Pharmacy form: To be provided by client (Maryam).
- Laboratory form: To be provided by client (Maryam).

**Step 3 — Compliance:**
- DRAP policy agreement checkbox
- Terms of service acceptance

All form submissions go to the **iCare admin dashboard** and trigger an admin email notification.

---

## 4. Laboratory Account Changes

### 4.1 Dashboard & Sidebar

#### Dashboard Stats — Display Order
1. **Today**
2. **Total**
3. **Pending**
4. **Completed**

#### Recent Activity
- Add a **Recent Activity** widget to the lab dashboard (same as pharmacy and doctor).

#### Final Sidebar Order
1. Dashboard
2. New Requests / Awaiting Fulfillment
3. Orders
4. Test Catalog
5. Result Entry
6. Invoices
7. Revenue & Analytics
8. Settings
9. iCare Lab Support *(chat with iCare team)*

#### Items to Remove from Sidebar
| Item | Action |
|---|---|
| My Profile | Remove from sidebar — move to **right-side icon** (top-right) |
| My Appointments | Remove — functionality covered elsewhere |
| Supplies / Supply Chain | Remove — not applicable |
| Analytical Archives | Remove — duplicate |
| Clinical Archive | Remove — not applicable |
| Task | Remove — not applicable |
| Settings | Remove from main sidebar — accessible from profile/right-side icon area |

### 4.2 Test Catalog & Orders

#### Test Catalog
- The lab account includes a **Test Catalog** — the complete list of tests the lab offers.
- Each entry: standardized test name, price (PKR), turnaround time, sample type.
- Search bar at the top with **multi-keyword support** — typing partial text filters in real time.
- Lab staff can add new tests to their catalog.

#### Standardized Test Nomenclature
- A **single standardized test name list** is used across all three interfaces: Doctor, Patient, and Lab.
- Example: Always "CBC" — never "Blood CP" in one place and "Complete Blood Profile" in another.
- The master list of standardized test names will be provided by the client (Maryam).
- This same list populates the doctor's prescription test selector and the patient's lab search.

#### Create New Order (Lab-Initiated)
- Lab staff can **manually create a new order** for walk-in patients.
- Located under **Orders → Create Order**.
- Fields: Patient name, contact number, address, test(s) selected, in-house or home collection.

#### In-House vs. Home Collection
- Each order specifies:
  - **In-house** — patient visits the lab.
  - **Home visit** — lab technician collects sample at patient's location.

### 4.3 Result Entry & Reports

#### Unified Result Entry Page
- **"Upload Reports"** and **"Result Entry"** are merged into **one page**.
- Lab staff on this page can:
  - Manually enter test result values for each parameter.
  - Upload a scanned / digital report PDF.
- If API integration is active for this lab, results auto-populate from the lab's own system.

#### Result Delivery
- Completed results are pushed to:
  - The **patient** (in-app notification + viewable in patient account).
  - The **referring doctor** if the test was ordered via a doctor's prescription.

#### Invoices
- Lab invoices display amounts in **PKR**.
- Invoice carries iCare branding; lab name in secondary position.
- Downloadable PDF format.

### 4.4 API Integration

#### Purpose
Major lab chains (Chughtai Lab, Agha Khan, etc.) have their own internal lab management software. API integration allows orders placed on iCare to appear in the lab's system automatically and results to flow back.

#### Approach
Both manual and API flows must coexist:

| Scenario | Flow |
|---|---|
| Lab has existing software + provides API | Orders and results sync automatically |
| Lab has no existing software | Lab staff use iCare's manual entry and import/export |

- Each lab chain requires its **own separate API integration** — no universal connector.
- Steps to enable API for a lab:
  1. Lab provides API documentation and credentials.
  2. iCare dev team reviews and implements the connection.
  3. An **Import / Export button** is available in the lab account for manual sync when needed.

### 4.5 Revenue & Analytics

**Revenue & Analytics** is present in all three account types with consistent structure:

| Account | Management Section Label |
|---|---|
| Doctor | Clinical Management |
| Pharmacy | Pharmacy Management |
| Laboratory | Laboratory Management |

Each Revenue & Analytics section contains:
- Total earnings (PKR)
- Payout history and pending payouts
- Order / test volume over time
- Acceptance rate
- Completion rate
- Average patient rating
- Invoices (downloadable, PKR)

All payments pass through the iCare payment gateway. Payouts to labs and pharmacies are managed via the iCare admin portal.

#### Laboratory Profile — Test Listing
- The lab's public profile (visible to patients and doctors) must display the **list of tests it offers**, so patients and doctors can confirm availability before booking.
- Sourced from the lab's own Test Catalog.

### 4.6 Settings & Notifications

#### Lab Profile (Accessed via Right-Side Icon)
Required fields:
- Lab name
- License number — mandatory
- Branch address
- Contact number
- Operating hours
- DRAP compliance agreement

#### Notification Preferences (Lab-Specific)
- **New Test Requests** — mandatory, cannot be disabled
- Sample collection status updates
- Result upload reminders
- System alerts
- Labels use lab-specific language (e.g., "New Test Request" not "New Order")

#### Settings Scope
- Lab settings show only lab-relevant options — no patient-facing or pharmacy-related items.
- Help / Support section contains **lab-specific FAQ content** only.
- "Report an Issue" form: Submits to iCare admin email (same mechanism as pharmacy).

---

## 5. Cross-Cutting Changes (All Accounts)

### 5.1 My Profile — Right Side Icon (All Accounts)
- In all service-provider accounts (Doctor, Pharmacy, Lab), **My Profile is removed from the left sidebar**.
- It is accessed via a **profile icon in the top-right corner** of the screen.
- Tapping the icon opens the account's profile / edit profile page.

### 5.2 Revenue & Analytics — All Three Accounts
- Present in Doctor, Pharmacy, and Laboratory accounts.
- Same internal structure across all three; only the section heading and data labels differ per account type.

### 5.3 Rating & Review System
- Star rating (1–5) + optional written comment.
- Publicly visible on each doctor, pharmacy, and lab profile.
- Rating prompt sent immediately after each completed service (consultation, order, or test).
- Aggregate ratings tracked in Revenue & Analytics.

### 5.4 Invoices — Currency
- All invoices and financial displays across the platform use **PKR** (Pakistani Rupee).

### 5.5 Recent Activity Widget
- A **Recent Activity** section / widget is added to the dashboard of all service-provider accounts (Doctor, Pharmacy, Lab).
- Shows the latest actions taken (new order received, result uploaded, appointment completed, etc.).

### 5.6 Onboarding Forms
- Separate onboarding forms for Doctor, Pharmacy, and Laboratory via the "Work With Us" page.
- Each form ends with DRAP compliance and terms acceptance.
- All submissions route to the iCare admin dashboard + email notification.

### 5.7 Help Center — Account-Specific Content
- Each account type (Doctor, Pharmacy, Lab, Patient) has its own **separate Help Center content**.
- FAQ questions, support topics, and "Report an Issue" flows are tailored to that account's context.
- No cross-account content bleed (e.g., pharmacy settings must not show consultation-related help topics).

### 5.8 Settings Pages — Account-Specific
- Every settings page is scoped to its account type.
- Items not relevant to the account are hidden or removed entirely.

### 5.9 Invoice / PDF Branding
- All PDFs and printed documents carry **iCare branding** prominently (logo + "Your Trusted Healthcare Platform").
- The service provider's name (pharmacy / lab) appears in a secondary position.
- Currency on all invoices: **PKR**.

---

*Document prepared based on client discussion — April 18, 2026.*
