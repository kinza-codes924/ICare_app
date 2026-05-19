const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const LiveSession = require('../models/LiveSession');
const Enrollment = require('../models/Enrollment');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ── INSTRUCTOR: Create live session ─────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.create({
      ...req.body,
      instructorId: toId(req.user.id)
    });
    res.status(201).json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get sessions for a course ───────────────────────────────────────────────
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sessions = await LiveSession.find({ 
      courseId: toId(req.params.courseId) 
    })
    .populate('instructorId', 'name username')
    .sort({ scheduledAt: 1 })
    .lean();

    res.json({ success: true, sessions });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get upcoming sessions ───────────────────────────────────────────────────
router.get('/upcoming', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const now = new Date();
    
    const sessions = await LiveSession.find({
      scheduledAt: { $gte: now },
      status: { $in: ['scheduled', 'live'] }
    })
    .populate('courseId', 'title')
    .populate('instructorId', 'name username')
    .sort({ scheduledAt: 1 })
    .limit(10)
    .lean();

    res.json({ success: true, sessions });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: Join session ───────────────────────────────────────────────────
router.post('/:id/join', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sessionId = toId(req.params.id);
    const studentId = toId(req.user.id);

    const session = await LiveSession.findById(sessionId);
    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    // Check if student is enrolled in the course
    const enrollment = await Enrollment.findOne({
      userId: studentId,
      courseId: session.courseId
    });

    if (!enrollment) {
      return res.status(403).json({ 
        success: false, 
        message: 'You must be enrolled in this course' 
      });
    }

    // Add to attendees if not already present
    if (!session.attendees.includes(studentId)) {
      if (session.attendees.length >= session.maxParticipants) {
        return res.status(400).json({ 
          success: false, 
          message: 'Session is full' 
        });
      }
      session.attendees.push(studentId);
      await session.save();
    }

    res.json({ 
      success: true, 
      session: {
        _id: session._id,
        title: session.title,
        meetingLink: session.meetingLink,
        meetingId: session.meetingId,
        meetingPassword: session.meetingPassword
      }
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Update session ──────────────────────────────────────────────
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findByIdAndUpdate(
      toId(req.params.id),
      { $set: req.body },
      { new: true }
    );

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Cancel session ──────────────────────────────────────────────
router.post('/:id/cancel', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));
    
    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    session.status = 'cancelled';
    await session.save();

    // TODO: Send notification to all attendees

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Mark session as completed ───────────────────────────────────
router.post('/:id/complete', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { recordingUrl } = req.body;

    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    session.status = 'completed';
    if (recordingUrl) session.recordingUrl = recordingUrl;
    await session.save();

    // Auto-save recording to linked lesson
    if (recordingUrl && session.linkedLessonId && session.linkedModuleId) {
      const Course = require('../models/Course');
      const course = await Course.findById(session.courseId);

      if (course) {
        const module = course.modules.id(session.linkedModuleId);
        if (module) {
          const lesson = module.lessons.id(session.linkedLessonId);
          if (lesson) {
            lesson.videoUrl = recordingUrl;
            await course.save();
          }
        }
      }
    }

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── POST chat message during live session ────────────────────────────────────
router.post('/:id/chat', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message required' });
    }

    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    session.chatMessages.push({
      userId: toId(req.user.id),
      userName: req.user.name || req.user.username,
      message: message.trim(),
      timestamp: new Date(),
    });

    await session.save();

    res.json({ success: true, message: 'Message sent' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── GET chat messages for a session ──────────────────────────────────────────
router.get('/:id/chat', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id)).lean();

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    res.json({ success: true, messages: session.chatMessages || [] });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: Raise hand ──────────────────────────────────────────────────────
router.post('/:id/raise-hand', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    const userId = toId(req.user.id);
    const alreadyRaised = session.raisedHands.find(h => h.userId.equals(userId));

    if (!alreadyRaised) {
      session.raisedHands.push({
        userId,
        userName: req.user.name || req.user.username,
        raisedAt: new Date(),
      });
      await session.save();
    }

    res.json({ success: true, message: 'Hand raised' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: Lower hand ──────────────────────────────────────────────────────
router.post('/:id/lower-hand', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    const userId = toId(req.user.id);
    session.raisedHands = session.raisedHands.filter(h => !h.userId.equals(userId));
    await session.save();

    res.json({ success: true, message: 'Hand lowered' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Clear all raised hands ───────────────────────────────────────
router.post('/:id/clear-hands', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    session.raisedHands = [];
    await session.save();

    res.json({ success: true, message: 'All hands cleared' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Admit student from waiting room ──────────────────────────────
router.post('/:id/admit/:studentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    const studentId = toId(req.params.studentId);

    // Remove from waiting room
    session.waitingStudents = session.waitingStudents.filter(id => !id.equals(studentId));

    // Add to attendees
    if (!session.attendees.includes(studentId)) {
      session.attendees.push(studentId);
    }

    await session.save();

    res.json({ success: true, message: 'Student admitted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: Admit all from waiting room ──────────────────────────────────
router.post('/:id/admit-all', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    // Move all waiting students to attendees
    session.waitingStudents.forEach(studentId => {
      if (!session.attendees.includes(studentId)) {
        session.attendees.push(studentId);
      }
    });

    session.waitingStudents = [];
    await session.save();

    res.json({ success: true, message: 'All students admitted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get session details ─────────────────────────────────────────────────────
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id))
      .populate('courseId', 'title')
      .populate('instructorId', 'name username')
      .populate('attendees', 'name username')
      .lean();

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Delete session ──────────────────────────────────────────────────────────
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await LiveSession.findByIdAndDelete(toId(req.params.id));
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
