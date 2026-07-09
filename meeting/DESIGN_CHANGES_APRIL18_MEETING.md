# iCare App â€” Design & Feature Changes

## Client Meeting: April 18, 2026

## Table of Contents

1\. Login Screen Changes

2\. Home Page Changes

3\. Pharmacy Account Changes

- - 3.1 Dashboard & Analytics
    - 3.2 Sidebar Structure
    - 3.3 Order Management Flow
    - 3.4 Controlled Medicines & Quantity Limits
    - 3.5 Delivery System
    - 3.6 Inventory Management
    - 3.7 Notifications & Ratings
    - 3.8 Profile & Settings
    - 3.9 Onboarding

4\. Laboratory Account Changes

- - 4.1 Dashboard & Sidebar
    - 4.2 Test Catalog & Orders
    - 4.3 Result Entry & Reports
    - 4.4 API Integration
    - 4.5 Revenue & Analytics
    - 4.6 Settings & Notifications

5\. Cross-Cutting Changes (All Accounts)

## 1\. Login Screen Changes

- <span style="color:green">**[DONE]**</span> Add tagline: **”Your Trusted Healthcare Platform”** on the login screen.
- <span style="color:green">**[DONE]**</span> Display branding: **"iCare by RM Health Solution"** on the login screen.
- <span style="color:green">**[DONE]**</span> Add **RM Health Solutions logo** to the login screen.

## 2\. Home Page Changes

### 2.1 Logo Placement

- <span style="color:red">**[PENDING]**</span> Revert to the **original logo** (logo with iCare text at the bottom).
- <span style="color:red">**[PENDING]**</span> The modified version (iCare name placed beside the circle) is not acceptable â€” it causes the name to appear twice.
- <span style="color:red">**[PENDING]**</span> **Center-align** the logo on the home screen.

### 2.2 Clickable Section Headings

<span style="color:green">**[DONE]**</span> All three primary action headings on the home page must be fully **clickable buttons** that navigate the user forward:

| **Heading** | **Action on Click** |
| --- | --- |
| <span style="color:green">**[DONE]**</span> **Order Medicine** | Opens a search bar â€” patient types a medicine name, pharmacies stocking it are listed |
| <span style="color:green">**[DONE]**</span> **Book a Lab Test** | Opens a search bar â€” patient types a test name, labs offering it are listed |
| <span style="color:green">**[DONE]**</span> **Connect to a Doctor** | Opens doctor search / listing page |

- <span style="color:green">**[DONE]**</span> The entire heading area must be tappable â€” not just a small icon or text portion.

### 2.3 Doctor Section on Home Page

- <span style="color:green">**[DONE]**</span> Change the heading **"Talk to a Verified Specialist Doctor"** â†’ **"Consult Available Doctors"**
    - Remove the word "Specialist" â€” general practitioners (GPs) are also listed.
- <span style="color:red">**[PENDING]**</span> Doctors shown on the home page are those who are **currently online**.
- <span style="color:red">**[PENDING]**</span> Place the **search bar below the doctor listing**, not above it.
- <span style="color:green">**[DONE]**</span> Below the search bar, include two browse sections:
    - <span style="color:green">**[DONE]**</span> **Browse by Specialty** â€” search box to filter by doctor specialty
    - <span style="color:green">**[DONE]**</span> **Search by Condition** â€” search box to find doctors by patient condition/symptom
    - <span style="color:green">**[DONE]**</span> (These sections were lost during color-change updates â€” restore them.)

### 2.4 App Store Buttons

- <span style="color:green">**[DONE]**</span> The Google Play and Apple Store download buttons must be **non-clickable** until the app is officially published.
- <span style="color:green">**[DONE]**</span> Preferred approach: Leave them visually present but non-interactive (no "Coming Soon" label needed).
- Once the app is live, activate the buttons.

### 2.5 LMS Section on Home Page

- <span style="color:green">**[DONE]**</span> The LMS block label can be renamed to any appropriate title.
- <span style="color:green">**[DONE]**</span> While the platform is not yet live, the LMS block should be non-clickable or show a minimal "Coming Soon" state.

## 3\. Pharmacy Account Changes

### 3.1 Dashboard & Analytics

#### Dashboard Stats â€” Display Order

