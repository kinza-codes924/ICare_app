# iCare App — Doctor Account Urgent Changes
**Meeting Date:** 14 April 2026
**Subject:** Doctor Dashboard, Appointments, Prescription, Availability, Clinical Tools

---

## 1. Doctor Dashboard

### 1.1 Appointment Request Card
- The "Appointment Requests" section heading color should change to **dark green**
- **Accept** and **Reject** buttons need a color update (confirm exact colors with client)

### 1.2 Stats Row — Remove Entirely
The four stats cards currently showing Consultation / Pending / Rating / Satisfaction — **remove the entire row**. No stats cards on the dashboard.

### 1.3 Quick Actions Section — Remove Entirely
The Quick Actions section on the dashboard is to be **completely removed**.

### 1.4 Patient Records (Quick Action) — Move to Admin
The "Patient Records" quick action is removed from the doctor's view.
Patient records will live in the **Admin panel** instead.
The only time a patient record should appear for a doctor is **during an active consultation** — it should surface contextually while the doctor is consulting that specific patient.

### 1.5 Appointments — Move to Clinical Management
The appointments widget/section on the dashboard will move into a **Clinical Management** area rather than appearing as a separate card.

---

## 2. Availability / My Schedule

### 2.1 Weekly Schedule with Time Slots
- Display **Monday through Sunday** as separate tabs
- Doctor can click to add **multiple time slots per day**
- Each day should support multiple named slots: **Slot 1, Slot 2, Slot 3**, and so on
- UI should allow adding and removing slots freely per day

### 2.2 Emergency Appointment
- Add an "Emergency Appointment" option
- Label it **"Coming Soon"** for now — full implementation to be discussed separately

### 2.3 Consultation Durations — Remove from Doctor View
Consultation duration settings should be **removed from the doctor's availability screen**.
This setting will be managed by the **Admin** instead.

### 2.4 Unavailable Dates
- Keep the **Unavailable Dates** feature in the doctor's availability screen as-is

---

## 3. Prescription — New Fields

### 3.1 Refer to Specialist
- Add a **"Refer to Specialist"** field inside the doctor's prescription form
- The **specialty name should be clickable/tappable**
- When the patient opens the prescription and taps the specialty, it should open a list of doctors in that specialty with a **Book Appointment** option — completing the referral flow end-to-end

### 3.2 Follow-Up Scheduling
- Add a **"Follow Up After"** field to the prescription
- Doctor can set follow-up in **days or months** (scrollable selector)
- This should also trigger **next appointment scheduling** directly from the prescription — so the follow-up gets booked without the patient having to do it manually

---

## 4. Online Doctor — Response Time & Assignment Flow

### 4.1 Response Time Metric
- Set a **3-minute response window** for online doctors
- This becomes a quality metric: tracking how quickly each doctor responds to a patient request
- The 3-minute timer applies specifically to **video consultations**

### 4.2 No-Show Handling
If a patient arrives (e.g., 9:30 appointment) and the doctor does not join the video call within 3 minutes:
- The **Admin receives a notification or warning** about the doctor's absence
- Admin can then **call the doctor** or take manual action
- If the doctor is still unavailable, Admin can **reassign the appointment** to another available doctor
- The patient is seamlessly handed to the replacement doctor for the video call

### 4.3 Instant Connect Flow ("Connect to a Doctor")
- When a patient taps "Connect to a Doctor":
  - A notification goes out to **3 nearby/available doctors simultaneously**
  - Whichever doctor **accepts first** gets the appointment
  - Connection is **immediate and instant** — no waiting queue

---

## 5. Clinical Revenue & Analytics

### 5.1 Earnings Display
- Show the **previous month's earnings** prominently
- Show **total net earnings up to the current date** (cumulative)
- A clear formula/calculation should be visible behind the numbers

### 5.2 Commission Structure
- The commission logic needs to be implemented at the **backend level**
- Client (the business team) will provide the exact commission formula and breakdown
- Revenue details and structure will be clarified directly by the client — do not assume values

### 5.3 Patient Distribution Widget
- **Remove** from the doctor's dashboard
- Patient distribution data belongs in the **Admin panel** only

---

## 6. Clinical Audit — Flags & QA Reviews

### 6.1 Clinical Flags Panel
- Add a **Clinical Flags & QA Reviews** section (likely in the doctor's clinical area)
- This panel highlights quality and compliance issues automatically

### 6.2 Missing SOAP Notes Alerts
- The system should automatically flag **incomplete or missing SOAP notes** for appointments
- Example flag entry:
  - *"Missing SOAP notes for Appointment #821"*
  - *"Missing SOAP notes for appointment with Fahad at 9:30 PM"*
- Each flag should be **clickable** — tapping it opens the relevant appointment record so the doctor can complete the notes
- The panel shows a count: e.g., *"2 incomplete SOAP notes found"*
- This is a **highlight/alert system only** — it surfaces issues, not a full records editor

---

## 7. Specialist Forum — Start a Discussion

Inside the "Start a Discussion" feature in the Specialist Forum:
- Add **picture/image upload** option
- Add **document attachment** option

---

## 8. Certificate Section

- Add an **"Add a Document"** button in the Certificate section
- Uploaded document should display with a **white background and readable text**

---

## 9. Pending Decisions (Needs Client Confirmation)

| Topic | Status | Notes |
|-------|--------|-------|
| Programs Linked section | Undecided | Client to confirm whether to keep or remove this section from the doctor's view |
| Accept/Reject button exact colors | Undecided | Need specific color values from client |
| Commission formula details | Pending | Client (business team) will provide the formula |
| Emergency Appointment full flow | Deferred | "Coming Soon" label for now, full design to be discussed |

---

*Notes compiled: 14 April 2026*
*Source: Doctor account client meeting — raw notes organized*
