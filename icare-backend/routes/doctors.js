const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const Appointment = require('../models/Appointment');
const { authMiddleware } = require('../middleware/auth');
const MedicalRecord = require('../models/MedicalRecord');
const EnhancedPrescription = require('../models/EnhancedPrescription');
const PharmacyOrder = require('../models/PharmacyOrder');
const Consultation = require('../models/Consultation');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

/** Pharmacy rejection reasons that must appear only on Admin reporting, not Doctor Clinical Flags. */
function isNoReferrerReason(raw) {
  if (raw == null) return false;
  const n = String(raw).toLowerCase().replace(/[_-]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (!n) return false;
  return n === 'no referrer' || n.includes('no referrer');
}

// ─── DOCTOR STATS ─────────────────────────────────────────────────────────────
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id);
    const [total, pending, confirmed, completed, cancelled, missed, profile, consultations] = await Promise.all([
      Appointment.countDocuments({ doctor_id: doctorId }),
      Appointment.countDocuments({ doctor_id: doctorId, status: 'pending' }),
      Appointment.countDocuments({ doctor_id: doctorId, status: 'confirmed' }),
      Appointment.countDocuments({ doctor_id: doctorId, status: 'completed' }),
      Appointment.countDocuments({ doctor_id: doctorId, status: 'cancelled' }),
      Appointment.countDocuments({ doctor_id: doctorId, status: 'missed' }),
      DoctorProfile.findOne({ user_id: doctorId }).lean(),
      Consultation.find({ doctorId, status: 'completed', duration: { $gt: 0 } }).select('duration').lean(),
    ]);

    // Average consultation time in minutes (duration stored in seconds)
    let avgConsultationMinutes = null;
    if (consultations.length > 0) {
      const totalSeconds = consultations.reduce((sum, c) => sum + (c.duration || 0), 0);
      avgConsultationMinutes = Math.round((totalSeconds / consultations.length / 60) * 10) / 10;
    }

    // Revenue = completed appointments × consultation fee
    const consultationFee = profile?.consultation_fee || 0;
    const revenue = completed * consultationFee;

    // Compute avgRating and satisfaction from actual patient reviews
    const ratedAppts = await Appointment.find({
      doctor_id: doctorId,
      rating: { $gte: 1, $lte: 5 },
    }).select('rating satisfied').lean();

    const avgRatingVal = ratedAppts.length > 0
      ? Math.round((ratedAppts.reduce((s, a) => s + (a.rating || 0), 0) / ratedAppts.length) * 10) / 10
      : 0;
    const satisfiedCount = ratedAppts.filter(a => a.satisfied !== false).length;
    const satisfactionPct = ratedAppts.length > 0
      ? Math.round((satisfiedCount / ratedAppts.length) * 100)
      : 0;

    res.json({
      success: true,
      stats: {
        totalAppointments: total,
        pendingAppointments: pending,
        confirmedAppointments: confirmed,
        completedAppointments: completed,
        cancelledAppointments: cancelled,
        missedAppointments: missed,
        rating: avgRatingVal,
        totalReviews: ratedAppts.length,
        revenue,
        satisfaction: `${satisfactionPct}%`,
        avgRating: avgRatingVal,
        consultationFee,
        avgConsultationMinutes,
      },
    });
  } catch (e) {
    console.error('Doctor stats error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── SET ONLINE STATUS ────────────────────────────────────────────────────────
router.post('/online-status', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role?.toLowerCase() !== 'doctor') {
      return res.status(403).json({ success: false, message: 'Only doctors can update online status' });
    }
    const userId = toId(req.user.id);
    const { isOnline } = req.body;

    await DoctorProfile.findOneAndUpdate(
      { user_id: userId },
      { $set: { is_online: !!isOnline, last_seen: new Date() } },
      { upsert: true }
    );

    res.json({ success: true, isOnline: !!isOnline });
  } catch (e) {
    console.error('Online status error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET ALL DOCTORS ──────────────────────────────────────────────────────────
router.get('/get_all_doctors', async (req, res) => {
  try {
    await connectMongoDB();
    // Case-insensitive match — old accounts may have 'Doctor' (capital D)
    const doctors = await User.find({ role: /^doctor$/i, is_active: { $ne: false } }).lean();
    const ids = doctors.map(d => d._id);
    const profiles = await DoctorProfile.find({ user_id: { $in: ids } }).lean();
    const profileMap = {};
    profiles.forEach(p => { profileMap[p.user_id.toString()] = p; });

    const result = doctors.map(d => {
      const p = profileMap[d._id.toString()] || {};
      // Consider online if last_seen within 5 minutes
      const lastSeen = p.last_seen ? new Date(p.last_seen) : null;
      const isOnline = p.is_online === true &&
        lastSeen &&
        (Date.now() - lastSeen.getTime()) < 5 * 60 * 1000;

      return {
        id: d._id.toString(),
        _id: d._id.toString(),
        name: d.username || d.name,
        email: d.email,
        phoneNumber: d.phone,
        role: d.role,
        profilePicture: d.profilePicture || null,
        specialization: p.specialization,
        experience: p.experience_years,
        licenseNumber: p.license_number,
        consultationFee: p.consultation_fee,
        conditionsTreated: p.conditions_treated || [],
        availableDays: p.available_days,
        availableTime: p.available_hours,
        rating: p.rating || 0,
        totalReviews: p.total_reviews || 0,
        isOnline: !!isOnline,
      };
    });

    res.json({ success: true, doctors: result });
  } catch (error) {
    console.error('Get doctors error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch doctors' });
  }
});

// ─── UPDATE DOCTOR PROFILE ────────────────────────────────────────────────────
router.post('/add_doctor_details', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role?.toLowerCase() !== 'doctor') {
      return res.status(403).json({ success: false, message: 'Only doctors can update doctor profiles' });
    }
    const userId = toId(req.user.id);
    const {
      specialization, experience, licenseNumber,
      consultationFee, availableDays, availableTime,
      degrees, clinicName, clinicAddress, consultationType, languages,
      profilePicture, conditionsTreated,
    } = req.body;

    const update = {};
    if (specialization !== undefined) update.specialization = specialization;
    if (experience !== undefined) update.experience_years = parseInt(experience) || 0;
    if (licenseNumber !== undefined) update.license_number = licenseNumber;
    if (consultationFee !== undefined) update.consultation_fee = parseFloat(consultationFee) || 0;
    if (availableDays !== undefined) update.available_days = availableDays;
    if (availableTime !== undefined) {
      update.available_hours = typeof availableTime === 'object'
        ? `${availableTime.start || ''} - ${availableTime.end || ''}`
        : availableTime;
    }
    if (degrees !== undefined) update.degrees = degrees;
    if (clinicName !== undefined) update.clinic_name = clinicName;
    if (clinicAddress !== undefined) update.clinic_address = clinicAddress;
    if (consultationType !== undefined) update.consultation_type = consultationType;
    if (languages !== undefined) update.languages = languages;
    if (conditionsTreated !== undefined) update.conditions_treated = conditionsTreated;

    const profile = await DoctorProfile.findOneAndUpdate(
      { user_id: userId },
      { $set: update },
      { new: true, upsert: true }
    );

    // Save profilePicture to User model so it's returned by /users/profile
    if (profilePicture !== undefined) {
      await User.findByIdAndUpdate(userId, { $set: { profilePicture } });
    }

    res.json({ success: true, message: 'Profile updated successfully', profile });
  } catch (error) {
    console.error('Update doctor profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
});

// ─── MY PATIENT REVIEWS (rated appointments) ──────────────────────────────────
router.get('/me/patient-reviews', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role?.toLowerCase() !== 'doctor') {
      return res.status(403).json({ success: false, message: 'Only doctors can view patient reviews' });
    }
    const doctorId = toId(req.user.id);
    const rows = await Appointment.find({
      doctor_id: doctorId,
      rating: { $gte: 1, $lte: 5 },
    })
      .populate('patient_id', 'name username')
      .sort({ ratedAt: -1, createdAt: -1 })
      .limit(200)
      .lean();

    const reviews = rows.map((a) => {
      const p = a.patient_id;
      const patientName = (p && typeof p === 'object')
        ? (p.username || p.name || 'Patient')
        : 'Patient';
      return {
        appointmentId: a._id.toString(),
        patientName,
        rating: a.rating,
        comment: a.ratingComment || '',
        satisfied: a.satisfied !== false,
        ratedAt: a.ratedAt || a.updatedAt || a.createdAt,
      };
    });

    res.json({ success: true, reviews, count: reviews.length });
  } catch (e) {
    console.error('me/patient-reviews error:', e);
    res.status(500).json({ success: false, message: e.message || 'Failed to load reviews' });
  }
});

