const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const MedicalRecord = require('../models/MedicalRecord');
const PharmacyOrder = require('../models/PharmacyOrder');
const EnhancedPrescription = require('../models/EnhancedPrescription');

// Normalize an EnhancedPrescription into the same shape as MedicalRecord
function normalizeEnhancedPrescription(ep) {
  const diagnosisText = ep.diagnoses && ep.diagnoses.length > 0
    ? ep.diagnoses.map(d => d.diagnosis).join(', ')
    : 'General Consultation';

  const medicines = (ep.medicines || []).map(m => ({
    name: m.medicineName,
    dosage: m.dose,
    frequency: m.frequency,
    duration: m.duration,
    instructions: m.notes || '',
  }));

  const labTests = (ep.labTests || []).map(t => ({
    name: t.testName,
    urgency: t.isUrgent ? 'urgent' : 'routine',
    notes: t.instructions || '',
  }));

  const doctor = ep.doctorId && typeof ep.doctorId === 'object'
    ? { _id: ep.doctorId._id?.toString(), name: ep.doctorId.name, email: ep.doctorId.email }
    : null;

  const patient = ep.patientId && typeof ep.patientId === 'object'
    ? { _id: ep.patientId._id?.toString(), name: ep.patientId.name, email: ep.patientId.email, gender: ep.patientId.gender, age: ep.patientId.age }
    : null;

  const referral = ep.referralFollowUp && ep.referralFollowUp.referralType && ep.referralFollowUp.referralType !== 'none'
    ? {
        specialty: ep.referralFollowUp.referralSpecialty,
        reason: ep.referralFollowUp.referralNotes,
        type: ep.referralFollowUp.referralType,
      }
    : null;

  return {
    _id: ep._id.toString(),
    _source: 'enhanced',
    _consultationId: ep.consultationId?.toString(),
    diagnosis: diagnosisText,
    doctor,
    patient,
    prescription: {
      medicines,
      labTests,
      referral,
      soapNotes: ep.soapNotes,
    },
    labTests: labTests.map(t => t.name),
    notes: ep.doctorNotes || '',
    createdAt: ep.createdAt,
    prescribedAt: ep.prescribedAt,
    status: ep.status,
    expiresAt: ep.expiresAt,
    followUpDays: ep.referralFollowUp?.followUpDuration ? _followUpToDays(ep.referralFollowUp.followUpDuration) : 0,
  };
}

function _followUpToDays(duration) {
  const map = { oneWeek: 7, twoWeeks: 14, oneMonth: 30, twoMonths: 60, threeMonths: 90, sixMonths: 180 };
  return map[duration] || 0;
}

// POST /api/medical-records/create
router.post('/create', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const {
      patientId,
      appointmentId,
      diagnosis,
      symptoms,
      prescription,
      labTests,
      vitalSigns,
      notes,
      followUpDate,
      followUpDays,
      followUpMonths,
      referredLaboratory,
      selectedPharmacy,
      assignedCourses,
    } = req.body;

    if (!patientId || !diagnosis) {
      return res.status(400).json({ success: false, message: 'patientId and diagnosis are required' });
    }

    // Extract and normalize lab tests
    const normalizedLabTests = (() => {
      const raw = prescription?.labTests || labTests || [];
      return raw.map(t => typeof t === 'string' ? { name: t, urgency: 'Routine' } : t);
    })();

    // Extract test names for top-level labTests field (backward compatibility)
    const labTestNames = normalizedLabTests.map(t => t.name || t);

    const record = await MedicalRecord.create({
      doctor: req.user.id || req.user._id,
      patient: patientId,
      appointment: appointmentId || undefined,
      diagnosis,
      symptoms: symptoms || [],
      prescription: {
        ...(prescription || {}),
        labTests: normalizedLabTests,
      },
      labTests: labTestNames,
      vitalSigns: vitalSigns || {},
      notes: notes || '',
      followUpDate: followUpDate ? new Date(followUpDate) : undefined,
      followUpDays: followUpDays || 0,
      followUpMonths: followUpMonths || 0,
      referredLaboratory: referredLaboratory && mongoose.isValidObjectId(referredLaboratory) ? referredLaboratory : undefined,
      selectedPharmacy: selectedPharmacy && mongoose.isValidObjectId(selectedPharmacy) ? selectedPharmacy : undefined,
      assignedCourses: assignedCourses || [],
    });

    const populated = await MedicalRecord.findById(record._id)
      .populate('doctor', 'name email')
      .populate('patient', 'name email');

    // ── AUTO-TRIGGER: Send prescription to pharmacy ──────────────────────────
    if (
      selectedPharmacy &&
      mongoose.isValidObjectId(selectedPharmacy) &&
      prescription?.medicines?.length > 0
    ) {
      try {
        const orderItems = prescription.medicines.map((m) => ({
          product_name: m.name || 'Medicine',
          generic_name: m.dosage || '',
          quantity: 1,
          price: 0,
        }));
        const rxOrderNumber = `RX-${Date.now().toString().slice(-8)}-${Math.random().toString(36).slice(-4).toUpperCase()}`;
        await PharmacyOrder.create({
          patient_id: patientId,
          pharmacy_id: selectedPharmacy,
          prescription_id: record._id.toString(),
          delivery_address: '',
          total_amount: 0,
          status: 'pending',
          order_number: rxOrderNumber,
          orderNumber: rxOrderNumber,
          items: orderItems,
        });
        console.log(`✅ Pharmacy order auto-created for record ${record._id}`);
      } catch (pharmErr) {
        console.error('⚠️  Auto pharmacy order failed:', pharmErr.message);
      }
    }

    // Lab bookings are created by the patient from "My Prescription" — not auto-created here.

    res.status(201).json({ success: true, record: populated });
  } catch (err) {
    console.error('Create medical record error:', err);
    res.status(500).json({ success: false, message: 'Internal server error', error: err.message });
  }
});

