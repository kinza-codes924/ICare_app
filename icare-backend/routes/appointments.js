const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const Appointment = require('../models/Appointment');
const DoctorProfile = require('../models/DoctorProfile');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

async function getAppointments(userId, userRole) {
  await connectMongoDB();
  const uid = toId(userId);

  // Auto-fix stale in_progress sessions older than 2 hours → revert to confirmed
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
  await Appointment.updateMany(
    { status: 'in_progress', updatedAt: { $lt: twoHoursAgo } },
    { $set: { status: 'confirmed' } }
  ).catch(() => {});

  let appointments;

  // Case-insensitive role check — some accounts have 'Doctor', some have 'doctor'
  if (userRole?.toLowerCase() === 'doctor') {
    appointments = await Appointment.find({ doctor_id: uid }).sort({ createdAt: -1 }).lean();
    const patientIds = [...new Set(appointments.map(a => a.patient_id.toString()))];
    const patients = await User.find({ _id: { $in: patientIds.map(id => toId(id)) } }).lean();
    const pMap = {};
    patients.forEach(p => { pMap[p._id.toString()] = p; });
    return appointments.map(a => {
      const p = pMap[a.patient_id.toString()];
      return {
        ...a,
        id: a._id.toString(),
        _id: a._id.toString(),
        patient_id: a.patient_id.toString(),
        patient_name: p?.username || p?.name,
        patient_age: p?.age?.toString() ?? null,
        patient_gender: p?.gender ?? null,
        patient_profilePicture: p?.profilePicture || null,
        // contact details intentionally excluded from doctor view
      };
    });
  } else {
    appointments = await Appointment.find({ patient_id: uid }).sort({ createdAt: -1 }).lean();
    const doctorIds = [...new Set(appointments.map(a => a.doctor_id.toString()))];
    const doctors = await User.find({ _id: { $in: doctorIds.map(id => toId(id)) } }).lean();
    const profiles = await DoctorProfile.find({ user_id: { $in: doctorIds.map(id => toId(id)) } }).lean();
    const dMap = {};
    doctors.forEach(d => { dMap[d._id.toString()] = d; });
    const pMap = {};
    profiles.forEach(p => { pMap[p.user_id.toString()] = p; });
    return appointments.map(a => ({
      ...a,
      id: a._id.toString(),
      _id: a._id.toString(),
      doctor_id: a.doctor_id.toString(),
      doctor_name: dMap[a.doctor_id.toString()]?.username || dMap[a.doctor_id.toString()]?.name,
      doctor_email: dMap[a.doctor_id.toString()]?.email,
      doctor_phone: dMap[a.doctor_id.toString()]?.phone,
      specialization: pMap[a.doctor_id.toString()]?.specialization,
      consultation_fee: pMap[a.doctor_id.toString()]?.consultation_fee,
      channel_name: a.channel_name || '',
    }));
  }
}

// GET /appointments
router.get('/', authMiddleware, async (req, res) => {
  try {
    const appts = await getAppointments(req.user.id, req.user.role);
    res.json({ success: true, appointments: appts });
  } catch (error) {
    console.error('Get appointments error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch appointments' });
  }
});

// GET /appointments/getAppointments
router.get('/getAppointments', authMiddleware, async (req, res) => {
  try {
    const appts = await getAppointments(req.user.id, req.user.role);
    res.json({ success: true, appointments: appts, count: appts.length });
  } catch (error) {
    console.error('Get appointments error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch appointments' });
  }
});

// POST /appointments - create
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const patientId = toId(req.user.id);
    const { doctorId, appointmentDate, appointmentTime, consultationType, notes } = req.body;

    if (!doctorId || !appointmentDate || !appointmentTime) {
      return res.status(400).json({ success: false, message: 'Doctor, date, and time are required' });
    }

    const doctor = await User.findOne({ _id: toId(doctorId), role: /^doctor$/i });
    if (!doctor) {
      return res.status(404).json({ success: false, message: 'Doctor not found' });
    }

    const appt = await Appointment.create({
      patient_id: patientId,
      doctor_id: toId(doctorId),
      appointment_date: appointmentDate,
      appointment_time: appointmentTime,
      consultation_type: consultationType || 'in-person',
      notes: notes || '',
      status: 'pending',
    });

    res.status(201).json({ success: true, message: 'Appointment booked successfully', appointment: { ...appt.toObject(), id: appt._id.toString() } });
  } catch (error) {
    console.error('Create appointment error:', error);
    res.status(500).json({ success: false, message: 'Failed to book appointment' });
  }
});

// POST /appointments/book_appointment
router.post('/book_appointment', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const patientId = toId(req.user.id);
    const { doctorId, date, timeSlot, reason } = req.body;

    if (!doctorId || !date || !timeSlot) {
      return res.status(400).json({ success: false, message: 'Doctor, date, and time are required' });
    }

    const doctor = await User.findOne({ _id: toId(doctorId), role: /^doctor$/i });
    if (!doctor) {
      return res.status(404).json({ success: false, message: 'Doctor not found' });
    }

    const appt = await Appointment.create({
      patient_id: patientId,
      doctor_id: toId(doctorId),
      appointment_date: new Date(date).toISOString().split('T')[0],
      appointment_time: timeSlot,
      consultation_type: 'in-person',
      notes: reason || '',
      status: 'pending',
    });

    res.status(201).json({ success: true, message: 'Appointment booked successfully', appointment: { ...appt.toObject(), id: appt._id.toString() } });
  } catch (error) {
    console.error('Book appointment error:', error);
    res.status(500).json({ success: false, message: 'Failed to book appointment' });
  }
});

