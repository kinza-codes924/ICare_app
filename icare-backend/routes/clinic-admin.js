const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const ClinicAdminProfile = require('../models/ClinicAdminProfile');
const ReceptionistProfile = require('../models/ReceptionistProfile');
const LabProfile = require('../models/LabProfile');
const PharmacyProfile = require('../models/PharmacyProfile');
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

// ─── STAFF MANAGEMENT — Receptionist / Doctor / Lab / Pharmacy ──────────────
// Every route below derives clinicId from the CALLER's own ClinicAdminProfile
// via requireClinicId() — never from the request body — so a clinic admin
// can only ever create/see/edit/remove staff scoped to their own clinic.
// Mirrors admin.js's platform-wide creation shape (same User fields,
// is_approved:false so accounts still flow through the existing Pending
// Users approval screen, same profile-model creation), just clinic-forced.

async function createStaffUser({ name, email, password, role }) {
  const existing = await User.findOne({ email: String(email).toLowerCase() });
  if (existing) return { error: 'A user with this email already exists' };
  const hashed = await bcrypt.hash(password, 10);
  const user = await User.create({
    username: name,
    name,
    email: String(email).toLowerCase(),
    password: hashed,
    role,
    is_approved: false,
    is_active: true,
  });
  return { user };
}

// ── Receptionists ──
router.post('/receptionists', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const { name, email, password, doctorIds, speciality } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'name, email and password are required' });
    }
    const { user, error } = await createStaffUser({ name, email, password, role: 'receptionist' });
    if (error) return res.status(400).json({ success: false, message: error });

    // Restrict assignable doctors to this clinic's own doctors — a
    // receptionist scoped to one clinic shouldn't be wired to another
    // clinic's doctor even if the id was supplied.
    const requestedIds = Array.isArray(doctorIds) ? doctorIds.map(toId).filter(Boolean) : [];
    let doctorIdList = [];
    if (requestedIds.length) {
      const clinicDoctorProfiles = await DoctorProfile.find({ clinicId, user_id: { $in: requestedIds } }).select('user_id').lean();
      doctorIdList = clinicDoctorProfiles.map(p => p.user_id);
    }

    await ReceptionistProfile.create({
      user_id: user._id,
      doctorIds: doctorIdList,
      speciality: speciality || null,
      clinicName: clinicId,
    });
    res.status(201).json({ success: true, message: 'Receptionist created — pending approval', user: { _id: user._id.toString(), email: user.email } });
  } catch (err) {
    console.error('clinic-admin/receptionists create error:', err);
    res.status(500).json({ success: false, message: 'Failed to create receptionist' });
  }
});

router.get('/receptionists', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profiles = await ReceptionistProfile.find({ clinicName: clinicId })
      .populate('doctorIds', 'name username email')
      .lean();
    const users = await User.find({ _id: { $in: profiles.map(p => p.user_id) } }).select('-password').lean();
    const userById = new Map(users.map(u => [u._id.toString(), u]));
    const result = profiles.map(p => {
      const u = userById.get(p.user_id.toString());
      return {
        _id: p.user_id.toString(),
        name: u?.name || u?.username || '',
        email: u?.email || '',
        isApproved: u?.is_approved === true,
        speciality: p.speciality || '',
        createdAt: u?.createdAt,
        doctors: (p.doctorIds || []).map(d => ({ _id: d._id.toString(), name: d.name || d.username || '' })),
      };
    });
    res.json({ success: true, receptionists: result });
  } catch (err) {
    console.error('clinic-admin/receptionists list error:', err);
    res.status(500).json({ success: false, message: 'Failed to load receptionists' });
  }
});

