const mongoose = require('mongoose');

// Sub-schemas for nested structures

const chiefComplaintSchema = new mongoose.Schema({
  complaint: { type: String, default: '' },
  duration: { type: String, default: '' }
}, { _id: false });

const historyOfPresentIllnessSchema = new mongoose.Schema({
  onset: String,
  duration: String,
  progression: String,
  location: String,
  radiation: String,
  character: String,
  severity: String,
  aggravatingFactors: String,
  relievingFactors: String,
  associatedSymptoms: String,
  previousEpisodes: String,
  treatmentTaken: String,
  additionalNotes: String
}, { _id: false });

const otherChronicIllnessSchema = new mongoose.Schema({
  illness: String,
  details: String
}, { _id: false });

const pastMedicalHistorySchema = new mongoose.Schema({
  hypertension: { type: Boolean, default: false },
  hypertensionDetails: String,
  diabetesMellitus: { type: Boolean, default: false },
  diabetesDetails: String,
  ischemicHeartDisease: { type: Boolean, default: false },
  ihdDetails: String,
  asthma: { type: Boolean, default: false },
  asthmaDetails: String,
  tuberculosis: { type: Boolean, default: false },
  tbDetails: String,
  hepatitis: { type: Boolean, default: false },
  hepatitisDetails: String,
  thyroidDisease: { type: Boolean, default: false },
  thyroidDetails: String,
  renalDisease: { type: Boolean, default: false },
  renalDetails: String,
  epilepsy: { type: Boolean, default: false },
  epilepsyDetails: String,
  psychiatricIllness: { type: Boolean, default: false },
  psychiatricDetails: String,
  otherIllnesses: [otherChronicIllnessSchema]
}, { _id: false });

const surgicalHistorySchema = new mongoose.Schema({
  surgeryProcedure: { type: String, default: '' },
  year: { type: Number, default: 0 },
  hospitalRemarks: String
}, { _id: false });

const currentMedicationSchema = new mongoose.Schema({
  medication: { type: String, default: '' },
  dose: { type: String, default: '' },
  frequency: { type: String, default: '' },
  duration: { type: String, default: '' }
}, { _id: false });

const allergySchema = new mongoose.Schema({
  type: { type: String, enum: ['drug', 'food', 'other', ''], default: 'other' },
  allergen: { type: String, default: '' },
  reaction: { type: String, default: '' }
}, { _id: false });

const drugHistorySchema = new mongoose.Schema({
  currentMedications: [currentMedicationSchema],
  allergies: [allergySchema]
}, { _id: false });

const familyMemberHistorySchema = new mongoose.Schema({
  diseaseCondition: String,
  ageAtDiagnosis: Number
}, { _id: false });

const familyHistorySchema = new mongoose.Schema({
  father: familyMemberHistorySchema,
  mother: familyMemberHistorySchema,
  siblings: [familyMemberHistorySchema],
  children: [familyMemberHistorySchema],
  otherRelevantHistory: String
}, { _id: false });

const personalSocialHistorySchema = new mongoose.Schema({
  diet: String,
  appetite: String,
  sleep: String,
  bowelHabits: String,
  bladderHabits: String,
  smoking: { type: String, enum: ['never', 'former', 'current'], default: 'never' },
  alcoholUse: { type: String, enum: ['never', 'occasional', 'regular'], default: 'never' },
  substanceAbuse: { type: Boolean, default: false },
  substanceDetails: String,
  exercise: String,
  sexualHistory: String,
  occupationalExposure: String,
  travelHistory: String,
  vaccinationHistory: String
}, { _id: false });

const gynecologicalHistorySchema = new mongoose.Schema({
  menarche: Number,
  lastMenstrualPeriod: Date,
  menstrualCycle: String,
  gravida: { type: Number, default: 0 },
  para: { type: Number, default: 0 },
  abortions: { type: Number, default: 0 },
  livingChildren: { type: Number, default: 0 },
  contraceptiveUse: String,
  menopause: { type: Boolean, default: false },
  menopauseAge: Number
}, { _id: false });

const reviewOfSystemsSchema = new mongoose.Schema({
  general: String,
  cardiovascular: String,
  respiratory: String,
  gastrointestinal: String,
  genitourinary: String,
  neurological: String,
  musculoskeletal: String,
  endocrine: String,
  skin: String,
  psychiatric: String
}, { _id: false });

const vitalSignsSchema = new mongoose.Schema({
  bloodPressure: String,
  pulseRate: String,
  respiratoryRate: String,
  temperature: String,
  oxygenSaturation: String,
  weight: String,
  height: String,
  bmi: String
}, { _id: false });

const generalExaminationFindingsSchema = new mongoose.Schema({
  generalAppearance: String,
  levelOfConsciousness: String,
  orientation: String,
  hydration: String,
  pallor: { type: Boolean, default: false },
  icterus: { type: Boolean, default: false },
  cyanosis: { type: Boolean, default: false },
  clubbing: { type: Boolean, default: false },
  edema: { type: Boolean, default: false },
  lymphadenopathy: { type: Boolean, default: false },
  nutritionalStatus: String,
  mobilityGait: String
}, { _id: false });

const virtualPhysicalExaminationSchema = new mongoose.Schema({
  vitalSigns: vitalSignsSchema,
  generalFindings: generalExaminationFindingsSchema,
  notes: String
}, { _id: false });

// Main Patient History Form Schema
const patientHistoryFormSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  consultationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Consultation',
    required: true
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // 1. Chief Complaint(s)
  chiefComplaints: [chiefComplaintSchema],
  
  // 2. History of Present Illness
  hpi: historyOfPresentIllnessSchema,
  
  // 3. Past Medical History
  pastMedicalHistory: pastMedicalHistorySchema,
  
  // 4. Past Surgical History
  surgicalHistory: [surgicalHistorySchema],
  
  // 5. Drug History
  drugHistory: drugHistorySchema,
  
  // 6. Family History
  familyHistory: familyHistorySchema,
  
  // 7. Personal and Social History
  personalSocialHistory: personalSocialHistorySchema,
  
  // 8. Gynecological/Obstetric History
  gynecologicalHistory: gynecologicalHistorySchema,
  
  // 9. Review of Systems
  reviewOfSystems: reviewOfSystemsSchema,
  
  // 10. Virtual General Physical Examination
  virtualExamination: virtualPhysicalExaminationSchema
}, {
  timestamps: true
});

// Indexes for faster queries
patientHistoryFormSchema.index({ patientId: 1, consultationId: 1 });
patientHistoryFormSchema.index({ consultationId: 1 });
patientHistoryFormSchema.index({ patientId: 1, createdAt: -1 });

module.exports = mongoose.model('PatientHistoryForm', patientHistoryFormSchema);