- <span style="color:green">**[DONE]**</span> 1\. **Today** (orders received today)
- <span style="color:green">**[DONE]**</span> 2\. **Total** (all-time orders)
- <span style="color:green">**[DONE]**</span> 3\. **Pending**
- <span style="color:green">**[DONE]**</span> 4\. **Completed**

#### Revenue & Analytics Section

<span style="color:green">**[DONE]**</span> Rename to **"Revenue & Analytics"** â€” consistent across all account types.

Must include:

- <span style="color:red">**[PENDING]**</span> Total orders submitted
- <span style="color:red">**[PENDING]**</span> Total orders accepted
- <span style="color:red">**[PENDING]**</span> Total orders completed
- <span style="color:red">**[PENDING]**</span> Average process / fulfillment time
- <span style="color:red">**[PENDING]**</span> Response time
- <span style="color:red">**[PENDING]**</span> Failed deliveries count
- <span style="color:red">**[PENDING]**</span> Out-of-stock item count
- <span style="color:red">**[PENDING]**</span> Complaints count
- <span style="color:red">**[PENDING]**</span> Average star rating

#### Recent Activity

- <span style="color:red">**[PENDING]**</span> Add a **Recent Activity** bar/widget to the pharmacy dashboard showing the latest actions (order received, order dispatched, etc.).

### 3.2 Sidebar Structure

#### Final Sidebar Order

1\. <span style="color:green">**[DONE]**</span> Dashboard

2\. <span style="color:green">**[DONE]**</span> Awaiting Fulfillment _(new incoming orders)_

3\. <span style="color:green">**[DONE]**</span> Orders _(active / in-progress)_

4\. <span style="color:green">**[DONE]**</span> Inventory

5\. <span style="color:green">**[DONE]**</span> Invoices

6\. <span style="color:green">**[DONE]**</span> Revenue & Analytics

7\. <span style="color:green">**[DONE]**</span> Settings

8\. <span style="color:green">**[DONE]**</span> iCare Pharmacist Support _(chat with iCare team)_

#### Items to Remove from Sidebar

| **Item** | **Action** | **Status** |
| --- | --- | --- |
| My Profile | Remove from sidebar â€” move to **right-side icon** (top-right of screen) | <span style="color:green">**[DONE]**</span> Done |
| My Task | Remove entirely â€” not applicable to pharmacy | <span style="color:green">**[DONE]**</span> Done |
| Supplies | Remove â€” not applicable | <span style="color:green">**[DONE]**</span> Done |
| Analytical Archives | Remove â€” duplicate of Revenue & Analytics | <span style="color:green">**[DONE]**</span> Done |
| Diagnostic Queue | Remove â€” not applicable to pharmacy | <span style="color:green">**[DONE]**</span> Done |
| Clinical Auditing | Remove â€” not applicable to pharmacy | <span style="color:green">**[DONE]**</span> Done |
| Prescriptions | **Rename to "Orders"** â€” then place below "Awaiting Fulfillment" | <span style="color:green">**[DONE]**</span> Done |

#### "Prescriptions" â†’ "Orders"

- <span style="color:green">**[DONE]**</span> The current sidebar item labeled **"Prescriptions"** must be renamed to **"Orders"**.
- <span style="color:red">**[PENDING]**</span> Under the Orders section, add a **"Create Order"** button at the bottom.

#### My Profile â€” Right Side Icon

- <span style="color:green">**[DONE]**</span> My Profile is removed from the left sidebar.
- <span style="color:red">**[PENDING]**</span> It moves to a **profile icon on the right side** (top-right corner of the screen), consistent with how it is handled in other account types.
- <span style="color:red">**[PENDING]**</span> Tapping this icon opens the pharmacy profile / edit profile page.

### 3.3 Order Management Flow

The pharmacy order lifecycle, modeled on Foodpanda:

  
Patient Places Order  
â†“  
Awaiting Fulfillment â†’ Pharmacy receives notification  
â†“  
Pharmacy Accepts Order â†’ Patient status: "Processing"  
â†“  
Pharmacist Prepares Order  
â†“  
Pharmacist Clicks "Dispatch"  
â””â”€ Must enter Expected Delivery Time â† mandatory field, cannot skip  
â†“  
Status: "Out for Delivery"  
â””â”€ Patient receives notification with expected delivery time  
â†“  
Pharmacist marks "Delivered"  
â””â”€ Patient receives "Order Delivered" notification  
â””â”€ Rating prompt sent to patient immediately  

