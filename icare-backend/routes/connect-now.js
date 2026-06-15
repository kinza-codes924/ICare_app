const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const ConnectNow = require('../models/ConnectNow');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');
const { sendToUser } = require('../services/notificationService');

// POST /api/connect-now/initiate — patient initiates instant consultation
router.post('/initiate', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();

    const patientName = req.body.patientName || 'Patient';

    // Generate unique channel name
    const channelName = `connect_now_${Date.now()}_${req.user.id}`;

    // Create request
    const request = await ConnectNow.create({
      patientId: req.user.id,
      patientName,
      channelName,
    });

    // Push notification to ALL available doctors immediately — no waiting for polling
    let notifiedDoctors = 0;
    try {
      const doctors = await User.find({
        role: { $in: ['Doctor', 'doctor'] },
        is_active: { $ne: false },
      }).select('_id').lean();

      notifiedDoctors = doctors.length;

      await Promise.all(doctors.map(d =>
        sendToUser(d._id, {
          title: '🚨 Instant Consultation Request',
          body: `${patientName} needs a doctor right now! Tap to accept.`,
          data: {
            type: 'connect_now_request',
            requestId: request._id.toString(),
            patientName,
            channelName,
          },
          type: 'connect_now_request',
        }).catch(() => {})
      ));
    } catch (notifErr) {
      console.warn('[ConnectNow] Push notification failed (non-blocking):', notifErr.message);
    }

    res.json({
      success: true,
      requestId: request._id,
      channelName,
      notifiedDoctors,
    });
  } catch (err) {
    console.error('Connect now initiate error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/connect-now/pending — doctor checks for pending requests
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();

    // Find oldest pending request
    const request = await ConnectNow.findOne({ status: 'pending' })
      .sort({ createdAt: 1 });

    if (!request) {
      return res.json({ success: true, hasPending: false });
    }

    res.json({
      success: true,
      hasPending: true,
      request: {
        _id: request._id.toString(),
        id: request._id.toString(),
        patientId: request.patientId,
        patientName: request.patientName,
        channelName: request.channelName,
        createdAt: request.createdAt,
        waitingTime: Math.floor((Date.now() - request.createdAt) / 1000),
      },
    });
  } catch (err) {
    console.error('Connect now pending error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/connect-now/accept — doctor accepts request
router.post('/accept', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { requestId, doctorName } = req.body;

    if (!requestId) {
      return res.status(400).json({ success: false, message: 'requestId required' });
    }

    let request = await ConnectNow.findById(requestId).catch(() => null);

    // If already accepted by this doctor, return success (idempotent)
    if (request && request.status === 'accepted') {
      return res.json({
        success: true,
        channelName: request.channelName,
        patientName: request.patientName,
        patientId: request.patientId?.toString() || '',
        appointmentId: request.appointmentId?.toString() || '',
      });
    }

    if (!request || request.status !== 'pending') {
      request = await ConnectNow.findOne({ status: 'pending' }).sort({ createdAt: -1 }).catch(() => null);
      if (!request) {
        return res.status(404).json({ success: false, message: 'No pending request found' });
      }
    }

    request.status = 'accepted';
    request.acceptedBy = {
      doctorId: req.user.id,
      doctorName: doctorName || 'Doctor',
    };

    // Create an appointment record so patient can rejoin via "Consultation in Progress"
    let appointmentId = '';
    try {
      const Appointment = require('../models/Appointment');
      const mongoose = require('mongoose');
      const patientObjId = mongoose.Types.ObjectId.isValid(request.patientId)
        ? new mongoose.Types.ObjectId(request.patientId)
        : null;
      const doctorObjId = mongoose.Types.ObjectId.isValid(req.user.id)
        ? new mongoose.Types.ObjectId(req.user.id)
        : null;

      if (patientObjId && doctorObjId) {
        const now = new Date();
        const appt = await Appointment.create({
          patient_id: patientObjId,
          doctor_id: doctorObjId,
          appointment_date: now.toISOString().split('T')[0],
          appointment_time: now.toTimeString().slice(0, 5),
          status: 'in_progress',
          consultation_type: 'video',
          channel_name: request.channelName,
          notes: `Instant consultation via Connect Now. Channel: ${request.channelName}`,
        });
        appointmentId = appt._id.toString();
        request.appointmentId = appt._id;
      }
    } catch (apptErr) {
      console.warn('Could not create appointment for connect-now:', apptErr.message);
    }

    await request.save();

    res.json({
      success: true,
      channelName: request.channelName,
      patientName: request.patientName,
      patientId: request.patientId?.toString() || '',
      appointmentId,
    });
  } catch (err) {
    console.error('Connect now accept error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/connect-now/status/:requestId — patient polls for status
router.get('/status/:requestId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const request = await ConnectNow.findById(req.params.requestId);

    if (!request) {
      return res.json({ success: true, status: 'expired' });
    }

    res.json({
      success: true,
      status: request.status,
      channelName: request.channelName,
      acceptedBy: request.acceptedBy,
      appointmentId: request.appointmentId?.toString() || '',
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
