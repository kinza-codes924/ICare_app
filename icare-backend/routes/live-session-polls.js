const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const LiveSessionPoll = require('../models/LiveSessionPoll');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ── INSTRUCTOR: Create poll ─────────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { sessionId, question, options } = req.body;

    if (!sessionId || !question || !options || options.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'sessionId, question, and at least 2 options required'
      });
    }

    const poll = await LiveSessionPoll.create({
      sessionId: toId(sessionId),
      instructorId: toId(req.user.id),
      question,
      options,
    });

    res.json({ success: true, poll });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get polls for a session ─────────────────────────────────────────────────
router.get('/session/:sessionId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const polls = await LiveSessionPoll.find({
      sessionId: toId(req.params.sessionId),
    }).sort({ createdAt: -1 }).lean();

    res.json({ success: true, polls });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: Submit poll response ───────────────────────────────────────────
router.post('/:pollId/respond', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { optionIndex } = req.body;

    if (optionIndex === undefined || optionIndex < 0) {
      return res.status(400).json({ success: false, message: 'Valid optionIndex required' });
    }

    const poll = await LiveSessionPoll.findById(toId(req.params.pollId));

    if (!poll) {
      return res.status(404).json({ success: false, message: 'Poll not found' });
    }

    if (!poll.isActive) {
      return res.status(400).json({ success: false, message: 'Poll is closed' });
    }

    if (optionIndex >= poll.options.length) {
      return res.status(400).json({ success: false, message: 'Invalid option index' });
    }

    const userId = toId(req.user.id);

    // Check if already responded
    const existingResponse = poll.responses.find(r => r.userId.equals(userId));

    if (existingResponse) {
      // Update response
      existingResponse.optionIndex = optionIndex;
      existingResponse.respondedAt = new Date();
    } else {
      // Add new response
      poll.responses.push({
        userId,
        optionIndex,
        respondedAt: new Date(),
      });
    }

    await poll.save();

    res.json({ success: true, message: 'Response recorded' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get poll results (instructor or after poll closes) ──────────────────────
router.get('/:pollId/results', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const poll = await LiveSessionPoll.findById(toId(req.params.pollId)).lean();

    if (!poll) {
      return res.status(404).json({ success: false, message: 'Poll not found' });
    }

    // Calculate results
    const results = poll.options.map((option, index) => {
      const count = poll.responses.filter(r => r.optionIndex === index).length;
      const percentage = poll.responses.length > 0
        ? Math.round((count / poll.responses.length) * 100)
        : 0;

      return {
        option,
        count,
        percentage,
      };
    });

    res.json({
      success: true,
      poll: {
        question: poll.question,
        options: poll.options,
        totalResponses: poll.responses.length,
        isActive: poll.isActive,
      },
      results,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Close poll ──────────────────────────────────────────────────
router.post('/:pollId/close', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const poll = await LiveSessionPoll.findById(toId(req.params.pollId));

    if (!poll) {
      return res.status(404).json({ success: false, message: 'Poll not found' });
    }

    poll.isActive = false;
    poll.closedAt = new Date();
    await poll.save();

    res.json({ success: true, message: 'Poll closed' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