#### Order Details â€” Required Fields

Every incoming order visible to the pharmacist must display:

- <span style="color:red">**[PENDING]**</span> Patient full name
- <span style="color:red">**[PENDING]**</span> Phone / contact number
- <span style="color:red">**[PENDING]**</span> Delivery address
- <span style="color:red">**[PENDING]**</span> Email _(optional â€” auto-filled from login if available)_
- <span style="color:red">**[PENDING]**</span> Order items with quantities
- <span style="color:red">**[PENDING]**</span> Prescription reference (if applicable)
- <span style="color:red">**[PENDING]**</span> Delivery fee
- <span style="color:red">**[PENDING]**</span> Total amount

#### Key Rules

- <span style="color:red">**[PENDING]**</span> **Customer does NOT confirm delivery.** The pharmacist marks the order as delivered. Allowing customers to confirm/deny delivery creates fraud risk (customers falsely claiming non-delivery).
- <span style="color:red">**[PENDING]**</span> **Expected delivery time** is a mandatory field. The pharmacist cannot dispatch an order without entering this.
- <span style="color:red">**[PENDING]**</span> Rating notification is sent **immediately** after the pharmacist marks delivered â€” not after a delay.

#### Order Invoice / Print

- <span style="color:red">**[PENDING]**</span> Every completed order must have a **printable PDF invoice**.
- <span style="color:red">**[PENDING]**</span> Currency displayed: **PKR**
- <span style="color:red">**[PENDING]**</span> Invoice must carry **iCare branding** prominently (logo + "Your Trusted Healthcare Platform").
- <span style="color:red">**[PENDING]**</span> Pharmacy name / branding appears in a secondary position (bottom or smaller).
- <span style="color:red">**[PENDING]**</span> Invoice contains: patient name, items, quantities, unit prices, delivery fee, total (PKR), date.

### 3.4 Controlled Medicines & Quantity Limits

#### Medicine Categories

All medicines in the system are classified into three categories:

| **Category** | **Label in System** | **Description** | **Status** |
| --- | --- | --- | --- |
| **Over-the-Counter (OTC)** | OTC | Freely purchasable | <span style="color:red">**[PENDING]**</span> Pending |
| **Controlled / Restricted** | Controlled (Restricted â€” sleeping pills) | Requires iCare-issued prescription | <span style="color:red">**[PENDING]**</span> Pending |
| **Vaccines** | Vaccines | Requires prior consultation | <span style="color:red">**[PENDING]**</span> Pending |

**Team note:** When labeling controlled medicines, add the colloquial name in brackets for internal clarity, e.g., Controlled (Restricted â€” neend ki goliyan / sleeping pills). No sub-categories within the Controlled group.

#### Controlled Medicine â€” Patient Flow

- <span style="color:red">**[PENDING]**</span> When a patient searches for or taps a controlled medicine (e.g., Alprazolam):

  
Patient taps controlled medicine  
â†“  
System message:  
"This medicine can only be purchased online after consultation  
with our doctor. It is mandatory to have a consultation with  
our doctor."  
â†“  
Button: "Connect to a Doctor Now" / "Book Now"  
â†“  
Patient consults iCare doctor  
â†“  
Doctor issues prescription (with quantity) via platform  
â†“  
Prescription auto-sent to pharmacy â€” quantity as prescribed, no further restriction  

#### Quantity Limiter â€” Self-Purchase (No Prescription)

- <span style="color:red">**[PENDING]**</span> Any customer purchasing **without a prescription** is capped at **30 units maximum** per medicine per order.
    - Basis: 3 doses/day Ã— 10 days = 30 tablets.
- <span style="color:red">**[PENDING]**</span> Attempting to order more than 30 units without a prescription blocks the order and redirects to the consultation flow.

#### Doctor Prescription â€” No Quantity Restriction

- <span style="color:red">**[PENDING]**</span> When a doctor issues a prescription via the iCare platform, **the prescribed quantity passes directly to the pharmacy** with no system-imposed limit.
- <span style="color:red">**[PENDING]**</span> Example: Psychiatrist prescribes 90 tablets (1/day Ã— 3 months) â€” passes through freely because it originates from a verified iCare prescription.
- <span style="color:red">**[PENDING]**</span> The prescription quantity is automatically reflected in the patient's pharmacy cart.
- <span style="color:red">**[PENDING]**</span> The customer cannot increase the quantity beyond what the doctor prescribed.

