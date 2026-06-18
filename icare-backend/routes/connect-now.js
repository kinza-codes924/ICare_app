const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const ConnectNow = require('../models/ConnectNow');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');
const { getFirebaseAdmin } = require('../config/firebase');

// ─── Batch FCM sender — 1 DB query + 1 Firebase multicast ────────────────────
// This replaces N individual sendToUser() calls.
// Called AFTER res.json() so patient gets response instantly.
async function _notifyAllDoctors(requestId, patientName, channelName) {
  const t0 = Date.now();
  try {
    // Single query — fetch all active doctor FCM tokens
    const doctors = await User.find({
      role: { $in: ['Doctor', 'doctor'] },
      is_active: { $ne: false },
      fcm_tokens: { $exists: true, $not: { $size: 0 } },
    }).select('_id fcm_tokens').lean();

    // Flatten and deduplicate tokens
    const allTokens = [...new Set(
      doctors.flatMap(d => (d.fcm_tokens || []).filter(Boolean))
    )];

    if (allTokens.length === 0) {
      console.log(`[ConnectNow] No FCM tokens found for doctors (${Date.now() - t0}ms)`);
      return 0;
    }

    const notifData = {
      type: 'connect_now_request',
      requestId: String(requestId),
      patientName: String(patientName),
      channelName: String(channelName),
    };

    const admin = getFirebaseAdmin();
    // Firebase allows max 500 tokens per sendEachForMulticast call
    const BATCH = 500;
    let successCount = 0;
    const invalidTokens = [];

    for (let i = 0; i < allTokens.length; i += BATCH) {
      const batch = allTokens.slice(i, i + BATCH);
      try {
        const result = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          notification: {
            title: '🚨 Instant Consultation Request',
            body: `${patientName} needs a doctor right now! Tap to accept.`,
          },
          data: notifData,
          android: {
            priority: 'high',
            notification: { sound: 'default', channelId: 'icare_high_importance' },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
          },
        });
        successCount += result.successCount;
        // Collect stale tokens for cleanup
        result.responses.forEach((r, idx) => {
          if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
            invalidTokens.push(batch[idx]);
          }
        });
      } catch (batchErr) {
        console.warn(`[ConnectNow] FCM batch ${i}-${i + BATCH} failed:`, batchErr.message);
      }
    }

    // Async cleanup of stale tokens (non-blocking)
    if (invalidTokens.length > 0) {
      User.updateMany({}, { $pull: { fcm_tokens: { $in: invalidTokens } } })
        .catch(e => console.warn('[ConnectNow] Token cleanup failed:', e.message));
    }

    console.log(`[ConnectNow] FCM sent to ${successCount}/${allTokens.length} tokens in ${Date.now() - t0}ms`);
    return doctors.length;
  } catch (err) {
    console.error('[ConnectNow] _notifyAllDoctors failed:', err.message);
    return 0;
  }
}

// POST /api/connect-now/initiate — patient initiates instant consultation
router.post('/initiate', authMiddleware, async (req, res) => {
  const initiateStart = Date.now();
  try {
    await connectMongoDB();

    const patientName = req.body.patientName || 'Patient';
    const channelName = `connect_now_${Date.now()}_${req.user.id}`;

    // Check for duplicate active request from same patient (idempotency)
    const existing = await ConnectNow.findOne({
      patientId: req.user.id,
      status: 'pending',
      createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }, // within last 5 min
    }).lean();

    if (existing) {
      console.log(`[ConnectNow] Returning existing request ${existing._id} for patient ${req.user.id}`);
      return res.json({
        success: true,
        requestId: existing._id,
        channelName: existing.channelName,
        notifiedDoctors: 0,
        reused: true,
      });
    }

    // Create consultation request
    const request = await ConnectNow.create({
      patientId: req.user.id,
      patientName,
      channelName,
    });

    const dbTime = Date.now() - initiateStart;
    console.log(`[ConnectNow] Request ${request._id} created in ${dbTime}ms`);

    // ─── RESPOND TO PATIENT IMMEDIATELY ────────────────────────────────────
    // Do NOT wait for FCM — patient gets success confirmation NOW
    res.json({
      success: true,
      requestId: request._id,
      channelName,
      notifiedDoctors: -1, // will be sent async
      timestamps: { created: new Date().toISOString(), dbMs: dbTime },
    });

    // ─── SEND FCM IN BACKGROUND (fire-and-forget after response) ───────────
    // Vercel keeps function alive until event loop drains — FCM completes.
    _notifyAllDoctors(request._id, patientName, channelName)
      .then(count => console.log(`[ConnectNow] Notified ${count} doctors for request ${request._id}`))
      .catch(err => console.error('[ConnectNow] Background FCM failed:', err.message));

  } catch (err) {
    console.error('[ConnectNow] initiate error:', err);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
});

