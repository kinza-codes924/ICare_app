const mongoose = require('mongoose');

// Sub-schemas

const soapNotesSchema = new mongoose.Schema({
  subjective: String,
  objective: String,
  assessment: String,
  plan: String
}, { _id: false });

const diagnosisItemSchema = new mongoose.Schema({
  diagnosis: { type: String, required: true },
  icd10Code: { type: String, default: '' },
  notes: String
}, { _id: false });

const prescriptionMedicineSchema = new mongoose.Schema({
  medicineName: { type: String, required: true },
  dose: { type: String, default: '' },
  formType: {
    type: String,
    enum: ['tablet', 'capsule', 'liquid', 'injection', 'cream', 'drops', 'inhaler', 'other', ''],
    default: 'tablet'
  },
  frequency: {
    type: String,
    default: 'od',
  },
  duration: { type: String, default: '' },
  notes: String
}, { _id: false });

const labTestItemSchema = new mongoose.Schema({
  testName: { type: String, required: true },
  instructions: String,
  isUrgent: { type: Boolean, default: false }
}, { _id: false });

const referralFollowUpSchema = new mongoose.Schema({
  referralType: {
    type: String,
    enum: ['none', 'emergency', 'hospital', 'specialist']
  },
  referralSpecialty: String,
  referralNotes: String,
  followUpDuration: {
    type: String,
    enum: ['none', 'oneWeek', 'twoWeeks', 'oneMonth', 'twoMonths', 'threeMonths', 'sixMonths']
  },
  followUpDate: Date,
  followUpNotes: String
}, { _id: false });

// Main Enhanced Prescription Schema
const enhancedPrescriptionSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  consultationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Consultation',
    required: true
  },
  
  // Patient History Reference
  patientHistoryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'PatientHistoryForm'
  },
  
  // SOAP Notes
  soapNotes: soapNotesSchema,
  
  // Doctor Notes (renamed from Diagnosis Notes)
  doctorNotes: {
    type: String,
    required: false,
    default: ''
  },
  
  // Diagnosis with ICD-10
  diagnoses: [diagnosisItemSchema],
  
  // Medications
  medicines: [prescriptionMedicineSchema],
  
  // Lab Tests
  labTests: [labTestItemSchema],
  
  // Lifestyle Advice Reference
  lifestyleAdviceId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'LifestyleAdvice'
  },
  
  // Referral & Follow-up
  referralFollowUp: referralFollowUpSchema,
  
  // Course Assignment
  assignedCourseIds: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Course'
  }],
  
  // Status
  status: {
    type: String,
    enum: ['draft', 'active', 'expired', 'cancelled'],
    default: 'draft'
  },
  isComplete: {
    type: Boolean,
    default: false
  },
  
  // Timestamps
  prescribedAt: {
    type: Date,
    default: Date.now
  },
  expiresAt: Date
}, {
  timestamps: true
});

// Indexes for faster queries
enhancedPrescriptionSchema.index({ consultationId: 1 });
enhancedPrescriptionSchema.index({ patientId: 1, prescribedAt: -1 });
enhancedPrescriptionSchema.index({ doctorId: 1, prescribedAt: -1 });
enhancedPrescriptionSchema.index({ status: 1, prescribedAt: -1 });

// Virtual to check if prescription is within 30-day active window
enhancedPrescriptionSchema.virtual('isWithinActiveWindow').get(function() {
  const now = new Date();
  const daysSincePrescribed = Math.floor((now - this.prescribedAt) / (1000 * 60 * 60 * 24));
  return daysSincePrescribed <= 30;
});

// Virtual to check if minimum required fields are present
enhancedPrescriptionSchema.virtual('hasMinimumRequiredFields').get(function() {
  return this.diagnoses.length > 0 || this.medicines.length > 0 || this.labTests.length > 0;
});

// Method to validate completion
enhancedPrescriptionSchema.methods.validateCompletion = function() {
  if (!this.doctorNotes || this.doctorNotes.trim() === '') {
    return 'Doctor notes are required';
  }
  if (!this.hasMinimumRequiredFields) {
    return 'At least one diagnosis, medication, or lab test is required';
  }
  return null;
};

// Pre-save hook to set expiration date (30 days from prescription)
enhancedPrescriptionSchema.pre('save', async function() {
  if (this.isNew && this.status === 'active') {
    const expirationDate = new Date(this.prescribedAt);
    expirationDate.setDate(expirationDate.getDate() + 30);
    this.expiresAt = expirationDate;
  }
});

// Pre-save hook to update status based on expiration
enhancedPrescriptionSchema.pre('save', async function() {
  if (this.status === 'active' && this.expiresAt && new Date() > this.expiresAt) {
    this.status = 'expired';
  }
});

module.exports = mongoose.model('EnhancedPrescription', enhancedPrescriptionSchema);