#### Vaccines

- <span style="color:red">**[PENDING]**</span> Listed under: **"Get Vaccines at Your Doorstep"**
- <span style="color:red">**[PENDING]**</span> Ordering any vaccine requires **prior consultation** â€” same flow as controlled medicines.

### 3.5 Delivery System

#### Delivery Fee

- <span style="color:red">**[PENDING]**</span> Each pharmacy has its own **fixed delivery fee**.
- <span style="color:red">**[PENDING]**</span> Delivery fees are **set by iCare admin** (not editable by the pharmacist in the current phase).
    - Future phase: Allow pharmacists to manage their own delivery fee.
- <span style="color:red">**[PENDING]**</span> Delivery fee is included in and displayed with the order total before the patient confirms checkout.

#### No Third-Party Delivery API (Current Phase)

- <span style="color:red">**[PENDING]**</span> Integration with Bykea, InDrive, Careem, or similar services is **out of scope for the current phase**.
- <span style="color:red">**[PENDING]**</span> Delivery is the pharmacy's own operational responsibility.
- Future partnership with a delivery service may be explored separately.

#### Delivery Tracking

- <span style="color:red">**[PENDING]**</span> Full GPS live tracking is **not in scope** for the current phase.
- <span style="color:red">**[PENDING]**</span> Replacement: Pharmacist enters an **expected delivery time** before dispatching. This time is shown to the patient in the order status screen.

### 3.6 Inventory Management

#### Bulk Upload (Import / Export)

- <span style="color:red">**[PENDING]**</span> Pharmacists can upload their full medicine inventory via an **Excel/CSV bulk import**.
- <span style="color:red">**[PENDING]**</span> The system provides a **downloadable template file** pre-formatted with all required fields.
- <span style="color:red">**[PENDING]**</span> Pharmacist fills the template and uploads â€” all entries auto-populate the inventory.
- <span style="color:red">**[PENDING]**</span> An **Export** option is also available so pharmacists can download their current inventory.

#### E-Mareez Compatibility

- <span style="color:red">**[PENDING]**</span> Many pharmacies use **E-Mareez** for local inventory management.
- <span style="color:red">**[PENDING]**</span> Where feasible, align iCare's import template fields to match E-Mareez's export format so pharmacists can export from E-Mareez and upload directly without reformatting.
- <span style="color:red">**[PENDING]**</span> Obtain a sample E-Mareez export file to verify field alignment.

#### Inventory Fields per Medicine Entry

- <span style="color:red">**[PENDING]**</span> Brand name
- <span style="color:red">**[PENDING]**</span> Generic name (INN)
- <span style="color:red">**[PENDING]**</span> Category (OTC / Controlled / Vaccine)
- <span style="color:red">**[PENDING]**</span> Price (PKR)
- <span style="color:red">**[PENDING]**</span> Stock quantity
- <span style="color:red">**[PENDING]**</span> Unit (tablets, ml, vials, etc.)

#### Pharmacist-Initiated New Order

- <span style="color:red">**[PENDING]**</span> Pharmacists can **manually create a new order** (for walk-in patients or known contacts).
- <span style="color:red">**[PENDING]**</span> Located under **Orders â†’ Create Order**.
- <span style="color:red">**[PENDING]**</span> Controlled drugs: If the pharmacist attempts to add a controlled medicine to a manual order, the system checks the controlled-drug list. The order can only proceed if a valid iCare-generated prescription is linked.
- <span style="color:red">**[PENDING]**</span> The controlled-drug classification list is **maintained by iCare admin** using generic/INN names. Pharmacists cannot reclassify medicines.

### 3.7 Notifications & Ratings

#### Rating System

<span style="color:red">**[PENDING]**</span> After every completed order, a rating prompt is sent **immediately** to the patient:

"How was your experience with this order?"

- <span style="color:red">**[PENDING]**</span> Star rating (1â€“5) + optional written comment.
- Applied to all three service types:

