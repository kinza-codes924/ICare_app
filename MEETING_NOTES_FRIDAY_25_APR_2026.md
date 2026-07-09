# iCare — Friday Meeting Notes (25 April 2026)

**Next Meeting:** Tuesday, 29 April 2026
**Deadline:** All 4 modules (Doctor, Patient, Lab, Pharmacy) — 100% done by Tuesday

---

## Pending Items

- Standardized **Lab Test Names** list required (for master dropdown)
- **Diagnosis Codes** list required (ICD or custom)

---

## 1. Patient Account

### Appointments Page — Restore Old Design

Revert to the previous **Bookings History** page design. Details:
- Dark navy header with calendar icon
- Title: **Bookings History**
- Subtitle: *Stay on top of your schedule with real-time updates*
- 3 stat pills at top: `Total` | `Active` | `Done`
- Category rows (icon + title + subtitle + count badge + arrow `>`):
  - In Progress Bookings — *Currently active appointments*
  - Upcoming Bookings — *Scheduled for later*
  - Cancelled Bookings — *Appointments you cancelled*
  - Completed Bookings — *Past successful visits*
  - Pending Bookings — *Awaiting confirmation*

---

### My Prescription — Consultation Flow (New Feature)

After doctor completes consultation and writes prescription, patient opens **My Prescription** and sees:

```
My Prescription
│
├── Tests Section
│   ├── List of all tests prescribed by doctor
│   └── [Find Labs] button
│       └── Opens labs where these tests are available
│           (Patient's choice: book online or visit in person)
│
└── Medicines Section
    ├── List of all medicines prescribed by doctor
    └── [Find Pharmacies] button
        └── Opens pharmacies carrying these medicines
            (Patient's choice: book online or visit in person)
```

---

## 2. Doctor Account

### Prescription Form Changes

**Diagnosis field:**
- Change from plain text to searchable dropdown
- Doctor types partial name → suggestions appear → click to select
- Must have **"Other"** option for custom entry
- Order on prescription: **Symptoms first → Diagnosis at bottom**

**Duration field (in templates):**
- Change text input to dropdown: **Days / Months / Years**

**Remove from prescription form:**
- Remove "Referral to Lab" button
- Remove "Referral to Pharmacy" button
(Patient will find labs/pharmacies themselves via My Prescription flow)

**Vital signs:**
- Move to **History** section, not main prescription

**Medicines field:**
- Searchable dropdown (same approach as diagnosis)
- "Other" option for unlisted medicines

**Lab Tests in prescription:**
- Searchable dropdown from admin-uploaded list
- "Other" option available
- Admin will upload the list (Dr. Sahab to provide)

---

### Admin Panel — Diagnosis Codes

- Add section: **Diagnosis Codes**
- Admin can add entries: `Code + Disease Name`
- These populate the diagnosis dropdown in prescription
- Start with most common diagnoses, add more over time

---

### Admin Panel — Lab Test Master List

- Add section: **Lab Tests Master List**
- Admin uploads standardized test names
- These populate the lab tests dropdown in prescription

---

## 3. Lab Account

### Report / Order Form

| Field | Notes |
|-------|-------|
| Patient Name, Age, Gender, Contact | Non-editable when order comes from app; editable for walk-in |
| Address | Rename "Location" field → **Address** |
| MR Number | Lab staff enters manually |
| Referred by Doctor | Show doctor name if referred |
| Test Prescription Date | — |
| Test Name(s) | — |
| Specimen ID | Allow multiple |
| Sample Collection Type | See below |
| Urgency | Options: 1, 2, 4, 6, 12, 24 hours |
| Turn Around Time (Normal) | Options: 2h, 4h, 6h, 12h, 1d, 2d, 3d, 4d, 5d, 7d |

---

### Sample Collection Type — Show on Accepted Booking

When lab views an **Accepted** booking, clearly display whether it is:
- `In Lab` — patient is coming to the lab
- `Home Collection` — lab must go to patient

Add a visible label/badge on the accepted booking card. Currently stored in backend but not shown on frontend.

---

### Cancellation — Mandatory Reason

When lab cancels a booking/order, a **reason field is mandatory** before cancellation can be submitted.

---

### Invoices / Finance

- **Platform Fee:** Visible only to admin — sets iCare's cut
- **Cash Held with Labs** logic:
  - Value is **negative** → label shows: *Amount Payable to iCare*
  - Value is **positive** → label shows: *Amount Payable to Lab*

---

## 4. Aesthetic Changes (After Functionality)

To be done in one batch after all functionality is complete:

1. **Banner:** Girl's figure is too large — head is cropped. Make figure slightly smaller so full head is visible
2. **Logo bar:** Remove the grey horizontal divider line below the navigation bar
3. **Logo badge on coat:** Position iCare logo badge on the coat like embroidery — over the stethoscope/coat area

---

## 5. Complete Consultation Flow (End-to-End)

```
Patient books appointment with Doctor
          ↓
Doctor accepts appointment
          ↓
Consultation happens
          ↓
Doctor writes prescription:
  - Symptoms
  - Diagnosis (dropdown)
  - Medicines (dropdown)
  - Lab Tests ordered
          ↓
Patient opens My Prescription
  - Sees all medicines + all tests
          ↓
Patient clicks [Find Labs]            Patient clicks [Find Pharmacies]
→ Labs with those tests shown         → Pharmacies with medicines shown
→ Book online or visit in person      → Order online or visit in person
          ↓                                       ↓
Lab receives order                    Pharmacy receives order
→ Processes sample                    → Fulfills prescription
→ Uploads report                      → Marks complete
→ Status: Completed
```

---

## 6. LMS

- LMS full review scheduled for **Tuesday or within 2–3 days after video issue resolved**
- No LMS changes finalized yet in this meeting

---

## 7. Deferred Items

| Item | Status | Reason |
|------|--------|--------|
| Dependent/family member accounts with separate MR numbers | Deferred — discuss later | Requires full data structure rebuild |
| Video consultation | Pending fix (~2–3 days) | Video code conflict between LMS lessons and consultation |
| Video/third-party cost breakdown document | To be sent by team | — |
