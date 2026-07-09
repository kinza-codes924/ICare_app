const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const CallSignal = require('../models/CallSignal');
const { authMiddleware } = require('../middleware/auth');

// POST /api/call/initiate — caller sends when starting a call
router.post('/initiate', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { receiverId, channelName, callType = 'video', callerName } = req.body;
    if (!receiverId || !channelName) {
      return res.status(400).json({ success: false, message: 'receiverId and channelName required' });
    }
    // Cancel any existing pending signal between these two users
    await CallSignal.deleteMany({
      $or: [
        { callerId: req.user.id, receiverId },
        { callerId: receiverId, receiverId: req.user.id },
      ],
      status: 'pending',
    });
    const signal = await CallSignal.create({
      channelName,
      callerId: req.user.id,
      callerName: callerName || 'Unknown',
      receiverId,
      callType,
    });
    res.json({ success: true, signalId: signal._id });
  } catch (err) {
    console.error('Call initiate error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/call/incoming — callee polls this to check for incoming calls
// Uses a hard 7-second deadline so Vercel never hangs on cold-start DB connections
router.get('/incoming', authMiddleware, async (req, res) => {
  // Hard timeout — respond within 7 s no matter what
  const deadline = setTimeout(() => {
    if (!res.headersSent) {
      res.json({ success: true, hasIncomingCall: false });
    }
  }, 7000);

  try {
    await connectMongoDB();
    const signal = await CallSignal.findOne({
      receiverId: req.user.id,
      status: 'pending',
    })
      .sort({ createdAt: -1 })
      .maxTimeMS(4000); // mongo query must finish in 4 s

    clearTimeout(deadline);
    if (res.headersSent) return;

    if (!signal) {
      return res.json({ success: true, hasIncomingCall: false });
    }
    res.json({
      success: true,
      hasIncomingCall: true,
      signal: {
        id: signal._id,
        channelName: signal.channelName,
        callerName: signal.callerName,
        callerId: signal.callerId,
        callType: signal.callType,
      },
    });
  } catch (err) {
    clearTimeout(deadline);
    if (!res.headersSent) {
      // On timeout or DB error return "no call" so client doesn't crash
      res.json({ success: true, hasIncomingCall: false });
    }
  }
});

// POST /api/call/respond — callee accepts or rejects
router.post('/respond', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { signalId, action } = req.body; // action: 'accepted' | 'rejected'
    if (!signalId || !action) {
      return res.status(400).json({ success: false, message: 'signalId and action required' });
    }
    await CallSignal.findByIdAndUpdate(signalId, { status: action });
    res.json({ success: true });
  } catch (err) {
    console.error('Call respond error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/call/signal/:id — check status of a specific call signal (for decline detection)
router.get('/signal/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const signal = await CallSignal.findById(req.params.id);
    if (!signal) {
      return res.status(404).json({ success: false, message: 'Signal not found' });
    }
    res.json({
      success: true,
      status: signal.status,
      signal: {
        id: signal._id,
        status: signal.status,
        channelName: signal.channelName,
        callType: signal.callType,
      },
    });
  } catch (err) {
    console.error('Call signal check error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/call/end — either party ends the call
router.post('/end', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { channelName } = req.body;
    if (channelName) {
      await CallSignal.updateMany(
        { channelName, status: { $in: ['pending', 'accepted'] } },
        { status: 'ended' },
      );
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
