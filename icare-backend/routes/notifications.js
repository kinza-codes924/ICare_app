const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');

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

// GET /api/notifications — list in-app notifications (stub, returns empty)
router.get('/', authMiddleware, async (req, res) => {
  res.json({ success: true, notifications: [], count: 0 });
});

// GET /api/notifications/history/:userId — notification history stub
router.get('/history/:userId', authMiddleware, async (req, res) => {
  res.json({ success: true, notifications: [], count: 0 });
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

// PUT /api/notifications/:id/read — mark as read stub
router.put('/:id/read', authMiddleware, async (req, res) => {
  res.json({ success: true });
});

// PUT /api/notifications/read-all — mark all as read stub
router.put('/read-all', authMiddleware, async (req, res) => {
  res.json({ success: true });
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

module.exports = router;
