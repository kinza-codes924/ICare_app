# iCare Project - Client Meeting Documentation
**Date:** May 4, 2026  
**Project:** iCare (Telehealth & Learning Management Platform)  
**Meeting Type:** Client Requirements & Change Requests

---

## Table of Contents
1. [Video Consultation Flow](#video-consultation-flow)
2. [Prescription Management](#prescription-management)
3. [Patient & Doctor Dashboard](#patient--doctor-dashboard)
4. [Lab Tests & Pharmacy Integration](#lab-tests--pharmacy-integration)
5. [Health Tracker & Health Journey](#health-tracker--health-journey)
6. [User Registration & Sign-in](#user-registration--sign-in)
7. [LMS Integration](#lms-integration)
8. [Settings & Configuration](#settings--configuration)
9. [Technical Requirements](#technical-requirements)

---

## 1. Video Consultation Flow

### 1.1 Consultation Initiation
- **Connect Now** option available for instant consultation
- Two options:
  - **For Myself**: Auto-fills patient profile data (name, gender, age)
  - **For Someone Else**: Allows manual entry of patient details

### 1.2 Reason for Consultation
- **Status**: Changed from Mandatory to **Optional**
- **Rationale**: Some patients may not know how to describe symptoms
- **Note**: "I certify that all the information I provided is correct" - **REMOVE** (already covered in terms & conditions during sign-up)

### 1.3 Chat-First Approach
**IMPORTANT CHANGE**: Video call will NOT start automatically
- Consultation starts with **Chat** first
- Chat screen includes:
  - Doctor's name
  - Patient's name
  - Chat box with message input
  - Attachment option (for images/files)
  - Send button
  - **Voice Call** button
  - **Video Call** button
  - **Timer** (consultation duration)
  - **End Consultation** button

### 1.4 Consent Message
- Automatic message sent at chat start
- Template: "Hi, I am Dr. [Name]. I confirm that telehealth has limitations and some emergencies require in-person visits."
- **Action Required**: Client to provide exact consent message text

### 1.5 Video Call Controls
**Two Buttons Required:**

#### Red Button (Leave Video)
- **Function**: Temporarily leave video call
- **Behavior**: Shows "Rejoin" option
- **Confirmation**: Add popup - "Do you want to leave video?"

#### Purple Button (End Consultation)
- **Function**: Permanently end consultation
- **Behavior**: Cannot rejoin after this
- **Confirmation**: Add popup - "Do you want to end consultation?"
- **Icon Change**: Use camera icon instead of stop icon

### 1.6 Consultation Duration
- **Minimum**: 10 minutes (cannot end before this)
- **Maximum**: 30 minutes (auto-ends after this)
- **Timer**: Display consultation time at top

---

## 2. Prescription Management

### 2.1 In-Consultation Prescription
**CRITICAL CHANGE**: Prescription must be created **during** consultation, not after

#### Prescription Button
- Add "Prescription" button **within video/chat interface**
- Opens prescription form in same view
- Doctor can fill while consulting

#### Prescription Form Structure (In Order):
1. **Patient History** (new tab)
   - Form to be provided by client
   - Includes: general history, examination notes
   
2. **SOAP Notes** (new tab)
   - Subjective
   - Objective
   - Assessment
   - Plan

3. **Doctor Notes** (renamed from "Diagnosis Notes")
   - Free text field for doctor's observations

4. **Diagnosis** (clickable heading with dropdown)
   - ICD-10 codes integrated
   - Searchable dropdown
   - Multiple diagnoses can be added

5. **Medications** (clickable heading)
   - Medicine name (searchable dropdown)
   - Dose options: BD, TDS, QID, etc. (dropdown)
   - Duration: dropdown with days/weeks/months
   - Notes (optional)
   - **"+ Add Medicine"** button for multiple entries
   - Each medicine shows as separate line with minus (-) button to remove

6. **Lab Tests** (clickable heading)
   - Search bar for test names
   - Common tests with checkboxes:
     - CBC
     - Blood Glucose Fasting
     - Lipid Profile
     - LFTs (Liver Function Tests)
     - RFTs (Renal Function Tests)
   - Selected tests appear in list
   - **Remove "Use Template"** option

7. **Referral & Follow-up** (new section)
   - Refer to Emergency/Hospital
   - Refer to Specialist
   - Follow-up options: 15 days, 1 month, etc. (dropdown)

8. **Course Assignment** (new section)
   - Option to assign health awareness videos/courses to patient

### 2.2 Prescription Completion Rules
- **Save** button: Saves draft (can edit later during consultation)
- **Cannot end consultation** until prescription is complete
- If doctor tries to end without completing prescription → Show error popup
- Once consultation ends → Prescription auto-publishes to patient

### 2.3 Prescription Display (Patient Side)
**Format**: Single-page PDF-style view

**Header Section:**
- Patient Information: Name, Age, Gender, MR Number, Date & Time
- Doctor Information: Name, PMDC License Number, Phone Number

**Body Section:**
- Diagnosis
- Medications (with dose and duration)
- Lab Tests
- Doctor Notes/Instructions

**Footer Section:**
- **Order Medicine** button (links to pharmacy)
- **Order Lab Tests** button (links to lab)

### 2.4 Prescription Standards
- **Medicine Database**: British Pharmacopoeia (client to provide)
- **Lab Tests**: Standard catalogue (client to provide)
- **ICD-10 Codes**: Already integrated

---

## 3. Patient & Doctor Dashboard

### 3.1 Patient History Access
**During Consultation:**
- Doctor can view patient's past consultation history
- Includes: previous prescriptions, SOAP notes, diagnoses
- **After Consultation**: Doctor loses access to patient records

**Past Consultations Tab:**
- Rename "Patient History" → **"Past Consultations"**
- Shows all previous consultations with this patient
- Clickable to view details

### 3.2 My Prescriptions (Patient Side)
**Latest Prescription (30 days):**
- Full prescription view with "Order" buttons active
- Can order medicines and lab tests directly

**Older Prescriptions (30+ days):**
- View-only mode
- No order buttons
- Can print/download PDF

### 3.3 Doctor Dashboard
**Pending Requests:**
- Shows instant consultation requests
- 3-minute waiting time for doctor to accept
- Notification with patient details

**Appointment Management:**
- Upcoming appointments
- Completed consultations
- Rejected requests

---

## 4. Lab Tests & Pharmacy Integration

### 4.1 Unified Flow
**IMPORTANT**: Lab and Pharmacy should have **same design flow** on both doctor and patient sides

### 4.2 Lab Test Ordering
**From Prescription:**
1. Patient clicks "Order Lab Tests"
2. Single-page form opens with:
   - Selected tests (from prescription)
   - Option to add more tests (search bar)
   - Lab selection (nearest or search by location)
   - Service type:
     - **Home Sample Collection** (with address)
     - **Visit Lab** (lab address shown)
   - Patient details (auto-filled)
   - Payment

**Direct Lab Booking (without prescription):**
- Patient can search and book tests directly
- Same flow as above

### 4.3 Pharmacy/Medicine Ordering
**From Prescription:**
1. Patient clicks "Order Medicine"
2. Single-page form with:
   - Prescribed medicines listed
   - Pharmacy selection (nearest or search)
   - Delivery options:
     - **Home Delivery** (with address)
     - **Self Pickup** (pharmacy address shown)
   - Patient details (auto-filled)
   - Payment

**Direct Medicine Order:**
- E-commerce functionality for browsing medicines
- Upload prescription option
- Cart functionality

### 4.4 Order Tracking
**New Sections Required:**
- **My Lab Tests**: Order history and status
- **My Medicines**: Order history and status

---

## 5. Health Tracker & Health Journey

### 5.1 Health Tracker
**Purpose**: Patient manually enters health data

**Vitals to Track:**
- Blood Pressure (BP)
- Blood Sugar
- Weight (kg/pounds - both options)
- Heart Rate
- Water Intake
- Steps
- Sleep
- Medication Adherence

**Data Storage:**
- Indefinite storage (as long as patient uses app)
- Each entry with timestamp
- Viewable as table/graph

### 5.2 Health Journey
**Purpose**: Personalized health dashboard based on conditions

**Health Mode Toggle:**
- New button in Settings: "Health Mode"
- Patient selects conditions: Diabetes, Hypertension, etc.
- When ON: Health Journey shows only relevant data
- When OFF: Shows all data

**Difference from Health Tracker:**
- Health Tracker = Manual data entry
- Health Journey = Filtered view based on selected conditions

---

## 6. User Registration & Sign-in

### 6.1 Sign-in Page
**Single Sign-in for All Roles:**
- Email/Password
- Sign in with Google
- Sign in with Apple ID (add this option)
- Backend auto-detects user role and opens appropriate dashboard

### 6.2 Sign-up Options
**Two Main Buttons:**

#### Button 1: "Patient Sign-up"
- Simple form: Name, Email, Phone, Password
- Email verification (to be implemented)
- Phone verification (to be implemented)
- Terms & Conditions checkbox

#### Button 2: "For Professionals and Students"
- Replaces "Work with Us"
- Opens role selection page

### 6.3 Professional Registration Flow
**Step 1: Select Your Role**
- Doctor
- Pharmacy
- Laboratory
- Instructor
- Student

**Step 2: Basic Information**
- Name, Age, Gender, City
- Contact Person Name (for organizations)
- Phone, Email

**Step 3: Role-Specific Details**

#### Doctor Registration:
- Professional Details:
  - Qualification (mandatory)
  - Specialization
  - PMDC Number (mandatory)
  - Years of Experience
  - Current Workplace
- Availability:
  - Days
  - Time slots (30-minute intervals)
- Document Upload (multi-upload):
  - Picture (passport size)
  - CNIC (front & back)
  - Valid PMDC Certificate
  - MBBS/BDS Degree (mandatory)
  - Post-graduate Qualifications (optional, multiple)
  - CV (mandatory)
- Agreement:
  - Single checkbox: "I agree to terms and conditions"

#### Pharmacy Registration:
- Business Name
- Drug License Number
- Pharmacist Name
- Years of Operation
- Location: Address, City
- Contact Number (mandatory)
- Alternative Contact (optional)
- Document Upload:
  - CNIC
  - Drug License
  - Business Registration
- API Integration:
  - Checkbox: "Willing to integrate with iCare platform"
- Agreement checkbox

#### Laboratory Registration:
- Lab Name
- License Number
- Location: Address, City
- Contact Number (mandatory)
- Alternative Contact (optional)
- LIS (Lab Information System) details
- Document Upload:
  - CNIC
  - Lab License
  - Accreditation Certificates
- API Integration checkbox
- Agreement checkbox
- **Remove**: Test list upload (will use standard catalogue)

#### Student Registration:
- Name, Email, Phone, Password
- Educational Institute (optional)
- Degree/Program (optional)
- **Simple form** - minimal information required
- By default, student also becomes "patient" (can access telehealth)

#### Instructor Registration:
- **Only doctors can be instructors**
- Instructor option appears in doctor's dashboard
- Separate email NOT required
- Doctor can switch between roles

### 6.4 Role Assignment Logic
- Patient: Auto-approved, instant access
- Doctor/Pharmacy/Lab: Admin approval required
- Student: Auto-approved after payment (for courses)
- Instructor: Only accessible to approved doctors

---

## 7. LMS Integration

### 7.1 Current Status
**LMS is 20% complete** - Major work required

### 7.2 Reference Platforms
Study and implement features from:
- **Moodle** (primary reference)
- **Open edX**
- **Chamilo**
- **Sakai**
- Google Classroom
- Coursera
- Udemy

### 7.3 Required Features

#### For Students:
- Course browsing (without login)
- Course purchase flow:
  1. Select course
  2. View details and price
  3. "Buy Now" → Simple sign-up form (Name, Email, Phone, Password)
  4. Payment
  5. Limited access (only purchased course visible)
  6. Document verification request
  7. Full LMS access after admin approval
- Learning Dashboard
- My Courses
- Grades
- Assignments (upload/submit)
- Quizzes/Assessments
- Live Sessions
- Course Progress Tracking
- Attendance Tracking

#### For Instructors:
- Course Creation
- Content Upload (videos, documents, presentations)
- Quiz/Assignment Creation
- Grading System
- Student Progress Monitoring
- Live Session Scheduling
- Feedback System

#### For Admin:
- Student Verification
- Course Approval
- Instructor Management
- Analytics Dashboard
- Payment Management

### 7.4 Integration with Main App
- **"My Learning"** button in all user dashboards (Doctor, Patient, Pharmacy, Lab)
- Clicking opens LMS student portal
- **"Telehealth"** button in student dashboard (links to patient services)
- Instructor portal accessible only to doctors (separate menu item)

---

## 8. Settings & Configuration

### 8.1 Patient Settings
**Profile:**
- Name, Age, Gender
- Phone, Email (with verification badges)
- Address
- Emergency Contacts (add from here, display in profile)

**Consultation Settings:**
- Notification preferences
- Preferred language (Urdu/English)

**Health Mode:**
- Toggle ON/OFF
- Select conditions: Diabetes, Hypertension, General
- Affects Health Journey display

**Other:**
- Terms & Conditions
- Privacy Policy
- Help & Support
- App Version

### 8.2 Doctor Settings
**Profile:**
- Professional details
- Availability schedule
- Consultation fees

**Consultation Settings:**
- Online/Offline toggle
- **Instant Consultation toggle** (separate from online status)
  - Online only = Available for scheduled appointments
  - Instant ON = Available for immediate consultations

**Instructor Settings:**
- Course management
- Student management

### 8.3 Pharmacy/Lab Settings
- Business information
- Operating hours
- Service areas
- API integration status

---

## 9. Technical Requirements

### 9.1 Standards & APIs
- **Medicine Database**: British Pharmacopoeia
- **Lab Tests**: Standard catalogue (client to provide)
- **ICD-10 Codes**: Integrated
- **Payment Gateway**: To be integrated
- **Email Service**: To be integrated (verification emails)
- **SMS Service**: To be integrated (phone verification)

### 9.2 Multi-language Support
- **Primary**: English
- **Secondary**: Urdu
- Language toggle in settings
- All UI elements should support both languages

### 9.3 Document Formats
- Prescriptions: PDF format
- Email delivery of prescriptions
- In-app viewing

### 9.4 Security & Privacy
- Email verification mandatory
- Phone verification mandatory
- 2FA (Two-Factor Authentication) - optional
- Biometric login (device-level, not app-level)
- Data encryption
- HIPAA compliance considerations

### 9.5 Notifications
**Appointment Reminders:**
- 1 hour before
- 10 minutes before

**Consultation Notifications:**
- Doctor: Instant consultation request (3-minute window)
- Patient: Doctor accepted/rejected
- Both: Consultation started/ended

**Order Notifications:**
- Order confirmed
- Order dispatched
- Order delivered

---

## 10. UI/UX Changes

### 10.1 Color Scheme
- **Labs**: Orange theme
- **Pharmacy**: Blue theme
- **Conditions**: Purple theme (for cancer, etc.)
- Consistent color coding throughout app

### 10.1 Icons
- Use relevant icons for specialties (heart for cardiology, brain for neurology, etc.)
- Skin icon for dermatology
- Eye icon for ophthalmology

### 10.3 Buttons & Navigation
- Clear, consistent button placement
- Minimize clicks (single-page forms where possible)
- Back button functionality on all screens
- Hamburger menu for side navigation

### 10.4 Forms
- Auto-fill wherever possible
- Dropdown menus for standard options
- Search functionality for long lists
- Multi-select where applicable
- Clear validation messages

---

## 11. Pending Items & Action Required

### 11.1 From Client
- [ ] Consent message text (for chat start)
- [ ] Patient history form template
- [ ] SOAP notes form template
- [ ] Medicine database (British Pharmacopoeia)
- [ ] Lab tests catalogue
- [ ] Terms & Conditions document
- [ ] Privacy Policy document
- [ ] Verification process policy
- [ ] Instructor course assignment details
- [ ] Screenshots for chat interface design

### 11.2 Development Tasks
- [ ] Chat-first consultation flow
- [ ] In-consultation prescription form
- [ ] Prescription PDF generation
- [ ] Lab/Pharmacy unified flow
- [ ] Health Tracker implementation
- [ ] Health Journey with toggle
- [ ] Role-based registration
- [ ] LMS integration (80% target for next meeting)
- [ ] Email/SMS verification
- [ ] Payment gateway integration
- [ ] Multi-language support
- [ ] Notification system

### 11.3 Design Tasks
- [ ] Chat interface mockup
- [ ] Prescription layout (Aga Khan style reference)
- [ ] Single-page forms for lab/pharmacy
- [ ] Health Journey dashboard
- [ ] LMS student/instructor portals
- [ ] Registration flow screens

---

## 12. Meeting Notes & Decisions

### 12.1 Key Decisions
1. **Chat-first approach** instead of direct video call
2. **Prescription during consultation** (not after)
3. **Unified flow** for lab and pharmacy on both sides
4. **Health Mode toggle** for personalized health journey
5. **Single sign-in** for all roles (backend detection)
6. **Student = Patient** by default (can access telehealth)
7. **Instructor = Doctor only** (no separate email needed)
8. **30-day active prescription** window for ordering

### 12.2 Removed Features
- "I certify..." checkbox (covered in T&C)
- "Use Template" for lab tests
- Test list upload for laboratories
- Separate sign-in pages for different roles
- Agreement section in registration (moved to single checkbox)

### 12.3 Renamed Items
- "Patient History" → "Past Consultations"
- "Diagnosis Notes" → "Doctor Notes"
- "Work with Us" → "For Professionals and Students"
- "Partner Type" → "Select Your Role"

---

## 13. Timeline & Next Steps

### 13.1 Next Meeting
- **Target**: Weekend
- **Deliverables**:
  - All current changes implemented
  - LMS 70-80% complete
  - Aesthetic improvements
  - Functional testing complete

### 13.2 Priority Order
1. Chat-first consultation flow
2. In-consultation prescription
3. Registration flow with role selection
4. Lab/Pharmacy unified design
5. Health Tracker & Health Journey
6. LMS integration
7. Settings & configuration
8. Email/SMS verification
9. Payment gateway

---

## 14. Technical Notes

### 14.1 Development Approach
- Frontend: React Native / Flutter (mobile app)
- Backend: Node.js / Python
- Database: PostgreSQL / MongoDB
- File Storage: AWS S3 / Cloud Storage
- Video Calls: WebRTC / Agora / Twilio
- Chat: Socket.io / Firebase
- Payment: Stripe / Local payment gateways

### 14.2 Testing Requirements
- Unit testing for all modules
- Integration testing for consultation flow
- User acceptance testing (UAT)
- Performance testing (load testing for video calls)
- Security testing (penetration testing)

### 14.3 Deployment
- Staging environment for client review
- Production deployment after final approval
- App store submission (iOS & Android)
- Web portal for admin

---

## 15. Contact & Communication

### 15.1 Communication Channels
- WhatsApp group for quick updates
- Email for formal documentation
- Weekly meetings for progress review
- Screen recordings for complex features

### 15.2 Documentation
- Meeting minutes (MOM) after each meeting
- Change request log
- Technical specification document
- User manual (to be created)
- API documentation (to be created)

---

**Document Version**: 1.0  
**Last Updated**: May 4, 2026  
**Prepared By**: Development Team  
**Reviewed By**: Client

---

## Appendix A: Glossary

- **MR Number**: Medical Record Number (unique patient identifier)
- **PMDC**: Pakistan Medical and Dental Council
- **ICD-10**: International Classification of Diseases, 10th Revision
- **SOAP**: Subjective, Objective, Assessment, Plan (medical documentation format)
- **LMS**: Learning Management System
- **LIS**: Laboratory Information System
- **API**: Application Programming Interface
- **2FA**: Two-Factor Authentication
- **UAT**: User Acceptance Testing

---

## Appendix B: Reference Documents

1. Aga Khan Hospital Prescription Format (provided by client)
2. British Pharmacopoeia (medicine database)
3. ICD-10 Code List
4. Moodle LMS Documentation
5. Open edX Documentation
6. HIPAA Compliance Guidelines

---

**End of Document**
