const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const mongoose = require('mongoose');

// Simple in-memory store for call chat messages (per channel)
// In production this would be Redis or MongoDB, but for demo this works
// since Vercel functions are stateless — use MongoDB instead
const CallChatSchema = new mongoose.Schema({
  channelName: { type: String, required: true, index: true },
  sender: { type: String, required: true },
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 3600 }, // auto-delete after 1 hour
});

const CallChat = mongoose.models.CallChat ||
  mongoose.model('CallChat', CallChatSchema);

// POST /call-chat/send — send a message
router.post('/send', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { channelName, text, sender } = req.body;
    if (!channelName || !text) {
      return res.status(400).json({ success: false, message: 'channelName and text required' });
    }
    const msg = await CallChat.create({
      channelName,
      sender: sender || 'User',
      text,
    });
    res.json({ success: true, message: msg });
  } catch (e) {
    console.error('Call chat send error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /call-chat/messages/:channelName?since=<timestamp> — get messages
router.get('/messages/:channelName', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { channelName } = req.params;
    const since = req.query.since ? new Date(parseInt(req.query.since)) : new Date(0);
    const messages = await CallChat.find({
      channelName,
      createdAt: { $gt: since },
    }).sort({ createdAt: 1 }).lean();
    res.json({ success: true, messages });
  } catch (e) {
    console.error('Call chat get error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