// GET /api/connect-now/pending — doctor checks for pending requests
// Exclude requests older than 5 minutes (they're expired)
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();

    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
    const request = await ConnectNow.findOne({
      status: 'pending',
      createdAt: { $gte: fiveMinAgo },
    }).sort({ createdAt: 1 }).lean();

    if (!request) {
      return res.json({ success: true, hasPending: false });
    }

    const waitingTime = Math.floor((Date.now() - new Date(request.createdAt).getTime()) / 1000);
    console.log(`[ConnectNow] Doctor ${req.user.id} polled — found request ${request._id} (waiting ${waitingTime}s)`);

    res.json({
      success: true,
      hasPending: true,
      request: {
        _id: request._id.toString(),
        id: request._id.toString(),
        patientId: request.patientId?.toString() || '',
        patientName: request.patientName,
        channelName: request.channelName,
        createdAt: request.createdAt,
        waitingTime,
      },
    });
  } catch (err) {
    console.error('[ConnectNow] pending error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/connect-now/retry-notify — patient can re-trigger FCM if no doctor responds in 30s
router.post('/retry-notify', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { requestId } = req.body;
    if (!requestId) return res.status(400).json({ success: false, message: 'requestId required' });

    const request = await ConnectNow.findOne({ _id: requestId, patientId: req.user.id, status: 'pending' }).lean();
    if (!request) return res.json({ success: false, message: 'Request not found or already handled' });

    res.json({ success: true, message: 'Retrying doctor notifications...' });

    // Re-send FCM in background
    _notifyAllDoctors(request._id, request.patientName, request.channelName)
      .then(count => console.log(`[ConnectNow] Retry: notified ${count} doctors for request ${request._id}`))
      .catch(err => console.error('[ConnectNow] Retry FCM failed:', err.message));
  } catch (err) {
    console.error('[ConnectNow] retry-notify error:', err);
    if (!res.headersSent) res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/connect-now/accept — doctor accepts request
router.post('/accept', authMiddleware, async (req, res) => {
  const acceptStart = Date.now();
  try {
    await connectMongoDB();
    const { requestId, doctorName } = req.body;
    console.log(`[ConnectNow] Doctor ${req.user.id} accepting request ${requestId}`);

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

    const totalMs = Date.now() - acceptStart;
    const waitMs = Date.now() - new Date(request.createdAt).getTime();
    console.log(`[ConnectNow] Request ${request._id} accepted by doctor ${req.user.id} — accept latency ${totalMs}ms, patient waited ${Math.round(waitMs / 1000)}s`);

    res.json({
      success: true,
      channelName: request.channelName,
      patientName: request.patientName,
      patientId: request.patientId?.toString() || '',
      appointmentId,
    });
  } catch (err) {
    console.error('[ConnectNow] accept error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/connect-now/status/:requestId — patient polls for status
router.get('/status/:requestId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const request = await ConnectNow.findById(req.params.requestId).lean();

    if (!request) {
      return res.json({ success: true, status: 'expired' });
    }

    if (request.status === 'accepted') {
      const waitMs = new Date(request.updatedAt).getTime() - new Date(request.createdAt).getTime();
      console.log(`[ConnectNow] Patient ${req.user.id} saw accepted status — doctor responded in ${Math.round(waitMs / 1000)}s`);
    }

    res.json({
      success: true,
      status: request.status,
      channelName: request.channelName,
      acceptedBy: request.acceptedBy,
      appointmentId: request.appointmentId?.toString() || '',
    });
  } catch (err) {
    console.error('[ConnectNow] status error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
