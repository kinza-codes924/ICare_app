const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const Consultation = require('../models/Consultation');
const DoctorProfile = require('../models/DoctorProfile');
const ReceptionistProfile = require('../models/ReceptionistProfile');
const EnhancedPrescription = require('../models/EnhancedPrescription');
const StandaloneInvoice = require('../models/StandaloneInvoice');
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

    const docs = profile?.doctorIds || [];

    // Specialisation lives on DoctorProfile, not User — the front desk needs
    // it to tell two doctors apart when picking one for a walk-in.
    const DoctorProfile = require('../models/DoctorProfile');
    const specById = {};
    if (docs.length) {
      const profiles = await DoctorProfile
        .find({ user_id: { $in: docs.map(d => d._id) } })
        .select('user_id specialization')
        .lean();
      for (const p of profiles) {
        if (p.specialization) specById[p.user_id.toString()] = p.specialization;
      }
    }

    const doctors = docs.map(d => ({
      _id: d._id.toString(),
      name: d.name || d.username || '',
      email: d.email || '',
      specialization: specById[d._id.toString()] || '',
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
    const consultation = await Consultation.findById(toId(req.params.consultationId))
      .populate('doctorId', 'name username')
      .lean();
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

// Sets the SRB tax rate on a walk-in consultation before payment — the
// actual taxAmount is (re)computed server-side by payments.js's
// calculateAmount() at payment time, this just records the requested rate.
router.put('/consultations/:consultationId/tax', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const taxEnabled = req.body.taxEnabled !== false;
    const taxRate = Number(req.body.taxRate);
    if (taxEnabled && (!Number.isFinite(taxRate) || taxRate < 0)) {
      return res.status(400).json({ success: false, message: 'taxRate must be a non-negative number' });
    }
    const consultation = await Consultation.findByIdAndUpdate(
      toId(req.params.consultationId),
      { $set: { taxEnabled, taxRate: taxEnabled ? taxRate : 0 } },
      { new: true }
    ).lean();
    if (!consultation) return res.status(404).json({ success: false, message: 'Consultation not found' });
    res.json({ success: true, taxEnabled: consultation.taxEnabled, taxRate: consultation.taxRate });
  } catch (err) {
    console.error('reception set tax error:', err);
    res.status(500).json({ success: false, message: 'Failed to update tax rate' });
  }
});

// ─── STANDALONE INVOICES (not tied to any walk-in visit) ───────────────────
router.post('/invoices', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { clientName, items, taxRate, taxEnabled } = req.body;
    if (!clientName) return res.status(400).json({ success: false, message: 'clientName is required' });
    const cleanItems = (Array.isArray(items) ? items : [])
      .map(i => ({ name: (i?.name || '').toString().trim(), price: Number(i?.price) || 0 }))
      .filter(i => i.name);
    if (cleanItems.length === 0) {
      return res.status(400).json({ success: false, message: 'At least one item is required' });
    }
    const enabled = taxEnabled !== false;
    const rate = enabled && Number.isFinite(Number(taxRate)) ? Number(taxRate) : 0;
    // Server always computes the real totals — never trust client-sent sums.
    const subtotal = cleanItems.reduce((sum, i) => sum + i.price, 0);
    const taxAmount = subtotal * (rate / 100);
    const totalAmount = subtotal + taxAmount;
    const invoice = await StandaloneInvoice.create({
      receptionistId: toId(req.user.id),
      clientName,
      items: cleanItems,
      taxEnabled: enabled,
      taxRate: rate,
      subtotal,
      taxAmount,
      totalAmount,
    });
    res.status(201).json({ success: true, invoice });
  } catch (err) {
    console.error('reception create invoice error:', err);
    res.status(500).json({ success: false, message: 'Failed to create invoice' });
  }
});

router.get('/invoices/:invoiceId', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const invoice = await StandaloneInvoice.findById(toId(req.params.invoiceId)).lean();
    if (!invoice) return res.status(404).json({ success: false, message: 'Invoice not found' });
    res.json({ success: true, invoice });
  } catch (err) {
    console.error('reception get invoice error:', err);
    res.status(500).json({ success: false, message: 'Failed to load invoice' });
  }
});

// ─── RECORDS (paid walk-ins + paid standalone invoices, merged) ────────────
router.get('/records', ...receptionistOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const receptionistId = toId(req.user.id);
    const [visits, invoices] = await Promise.all([
      Consultation.find({ receptionistId, isWalkIn: true, paymentStatus: 'paid' }).lean(),
      StandaloneInvoice.find({ receptionistId, paymentStatus: 'paid' }).lean(),
    ]);
    const records = [
      ...visits.map(v => ({
        recordType: 'visit',
        id: v._id.toString(),
        title: v.patientName || 'Walk-in Patient',
        amount: (v.consultationFee || 0) + (v.procedures || []).reduce((s, p) => s + (p.price || 0), 0) + (v.taxAmount || 0),
        createdAt: v.createdAt,
      })),
      ...invoices.map(i => ({
        recordType: 'invoice',
        id: i._id.toString(),
        title: i.clientName,
        amount: i.totalAmount,
        createdAt: i.createdAt,
      })),
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.json({ success: true, records });
  } catch (err) {
    console.error('reception records error:', err);
    res.status(500).json({ success: false, message: 'Failed to load records' });
  }
});

module.exports = router;
