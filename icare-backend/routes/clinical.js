const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── SOAP NOTES SCHEMA ────────────────────────────────────────────────────────
const SoapNoteSchema = new mongoose.Schema({
  appointment_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  doctor_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  patient_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  subjective: { type: String, default: '' },
  objective: { type: String, default: '' },
  assessment: { type: String, default: '' },
  plan: { type: String, default: '' },
  icdCodes: [{
    code: String,
    description: String,
    category: String
  }],
  created_at: { type: Date, default: Date.now },
  updated_at: { type: Date, default: Date.now },
}, { collection: 'soap_notes' });

const SoapNote = mongoose.models.SoapNote || mongoose.model('SoapNote', SoapNoteSchema);

// ─── INTAKE NOTES SCHEMA ──────────────────────────────────────────────────────
const IntakeNoteSchema = new mongoose.Schema({
  appointment_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  doctor_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  patient_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  notes: { type: mongoose.Schema.Types.Mixed, default: {} },
  created_at: { type: Date, default: Date.now },
  updated_at: { type: Date, default: Date.now },
}, { collection: 'intake_notes' });

const IntakeNote = mongoose.models.IntakeNote || mongoose.model('IntakeNote', IntakeNoteSchema);

// ─── REFERRAL SCHEMA ──────────────────────────────────────────────────────────
const ReferralSchema = new mongoose.Schema({
  from_doctor_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  to_doctor_id: { type: mongoose.Schema.Types.ObjectId },
  patient_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  appointment_id: { type: mongoose.Schema.Types.ObjectId },
  specialty: { type: String, required: true },
  reason: { type: String, required: true },
  status: { type: String, enum: ['pending', 'accepted', 'declined'], default: 'pending' },
  decline_reason: { type: String },
  created_at: { type: Date, default: Date.now },
  updated_at: { type: Date, default: Date.now },
}, { collection: 'referrals' });

const Referral = mongoose.models.Referral || mongoose.model('Referral', ReferralSchema);