router.put('/receptionists/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await ReceptionistProfile.findOne({ user_id: toId(req.params.userId) });
    if (!profile || profile.clinicName !== clinicId) {
      return res.status(404).json({ success: false, message: 'Receptionist not found' });
    }
    if (Array.isArray(req.body.doctorIds)) {
      const requestedIds = req.body.doctorIds.map(toId).filter(Boolean);
      const clinicDoctorProfiles = requestedIds.length
        ? await DoctorProfile.find({ clinicId, user_id: { $in: requestedIds } }).select('user_id').lean()
        : [];
      profile.doctorIds = clinicDoctorProfiles.map(p => p.user_id);
    }
    if (req.body.speciality !== undefined) profile.speciality = req.body.speciality || null;
    await profile.save();
    res.json({ success: true, message: 'Receptionist updated' });
  } catch (err) {
    console.error('clinic-admin/receptionists update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update receptionist' });
  }
});

router.delete('/receptionists/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await ReceptionistProfile.findOne({ user_id: toId(req.params.userId) }).lean();
    if (!profile || profile.clinicName !== clinicId) {
      return res.status(404).json({ success: false, message: 'Receptionist not found' });
    }
    await User.findByIdAndUpdate(req.params.userId, { is_active: false });
    res.json({ success: true, message: 'Receptionist removed' });
  } catch (err) {
    console.error('clinic-admin/receptionists delete error:', err);
    res.status(500).json({ success: false, message: 'Failed to remove receptionist' });
  }
});

// ── Doctors ──
router.post('/doctors', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const { name, email, password, specialization } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'name, email and password are required' });
    }
    const { user, error } = await createStaffUser({ name, email, password, role: 'doctor' });
    if (error) return res.status(400).json({ success: false, message: error });
    await DoctorProfile.create({
      user_id: user._id,
      specialization: specialization || null,
      clinicId,
    });
    res.status(201).json({ success: true, message: 'Doctor created — pending approval', user: { _id: user._id.toString(), email: user.email } });
  } catch (err) {
    console.error('clinic-admin/doctors create error:', err);
    res.status(500).json({ success: false, message: 'Failed to create doctor' });
  }
});

router.put('/doctors/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await DoctorProfile.findOne({ user_id: toId(req.params.userId) });
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Doctor not found' });
    }
    if (req.body.specialization !== undefined) profile.specialization = req.body.specialization || null;
    await profile.save();
    res.json({ success: true, message: 'Doctor updated' });
  } catch (err) {
    console.error('clinic-admin/doctors update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update doctor' });
  }
});

router.delete('/doctors/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await DoctorProfile.findOne({ user_id: toId(req.params.userId) }).lean();
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Doctor not found' });
    }
    await User.findByIdAndUpdate(req.params.userId, { is_active: false });
    res.json({ success: true, message: 'Doctor removed' });
  } catch (err) {
    console.error('clinic-admin/doctors delete error:', err);
    res.status(500).json({ success: false, message: 'Failed to remove doctor' });
  }
});

// ── Lab ──
router.post('/lab', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const { name, email, password, lab_name } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'name, email and password are required' });
    }
    const { user, error } = await createStaffUser({ name, email, password, role: 'lab' });
    if (error) return res.status(400).json({ success: false, message: error });
    await LabProfile.create({ user_id: user._id, lab_name: lab_name || name, clinicId });
    res.status(201).json({ success: true, message: 'Lab account created — pending approval', user: { _id: user._id.toString(), email: user.email } });
  } catch (err) {
    console.error('clinic-admin/lab create error:', err);
    res.status(500).json({ success: false, message: 'Failed to create lab account' });
  }
});

router.get('/lab', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profiles = await LabProfile.find({ clinicId }).lean();
    const users = await User.find({ _id: { $in: profiles.map(p => p.user_id) } }).select('-password').lean();
    const userById = new Map(users.map(u => [u._id.toString(), u]));
    res.json({
      success: true,
      labs: profiles.map(p => ({
        _id: p.user_id.toString(),
        name: userById.get(p.user_id.toString())?.name || '',
        email: userById.get(p.user_id.toString())?.email || '',
        lab_name: p.lab_name || '',
        isApproved: userById.get(p.user_id.toString())?.is_approved === true,
      })),
    });
  } catch (err) {
    console.error('clinic-admin/lab list error:', err);
    res.status(500).json({ success: false, message: 'Failed to load lab accounts' });
  }
});

