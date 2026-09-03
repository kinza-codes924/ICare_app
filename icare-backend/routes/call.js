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

    // If a stale 'accepted' signal exists between these two, end it before
    // placing a new ring. Returning alreadyActive caused the intermittent
    // call failure: calls that ended without a proper /end cleanup left an
    // 'accepted' row that suppressed the next ring for up to 30 minutes —
    // the caller joined a dead Jitsi channel while the patient saw nothing.
    // Ending it here and falling through always creates a fresh pending signal
    // the patient's poller will see.
    const stale = await CallSignal.findOne({
      ...pairFilter,
      status: 'accepted',
      createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) },
    }).sort({ createdAt: -1 });
    if (stale) {
      await CallSignal.findByIdAndUpdate(stale._id, { status: 'ended' }).catch(() => {});
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

    // Suppress a ring ONLY while this user's own outgoing call is still
    // ringing — that is the genuine simultaneous-dial case, where both sides
    // press call within a second of each other and the one who connects first
    // would otherwise get a dialog on top of the call they just started.
    //
    // Deliberately NOT checked here: whether an 'accepted' signal exists for
    // this user. That check used to be in this list and is what broke calling
    // outright — one completed call left an 'accepted' row that marked the
    // user busy for a full 30 minutes, so no further call could ring either
    // side for the rest of the consultation. A finished call must never block
    // the next one, and /initiate already hands back a genuinely live call
    // instead of creating a rival, which is the case that check was aiming at.
    //
    // The window is short on purpose: a ring lasts about a minute, so anything
    // older is an abandoned row, not a call in progress.
    const ringingCutoff = new Date(Date.now() - 45 * 1000);
    const ringingOut = await CallSignal.findOne({
      status: 'pending',
      callerId: req.user.id,
      createdAt: { $gte: ringingCutoff },
    }).sort({ createdAt: -1 }).maxTimeMS(2000);

    // Only stand down for a call placed BEFORE the one now arriving. If our
    // own ring is the newer of the two we are the later dialler, so we take
    // theirs and let our stale one go — otherwise both sides suppress each
    // other and neither phone ever rings.
    if (ringingOut && ringingOut.createdAt <= signal.createdAt) {
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