| **Service** | **Prompt** | **Status** |
| --- | --- | --- |
| Consultation | "How was your consultation with Dr. \[Name\]?" | <span style="color:red">**[PENDING]**</span> Pending |
| Pharmacy order | "How was your experience with this order?" | <span style="color:red">**[PENDING]**</span> Pending |
| Lab test | "How was your experience with this lab?" | <span style="color:red">**[PENDING]**</span> Pending |

- <span style="color:red">**[PENDING]**</span> Ratings are **publicly visible** on the pharmacy/lab/doctor profile.

#### Pharmacy Notification Sub-Categories

- <span style="color:red">**[PENDING]**</span> **New Orders** â€” mandatory, cannot be turned off
- <span style="color:red">**[PENDING]**</span> **Order dispatched / Out for Delivery**
- <span style="color:red">**[PENDING]**</span> **Delivery status updates**
- <span style="color:red">**[PENDING]**</span> System alerts
- <span style="color:red">**[PENDING]**</span> Remove: Booking updates (patient-facing, not applicable here)

### 3.8 Profile & Settings

#### Pharmacy Profile (Accessed via Right-Side Icon)

Required fields:

- <span style="color:red">**[PENDING]**</span> Pharmacy name
- <span style="color:red">**[PENDING]**</span> **Drug Sale License number** â€” mandatory
- <span style="color:red">**[PENDING]**</span> Branch address
- <span style="color:red">**[PENDING]**</span> Contact number
- <span style="color:red">**[PENDING]**</span> Operating hours
- <span style="color:red">**[PENDING]**</span> DRAP compliance checkbox (linked to DRAP policy page)
- <span style="color:red">**[PENDING]**</span> No "Health Details" section â€” not applicable to pharmacy

#### Bank / Account Details

- <span style="color:red">**[PENDING]**</span> Not editable within the app.
- <span style="color:red">**[PENDING]**</span> To update banking details, pharmacist must contact iCare head office.
- <span style="color:red">**[PENDING]**</span> Reason: Prevents accidental or unauthorized payment misdirection.

#### Change Password

- <span style="color:red">**[PENDING]**</span> Flow: **Old password â†’ New password â†’ Confirm new password**

#### Settings Page â€” Items to Remove

The following patient-facing items must be removed from the pharmacy settings page:

- <span style="color:red">**[PENDING]**</span> Health profile / health details
- <span style="color:red">**[PENDING]**</span> Consultation settings
- <span style="color:red">**[PENDING]**</span> Test history
- <span style="color:red">**[PENDING]**</span> Learning / LMS settings
- <span style="color:red">**[PENDING]**</span> Booking updates (notification)

#### Items to Keep / Add

- <span style="color:red">**[PENDING]**</span> Change Password (updated flow as above)
- <span style="color:red">**[PENDING]**</span> Notification preferences (pharmacy-specific, as described in 3.7)
- <span style="color:red">**[PENDING]**</span> Language preferences
- <span style="color:red">**[PENDING]**</span> About / Legal â€” placed **at the bottom** of settings
- <span style="color:red">**[PENDING]**</span> DRAP & drug policy links

#### Support â€” Report an Issue

- <span style="color:red">**[PENDING]**</span> A **"Report an Issue"** form in the help/support section.
- <span style="color:red">**[PENDING]**</span> On submission, the report is sent directly to the iCare admin email.
- <span style="color:red">**[PENDING]**</span> Help center questions must be **pharmacy-specific** â€” remove all patient/consultation-related FAQ entries.

#### iCare Pharmacist Support Chat

- <span style="color:green">**[DONE]**</span> A messaging channel for direct communication with the iCare support team.
- <span style="color:green">**[DONE]**</span> Label: **"iCare Pharmacist Support"**
- <span style="color:red">**[PENDING]**</span> Simple chat thread (like WhatsApp) â€” not a task system.

### 3.9 Onboarding (Work With Us)

The "Work With Us" registration page:

**Step 1 â€” Basic Info:**

- <span style="color:green">**[DONE]**</span> Full name
- <span style="color:green">**[DONE]**</span> Phone number
- <span style="color:green">**[DONE]**</span> Email address
- <span style="color:green">**[DONE]**</span> City

**Step 2 â€” Role Selection:**

"Do you want to work with us as?"

Three buttons:

**<span style="color:green">**[DONE]**</span> \[ Doctor \] \[ Pharmacy \] \[ Laboratory \]**

