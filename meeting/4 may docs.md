iCare Project - Client Meeting Documentation
Date: May 4, 2026
Project: iCare (Telehealth & Learning Management Platform)
Meeting Type: Client Requirements & Change Requests
________________________________________
Table of Contents
1.	Video Consultation Flow
2.	Prescription Management
3.	Patient & Doctor Dashboard
4.	Lab Tests & Pharmacy Integration
5.	Health Tracker & Health Journey
6.	User Registration & Sign-in
7.	LMS Integration
8.	Settings & Configuration
9.	Technical Requirements
________________________________________
1. Video Consultation Flow
1.1 Consultation Initiation
<span style="color:green">**[DONE]**</span> Connect Now option available for instant consultation
<span style="color:green">**[DONE]**</span> Two options:
•	<span style="color:green">**[DONE]**</span> For Myself: Auto-fills patient profile data (name, gender, age)
•	<span style="color:green">**[DONE]**</span> For Someone Else: Allows manual entry of patient details
1.2 Reason for Consultation
•	<span style="color:green">**[DONE]**</span> Status: Changed from Mandatory to Optional
•	<span style="color:green">**[DONE]**</span> Rationale: Some patients may not know how to describe symptoms
•	<span style="color:green">**[DONE]**</span> Note: "I certify that all the information I provided is correct" - REMOVE (already covered in terms & conditions during sign-up)
1.3 Chat-First Approach
IMPORTANT CHANGE: Video call will NOT start automatically
<span style="color:green">**[DONE]**</span> Consultation starts with Chat first
<span style="color:green">**[DONE]**</span> Chat screen includes:
•	<span style="color:green">**[DONE]**</span> Doctor's name
•	<span style="color:green">**[DONE]**</span> Patient's name
•	<span style="color:green">**[DONE]**</span> Chat box with message input
•	<span style="color:green">**[DONE]**</span> Attachment option (for images/files)
•	<span style="color:green">**[DONE]**</span> Send button
•	<span style="color:green">**[DONE]**</span> Voice Call button
•	<span style="color:green">**[DONE]**</span> Video Call button
•	<span style="color:green">**[DONE]**</span> Timer (consultation duration)
•	<span style="color:green">**[DONE]**</span> End Consultation button
1.4 Consent Message
•	<span style="color:red">**[PENDING]**</span> Automatic message sent at chat start
•	<span style="color:red">**[PENDING]**</span> Template: "Hi, I am Dr. [Name]. I confirm that telehealth has limitations and some emergencies require in-person visits."
•	<span style="color:red">**[PENDING]**</span> Action Required: Client to provide exact consent message text
1.5 Video Call Controls
Two Buttons Required:
<span style="color:red">**[PENDING]**</span> Red Button (Leave Video)
•	Function: Temporarily leave video call
•	Behavior: Shows "Rejoin" option
•	Confirmation: Add popup - "Do you want to leave video?"
<span style="color:red">**[PENDING]**</span> Purple Button (End Consultation)
•	Function: Permanently end consultation
•	Behavior: Cannot rejoin after this
•	Confirmation: Add popup - "Do you want to end consultation?"
•	Icon Change: Use camera icon instead of stop icon
1.6 Consultation Duration
•	<span style="color:red">**[PENDING]**</span> Minimum: 10 minutes (cannot end before this)
•	<span style="color:red">**[PENDING]**</span> Maximum: 30 minutes (auto-ends after this)
•	<span style="color:green">**[DONE]**</span> Timer: Display consultation time at top
________________________________________
2. Prescription Management
2.1 In-Consultation Prescription
CRITICAL CHANGE: Prescription must be created during consultation, not after
Prescription Button
•	<span style="color:green">**[DONE]**</span> Add "Prescription" button within video/chat interface
•	<span style="color:green">**[DONE]**</span> Opens prescription form in same view
•	<span style="color:green">**[DONE]**</span> Doctor can fill while consulting
Prescription Form Structure (In Order):
1.	<span style="color:green">**[DONE]**</span> Patient History (new tab)
•	Form to be provided by client
•	Includes: general history, examination notes
1.	<span style="color:green">**[DONE]**</span> SOAP Notes (new tab)
•	Subjective
•	Objective
•	Assessment
•	Plan
1.	<span style="color:green">**[DONE]**</span> Doctor Notes (renamed from "Diagnosis Notes")
•	Free text field for doctor's observations
1.	<span style="color:green">**[DONE]**</span> Diagnosis (clickable heading with dropdown)
•	ICD-10 codes integrated
•	Searchable dropdown
•	Multiple diagnoses can be added
1.	<span style="color:green">**[DONE]**</span> Medications (clickable heading)
•	Medicine name (searchable dropdown)
•	Dose options: BD, TDS, QID, etc. (dropdown)
•	Duration: dropdown with days/weeks/months
•	Notes (optional)
•	"+ Add Medicine" button for multiple entries
•	Each medicine shows as separate line with minus (-) button to remove
1.	<span style="color:green">**[DONE]**</span> Lab Tests (clickable heading)
•	Search bar for test names
•	Common tests with checkboxes:
o	CBC
o	Blood Glucose Fasting
o	Lipid Profile
o	LFTs (Liver Function Tests)
o	RFTs (Renal Function Tests)
•	Selected tests appear in list
•	Remove "Use Template" option
1.	<span style="color:red">**[PENDING]**</span> Referral & Follow-up (new section)
•	Refer to Emergency/Hospital
•	Refer to Specialist
•	Follow-up options: 15 days, 1 month, etc. (dropdown)
1.	<span style="color:red">**[PENDING]**</span> Course Assignment (new section)
•	Option to assign health awareness videos/courses to patient
2.2 Prescription Completion Rules
•	<span style="color:green">**[DONE]**</span> Save button: Saves draft (can edit later during consultation)
•	<span style="color:red">**[PENDING]**</span> Cannot end consultation until prescription is complete
•	<span style="color:red">**[PENDING]**</span> If doctor tries to end without completing prescription → Show error popup
•	<span style="color:green">**[DONE]**</span> Once consultation ends → Prescription auto-publishes to patient
2.3 Prescription Display (Patient Side)
Format: <span style="color:green">**[DONE]**</span> Single-page PDF-style view
Header Section:
•	<span style="color:green">**[DONE]**</span> Patient Information: Name, Age, Gender, MR Number, Date & Time
•	<span style="color:green">**[DONE]**</span> Doctor Information: Name, PMDC License Number, Phone Number
Body Section:
•	<span style="color:green">**[DONE]**</span> Diagnosis
•	<span style="color:green">**[DONE]**</span> Medications (with dose and duration)
•	<span style="color:green">**[DONE]**</span> Lab Tests
•	<span style="color:green">**[DONE]**</span> Doctor Notes/Instructions
Footer Section:
•	<span style="color:red">**[PENDING]**</span> Order Medicine button (links to pharmacy)
•	<span style="color:red">**[PENDING]**</span> Order Lab Tests button (links to lab)
2.4 Prescription Standards
•	<span style="color:red">**[PENDING]**</span> Medicine Database: British Pharmacopoeia (client to provide)
•	<span style="color:red">**[PENDING]**</span> Lab Tests: Standard catalogue (client to provide)
•	<span style="color:green">**[DONE]**</span> ICD-10 Codes: Already integrated
________________________________________
3. Patient & Doctor Dashboard
3.1 Patient History Access
During Consultation:
•	<span style="color:green">**[DONE]**</span> Doctor can view patient's past consultation history
•	<span style="color:green">**[DONE]**</span> Includes: previous prescriptions, SOAP notes, diagnoses
•	<span style="color:green">**[DONE]**</span> After Consultation: Doctor loses access to patient records
Past Consultations Tab:
•	<span style="color:green">**[DONE]**</span> Rename "Patient History" → "Past Consultations"
•	<span style="color:green">**[DONE]**</span> Shows all previous consultations with this patient
•	<span style="color:green">**[DONE]**</span> Clickable to view details
3.2 My Prescriptions (Patient Side)
Latest Prescription (30 days):
•	<span style="color:green">**[DONE]**</span> Full prescription view with "Order" buttons active
•	<span style="color:red">**[PENDING]**</span> Can order medicines and lab tests directly
Older Prescriptions (30+ days):
•	<span style="color:red">**[PENDING]**</span> View-only mode
•	<span style="color:red">**[PENDING]**</span> No order buttons
•	<span style="color:green">**[DONE]**</span> Can print/download PDF
3.3 Doctor Dashboard
Pending Requests:
•	<span style="color:green">**[DONE]**</span> Shows instant consultation requests
•	<span style="color:red">**[PENDING]**</span> 3-minute waiting time for doctor to accept
•	<span style="color:green">**[DONE]**</span> Notification with patient details
Appointment Management:
•	<span style="color:green">**[DONE]**</span> Upcoming appointments
•	<span style="color:green">**[DONE]**</span> Completed consultations
•	<span style="color:red">**[PENDING]**</span> Rejected requests
________________________________________
4. Lab Tests & Pharmacy Integration
4.1 Unified Flow
<span style="color:red">**[PENDING]**</span> IMPORTANT: Lab and Pharmacy should have same design flow on both doctor and patient sides
4.2 Lab Test Ordering
From Prescription:
1.	<span style="color:red">**[PENDING]**</span> Patient clicks "Order Lab Tests"
2.	<span style="color:red">**[PENDING]**</span> Single-page form opens with:
•	Selected tests (from prescription)
•	Option to add more tests (search bar)
•	Lab selection (nearest or search by location)
•	Service type:
o	Home Sample Collection (with address)
o	Visit Lab (lab address shown)
•	Patient details (auto-filled)
•	Payment
Direct Lab Booking (without prescription):
•	<span style="color:green">**[DONE]**</span> Patient can search and book tests directly
•	<span style="color:green">**[DONE]**</span> Lab booking detail view with clickable Lab Name
•	<span style="color:green">**[DONE]**</span> Lab result entry step-by-step flow (3-step wizard: Sample Verify → Enter Results → Approve & Submit)
4.3 Pharmacy/Medicine Ordering
From Prescription:
1.	<span style="color:red">**[PENDING]**</span> Patient clicks "Order Medicine"
2.	<span style="color:red">**[PENDING]**</span> Single-page form with:
•	Prescribed medicines listed
•	Pharmacy selection (nearest or search)
•	Delivery options:
o	Home Delivery (with address)
o	Self Pickup (pharmacy address shown)
•	Patient details (auto-filled)
•	Payment
Direct Medicine Order:
•	<span style="color:green">**[DONE]**</span> E-commerce functionality for browsing medicines
•	<span style="color:green">**[DONE]**</span> Walk-in order creation (Create Order button with full form)
•	<span style="color:green">**[DONE]**</span> Cart functionality
4.4 Order Tracking
New Sections Required:
•	<span style="color:red">**[PENDING]**</span> My Lab Tests: Order history and status
•	<span style="color:red">**[PENDING]**</span> My Medicines: Order history and status
________________________________________
5. Health Tracker & Health Journey
5.1 Health Tracker
Purpose: Patient manually enters health data
Vitals to Track:
•	<span style="color:red">**[PENDING]**</span> Blood Pressure (BP)
•	<span style="color:red">**[PENDING]**</span> Blood Sugar
•	<span style="color:red">**[PENDING]**</span> Weight (kg/pounds - both options)
•	<span style="color:red">**[PENDING]**</span> Heart Rate
•	<span style="color:red">**[PENDING]**</span> Water Intake
•	<span style="color:red">**[PENDING]**</span> Steps
•	<span style="color:red">**[PENDING]**</span> Sleep
•	<span style="color:red">**[PENDING]**</span> Medication Adherence
Data Storage:
•	<span style="color:red">**[PENDING]**</span> Indefinite storage (as long as patient uses app)
•	<span style="color:red">**[PENDING]**</span> Each entry with timestamp
•	<span style="color:red">**[PENDING]**</span> Viewable as table/graph
5.2 Health Journey
Purpose: Personalized health dashboard based on conditions
Health Mode Toggle:
•	<span style="color:green">**[DONE]**</span> New button in Settings: "Health Mode"
•	<span style="color:green">**[DONE]**</span> Patient selects conditions: Diabetes, Hypertension, etc.
•	<span style="color:green">**[DONE]**</span> When ON: Health Journey shows only relevant data
•	<span style="color:red">**[PENDING]**</span> When OFF: Shows all data
Difference from Health Tracker:
•	<span style="color:green">**[DONE]**</span> Health Tracker = Manual data entry
•	<span style="color:green">**[DONE]**</span> Health Journey = Filtered view based on selected conditions
________________________________________
6. User Registration & Sign-in
6.1 Sign-in Page
Single Sign-in for All Roles:
•	<span style="color:green">**[DONE]**</span> Email/Password
•	<span style="color:red">**[PENDING]**</span> Sign in with Google (requires google_sign_in package installation)
•	<span style="color:red">**[PENDING]**</span> Sign in with Apple ID (add this option)
•	<span style="color:green">**[DONE]**</span> Backend auto-detects user role and opens appropriate dashboard
6.2 Sign-up Options
Two Main Buttons:
<span style="color:green">**[DONE]**</span> Button 1: "Patient Sign-up"
•	<span style="color:green">**[DONE]**</span> Simple form: Name, Email, Phone, Password
•	<span style="color:red">**[PENDING]**</span> Email verification (to be implemented)
•	<span style="color:red">**[PENDING]**</span> Phone verification (to be implemented)
•	<span style="color:green">**[DONE]**</span> Terms & Conditions checkbox
<span style="color:green">**[DONE]**</span> Button 2: "For Professionals and Students"
•	<span style="color:green">**[DONE]**</span> Replaces "Work with Us"
•	<span style="color:green">**[DONE]**</span> Opens role selection page
6.3 Professional Registration Flow
Step 1: Select Your Role
•	<span style="color:green">**[DONE]**</span> Doctor
•	<span style="color:green">**[DONE]**</span> Pharmacy
•	<span style="color:green">**[DONE]**</span> Laboratory
•	<span style="color:green">**[DONE]**</span> Instructor
•	<span style="color:red">**[PENDING]**</span> Student
Step 2: Basic Information
•	<span style="color:green">**[DONE]**</span> Name, Age, Gender, City
•	<span style="color:red">**[PENDING]**</span> Contact Person Name (for organizations)
•	<span style="color:green">**[DONE]**</span> Phone, Email
Step 3: Role-Specific Details
Doctor Registration:
•	Professional Details:
•	<span style="color:green">**[DONE]**</span> Qualification (mandatory)
•	<span style="color:green">**[DONE]**</span> Specialization
•	<span style="color:green">**[DONE]**</span> PMDC Number (mandatory)
•	<span style="color:green">**[DONE]**</span> Years of Experience
•	<span style="color:red">**[PENDING]**</span> Current Workplace
•	Availability:
•	<span style="color:green">**[DONE]**</span> Days
•	<span style="color:green">**[DONE]**</span> Time slots (30-minute intervals)
•	Document Upload (multi-upload):
•	<span style="color:green">**[DONE]**</span> Picture (passport size)
•	<span style="color:red">**[PENDING]**</span> CNIC (front & back)
•	<span style="color:green">**[DONE]**</span> Valid PMDC Certificate
•	<span style="color:green">**[DONE]**</span> MBBS/BDS Degree (mandatory)
•	<span style="color:green">**[DONE]**</span> Post-graduate Qualifications (optional, multiple)
•	<span style="color:green">**[DONE]**</span> CV (mandatory)
•	Agreement:
•	<span style="color:green">**[DONE]**</span> Single checkbox: "I agree to terms and conditions"
Pharmacy Registration:
•	<span style="color:green">**[DONE]**</span> Business Name
•	<span style="color:green">**[DONE]**</span> Drug License Number
•	<span style="color:red">**[PENDING]**</span> Pharmacist Name
•	<span style="color:red">**[PENDING]**</span> Years of Operation
•	<span style="color:green">**[DONE]**</span> Location: Address, City
•	<span style="color:green">**[DONE]**</span> Contact Number (mandatory)
•	<span style="color:red">**[PENDING]**</span> Alternative Contact (optional)
•	Document Upload:
•	<span style="color:red">**[PENDING]**</span> CNIC
•	<span style="color:green">**[DONE]**</span> Drug License
•	<span style="color:red">**[PENDING]**</span> Business Registration
•	API Integration:
•	<span style="color:red">**[PENDING]**</span> Checkbox: "Willing to integrate with iCare platform"
•	<span style="color:green">**[DONE]**</span> Agreement checkbox
Laboratory Registration:
•	<span style="color:green">**[DONE]**</span> Lab Name
•	<span style="color:green">**[DONE]**</span> License Number
•	<span style="color:green">**[DONE]**</span> Location: Address, City
•	<span style="color:green">**[DONE]**</span> Contact Number (mandatory)
•	<span style="color:red">**[PENDING]**</span> Alternative Contact (optional)
•	<span style="color:red">**[PENDING]**</span> LIS (Lab Information System) details
•	Document Upload:
•	<span style="color:red">**[PENDING]**</span> CNIC
•	<span style="color:green">**[DONE]**</span> Lab License
•	<span style="color:red">**[PENDING]**</span> Accreditation Certificates
•	<span style="color:red">**[PENDING]**</span> API Integration checkbox
•	<span style="color:green">**[DONE]**</span> Agreement checkbox
•	<span style="color:green">**[DONE]**</span> Remove: Test list upload (will use standard catalogue)
Student Registration:
•	<span style="color:red">**[PENDING]**</span> Name, Email, Phone, Password
•	<span style="color:red">**[PENDING]**</span> Educational Institute (optional)
•	<span style="color:red">**[PENDING]**</span> Degree/Program (optional)
•	<span style="color:red">**[PENDING]**</span> Simple form - minimal information required
•	<span style="color:red">**[PENDING]**</span> By default, student also becomes "patient" (can access telehealth)
Instructor Registration:
•	<span style="color:green">**[DONE]**</span> Only doctors can be instructors
•	<span style="color:green">**[DONE]**</span> Instructor option appears in doctor's dashboard
•	<span style="color:red">**[PENDING]**</span> Separate email NOT required
•	<span style="color:green">**[DONE]**</span> Doctor can switch between roles
6.4 Role Assignment Logic
•	<span style="color:green">**[DONE]**</span> Patient: Auto-approved, instant access
•	<span style="color:green">**[DONE]**</span> Doctor/Pharmacy/Lab: Admin approval required
•	<span style="color:red">**[PENDING]**</span> Student: Auto-approved after payment (for courses)
•	<span style="color:green">**[DONE]**</span> Instructor: Only accessible to approved doctors
________________________________________
7. LMS Integration
7.1 Current Status
<span style="color:green">**[DONE]**</span> LMS is 20% complete - Major work required (now ~60% complete)
7.2 Reference Platforms
Study and implement features from:
•	<span style="color:red">**[PENDING]**</span> Moodle (primary reference)
•	<span style="color:red">**[PENDING]**</span> Open edX
•	<span style="color:red">**[PENDING]**</span> Chamilo
•	<span style="color:red">**[PENDING]**</span> Sakai
•	<span style="color:green">**[DONE]**</span> Google Classroom
•	<span style="color:green">**[DONE]**</span> Coursera
•	<span style="color:green">**[DONE]**</span> Udemy
7.3 Required Features
For Students:
•	<span style="color:green">**[DONE]**</span> Course browsing (without login)
•	<span style="color:red">**[PENDING]**</span> Course purchase flow:
1.	<span style="color:green">**[DONE]**</span> Select course
2.	<span style="color:green">**[DONE]**</span> View details and price
3.	<span style="color:red">**[PENDING]**</span> "Buy Now" → Simple sign-up form (Name, Email, Phone, Password)
4.	<span style="color:red">**[PENDING]**</span> Payment
5.	<span style="color:red">**[PENDING]**</span> Limited access (only purchased course visible)
6.	<span style="color:red">**[PENDING]**</span> Document verification request
7.	<span style="color:red">**[PENDING]**</span> Full LMS access after admin approval
•	<span style="color:green">**[DONE]**</span> Learning Dashboard
•	<span style="color:green">**[DONE]**</span> My Courses
•	<span style="color:red">**[PENDING]**</span> Grades
•	<span style="color:green">**[DONE]**</span> Assignments (upload/submit)
•	<span style="color:green">**[DONE]**</span> Quizzes/Assessments
•	<span style="color:green">**[DONE]**</span> Live Sessions
•	<span style="color:green">**[DONE]**</span> Course Progress Tracking
•	<span style="color:green">**[DONE]**</span> Attendance Tracking (view attendance records, percentage, present/absent status)
For Instructors:
•	<span style="color:green">**[DONE]**</span> Course Creation
•	<span style="color:green">**[DONE]**</span> Content Upload (videos, documents, presentations)
•	<span style="color:green">**[DONE]**</span> Quiz/Assignment Creation
•	<span style="color:red">**[PENDING]**</span> Grading System
•	<span style="color:green">**[DONE]**</span> Student Progress Monitoring
•	<span style="color:green">**[DONE]**</span> Live Session Scheduling
•	<span style="color:green">**[DONE]**</span> Attendance Management (create sessions, view attendance records)
•	<span style="color:red">**[PENDING]**</span> Feedback System
For Admin:
•	<span style="color:green">**[DONE]**</span> Student Verification
•	<span style="color:green">**[DONE]**</span> Course Approval
•	<span style="color:green">**[DONE]**</span> Instructor Management
•	<span style="color:green">**[DONE]**</span> Analytics Dashboard
•	<span style="color:red">**[PENDING]**</span> Payment Management
7.4 Integration with Main App
•	<span style="color:green">**[DONE]**</span> "My Learning" button in all user dashboards (Doctor, Patient, Pharmacy, Lab)
•	<span style="color:green">**[DONE]**</span> Clicking opens LMS student portal
•	<span style="color:red">**[PENDING]**</span> "Telehealth" button in student dashboard (links to patient services)
•	<span style="color:green">**[DONE]**</span> Instructor portal accessible only to doctors (separate menu item)
________________________________________
8. Settings & Configuration
8.1 Patient Settings
Profile:
•	<span style="color:green">**[DONE]**</span> Name, Age, Gender
•	<span style="color:red">**[PENDING]**</span> Phone, Email (with verification badges)
•	<span style="color:red">**[PENDING]**</span> Address
•	<span style="color:green">**[DONE]**</span> Emergency Contacts (add from here, display in profile)
Consultation Settings:
•	<span style="color:red">**[PENDING]**</span> Notification preferences
•	<span style="color:red">**[PENDING]**</span> Preferred language (Urdu/English)
Health Mode:
•	<span style="color:green">**[DONE]**</span> Toggle ON/OFF
•	<span style="color:green">**[DONE]**</span> Select conditions: Diabetes, Hypertension, General
•	<span style="color:green">**[DONE]**</span> Affects Health Journey display
Other:
•	<span style="color:red">**[PENDING]**</span> Terms & Conditions
•	<span style="color:red">**[PENDING]**</span> Privacy Policy
•	<span style="color:green">**[DONE]**</span> Help & Support
•	<span style="color:green">**[DONE]**</span> App Version
8.2 Doctor Settings
Profile:
•	<span style="color:green">**[DONE]**</span> Professional details
•	<span style="color:green">**[DONE]**</span> Availability schedule
•	<span style="color:red">**[PENDING]**</span> Consultation fees
Consultation Settings:
•	<span style="color:green">**[DONE]**</span> Online/Offline toggle
•	<span style="color:green">**[DONE]**</span> Instant Consultation toggle (separate from online status)
•	<span style="color:green">**[DONE]**</span> Online only = Available for scheduled appointments
•	<span style="color:green">**[DONE]**</span> Instant ON = Available for immediate consultations
Instructor Settings:
•	<span style="color:green">**[DONE]**</span> Course management
•	<span style="color:green">**[DONE]**</span> Student management
8.3 Pharmacy/Lab Settings
•	<span style="color:red">**[PENDING]**</span> Business information
•	<span style="color:red">**[PENDING]**</span> Operating hours
•	<span style="color:red">**[PENDING]**</span> Service areas
•	<span style="color:red">**[PENDING]**</span> API integration status
________________________________________
9. Technical Requirements
9.1 Standards & APIs
•	<span style="color:red">**[PENDING]**</span> Medicine Database: British Pharmacopoeia
•	<span style="color:red">**[PENDING]**</span> Lab Tests: Standard catalogue (client to provide)
•	<span style="color:green">**[DONE]**</span> ICD-10 Codes: Integrated
•	<span style="color:red">**[PENDING]**</span> Payment Gateway: To be integrated
•	<span style="color:red">**[PENDING]**</span> Email Service: To be integrated (verification emails)
•	<span style="color:red">**[PENDING]**</span> SMS Service: To be integrated (phone verification)
9.2 Multi-language Support
•	<span style="color:red">**[PENDING]**</span> Primary: English
•	<span style="color:red">**[PENDING]**</span> Secondary: Urdu
•	<span style="color:red">**[PENDING]**</span> Language toggle in settings
•	<span style="color:red">**[PENDING]**</span> All UI elements should support both languages
9.3 Document Formats
•	<span style="color:green">**[DONE]**</span> Prescriptions: PDF format
•	<span style="color:red">**[PENDING]**</span> Email delivery of prescriptions
•	<span style="color:green">**[DONE]**</span> In-app viewing
9.4 Security & Privacy
•	<span style="color:red">**[PENDING]**</span> Email verification mandatory
•	<span style="color:red">**[PENDING]**</span> Phone verification mandatory
•	<span style="color:red">**[PENDING]**</span> 2FA (Two-Factor Authentication) - optional
•	<span style="color:green">**[DONE]**</span> Biometric login (device-level, not app-level)
•	<span style="color:red">**[PENDING]**</span> Data encryption
•	<span style="color:green">**[DONE]**</span> HIPAA compliance considerations
9.5 Notifications
Appointment Reminders:
•	<span style="color:red">**[PENDING]**</span> 1 hour before
•	<span style="color:red">**[PENDING]**</span> 10 minutes before
Consultation Notifications:
•	<span style="color:green">**[DONE]**</span> Doctor: Instant consultation request (3-minute window)
•	<span style="color:green">**[DONE]**</span> Patient: Doctor accepted/rejected
•	<span style="color:green">**[DONE]**</span> Both: Consultation started/ended
Order Notifications:
•	<span style="color:red">**[PENDING]**</span> Order confirmed
•	<span style="color:red">**[PENDING]**</span> Order dispatched
•	<span style="color:red">**[PENDING]**</span> Order delivered
________________________________________
10. UI/UX Changes
10.1 Color Scheme
•	<span style="color:red">**[PENDING]**</span> Labs: Orange theme
•	<span style="color:red">**[PENDING]**</span> Pharmacy: Blue theme
•	<span style="color:red">**[PENDING]**</span> Conditions: Purple theme (for cancer, etc.)
•	<span style="color:red">**[PENDING]**</span> Consistent color coding throughout app
10.1 Icons
•	<span style="color:red">**[PENDING]**</span> Use relevant icons for specialties (heart for cardiology, brain for neurology, etc.)
•	<span style="color:red">**[PENDING]**</span> Skin icon for dermatology
•	<span style="color:red">**[PENDING]**</span> Eye icon for ophthalmology
10.3 Buttons & Navigation
•	<span style="color:red">**[PENDING]**</span> Clear, consistent button placement
•	<span style="color:green">**[DONE]**</span> Minimize clicks (single-page forms where possible)
•	<span style="color:green">**[DONE]**</span> Back button functionality on all screens
•	<span style="color:green">**[DONE]**</span> Hamburger menu for side navigation
10.4 Forms
•	<span style="color:green">**[DONE]**</span> Auto-fill wherever possible
•	<span style="color:green">**[DONE]**</span> Dropdown menus for standard options
•	<span style="color:green">**[DONE]**</span> Search functionality for long lists
•	<span style="color:red">**[PENDING]**</span> Multi-select where applicable
•	<span style="color:red">**[PENDING]**</span> Clear validation messages
________________________________________
11. Pending Items & Action Required
11.1 From Client
•	<span style="color:red">**[PENDING]**</span> Consent message text (for chat start)
•	<span style="color:red">**[PENDING]**</span> Patient history form template
•	<span style="color:red">**[PENDING]**</span> SOAP notes form template
•	<span style="color:red">**[PENDING]**</span> Medicine database (British Pharmacopoeia)
•	<span style="color:red">**[PENDING]**</span> Lab tests catalogue
•	<span style="color:red">**[PENDING]**</span> Terms & Conditions document
•	<span style="color:red">**[PENDING]**</span> Privacy Policy document
•	<span style="color:red">**[PENDING]**</span> Verification process policy
•	<span style="color:red">**[PENDING]**</span> Instructor course assignment details
•	<span style="color:red">**[PENDING]**</span> Screenshots for chat interface design
11.2 Development Tasks
•	<span style="color:green">**[DONE]**</span> Chat-first consultation flow
•	<span style="color:green">**[DONE]**</span> In-consultation prescription form
•	<span style="color:green">**[DONE]**</span> Prescription PDF generation
•	<span style="color:green">**[DONE]**</span> Doctor loses access to patient records after consultation
•	<span style="color:green">**[DONE]**</span> Lab booking detail view (Lab Name clickable)
•	<span style="color:green">**[DONE]**</span> Lab result entry step-by-step flow (3-step wizard)
•	<span style="color:green">**[DONE]**</span> Walk-in pharmacy order creation
•	<span style="color:green">**[DONE]**</span> Booking confirmation → Payment screen navigation
•	<span style="color:green">**[DONE]**</span> Online doctors filter on home page
•	<span style="color:green">**[DONE]**</span> LMS Attendance tab (student view + instructor management)
•	<span style="color:red">**[PENDING]**</span> Lab/Pharmacy unified flow
•	<span style="color:red">**[PENDING]**</span> Health Tracker implementation
•	<span style="color:green">**[DONE]**</span> Health Journey with toggle
•	<span style="color:green">**[DONE]**</span> Role-based registration
•	<span style="color:red">**[PENDING]**</span> LMS integration (currently ~70% complete, target 80% for next meeting)
•	<span style="color:red">**[PENDING]**</span> Sign in with Google (requires google_sign_in package + OAuth setup)
•	<span style="color:red">**[PENDING]**</span> Sign in with Apple ID (requires sign_in_with_apple package + OAuth setup)
•	<span style="color:red">**[PENDING]**</span> Email/SMS verification
•	<span style="color:red">**[PENDING]**</span> Payment gateway integration
•	<span style="color:red">**[PENDING]**</span> Multi-language support
•	<span style="color:red">**[PENDING]**</span> Notification system
11.3 Design Tasks
•	<span style="color:green">**[DONE]**</span> Chat interface mockup
•	<span style="color:green">**[DONE]**</span> Prescription layout (Aga Khan style reference)
•	<span style="color:red">**[PENDING]**</span> Single-page forms for lab/pharmacy
•	<span style="color:red">**[PENDING]**</span> Health Journey dashboard
•	<span style="color:green">**[DONE]**</span> LMS student/instructor portals
•	<span style="color:green">**[DONE]**</span> Registration flow screens
________________________________________
12. Meeting Notes & Decisions
12.1 Key Decisions
1.	<span style="color:green">**[DONE]**</span> Chat-first approach instead of direct video call
2.	<span style="color:green">**[DONE]**</span> Prescription during consultation (not after)
