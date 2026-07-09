const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// POST /api/reviews/submit
// Patient submits a rating + review for a completed appointment
router.post('/submit', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Appointment = require('../models/Appointment');
    const { appointmentId, doctorId, rating, satisfied, review } = req.body;

    if (!appointmentId || !rating) {
      return res.status(400).json({ success: false, message: 'appointmentId and rating are required' });
    }
    const stars = Math.round(Number(rating));
    if (stars < 1 || stars > 5) {
      return res.status(400).json({ success: false, message: 'Rating must be 1–5' });
    }

    const apptId = toId(appointmentId);
    if (!apptId) return res.status(400).json({ success: false, message: 'Invalid appointmentId' });

    const patientId = toId(req.user.id);

    const updated = await Appointment.findOneAndUpdate(
      { _id: apptId, patient_id: patientId },
      {
        $set: {
          rating: stars,
          ratingComment: review || '',
          ratedAt: new Date(),
          satisfied: satisfied !== false,
        },
      },
      { new: true }
    );

    if (!updated) {
      // Try without patient check (in case patient_id is stored differently)
      const fallback = await Appointment.findByIdAndUpdate(
        apptId,
        { $set: { rating: stars, ratingComment: review || '', ratedAt: new Date() } },
        { new: true }
      );
      if (!fallback) return res.status(404).json({ success: false, message: 'Appointment not found' });
    }

    // Award gamification points for rating a doctor
    try {
      const User = require('../models/User');
      const patient = await User.findById(patientId);
      if (patient) {
        if (!patient.gamification) patient.gamification = { points: 0, stats: {}, history: [] };
        patient.gamification.points = (patient.gamification.points || 0) + 5;
        patient.gamification.history = patient.gamification.history || [];
        patient.gamification.history.push({ points: 5, reason: 'rate_doctor', date: new Date().toISOString() });
        patient.markModified('gamification');
        await patient.save();
      }
    } catch (gamErr) {
      console.error('Gamification award error on review submit:', gamErr.message);
    }

    res.json({ success: true, message: 'Review submitted successfully' });
  } catch (err) {
    console.error('Review submit error:', err);
    res.status(500).json({ success: false, message: 'Failed to submit review' });
  }
});

// GET /api/reviews/doctor/:doctorId
// Public: get all reviews for a specific doctor
router.get('/doctor/:doctorId', async (req, res) => {
  try {
    await connectMongoDB();
    const Appointment = require('../models/Appointment');
    const User = require('../models/User');

    const doctorId = toId(req.params.doctorId);
    if (!doctorId) return res.json({ success: true, reviews: [] });

    const appts = await Appointment.find({
      doctor_id: doctorId,
      rating: { $gte: 1, $lte: 5 },
    })
      .sort({ ratedAt: -1, updatedAt: -1 })
      .limit(100)
      .lean();

    const patientIds = [...new Set(appts.map(a => a.patient_id?.toString()).filter(Boolean))];
    const patients = await User.find({
      _id: { $in: patientIds.map(id => toId(id)).filter(Boolean) },
    }).lean();
    const pMap = {};
    patients.forEach(p => { pMap[p._id.toString()] = p; });

    const reviews = appts.map(a => {
      const p = pMap[a.patient_id?.toString()] || {};
      return {
        appointmentId: a._id.toString(),
        patientName: p.username || p.name || 'Patient',
        rating: a.rating,
        comment: a.ratingComment || '',
        ratedAt: a.ratedAt || a.updatedAt || a.createdAt,
        satisfied: a.satisfied !== false,
      };
    });

    res.json({ success: true, reviews, count: reviews.length });
  } catch (err) {
    console.error('Get doctor reviews error:', err);
    res.status(500).json({ success: false, message: 'Failed to load reviews' });
  }
});

module.exports = router;