// GET /api/medical-records/patient/:patientId
router.get('/patient/:patientId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const records = await MedicalRecord.find({ patient: req.params.patientId })
      .populate('doctor', 'name email')
      .populate('patient', 'name email')
      .sort({ createdAt: -1 });

    res.json({ success: true, records, count: records.length });
  } catch (err) {
    console.error('Get patient records error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// GET /api/medical-records/doctor
router.get('/doctor', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const records = await MedicalRecord.find({ doctor: req.user.id || req.user._id })
      .populate('doctor', 'name email')
      .populate('patient', 'name email')
      .sort({ createdAt: -1 });

    res.json({ success: true, records, count: records.length });
  } catch (err) {
    console.error('Get doctor records error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// GET /api/medical-records/my-records
router.get('/my-records', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = req.user.id || req.user._id;
    const role = req.user.role?.toLowerCase();

    const query = role === 'doctor' ? { doctor: userId } : { patient: userId };

    const records = await MedicalRecord.find(query)
      .populate('doctor', 'name email')
      .populate('patient', 'name email age gender')
      .sort({ createdAt: -1 })
      .lean();

    const normalizedMedical = records.map(r => ({
      ...r,
      _id: r._id.toString(),
      _source: 'medical',
      prescription: {
        ...(r.prescription || {}),
        medicines: r.prescription?.medicines || [],
        labTests: r.prescription?.labTests || [],
      },
      labTests: r.labTests || [],
      doctor: r.doctor ? { ...r.doctor, _id: r.doctor._id?.toString() } : null,
      patient: r.patient ? { ...r.patient, _id: r.patient._id?.toString() } : null,
    }));

    // Also fetch EnhancedPrescription records (from video consultations)
    let normalizedEnhanced = [];
    try {
      const epQuery = role === 'doctor'
        ? { doctorId: userId, isComplete: true }
        : { patientId: userId, isComplete: true };

      const enhancedPrescriptions = await EnhancedPrescription.find(epQuery)
        .populate('doctorId', 'name email')
        .populate('patientId', 'name email age gender')
        .sort({ createdAt: -1 })
        .lean();

      normalizedEnhanced = enhancedPrescriptions.map(ep => normalizeEnhancedPrescription(ep));
    } catch (epErr) {
      console.error('Warning: failed to load enhanced prescriptions:', epErr.message);
    }

    // Deduplicate: if a MedicalRecord has the same consultationId as an EP, prefer the EP
    const epConsultationIds = new Set(
      normalizedEnhanced.map(ep => ep._consultationId).filter(Boolean)
    );
    const filteredMedical = normalizedMedical.filter(
      r => !r.consultationId || !epConsultationIds.has(r.consultationId?.toString())
    );

    // Merge and sort by date descending
    const merged = [...filteredMedical, ...normalizedEnhanced].sort((a, b) => {
      const dateA = new Date(a.createdAt || a.prescribedAt || 0);
      const dateB = new Date(b.createdAt || b.prescribedAt || 0);
      return dateB - dateA;
    });

    res.json({ success: true, records: merged, count: merged.length });
  } catch (err) {
    console.error('Get my records error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// GET /api/medical-records/all  (admin — returns all records)
router.get('/all', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const records = await MedicalRecord.find({})
      .populate('doctor', 'name email username')
      .populate('patient', 'name email username')
      .sort({ createdAt: -1 })
      .lean();

    const normalized = records.map(r => ({
      ...r,
      _id: r._id.toString(),
      prescription: {
        ...(r.prescription || {}),
        medicines: r.prescription?.medicines || [],
        labTests: r.prescription?.labTests || [],
      },
      labTests: r.labTests || [],
      doctor: r.doctor ? { ...r.doctor, _id: r.doctor._id?.toString() } : null,
      patient: r.patient ? { ...r.patient, _id: r.patient._id?.toString() } : null,
    }));

    res.json({ success: true, records: normalized, count: normalized.length });
  } catch (err) {
    console.error('Get all records error:', err);
    res.json({ success: true, records: [], count: 0 });
  }
});

// GET /api/medical-records/:id
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const record = await MedicalRecord.findById(req.params.id)
      .populate('doctor', 'name email')
      .populate('patient', 'name email');

    if (!record) return res.status(404).json({ success: false, message: 'Record not found' });

    res.json({ success: true, record });
  } catch (err) {
    console.error('Get record error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// PUT /api/medical-records/:id
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const record = await MedicalRecord.findByIdAndUpdate(req.params.id, req.body, { new: true })
      .populate('doctor', 'name email')
      .populate('patient', 'name email');

    if (!record) return res.status(404).json({ success: false, message: 'Record not found' });

    res.json({ success: true, record });
  } catch (err) {
    console.error('Update record error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