// ─── GET MY AVAILABILITY ─────────────────────────────────────────────────────
router.get('/availability/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, availability: {} });

    const profile = await DoctorProfile.findOne({ user_id: doctorId }).lean();
    const availability = {
      availableDays: profile?.available_days || ['Monday','Tuesday','Wednesday','Thursday','Friday'],
      availableTime: { start: profile?.available_hours?.start || '09:00', end: profile?.available_hours?.end || '17:00' },
      unavailableDates: profile?.unavailableDates || [],
      bufferTime: profile?.bufferTime || 15,
      leaveRequests: (profile?.leaveRequests || []).filter(r => r.status === 'approved'),
    };
    res.json({ success: true, availability });
  } catch (e) {
    console.error('availability/me error:', e);
    res.json({ success: true, availability: {} });
  }
});

// ─── NAMED-PATH ALIASES (must be before /:id catch-all) ──────────────────────
// clinical-rejection-flags, leave-requests, availability/me are defined AFTER
// /:id below; re-register them here so Express matches them first.

router.get('/clinical-rejection-flags', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role?.toLowerCase() !== 'doctor') return res.status(403).json({ success: false, message: 'Forbidden' });
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, flags: [], totalRejections: 0 });
    const [medRecords, epRows] = await Promise.all([
      MedicalRecord.find({ doctor: doctorId }).select('_id').lean(),
      EnhancedPrescription.find({ doctorId }).select('_id').lean(),
    ]);
    const mrIdSet = new Set(medRecords.map(r => r._id.toString()));
    const epIdSet = new Set(epRows.map(p => p._id.toString()));
    const prescIds = [...new Set([...mrIdSet, ...epIdSet])];
    if (prescIds.length === 0) return res.json({ success: true, flags: [], totalRejections: 0 });
    const orders = await PharmacyOrder.find({ status: 'rejected', prescription_id: { $in: prescIds } }).sort({ updatedAt: -1 }).limit(50).lean();
    const patientIdStrings = [...new Set(orders.map(o => o.patient_id?.toString()).filter(Boolean))];
    const patients = patientIdStrings.length ? await User.find({ _id: { $in: patientIdStrings.map(toId) } }).lean() : [];
    const pMap = {};
    patients.forEach(p => { pMap[p._id.toString()] = p; });
    function isNoReferrer(raw) {
      if (!raw) return false;
      const n = String(raw).toLowerCase().replace(/[_-]+/g,' ').trim();
      return n === 'no referrer' || n.includes('no referrer');
    }
    const flags = [];
    for (const o of orders) {
      const pid = o.prescription_id;
      if (!pid || !prescIds.includes(pid)) continue;
      const reason = o.rejection_reason || o.cancellation_reason || '';
      if (isNoReferrer(reason)) continue;
      const ptId = o.patient_id?.toString() || '';
      const pt = pMap[ptId];
      const patientName = pt?.username || pt?.name || 'Patient';
      flags.push({ orderId: o._id.toString(), orderNumber: o.order_number || `#${o._id.toString().slice(-8).toUpperCase()}`, prescriptionId: pid, prescriptionSource: mrIdSet.has(pid) ? 'medical_record' : 'enhanced_prescription', patientId: ptId, patientName, rejectionReason: reason || 'Rejected by pharmacy', rejectedAt: o.updatedAt || o.createdAt });
    }
    res.json({ success: true, flags, totalRejections: flags.length });
  } catch (e) { console.error('clinical-rejection-flags error:', e); res.status(500).json({ success: false, message: e.message }); }
});

