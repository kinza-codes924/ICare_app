const mongoose = require('mongoose');

const medicalRecordSchema = new mongoose.Schema({
  doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  appointment: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment' },
  diagnosis: { type: String, required: true },
  symptoms: [{ type: String }],
  prescription: {
    medicines: [{
      name: String,
      dosage: String,
      frequency: String,
      duration: String,
      instructions: String,
    }],
    labTests: [{
      name: String,
      urgency: String,
    }],
    referral: {
      specialty: String,
      reason: String,
    },
  },
  labTests: [{ type: String }],
  vitalSigns: {
    bloodPressure: String,
    temperature: String,
    heartRate: Number,
    weight: Number,
    height: Number,
  },
  notes: { type: String },
  followUpDate: { type: Date },
  followUpDays: { type: Number },
  followUpMonths: { type: Number },
  referredLaboratory: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  selectedPharmacy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  assignedCourses: [{ type: mongoose.Schema.Types.ObjectId }],
}, { timestamps: true });

module.exports = mongoose.models.MedicalRecord || mongoose.model('MedicalRecord', medicalRecordSchema);
