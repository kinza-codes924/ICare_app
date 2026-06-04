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

module.exports = router;