router.get('/leave-requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, leaveRequests: [] });
    const profile = await DoctorProfile.findOne({ user_id: doctorId }).lean();
    const requests = (profile?.leaveRequests || []).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.json({ success: true, leaveRequests: requests });
  } catch (e) { console.error('leave-requests GET error:', e); res.status(500).json({ success: false, message: e.message }); }
});

router.post('/leave-requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.status(400).json({ success: false, message: 'Invalid doctor id' });
    const { fromDate, toDate, reason } = req.body;
    if (!fromDate || !toDate) return res.status(400).json({ success: false, message: 'fromDate and toDate are required' });
    const from = new Date(fromDate); const to = new Date(toDate);
    if (isNaN(from) || isNaN(to) || from > to) return res.status(400).json({ success: false, message: 'Invalid date range' });
    const conflicting = await Appointment.countDocuments({ doctor_id: doctorId, status: { $in: ['pending','confirmed'] }, appointmentDate: { $gte: from, $lte: to } });
    await DoctorProfile.findOneAndUpdate({ user_id: doctorId }, { $push: { leaveRequests: { _id: new mongoose.Types.ObjectId(), fromDate: from, toDate: to, reason: reason||'', status:'pending', conflictingAppointments: conflicting, createdAt: new Date() } } }, { upsert: true });
    res.json({ success: true, message: 'Leave request submitted. Pending admin approval.', conflictingAppointments: conflicting });
  } catch (e) { console.error('leave-requests POST error:', e); res.status(500).json({ success: false, message: e.message }); }
});

