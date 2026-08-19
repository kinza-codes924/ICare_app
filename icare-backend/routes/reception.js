const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const Consultation = require('../models/Consultation');
const DoctorProfile = require('../models/DoctorProfile');
const ReceptionistProfile = require('../models/ReceptionistProfile');
const EnhancedPrescription = require('../models/EnhancedPrescription');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

const receptionistOnly = [authMiddleware, roleMiddleware('receptionist')];

// Confirms doctorId is actually one of this receptionist's assigned doctors
// before letting them create/modify a consultation under that doctor's name.
async function assertAssignedDoctor(receptionistUserId, doctorId) {
  const profile = await ReceptionistProfile.findOne({ user_id: toId(receptionistUserId) }).lean();
  const assigned = (profile?.doctorIds || []).map(id => id.toString());
  return assigned.includes(doctorId?.toString());
}

// ─── MY DOCTORS ─────────────────────────────────────────────────────────────
router.get('/doctors', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const profile = await ReceptionistProfile.findOne({ user_id: toId(req.user.id) })
      .populate('doctorIds', 'name username email')
      .lean();
    const doctors = (profile?.doctorIds || []).map(d => ({
      _id: d._id.toString(),
      name: d.name || d.username || '',
      email: d.email || '',
    }));
    res.json({ success: true, doctors });
  } catch (err) {
    console.error('reception/doctors error:', err);
    res.status(500).json({ success: false, message: 'Failed to load doctors' });
  }
});

// ─── CREATE WALK-IN CONSULTATION ────────────────────────────────────────────
router.post('/walkin', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { doctorId, patientName, patientAge, patientGender, reason } = req.body;
    if (!doctorId || !patientName) {
      return res.status(400).json({ success: false, message: 'doctorId and patientName are required' });
    }
    const isAssigned = await assertAssignedDoctor(req.user.id, doctorId);
    if (!isAssigned) {
      return res.status(403).json({ success: false, message: 'This doctor is not assigned to your account' });
    }
    const doctorProfile = await DoctorProfile.findOne({ user_id: toId(doctorId) }).lean();
    const consultation = await Consultation.create({
      // No patient User account for a walk-in guest — patientId stays
      // unset, identity carried entirely by patientName/Age/Gender below.
      doctorId: toId(doctorId),
      patientName,
      patientAge: patientAge || '',
      patientGender: patientGender || '',
      reason: reason || '',
      isForSelf: false,
      status: 'active',
      isWalkIn: true,
      receptionistId: toId(req.user.id),
      consultationFee: doctorProfile?.consultation_fee || 0,
      appointmentId: null,
      channelName: null,
    });
    res.status(201).json({ success: true, consultation });
  } catch (err) {
    console.error('reception/walkin error:', err);
    res.status(500).json({ success: false, message: 'Failed to create walk-in consultation' });
  }
});

// ─── PROCEDURES ─────────────────────────────────────────────────────────────
router.post('/consultations/:consultationId/procedures', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { name, price } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'name is required' });
    const consultation = await Consultation.findById(toId(req.params.consultationId));
    if (!consultation) return res.status(404).json({ success: false, message: 'Consultation not found' });
    consultation.procedures.push({
      name,
      price: Number(price) || 0,
      addedBy: toId(req.user.id),
      addedAt: new Date(),
    });
    await consultation.save();
    res.json({ success: true, procedures: consultation.procedures });
  } catch (err) {
    console.error('reception add procedure error:', err);
    res.status(500).json({ success: false, message: 'Failed to add procedure' });
  }
});

router.delete('/consultations/:consultationId/procedures/:procedureId', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const consultation = await Consultation.findById(toId(req.params.consultationId));
    if (!consultation) return res.status(404).json({ success: false, message: 'Consultation not found' });
    consultation.procedures = consultation.procedures.filter(
      p => p._id.toString() !== req.params.procedureId
    );
    await consultation.save();
    res.json({ success: true, procedures: consultation.procedures });
  } catch (err) {
    console.error('reception remove procedure error:', err);
    res.status(500).json({ success: false, message: 'Failed to remove procedure' });
  }
});

// ─── CONSULTATION DETAIL (visit summary) ────────────────────────────────────
router.get('/consultations/:consultationId', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const consultation = await Consultation.findById(toId(req.params.consultationId)).lean();
    if (!consultation) return res.status(404).json({ success: false, message: 'Consultation not found' });
    const prescription = consultation.prescriptionId
      ? await EnhancedPrescription.findById(consultation.prescriptionId).lean()
      : null;
    res.json({ success: true, consultation, prescription });
  } catch (err) {
    console.error('reception get consultation error:', err);
    res.status(500).json({ success: false, message: 'Failed to load consultation' });
  }
});

module.exports = router;