- <span style="color:green">**[DONE]**</span> Tapping a button opens the **role-specific onboarding form**.
- <span style="color:red">**[PENDING]**</span> Doctor form: Already prepared by client.
- <span style="color:red">**[PENDING]**</span> Pharmacy form: To be provided by client (Maryam).
- <span style="color:red">**[PENDING]**</span> Laboratory form: To be provided by client (Maryam).

**Step 3 â€” Compliance:**

- <span style="color:red">**[PENDING]**</span> DRAP policy agreement checkbox
- <span style="color:red">**[PENDING]**</span> Terms of service acceptance

<span style="color:green">**[DONE]**</span> All form submissions go to the **iCare admin dashboard** and trigger an admin email notification.

## 4\. Laboratory Account Changes

### 4.1 Dashboard & Sidebar

#### Dashboard Stats â€” Display Order

- <span style="color:green">**[DONE]**</span> 1\. **Today**
- <span style="color:green">**[DONE]**</span> 2\. **Total**
- <span style="color:green">**[DONE]**</span> 3\. **Pending**
- <span style="color:green">**[DONE]**</span> 4\. **Completed**

#### Recent Activity

- <span style="color:red">**[PENDING]**</span> Add a **Recent Activity** widget to the lab dashboard (same as pharmacy and doctor).

#### Final Sidebar Order

1\. <span style="color:green">**[DONE]**</span> Dashboard

2\. <span style="color:green">**[DONE]**</span> New Requests / Awaiting Fulfillment

3\. <span style="color:green">**[DONE]**</span> Orders

4\. <span style="color:green">**[DONE]**</span> Test Catalog

5\. <span style="color:red">**[PENDING]**</span> Result Entry _(accessible from within orders)_

6\. <span style="color:green">**[DONE]**</span> Invoices

7\. <span style="color:green">**[DONE]**</span> Revenue & Analytics

8\. <span style="color:green">**[DONE]**</span> Settings

9\. <span style="color:green">**[DONE]**</span> iCare Lab Support _(chat with iCare team)_

#### Items to Remove from Sidebar

| **Item** | **Action** | **Status** |
| --- | --- | --- |
| My Profile | Remove from sidebar â€” move to **right-side icon** (top-right) | <span style="color:green">**[DONE]**</span> Done |
| My Appointments | Remove â€” functionality covered elsewhere | <span style="color:green">**[DONE]**</span> Done |
| Supplies / Supply Chain | Remove â€” not applicable | <span style="color:green">**[DONE]**</span> Done |
| Analytical Archives | Remove â€” duplicate | <span style="color:green">**[DONE]**</span> Done |
| Clinical Archive | Remove â€” not applicable | <span style="color:green">**[DONE]**</span> Done |
| Task | Remove â€” not applicable | <span style="color:green">**[DONE]**</span> Done |
| Settings | Remove from main sidebar â€” accessible from profile/right-side icon area | <span style="color:red">**[PENDING]**</span> Pending (Settings still in sidebar) |

### 4.2 Test Catalog & Orders

#### Test Catalog

- <span style="color:green">**[DONE]**</span> The lab account includes a **Test Catalog** â€” the complete list of tests the lab offers.
- <span style="color:red">**[PENDING]**</span> Each entry: standardized test name, price (PKR), turnaround time, sample type.
- <span style="color:green">**[DONE]**</span> Search bar at the top with **multi-keyword support** â€” typing partial text filters in real time.
- <span style="color:green">**[DONE]**</span> Lab staff can add new tests to their catalog.

#### Standardized Test Nomenclature

- <span style="color:red">**[PENDING]**</span> A **single standardized test name list** is used across all three interfaces: Doctor, Patient, and Lab.
- <span style="color:red">**[PENDING]**</span> Example: Always "CBC" â€” never "Blood CP" in one place and "Complete Blood Profile" in another.
- <span style="color:red">**[PENDING]**</span> The master list of standardized test names will be provided by the client (Maryam).
- <span style="color:red">**[PENDING]**</span> This same list populates the doctor's prescription test selector and the patient's lab search.

#### Create New Order (Lab-Initiated)