// ─── GET DOCTOR BY ID ─────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    await connectMongoDB();
    const id = toId(req.params.id);
    if (!id) return res.status(400).json({ success: false, message: 'Invalid doctor ID' });

    const user = await User.findOne({ _id: id, role: /^doctor$/i }).lean();
    if (!user) return res.status(404).json({ success: false, message: 'Doctor not found' });

    const profile = await DoctorProfile.findOne({ user_id: id }).lean() || {};

    res.json({
      success: true,
      doctor: {
        id: user._id.toString(),
        _id: user._id.toString(),
        name: user.username || user.name,
        email: user.email,
        phoneNumber: user.phone,
        role: user.role,
        profilePicture: user.profilePicture || null,
        specialization: profile.specialization,
        experience: profile.experience_years,
        licenseNumber: profile.license_number,
        consultationFee: profile.consultation_fee,
        availableDays: profile.available_days,
        availableTime: profile.available_hours,
        rating: profile.rating || 0,
        totalReviews: profile.total_reviews || 0,
      },
    });
  } catch (error) {
    console.error('Get doctor error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch doctor' });
  }
});

// ─── GET PATIENT HISTORY ──────────────────────────────────────────────────────
// ─── PATIENT HISTORY (for doctor viewing patient records) ────────────────────
// Access is allowed only if this doctor has at least one non-cancelled appointment
// with the patient. After consultation ends, doctors lose access unless another
// appointment exists.
router.get('/patients/:patientId/history', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const patientId = toId(req.params.patientId);
    if (!patientId) return res.status(400).json({ success: false, message: 'Invalid patient ID' });

    const doctorId = toId(req.user.id);

    // Verify this doctor has an appointment with this patient (any non-cancelled status)
    const hasAccess = await Appointment.exists({
      doctor_id: doctorId,
      patient_id: patientId,
      status: { $nin: ['cancelled', 'rejected'] },
    });

    if (!hasAccess) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. No active appointment found with this patient.',
      });
    }

    // Get completed appointments for this patient
    const appointments = await Appointment.find({
      patient_id: patientId,
      status: { $in: ['completed', 'confirmed'] },
    }).sort({ createdAt: -1 }).lean();

    res.json({
      success: true,
      history: appointments.map(a => ({
        ...a,
        _id: a._id.toString(),
        id: a._id.toString(),
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to fetch patient history' });
  }
});

// ─── CLINICAL FLAGS: pharmacy rejections on this doctor's prescriptions ───────
// "No referrer" rejections are omitted here and should be surfaced only to Admin.
router.get('/clinical-rejection-flags', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role?.toLowerCase() !== 'doctor') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, flags: [], totalRejections: 0 }); // graceful empty

    const [medRecords, epRows] = await Promise.all([
      MedicalRecord.find({ doctor: doctorId }).select('_id').lean(),
      EnhancedPrescription.find({ doctorId }).select('_id').lean(),
    ]);

    const mrIdSet = new Set(medRecords.map((r) => r._id.toString()));
    const epIdSet = new Set(epRows.map((p) => p._id.toString()));
    const prescIds = [...new Set([...mrIdSet, ...epIdSet])];

    if (prescIds.length === 0) {
      return res.json({ success: true, flags: [], totalRejections: 0 });
    }

    const orders = await PharmacyOrder.find({
      status: 'rejected',
      prescription_id: { $in: prescIds },
    })
      .sort({ updatedAt: -1 })
      .limit(50)
      .lean();

    const patientIdStrings = [...new Set(orders.map((o) => o.patient_id?.toString()).filter(Boolean))];
    const patients = patientIdStrings.length
      ? await User.find({ _id: { $in: patientIdStrings.map(toId) } }).lean()
      : [];
    const pMap = {};
    patients.forEach((p) => {
      pMap[p._id.toString()] = p;
    });

    const flags = [];
    for (const o of orders) {
      const pid = o.prescription_id;
      if (!pid || !prescIds.includes(pid)) continue;

      const reason = o.rejection_reason || o.cancellation_reason || '';
      if (isNoReferrerReason(reason)) continue;

      const ptId = o.patient_id?.toString() || '';
      const pt = pMap[ptId];
      const patientName = pt?.username || pt?.name || 'Patient';

      const prescriptionSource = mrIdSet.has(pid) ? 'medical_record' : 'enhanced_prescription';

      flags.push({
        orderId: o._id.toString(),
        orderNumber: o.order_number || `#${o._id.toString().slice(-8).toUpperCase()}`,
        prescriptionId: pid,
        prescriptionSource,
        patientId: ptId,
        patientName,
        rejectionReason: reason || 'Rejected by pharmacy',
        rejectedAt: o.updatedAt || o.createdAt,
      });
    }

    const totalRejections = flags.length;

    res.json({
      success: true,
      flags,
      totalRejections,
    });
  } catch (e) {
    console.error('clinical-rejection-flags error:', e);
    res.status(500).json({ success: false, message: e.message || 'Failed to load clinical flags' });
  }
});

