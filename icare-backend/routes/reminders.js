const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');

// GET /api/reminders — get reminders for current user
router.get('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const reminders = await Reminder.find({ userId: req.user.id })
      .sort({ scheduledFor: -1 })
      .limit(100)
      .lean();
    res.json({ success: true, reminders });
  } catch (err) {
    console.error('GET /reminders error:', err);
    res.json({ success: true, reminders: [] });
  }
});

// POST /api/reminders — create a reminder
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const Notification = require('../models/Notification');
    const { title, message, type, scheduledFor, remindBeforeMinutes, recurrence, prescriptionId, consultationId } = req.body;
    if (!title || title.trim() === '') {
      return res.status(400).json({ success: false, message: 'Title is required' });
    }
    const reminder = await Reminder.create({
      userId: req.user.id,
      title: title.trim(),
      message: message || '',
      type: type || 'self_created',
      scheduledFor: scheduledFor || null,
      remindBeforeMinutes: remindBeforeMinutes || 15,
      recurrence: recurrence || 'none',
      prescriptionId: prescriptionId || null,
      consultationId: consultationId || null,
    });

    // Auto-create an in-app notification for this reminder
    try {
      let notifMessage = message || '';
      if (scheduledFor) {
        const dt = new Date(scheduledFor);
        notifMessage = `Reminder set for ${dt.toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' })} at ${dt.toLocaleTimeString('en-PK', { hour: '2-digit', minute: '2-digit' })}. ${notifMessage}`.trim();
      }
      await Notification.create({
        userId: req.user.id,
        type: 'reminder',
        title: `Reminder: ${title.trim()}`,
        message: notifMessage || 'Your reminder has been set.',
        read: false,
      });
    } catch (notifErr) {
      console.error('Failed to create notification for reminder:', notifErr);
      // Don't fail the reminder creation if notification fails
    }

    res.status(201).json({ success: true, reminder: reminder.toObject() });
  } catch (err) {
    console.error('POST /reminders error:', err);
    res.status(500).json({ success: false, message: 'Failed to create reminder' });
  }
});

// PUT /api/reminders/:id — update a reminder
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const reminder = await Reminder.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { $set: req.body },
      { new: true }
    );
    if (!reminder) return res.status(404).json({ success: false, message: 'Reminder not found' });
    res.json({ success: true, reminder });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to update reminder' });
  }
});

// DELETE /api/reminders/:id — delete a reminder
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const reminder = await Reminder.findOneAndDelete({ _id: req.params.id, userId: req.user.id });
    if (!reminder) return res.status(404).json({ success: false, message: 'Reminder not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to delete reminder' });
  }
});

// PUT /api/reminders/:id/complete — mark reminder as completed
router.put('/:id/complete', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const reminder = await Reminder.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { isCompleted: true },
      { new: true }
    );
    if (!reminder) return res.status(404).json({ success: false, message: 'Reminder not found' });
    res.json({ success: true, reminder });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to complete reminder' });
  }
});

// GET /api/reminders/check-due — check for due reminders and create notifications
// Called periodically by the app to trigger in-app notifications for due reminders
router.get('/check-due', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Reminder = require('../models/Reminder');
    const Notification = require('../models/Notification');

    const now = new Date();
    // Find reminders that are due within the next remindBeforeMinutes and not yet notified
    const dueReminders = await Reminder.find({
      userId: req.user.id,
      isCompleted: false,
      notificationSent: false,
      scheduledFor: { $exists: true, $ne: null },
    }).lean();

    const triggered = [];
    for (const reminder of dueReminders) {
      const scheduledTime = new Date(reminder.scheduledFor);
      const remindAt = new Date(scheduledTime.getTime() - (reminder.remindBeforeMinutes || 15) * 60 * 1000);
      if (now >= remindAt) {
        // Create notification
        const minutesUntil = Math.max(0, Math.round((scheduledTime - now) / 60000));
        const timeLabel = minutesUntil <= 0 ? 'now' : `in ${minutesUntil} minute${minutesUntil !== 1 ? 's' : ''}`;
        await Notification.create({
          userId: req.user.id,
          type: 'reminder',
          title: `⏰ ${reminder.title}`,
          message: minutesUntil <= 0
            ? `Your reminder is due now. ${reminder.message || ''}`.trim()
            : `Your reminder is due ${timeLabel}. ${reminder.message || ''}`.trim(),
          read: false,
        });
        // Mark as notified
        await Reminder.findByIdAndUpdate(reminder._id, { notificationSent: true });
        triggered.push(reminder._id);
      }
    }

    res.json({ success: true, triggered: triggered.length });
  } catch (err) {
    console.error('GET /reminders/check-due error:', err);
    res.json({ success: true, triggered: 0 });
  }
});

module.exports = router;