- <span style="color:red">**[PENDING]**</span> Lab staff can **manually create a new order** for walk-in patients.
- <span style="color:red">**[PENDING]**</span> Located under **Orders â†’ Create Order**.
- <span style="color:red">**[PENDING]**</span> Fields: Patient name, contact number, address, test(s) selected, in-house or home collection.

#### In-House vs. Home Collection

- <span style="color:red">**[PENDING]**</span> Each order specifies:
    - **In-house** â€” patient visits the lab.
    - **Home visit** â€” lab technician collects sample at patient's location.

### 4.3 Result Entry & Reports

#### Unified Result Entry Page

- <span style="color:red">**[PENDING]**</span> **"Upload Reports"** and **"Result Entry"** are merged into **one page**.
- <span style="color:red">**[PENDING]**</span> Lab staff on this page can:
    - Manually enter test result values for each parameter.
    - Upload a scanned / digital report PDF.
- <span style="color:red">**[PENDING]**</span> If API integration is active for this lab, results auto-populate from the lab's own system.

#### Result Delivery

- <span style="color:red">**[PENDING]**</span> Completed results are pushed to:
    - The **patient** (in-app notification + viewable in patient account).
    - The **referring doctor** if the test was ordered via a doctor's prescription.

#### Invoices

- <span style="color:red">**[PENDING]**</span> Lab invoices display amounts in **PKR**.
- <span style="color:red">**[PENDING]**</span> Invoice carries iCare branding; lab name in secondary position.
- <span style="color:red">**[PENDING]**</span> Downloadable PDF format.

### 4.4 API Integration

#### Purpose

<span style="color:red">**[PENDING]**</span> Major lab chains (Chughtai Lab, Agha Khan, etc.) have their own internal lab management software. API integration allows orders placed on iCare to appear in the lab's system automatically and results to flow back.

#### Approach

<span style="color:red">**[PENDING]**</span> Both manual and API flows must coexist:

| **Scenario** | **Flow** |
| --- | --- |
| Lab has existing software + provides API | Orders and results sync automatically |
| Lab has no existing software | Lab staff use iCare's manual entry and import/export |

- <span style="color:red">**[PENDING]**</span> Each lab chain requires its **own separate API integration** â€” no universal connector.
- Steps to enable API for a lab:

1\. <span style="color:red">**[PENDING]**</span> Lab provides API documentation and credentials.

2\. <span style="color:red">**[PENDING]**</span> iCare dev team reviews and implements the connection.

3\. <span style="color:red">**[PENDING]**</span> An **Import / Export button** is available in the lab account for manual sync when needed.

### 4.5 Revenue & Analytics

<span style="color:red">**[PENDING]**</span> **Revenue & Analytics** is present in all three account types with consistent structure:

| **Account** | **Management Section Label** |
| --- | --- |
| Doctor | Clinical Management |
| Pharmacy | Pharmacy Management |
| Laboratory | Laboratory Management |

Each Revenue & Analytics section contains:

- <span style="color:red">**[PENDING]**</span> Total earnings (PKR)
- <span style="color:red">**[PENDING]**</span> Payout history and pending payouts
- <span style="color:red">**[PENDING]**</span> Order / test volume over time
- <span style="color:red">**[PENDING]**</span> Acceptance rate
- <span style="color:red">**[PENDING]**</span> Completion rate
- <span style="color:red">**[PENDING]**</span> Average patient rating
- <span style="color:red">**[PENDING]**</span> Invoices (downloadable, PKR)

<span style="color:red">**[PENDING]**</span> All payments pass through the iCare payment gateway. Payouts to labs and pharmacies are managed via the iCare admin portal.

#### Laboratory Profile â€” Test Listing

- <span style="color:red">**[PENDING]**</span> The lab's public profile (visible to patients and doctors) must display the **list of tests it offers**, so patients and doctors can confirm availability before booking.
- <span style="color:red">**[PENDING]**</span> Sourced from the lab's own Test Catalog.

### 4.6 Settings & Notifications

#### Lab Profile (Accessed via Right-Side Icon)

Required fields:

- <span style="color:red">**[PENDING]**</span> Lab name
- <span style="color:red">**[PENDING]**</span> License number â€” mandatory
- <span style="color:red">**[PENDING]**</span> Branch address
- <span style="color:red">**[PENDING]**</span> Contact number
- <span style="color:red">**[PENDING]**</span> Operating hours
- <span style="color:red">**[PENDING]**</span> DRAP compliance agreement

