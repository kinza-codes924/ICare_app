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
    const pairFilter = {
      $or: [
        { callerId: req.user.id, receiverId },
        { callerId: receiverId, receiverId: req.user.id },
      ],
    };

    // If a call between these two is already ANSWERED, don't start a second
    // one — both sides sitting in the chat would often ring each other at the
    // same moment, and whoever joined first then got re-prompted by the
    // other's signal. Hand back the live call instead of creating a rival.
    //
    // Only 'accepted' counts here. A 'pending' row is a ring nobody picked up:
    // treating those as live meant one unanswered call left the caller unable
    // to ever ring again — the next attempt silently returned the dead signal
    // and the other side was never notified at all.
    const active = await CallSignal.findOne({
      ...pairFilter,
      status: 'accepted',
      createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) },
    }).sort({ createdAt: -1 });
    if (active) {
      return res.json({
        success: true,
        signalId: active._id,
        channelName: active.channelName,
        alreadyActive: true,
      });
    }

    // Clear out any unanswered ring between these two before placing a new one.
    await CallSignal.deleteMany({ ...pairFilter, status: 'pending' });
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

    // Someone already in a live call must not be rung again. Both sides
    // calling each other at once left the one who answered first being
    // re-prompted by the other's signal — the repeating dialog. Retire the
    // redundant signal rather than surfacing it.
    // Only signals from the last 30 minutes count as "in a call" — a browser
    // that crashed mid-call would otherwise leave an 'accepted' row behind and
    // silently block every future call for that user.
    const liveCutoff = new Date(Date.now() - 30 * 60 * 1000);
    // A ring only lasts about a minute; past that an unanswered 'pending' row
    // is just litter and must not keep marking its caller as busy.
    const ringingCutoff = new Date(Date.now() - 90 * 1000);
    const inCall = await CallSignal.findOne({
      $or: [
        // The other side answered a call this user placed.
        { status: 'accepted', callerId: req.user.id, createdAt: { $gte: liveCutoff } },
        { status: 'accepted', receiverId: req.user.id, createdAt: { $gte: liveCutoff } },
        // …or this user placed a call that is still actually ringing.
        // Only the RECEIVER's signal ever turns 'accepted' — the caller's stays
        // 'pending' for its whole life. Checking 'accepted' alone therefore
        // never recognised the caller as busy, so the moment the other side
        // rang back they got a dialog on top of the call they had just started.
        { status: 'pending', callerId: req.user.id, createdAt: { $gte: ringingCutoff } },
      ],
    }).sort({ createdAt: -1 }).maxTimeMS(2000);

    if (inCall) {
      await CallSignal.findByIdAndUpdate(signal._id, { status: 'ended' }).catch(() => {});
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
    // Close out any other live signal this user is part of. Ending by channel
    // alone could leave a second signal (from the two sides ringing each other
    // at once) still 'accepted', which would then read as "already in a call"
    // and block every future call for that user.
    await CallSignal.updateMany(
      {
        status: { $in: ['pending', 'accepted'] },
        $or: [{ callerId: req.user.id }, { receiverId: req.user.id }],
      },
      { status: 'ended' },
    ).catch(() => {});
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
