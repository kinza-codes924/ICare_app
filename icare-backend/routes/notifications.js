const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const Notification = require('../models/Notification');

// POST /api/notifications/token  — save FCM token after login
router.post('/token', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { fcmToken } = req.body;
    if (!fcmToken) return res.status(400).json({ success: false, message: 'fcmToken required' });
    await User.findByIdAndUpdate(req.user.id, { $addToSet: { fcm_tokens: fcmToken } });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/notifications/token  — remove FCM token on logout
router.delete('/token', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { fcmToken } = req.body;
    if (fcmToken) {
      await User.findByIdAndUpdate(req.user.id, { $pull: { fcm_tokens: fcmToken } });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/notifications/preferences
router.get('/preferences', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(req.user.id).select('notification_preferences').lean();
    const defaults = {
      new_orders: true, order_dispatched: true, delivery_updates: true,
      system_alerts: true, booking_updates: true, doctor_messages: true,
      promotions: false, sound_notifications: true,
    };
    res.json({ success: true, preferences: { ...defaults, ...(user?.notification_preferences || {}) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/notifications/preferences
router.put('/preferences', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const allowed = ['new_orders','order_dispatched','delivery_updates','system_alerts','booking_updates','doctor_messages','promotions','sound_notifications'];
    const update = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        update[`notification_preferences.${key}`] = Boolean(req.body[key]);
      }
    }
    await User.findByIdAndUpdate(req.user.id, { $set: update });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/notifications — list in-app notifications for current user
router.get('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const notifications = await Notification.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();
    res.json({ success: true, notifications, count: notifications.length });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/notifications/history/:userId — notification history
router.get('/history/:userId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const notifications = await Notification.find({ userId: req.params.userId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json({ success: true, notifications, count: notifications.length });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/notifications/preferences/:userId — preferences by userId (alias)
router.get('/preferences/:userId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(req.params.userId).select('notification_preferences').lean();
    const defaults = {
      new_orders: true, order_dispatched: true, delivery_updates: true,
      system_alerts: true, booking_updates: true, doctor_messages: true,
      promotions: false, sound_notifications: true,
    };
    res.json({ success: true, preferences: { ...defaults, ...(user?.notification_preferences || {}) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/notifications/preferences/:userId — update preferences by userId (alias)
router.put('/preferences/:userId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const allowed = ['new_orders','order_dispatched','delivery_updates','system_alerts','booking_updates','doctor_messages','promotions','sound_notifications'];
    const update = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        update[`notification_preferences.${key}`] = Boolean(req.body[key]);
      }
    }
    await User.findByIdAndUpdate(req.params.userId, { $set: update });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/notifications/:id/read — mark single notification as read
router.put('/:id/read', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { read: true, updatedAt: new Date() }
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/notifications/read-all — mark all notifications as read
router.put('/read-all', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Notification.updateMany({ userId: req.user.id, read: false }, { read: true, updatedAt: new Date() });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST stubs for critical-alert, status-update, report-ready
router.post('/critical-alert', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Alert queued' });
});
router.post('/status-update', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Status update sent' });
});
router.post('/report-ready', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Report notification sent' });
});

// ─── PROMOTIONS & OFFERS ─────────────────────────────────────────────────────
// Users have had a "Promotions & Offers" notification preference since launch,
// but nothing could ever set it off — there was no promotion type and no way to
// send one. These two routes are that missing half.

// GET /api/notifications/promotions — the caller's own promotional offers.
router.get('/promotions', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const items = await Notification.find({
      userId: req.user.id,
      type: 'promotion',
    }).sort({ createdAt: -1 }).limit(100).lean();
    res.json({ success: true, promotions: items });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/notifications/promotions — admin broadcasts an offer.
// Only reaches users who left the promotions preference ON, which is what that
// switch in Settings is for.
router.post('/promotions', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sender = await User.findById(req.user.id).lean();
    if (!sender || String(sender.role).toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admins only' });
    }

    const { title, message, roles, link } = req.body;
    if (!title || !message) {
      return res.status(400).json({ success: false, message: 'title and message are required' });
    }

    // The field is notification_preferences (snake_case) -- that is what the
    // User model declares and what PUT /notifications/preferences writes. This
    // filter used to read notificationPrefs, a field no document has, so every
    // promotion reached exactly nobody however many people had opted in.
    const basePrefFilter = { 'notification_preferences.promotions': true };
    const filter = { ...basePrefFilter };
    if (Array.isArray(roles) && roles.length) {
      // `role` is stored in both cases in this collection ('student' and
      // 'Student' both exist -- see the enum comment on the User model), and
      // laboratories are stored as either 'lab' or 'Laboratory'. Matching the
      // one spelling the client sends found nobody, so a promotion aimed at a
      // role silently reached zero people. Expand each requested role into
      // every spelling that is actually in the data.
      const VARIANTS = {
        student: ['student', 'Student'],
        patient: ['patient', 'Patient'],
        doctor: ['doctor', 'Doctor'],
        instructor: ['instructor', 'Instructor'],
        pharmacy: ['pharmacy', 'Pharmacy'],
        laboratory: ['lab', 'Laboratory'],
        lab: ['lab', 'Laboratory'],
        receptionist: ['receptionist'],
        admin: ['admin', 'Admin'],
      };
      const wanted = [];
      for (const r of roles) {
        const key = String(r).toLowerCase();
        wanted.push(...(VARIANTS[key] || [r]));
      }
      filter.role = { $in: [...new Set(wanted)] };
    }

    const recipients = await User.find(filter, '_id').lean();
    if (!recipients.length) {
      // Say which of the two reasons it was: nobody has promotions switched on
      // at all, or nobody in the roles that were picked.
      const anyOptedIn = await User.countDocuments(basePrefFilter);
      return res.json({
        success: true,
        sent: 0,
        message: anyOptedIn === 0
          ? 'Nobody has Promotions & Offers switched on yet'
          : `No one in the selected role(s) has Promotions & Offers switched on (${anyOptedIn} user(s) have it on overall)`,
      });
    }

    await Notification.insertMany(recipients.map(u => ({
      userId: u._id,
      type: 'promotion',
      title,
      message,
      data: link ? { link } : {},
    })));

    res.json({ success: true, sent: recipients.length });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
