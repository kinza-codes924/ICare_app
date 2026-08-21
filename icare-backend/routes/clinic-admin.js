const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const ClinicAdminProfile = require('../models/ClinicAdminProfile');
const Appointment = require('../models/Appointment');
const Consultation = require('../models/Consultation');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

const clinicAdminOnly = [authMiddleware, roleMiddleware('admin')];

async function requireClinicId(req, res) {
  const profile = await ClinicAdminProfile.findOne({ user_id: toId(req.user.id) }).lean();
  if (!profile) {
    res.status(403).json({ success: false, message: 'This admin account is not scoped to a clinic' });
    return null;
  }
  return profile.clinicId;
}

// Lets the Flutter admin dashboard check, right after login, whether this
// admin account is clinic-scoped — if so it redirects to the clinic
// dashboard instead of the platform-wide admin screen. Returns clinicId:null
// for a regular platform admin (no ClinicAdminProfile), never an error.
router.get('/me', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const profile = await ClinicAdminProfile.findOne({ user_id: toId(req.user.id) }).lean();
    res.json({ success: true, clinicId: profile?.clinicId || null });
  } catch (err) {
    console.error('clinic-admin/me error:', err);
    res.status(500).json({ success: false, message: 'Failed to check clinic admin status' });
  }
});

// ─── MY CLINIC'S DOCTORS ────────────────────────────────────────────────────
router.get('/doctors', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profiles = await DoctorProfile.find({ clinicId }).lean();
    const doctors = await User.find({ _id: { $in: profiles.map(p => p.user_id) } })
      .select('name username email').lean();
    res.json({
      success: true,
      doctors: doctors.map(d => ({ _id: d._id.toString(), name: d.name || d.username || '', email: d.email || '' })),
    });
  } catch (err) {
    console.error('clinic-admin/doctors error:', err);
    res.status(500).json({ success: false, message: 'Failed to load clinic doctors' });
  }
});

// ─── BOOKINGS (appointments + walk-ins, merged) for every doctor in the clinic ──
// Gives the clinic-level admin the single-dashboard visibility the client
// asked for: "hamare paas kaise information aayegi" — every booking under
// this clinic's doctors, whether telehealth appointment or front-desk
// walk-in, in one place, sorted newest first.
router.get('/bookings', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;

    const profiles = await DoctorProfile.find({ clinicId }).select('user_id').lean();
    const doctorIds = profiles.map(p => p.user_id);
    if (doctorIds.length === 0) {
      return res.json({ success: true, bookings: [] });
    }

    const [appointments, walkins] = await Promise.all([
      Appointment.find({ doctor_id: { $in: doctorIds } }).sort({ createdAt: -1 }).limit(200).lean(),
      Consultation.find({ doctorId: { $in: doctorIds }, isWalkIn: true }).sort({ createdAt: -1 }).limit(200).lean(),
    ]);

    const doctorUsers = await User.find({ _id: { $in: doctorIds } }).select('name username').lean();
    const doctorNameById = new Map(doctorUsers.map(d => [d._id.toString(), d.name || d.username || '']));

    const patientIds = appointments.map(a => a.patient_id).filter(Boolean);
    const patients = patientIds.length
      ? await User.find({ _id: { $in: patientIds } }).select('name').lean()
      : [];
    const patientNameById = new Map(patients.map(p => [p._id.toString(), p.name || '']));

    const bookings = [
      ...appointments.map(a => ({
        bookingType: a.consultation_type === 'video' || a.channel_name ? 'telehealth' : 'appointment',
        id: a._id.toString(),
        doctorName: doctorNameById.get(a.doctor_id?.toString()) || '',
        patientName: patientNameById.get(a.patient_id?.toString()) || 'Patient',
        status: a.status,
        paymentStatus: a.paymentStatus,
        date: a.appointment_date || '',
        time: a.appointment_time || '',
        createdAt: a.createdAt,
      })),
      ...walkins.map(w => ({
        bookingType: 'walk-in',
        id: w._id.toString(),
        doctorName: doctorNameById.get(w.doctorId?.toString()) || '',
        patientName: w.patientName || 'Walk-in Patient',
        status: w.status,
        paymentStatus: w.paymentStatus,
        date: '',
        time: '',
        createdAt: w.createdAt,
      })),
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({ success: true, bookings });
  } catch (err) {
    console.error('clinic-admin/bookings error:', err);
    res.status(500).json({ success: false, message: 'Failed to load clinic bookings' });
  }
});

module.exports = router;