#### Notification Preferences (Lab-Specific)

- <span style="color:red">**[PENDING]**</span> **New Test Requests** â€” mandatory, cannot be disabled
- <span style="color:red">**[PENDING]**</span> Sample collection status updates
- <span style="color:red">**[PENDING]**</span> Result upload reminders
- <span style="color:red">**[PENDING]**</span> System alerts
- <span style="color:red">**[PENDING]**</span> Labels use lab-specific language (e.g., "New Test Request" not "New Order")

#### Settings Scope

- <span style="color:red">**[PENDING]**</span> Lab settings show only lab-relevant options â€” no patient-facing or pharmacy-related items.
- <span style="color:red">**[PENDING]**</span> Help / Support section contains **lab-specific FAQ content** only.
- <span style="color:red">**[PENDING]**</span> "Report an Issue" form: Submits to iCare admin email (same mechanism as pharmacy).

## 5\. Cross-Cutting Changes (All Accounts)

### 5.1 My Profile â€” Right Side Icon (All Accounts)

- <span style="color:red">**[PENDING]**</span> In all service-provider accounts (Doctor, Pharmacy, Lab), **My Profile is removed from the left sidebar**.
- <span style="color:red">**[PENDING]**</span> It is accessed via a **profile icon in the top-right corner** of the screen.
- <span style="color:red">**[PENDING]**</span> Tapping the icon opens the account's profile / edit profile page.

### 5.2 Revenue & Analytics â€” All Three Accounts

- <span style="color:green">**[DONE]**</span> Present in Doctor, Pharmacy, and Laboratory accounts.
- <span style="color:red">**[PENDING]**</span> Same internal structure across all three; only the section heading and data labels differ per account type.

### 5.3 Rating & Review System

- <span style="color:red">**[PENDING]**</span> Star rating (1â€“5) + optional written comment.
- <span style="color:red">**[PENDING]**</span> Publicly visible on each doctor, pharmacy, and lab profile.
- <span style="color:red">**[PENDING]**</span> Rating prompt sent immediately after each completed service (consultation, order, or test).
- <span style="color:red">**[PENDING]**</span> Aggregate ratings tracked in Revenue & Analytics.

### 5.4 Invoices â€” Currency

- <span style="color:red">**[PENDING]**</span> All invoices and financial displays across the platform use **PKR** (Pakistani Rupee).

### 5.5 Recent Activity Widget

- <span style="color:red">**[PENDING]**</span> A **Recent Activity** section / widget is added to the dashboard of all service-provider accounts (Doctor, Pharmacy, Lab).
- <span style="color:red">**[PENDING]**</span> Shows the latest actions taken (new order received, result uploaded, appointment completed, etc.).

### 5.6 Onboarding Forms

- <span style="color:green">**[DONE]**</span> Separate onboarding forms for Doctor, Pharmacy, and Laboratory via the "Work With Us" page.
- <span style="color:red">**[PENDING]**</span> Each form ends with DRAP compliance and terms acceptance.
- <span style="color:green">**[DONE]**</span> All submissions route to the iCare admin dashboard + email notification.

### 5.7 Help Center â€” Account-Specific Content

- <span style="color:red">**[PENDING]**</span> Each account type (Doctor, Pharmacy, Lab, Patient) has its own **separate Help Center content**.
- <span style="color:red">**[PENDING]**</span> FAQ questions, support topics, and "Report an Issue" flows are tailored to that account's context.
- <span style="color:red">**[PENDING]**</span> No cross-account content bleed (e.g., pharmacy settings must not show consultation-related help topics).

### 5.8 Settings Pages â€” Account-Specific

- <span style="color:red">**[PENDING]**</span> Every settings page is scoped to its account type.
- <span style="color:red">**[PENDING]**</span> Items not relevant to the account are hidden or removed entirely.

### 5.9 Invoice / PDF Branding

- <span style="color:red">**[PENDING]**</span> All PDFs and printed documents carry **iCare branding** prominently (logo + "Your Trusted Healthcare Platform").
- <span style="color:red">**[PENDING]**</span> The service provider's name (pharmacy / lab) appears in a secondary position.
- <span style="color:red">**[PENDING]**</span> Currency on all invoices: **PKR**.