// ─── LEAVE REQUESTS ───────────────────────────────────────────────────────────

// POST /doctors/leave-requests — doctor submits a leave/unavailability request
router.post('/leave-requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.status(400).json({ success: false, message: 'Invalid doctor id — check JWT payload' });

    const { fromDate, toDate, reason } = req.body;
    if (!fromDate || !toDate) return res.status(400).json({ success: false, message: 'fromDate and toDate are required' });

    const from = new Date(fromDate);
    const to   = new Date(toDate);
    if (isNaN(from) || isNaN(to) || from > to) {
      return res.status(400).json({ success: false, message: 'Invalid date range' });
    }

    // Check if any confirmed appointments exist in that range
    const conflicting = await Appointment.countDocuments({
      doctor_id: doctorId,
      status: { $in: ['pending', 'confirmed'] },
      appointmentDate: { $gte: from, $lte: to },
    });

    // Store in DoctorProfile.leaveRequests array
    await DoctorProfile.findOneAndUpdate(
      { user_id: doctorId },
      {
        $push: {
          leaveRequests: {
            fromDate: from,
            toDate: to,
            reason: reason || '',
            status: 'pending',
            conflictingAppointments: conflicting,
            createdAt: new Date(),
          },
        },
      },
      { upsert: true }
    );

    res.json({ success: true, message: 'Leave request submitted. Pending admin approval.', conflictingAppointments: conflicting });
  } catch (e) {
    console.error('leave-requests POST error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /doctors/leave-requests — doctor views their own leave requests
router.get('/leave-requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, leaveRequests: [] });

    const profile = await DoctorProfile.findOne({ user_id: doctorId }).lean();
    const requests = profile?.leaveRequests || [];
    // Sort newest first
    requests.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({ success: true, leaveRequests: requests });
  } catch (e) {
    console.error('leave-requests GET error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