router.put('/lab/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await LabProfile.findOne({ user_id: toId(req.params.userId) });
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Lab account not found' });
    }
    if (req.body.lab_name !== undefined) profile.lab_name = req.body.lab_name;
    await profile.save();
    res.json({ success: true, message: 'Lab account updated' });
  } catch (err) {
    console.error('clinic-admin/lab update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update lab account' });
  }
});

router.delete('/lab/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await LabProfile.findOne({ user_id: toId(req.params.userId) }).lean();
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Lab account not found' });
    }
    await User.findByIdAndUpdate(req.params.userId, { is_active: false });
    res.json({ success: true, message: 'Lab account removed' });
  } catch (err) {
    console.error('clinic-admin/lab delete error:', err);
    res.status(500).json({ success: false, message: 'Failed to remove lab account' });
  }
});

// ── Pharmacy ──
router.post('/pharmacy', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const { name, email, password, pharmacy_name } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'name, email and password are required' });
    }
    const { user, error } = await createStaffUser({ name, email, password, role: 'pharmacy' });
    if (error) return res.status(400).json({ success: false, message: error });
    await PharmacyProfile.create({ user_id: user._id, pharmacy_name: pharmacy_name || name, clinicId });
    res.status(201).json({ success: true, message: 'Pharmacy account created — pending approval', user: { _id: user._id.toString(), email: user.email } });
  } catch (err) {
    console.error('clinic-admin/pharmacy create error:', err);
    res.status(500).json({ success: false, message: 'Failed to create pharmacy account' });
  }
});

router.get('/pharmacy', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profiles = await PharmacyProfile.find({ clinicId }).lean();
    const users = await User.find({ _id: { $in: profiles.map(p => p.user_id) } }).select('-password').lean();
    const userById = new Map(users.map(u => [u._id.toString(), u]));
    res.json({
      success: true,
      pharmacies: profiles.map(p => ({
        _id: p.user_id.toString(),
        name: userById.get(p.user_id.toString())?.name || '',
        email: userById.get(p.user_id.toString())?.email || '',
        pharmacy_name: p.pharmacy_name || '',
        isApproved: userById.get(p.user_id.toString())?.is_approved === true,
      })),
    });
  } catch (err) {
    console.error('clinic-admin/pharmacy list error:', err);
    res.status(500).json({ success: false, message: 'Failed to load pharmacy accounts' });
  }
});

router.put('/pharmacy/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await PharmacyProfile.findOne({ user_id: toId(req.params.userId) });
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Pharmacy account not found' });
    }
    if (req.body.pharmacy_name !== undefined) profile.pharmacy_name = req.body.pharmacy_name;
    await profile.save();
    res.json({ success: true, message: 'Pharmacy account updated' });
  } catch (err) {
    console.error('clinic-admin/pharmacy update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update pharmacy account' });
  }
});

router.delete('/pharmacy/:userId', ...clinicAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const clinicId = await requireClinicId(req, res);
    if (!clinicId) return;
    const profile = await PharmacyProfile.findOne({ user_id: toId(req.params.userId) }).lean();
    if (!profile || profile.clinicId !== clinicId) {
      return res.status(404).json({ success: false, message: 'Pharmacy account not found' });
    }
    await User.findByIdAndUpdate(req.params.userId, { is_active: false });
    res.json({ success: true, message: 'Pharmacy account removed' });
  } catch (err) {
    console.error('clinic-admin/pharmacy delete error:', err);
    res.status(500).json({ success: false, message: 'Failed to remove pharmacy account' });
  }
});

module.exports = router;