// ─── GET SOAP NOTES ───────────────────────────────────────────────────────────
router.get('/soap-notes/:appointmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const appointmentId = toId(req.params.appointmentId);
    if (!appointmentId) {
      return res.status(400).json({ success: false, message: 'Invalid appointment ID' });
    }

    const soapNote = await SoapNote.findOne({ appointment_id: appointmentId }).lean();

    if (!soapNote) {
      // Return empty structure instead of 404
      return res.json({
        success: true,
        subjective: '',
        objective: '',
        assessment: '',
        plan: '',
        icdCodes: []
      });
    }

    res.json({
      success: true,
      subjective: soapNote.subjective || '',
      objective: soapNote.objective || '',
      assessment: soapNote.assessment || '',
      plan: soapNote.plan || '',
      icdCodes: soapNote.icdCodes || []
    });
  } catch (e) {
    console.error('Get SOAP notes error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── SAVE SOAP NOTES ──────────────────────────────────────────────────────────
router.post('/soap-notes/:appointmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const appointmentId = toId(req.params.appointmentId);
    if (!appointmentId) {
      return res.status(400).json({ success: false, message: 'Invalid appointment ID' });
    }

    const doctorId = toId(req.user.id);
    const { subjective, objective, assessment, plan, icdCodes } = req.body;

    // Get appointment to find patient_id
    const Appointment = require('../models/Appointment');
    const appointment = await Appointment.findById(appointmentId).lean();
    if (!appointment) {
      return res.status(404).json({ success: false, message: 'Appointment not found' });
    }

    const soapNote = await SoapNote.findOneAndUpdate(
      { appointment_id: appointmentId },
      {
        $set: {
          doctor_id: doctorId,
          patient_id: appointment.patient_id,
          subjective: subjective || '',
          objective: objective || '',
          assessment: assessment || '',
          plan: plan || '',
          icdCodes: icdCodes || [],
          updated_at: new Date()
        }
      },
      { new: true, upsert: true }
    );

    res.json({ success: true, message: 'SOAP notes saved successfully', soapNote });
  } catch (e) {
    console.error('Save SOAP notes error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET INTAKE NOTES ─────────────────────────────────────────────────────────
router.get('/intake-notes/:appointmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const appointmentId = toId(req.params.appointmentId);
    if (!appointmentId) {
      return res.status(400).json({ success: false, message: 'Invalid appointment ID' });
    }

    const intakeNote = await IntakeNote.findOne({ appointment_id: appointmentId }).lean();

    if (!intakeNote) {
      return res.json({ success: true, notes: {} });
    }

    res.json({ success: true, notes: intakeNote.notes || {} });
  } catch (e) {
    console.error('Get intake notes error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── SAVE INTAKE NOTES ────────────────────────────────────────────────────────
router.post('/intake-notes/:appointmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const appointmentId = toId(req.params.appointmentId);
    if (!appointmentId) {
      return res.status(400).json({ success: false, message: 'Invalid appointment ID' });
    }

    const doctorId = toId(req.user.id);
    const { notes } = req.body;

    const Appointment = require('../models/Appointment');
    const appointment = await Appointment.findById(appointmentId).lean();
    if (!appointment) {
      return res.status(404).json({ success: false, message: 'Appointment not found' });
    }

    const intakeNote = await IntakeNote.findOneAndUpdate(
      { appointment_id: appointmentId },
      {
        $set: {
          doctor_id: doctorId,
          patient_id: appointment.patient_id,
          notes: notes || {},
          updated_at: new Date()
        }
      },
      { new: true, upsert: true }
    );

    res.json({ success: true, message: 'Intake notes saved successfully', intakeNote });
  } catch (e) {
    console.error('Save intake notes error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── SEARCH ICD CODES ─────────────────────────────────────────────────────────
router.get('/icd-codes/search', authMiddleware, async (req, res) => {
  try {
    const { query } = req.query;

    if (!query || query.trim().length === 0) {
      return res.json({ success: true, results: [] });
    }

    // Local ICD-10 data - basic search
    const searchTerm = query.toLowerCase();
    const results = [];

    // Sample ICD-10 codes for common conditions
    const icdData = [
      { code: 'A00-A09', description: 'Intestinal infectious diseases', category: 'I Certain infectious and parasitic diseases' },
      { code: 'A15-A19', description: 'Tuberculosis', category: 'I Certain infectious and parasitic diseases' },
      { code: 'I10', description: 'Essential (primary) hypertension', category: 'IX Diseases of the circulatory system' },
      { code: 'I20-I25', description: 'Ischemic heart diseases', category: 'IX Diseases of the circulatory system' },
      { code: 'E10-E14', description: 'Diabetes mellitus', category: 'IV Endocrine, nutritional and metabolic diseases' },
      { code: 'J00-J06', description: 'Acute upper respiratory infections', category: 'X Diseases of the respiratory system' },
      { code: 'J40-J47', description: 'Chronic lower respiratory diseases', category: 'X Diseases of the respiratory system' },
      { code: 'K20-K31', description: 'Diseases of esophagus, stomach and duodenum', category: 'XI Diseases of the digestive system' },
      { code: 'M00-M25', description: 'Arthropathies', category: 'XIII Diseases of the musculoskeletal system' },
      { code: 'N00-N08', description: 'Glomerular diseases', category: 'XIV Diseases of the genitourinary system' },
    ];

    icdData.forEach(item => {
      if (item.code.toLowerCase().includes(searchTerm) ||
          item.description.toLowerCase().includes(searchTerm) ||
          item.category.toLowerCase().includes(searchTerm)) {
        results.push(item);
      }
    });

    res.json({ success: true, results });
  } catch (e) {
    console.error('ICD search error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET ICD CATEGORIES ───────────────────────────────────────────────────────
router.get('/icd-codes/categories', authMiddleware, async (req, res) => {
  try {
    const categories = [
      'I Certain infectious and parasitic diseases',
      'II Neoplasms',
      'III Diseases of the blood and blood-forming organs',
      'IV Endocrine, nutritional and metabolic diseases',
      'V Mental and behavioural disorders',
      'VI Diseases of the nervous system',
      'VII Diseases of the eye and adnexa',
      'VIII Diseases of the ear and mastoid process',
      'IX Diseases of the circulatory system',
      'X Diseases of the respiratory system',
      'XI Diseases of the digestive system',
      'XII Diseases of the skin and subcutaneous tissue',
      'XIII Diseases of the musculoskeletal system',
      'XIV Diseases of the genitourinary system',
      'XV Pregnancy, childbirth and the puerperium',
      'XVI Certain conditions originating in the perinatal period',
      'XVII Congenital malformations and chromosomal abnormalities',
      'XVIII Symptoms, signs and abnormal findings',
      'XIX Injury, poisoning and external causes',
      'XX External causes of morbidity',
      'XXI Factors influencing health status',
      'XXII Codes for special purposes'
    ];

    res.json({ success: true, categories });
  } catch (e) {
    console.error('Get categories error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET ICD CODES BY CATEGORY ────────────────────────────────────────────────
router.get('/icd-codes/category/:category', authMiddleware, async (req, res) => {
  try {
    const { category } = req.params;

    // Return sample codes for the category
    const codes = [
      { code: 'A00-A09', description: 'Intestinal infectious diseases' },
      { code: 'A15-A19', description: 'Tuberculosis' },
    ];

    res.json({ success: true, codes });
  } catch (e) {
    console.error('Get codes by category error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── CREATE REFERRAL ──────────────────────────────────────────────────────────
router.post('/referrals', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const fromDoctorId = toId(req.user.id);
    const { patientId, specialty, reason, appointmentId } = req.body;

    const referral = await Referral.create({
      from_doctor_id: fromDoctorId,
      patient_id: toId(patientId),
      appointment_id: appointmentId ? toId(appointmentId) : undefined,
      specialty,
      reason,
      status: 'pending'
    });

    res.json({ success: true, message: 'Referral created successfully', referral });
  } catch (e) {
    console.error('Create referral error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET SENT REFERRALS ───────────────────────────────────────────────────────
router.get('/referrals/sent', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id);

    const referrals = await Referral.find({ from_doctor_id: doctorId })
      .sort({ created_at: -1 })
      .lean();

    res.json({ success: true, referrals });
  } catch (e) {
    console.error('Get sent referrals error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET RECEIVED REFERRALS ───────────────────────────────────────────────────
router.get('/referrals/received', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id);

    const referrals = await Referral.find({ to_doctor_id: doctorId })
      .sort({ created_at: -1 })
      .lean();

    res.json({ success: true, referrals });
  } catch (e) {
    console.error('Get received referrals error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── ACCEPT REFERRAL ──────────────────────────────────────────────────────────
router.post('/referrals/:referralId/accept', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const referralId = toId(req.params.referralId);

    const referral = await Referral.findByIdAndUpdate(
      referralId,
      { $set: { status: 'accepted', updated_at: new Date() } },
      { new: true }
    );

    res.json({ success: true, message: 'Referral accepted', referral });
  } catch (e) {
    console.error('Accept referral error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── DECLINE REFERRAL ─────────────────────────────────────────────────────────
router.post('/referrals/:referralId/decline', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const referralId = toId(req.params.referralId);
    const { reason } = req.body;

    const referral = await Referral.findByIdAndUpdate(
      referralId,
      { $set: { status: 'declined', decline_reason: reason, updated_at: new Date() } },
      { new: true }
    );

    res.json({ success: true, message: 'Referral declined', referral });
  } catch (e) {
    console.error('Decline referral error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── ADDENDUM ─────────────────────────────────────────────────────────────────
router.post('/addendum/:type/:appointmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { type, appointmentId } = req.params;
    const { text } = req.body;
    const appointmentObjId = toId(appointmentId);

    if (type === 'soap') {
      const soapNote = await SoapNote.findOne({ appointment_id: appointmentObjId });
      if (soapNote) {
        soapNote.plan = (soapNote.plan || '') + '\n\nAddendum: ' + text;
        soapNote.updated_at = new Date();
        await soapNote.save();
      }
    }

    res.json({ success: true, message: 'Addendum added successfully' });
  } catch (e) {
    console.error('Add addendum error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── HEALTH JOURNEY ───────────────────────────────────────────────────────────
const HealthJourneySchema = new mongoose.Schema({
  patient_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  entries: [{ type: mongoose.Schema.Types.Mixed }],
  updated_at: { type: Date, default: Date.now },
}, { collection: 'health_journeys', strict: false });
const HealthJourney = mongoose.models.HealthJourney || mongoose.model('HealthJourney', HealthJourneySchema);

router.get('/health-journey', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const journey = await HealthJourney.findOne({ patient_id: userId }).lean() || { entries: [] };
    res.json({ success: true, journey, entries: journey.entries || [] });
  } catch (err) {
    console.error(err);
    res.json({ success: true, journey: { entries: [] }, entries: [] });
  }
});

// ─── LIFESTYLE LOGS ───────────────────────────────────────────────────────────
const LifestyleLogSchema = new mongoose.Schema({
  patient_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  logs: [{ type: mongoose.Schema.Types.Mixed }],
  updated_at: { type: Date, default: Date.now },
}, { collection: 'lifestyle_logs', strict: false });
const LifestyleLog = mongoose.models.LifestyleLog || mongoose.model('LifestyleLog', LifestyleLogSchema);

router.post('/lifestyle-logs', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const log = await LifestyleLog.findOneAndUpdate(
      { patient_id: userId },
      { $push: { logs: { ...req.body, createdAt: new Date() } }, $set: { updated_at: new Date() } },
      { new: true, upsert: true }
    );
    res.json({ success: true, message: 'Log saved', log });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to save log' });
  }
});

router.get('/lifestyle-summary', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const log = await LifestyleLog.findOne({ patient_id: userId }).lean() || { logs: [] };
    res.json({ success: true, summary: log, logs: log.logs || [] });
  } catch (err) {
    console.error(err);
    res.json({ success: true, summary: { logs: [] }, logs: [] });
  }
});

module.exports = router;