// PUT /appointments/update_status
router.put('/update_status', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { appointmentId, status } = req.body;
    const userId = toId(req.user.id);

    const validStatuses = ['pending', 'confirmed', 'completed', 'cancelled', 'in_progress', 'missed'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const appt = await Appointment.findOne({
      _id: toId(appointmentId),
      $or: [{ patient_id: userId }, { doctor_id: userId }],
    });

    if (!appt) return res.status(404).json({ success: false, message: 'Appointment not found or access denied' });

    const wasAlreadyCompleted = appt.status === 'completed';
    appt.status = status;
    await appt.save();

    // Award 20 points to patient when appointment is marked completed (once only)
    if (status === 'completed' && !wasAlreadyCompleted && appt.patient_id) {
      try {
        const User = require('../models/User');
        await User.findByIdAndUpdate(
          appt.patient_id,
          {
            $inc: { 'gamification.points': 20, 'gamification.stats.completedAppointments': 1 },
            $push: { 'gamification.history': { $each: [{ points: 20, reason: 'complete_appointment', date: new Date().toISOString() }], $slice: -200 } },
          },
          { strict: false }
        );
      } catch (e) {
        console.error('Appointment points award error:', e);
      }
    }

    res.json({ success: true, message: 'Status updated successfully', appointment: { ...appt.toObject(), id: appt._id.toString() } });
  } catch (error) {
    console.error('Update status error:', error);
    res.status(500).json({ success: false, message: 'Failed to update status' });
  }
});

// GET /appointments/:id — fetch single appointment by ID
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const apptId = toId(req.params.id);
    if (!apptId) return res.status(400).json({ success: false, message: 'Invalid appointment ID' });

    const appt = await Appointment.findOne({
      _id: apptId,
      $or: [{ patient_id: userId }, { doctor_id: userId }],
    }).lean();

    if (!appt) return res.status(404).json({ success: false, message: 'Appointment not found' });

    res.json({
      success: true,
      appointment: {
        ...appt,
        id: appt._id.toString(),
        _id: appt._id.toString(),
        patient_id: appt.patient_id?.toString(),
        doctor_id: appt.doctor_id?.toString(),
      },
    });
  } catch (error) {
    console.error('Get appointment by ID error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch appointment' });
  }
});

// PUT /appointments/:id
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { status } = req.body;

    const validStatuses = ['pending', 'confirmed', 'completed', 'cancelled', 'in_progress', 'missed'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const appt = await Appointment.findOne({
      _id: toId(req.params.id),
      $or: [{ patient_id: userId }, { doctor_id: userId }],
    });

    if (!appt) return res.status(404).json({ success: false, message: 'Appointment not found or access denied' });

    appt.status = status;
    await appt.save();

    // Notify patient when doctor confirms the appointment
    if (status === 'confirmed' && appt.patient_id) {
      try {
        const Notification = require('../models/Notification');
        const doctorName = appt.doctor_name || 'your doctor';
        await Notification.create({
          userId: appt.patient_id,
          type: 'appointment',
          title: 'Appointment Confirmed',
          message: `Your appointment with Dr. ${doctorName} has been confirmed.`,
          data: { appointmentId: appt._id.toString() },
          read: false,
        });
      } catch (notifErr) { console.error('Appointment confirm notification error:', notifErr.message); }
    }

    res.json({ success: true, message: 'Appointment updated successfully', appointment: { ...appt.toObject(), id: appt._id.toString() } });
  } catch (error) {
    console.error('Update appointment error:', error);
    res.status(500).json({ success: false, message: 'Failed to update appointment' });
  }
});

// DELETE /appointments/:id
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);

    const appt = await Appointment.findOne({
      _id: toId(req.params.id),
      $or: [{ patient_id: userId }, { doctor_id: userId }],
    });

    if (!appt) return res.status(404).json({ success: false, message: 'Appointment not found or access denied' });

    await appt.deleteOne();
    res.json({ success: true, message: 'Appointment deleted successfully' });
  } catch (error) {
    console.error('Delete appointment error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete appointment' });
  }
});

// POST /appointments/:id/rate — patient rates a completed appointment
router.post('/:id/rate', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { rating, comment } = req.body;
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ success: false, message: 'Rating must be 1-5' });
    }
    const appt = await Appointment.findById(toId(req.params.id));
    if (!appt) return res.status(404).json({ success: false, message: 'Appointment not found' });

    appt.rating = rating;
    appt.ratingComment = comment || '';
    appt.ratedAt = new Date();
    await appt.save();

    const ratedList = await Appointment.find({
      doctor_id: appt.doctor_id,
      rating: { $gte: 1, $lte: 5 },
    }).lean();
    const totalR = ratedList.length;
    const avgR = totalR > 0 ? ratedList.reduce((s, x) => s + x.rating, 0) / totalR : 0;
    await DoctorProfile.findOneAndUpdate(
      { user_id: appt.doctor_id },
      { $set: { rating: Math.round(avgR * 10) / 10, total_reviews: totalR } },
    ).catch(() => {});

    // Award 5 points to patient for rating a doctor
    try {
      const User = require('../models/User');
      await User.findByIdAndUpdate(
        appt.patient_id,
        {
          $inc: { 'gamification.points': 5 },
          $push: { 'gamification.history': { $each: [{ points: 5, reason: 'rate_doctor', date: new Date().toISOString() }], $slice: -200 } },
        },
        { strict: false }
      );
    } catch (e) {
      console.error('Rating points award error:', e);
    }

    res.json({ success: true, message: 'Rating submitted successfully' });
  } catch (error) {
    console.error('Rate appointment error:', error);
    res.status(500).json({ success: false, message: 'Failed to submit rating' });
  }
});

module.exports = router;
