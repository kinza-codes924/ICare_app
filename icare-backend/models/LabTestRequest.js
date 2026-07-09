const mongoose = require('mongoose');

const labTestRequestSchema = new mongoose.Schema({
  patient_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  lab_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  test_type: { type: String, required: true },
  test_date: String,
  price: { type: Number, default: 0 },
  urgency: { type: String, default: 'Normal' },
  is_urgent: { type: Boolean, default: false },
  collection_type: { type: String, default: 'in-lab' },
  turnaround_time: { type: String, default: null },
  source: { type: String, default: 'online' },
  // Patient details — saved separately for lab reference
  patient_name_override: { type: String, default: null },
  patient_age: { type: String, default: null },
  patient_gender: { type: String, default: null },
  patient_phone: { type: String, default: null },
  patient_address: { type: String, default: null },
  status: {
    type: String,
    enum: [
      'pending', 
      'confirmed', 
      'sample_collected', 'sample-collected',
      'awaiting_reports', 'awaiting-reports',
      'reporting_done', 'reporting-done',
      'processing', 
      'completed', 
      'cancelled',
      'declined',
    ],
    default: 'pending',
  },
  results: mongoose.Schema.Types.Mixed,
  report_url: String,
  report_notes: String,
  medical_record_id: String,
  doctor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true, strict: false });

module.exports = mongoose.models.LabTestRequest || mongoose.model('LabTestRequest', labTestRequestSchema);
