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

    // Check enrollment (soft check — allow if enrolled or if instructor)
    const isInstructor = session.instructorId?.toString() === req.user.id?.toString();
    if (!isInstructor) {
      const enrollment = await Enrollment.findOne({
        $or: [
          { userId: studentId, courseId: session.courseId },
          { userId: studentId, 'courseId': { $in: [session.courseId] } },
        ]
      });
      if (!enrollment) {
        // Log but don't block — let them join, attendance is tracked
        console.log(`Note: User ${req.user.id} joining session without enrollment record`);
      }
    }

    // Waiting room: add student to waitingStudents (instructor will admit)
    const alreadyAttendee = session.attendees.some(id => id.toString() === studentId.toString());
    const alreadyWaiting = session.waitingStudents.some(id => id.toString() === studentId.toString());
    const isSessionInstructor = session.instructorId?.toString() === req.user.id?.toString();

    if (!alreadyAttendee && !isSessionInstructor) {
      if (session.waitingRoom && !alreadyWaiting) {
        // Add to waiting room — instructor must admit
        session.waitingStudents.push(studentId);
        await session.save();
        // Notify instructor via notification
        try {
          const Notification = require('../models/Notification');
          const User = require('../models/User');
          const userDoc = await User.findById(req.user.id).select('name username').lean();
          const userName = userDoc?.name || userDoc?.username || 'A student';
          await Notification.create({
            userId: session.instructorId,
            type: 'general',
            title: `${userName} wants to join`,
            message: `${userName} is waiting to join your live session "${session.title}"`,
            data: { sessionId: session._id, studentId: req.user.id, type: 'join_request' },
          });
        } catch (_) {}
        return res.json({ success: true, status: 'waiting', message: 'You are in the waiting room. Please wait for the instructor to admit you.' });
      } else {
        // No waiting room — join directly
        if (session.attendees.length < session.maxParticipants) {
          session.attendees.push(studentId);
          await session.save();
        }
      }
    }

    res.json({
      success: true,
      status: 'joined',
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

    // Fetch actual name from DB (JWT doesn't contain name)
    const User = require('../models/User');
    const userDoc = await User.findById(toId(req.user.id)).select('name username').lean();
    const userName = userDoc?.name || userDoc?.username || 'User';

    session.chatMessages.push({
      userId: toId(req.user.id),
      userName,
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
      const User = require('../models/User');
      const userDoc = await User.findById(req.user.id).select('name username').lean();
      const userName = userDoc?.name || userDoc?.username || 'Student';
      session.raisedHands.push({
        userId,
        userName,
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
      .populate('waitingStudents', 'name username')
      .lean();

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    // Also fetch polls for this session
    const LiveSessionPoll = require('../models/LiveSessionPoll');
    const polls = await LiveSessionPoll.find({ sessionId: toId(req.params.id) }).lean().catch(() => []);

    res.json({ success: true, session: { ...session, polls } });
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

// GET /live-sessions/course/:courseId/active — check if any session is currently live
router.get('/course/:courseId/active', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findOne({
      courseId: toId(req.params.courseId),
      status: 'live',
    }).lean();
    res.json({ success: true, isLive: !!session, session: session || null });
  } catch (e) {
    res.status(500).json({ success: false, isLive: false });
  }
});

// POST /live-sessions/course/:courseId/set-live — instructor marks session live
router.post('/course/:courseId/set-live', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { sessionId, isLive } = req.body;
    if (sessionId) {
      await LiveSession.findByIdAndUpdate(toId(sessionId), { status: isLive ? 'live' : 'ended' });
    } else {
      // Create a quick live marker if no scheduled session
      if (isLive) {
        await LiveSession.findOneAndUpdate(
          { courseId: toId(req.params.courseId), status: 'live' },
          {
            courseId: toId(req.params.courseId),
            instructorId: toId(req.user.id),
            status: 'live',
            title: req.body.title || 'Live Session',
            scheduledAt: new Date(),   // ← required field fix
          },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );
      } else {
        await LiveSession.updateMany({ courseId: toId(req.params.courseId), status: 'live' }, { status: 'ended' });
      }
    }
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/notify-start — notify enrolled students when instructor goes live
router.post('/notify-start', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, sessionId, instructorName, sessionTitle } = req.body;

    // Find all enrolled students for this course
    const enrollments = await Enrollment.find({
      courseId: toId(courseId),
      status: { $in: ['active', 'enrolled'] }
    }).select('userId').lean();

    if (!enrollments.length) {
      return res.json({ success: true, message: 'No enrolled students', notified: 0 });
    }

    const User = require('../models/User');
    const Notification = require('../models/Notification');

    // Create in-app notifications for all students
    const notifications = enrollments.map(e => ({
      userId: e.userId,
      type: 'general',
      title: `🔴 LIVE: ${sessionTitle || 'Live Session Started'}`,
      message: `${instructorName || 'Your instructor'} has started a live session. Join now!`,
      data: { courseId, sessionId, type: 'live_session_started' },
    }));

    await Notification.insertMany(notifications);

    // Also send FCM if tokens available
    try {
      const fcmTokens = await User.find({
        _id: { $in: enrollments.map(e => e.userId) },
        fcmToken: { $exists: true, $ne: null }
      }).select('fcmToken').lean();

      if (fcmTokens.length > 0) {
        const admin = require('firebase-admin');
        const tokens = fcmTokens.map(u => u.fcmToken).filter(Boolean);
        if (tokens.length > 0) {
          await admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
              title: `🔴 LIVE: ${sessionTitle || 'Live Session'}`,
              body: `${instructorName || 'Your instructor'} has started a live session. Tap to join!`,
            },
            data: { courseId: courseId?.toString(), sessionId: sessionId?.toString(), type: 'live_session' },
          }).catch(() => {});
        }
      }
    } catch (_) {}

    res.json({ success: true, notified: enrollments.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/:id/recording/start — start Agora Cloud Recording
router.post('/:id/recording/start', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const agoraRecording = require('../services/agoraCloudRecording');

    if (!agoraRecording.isConfigured()) {
      // Credentials not set yet — mark locally and return
      session.isRecorded = true;
      session.recordingStartedAt = new Date();
      await session.save();
      return res.json({ success: true, message: 'Recording marked (cloud credentials not configured)', sessionId: session._id });
    }

    const channelName = `lms_${session.courseId?.toString()}`;

    // Acquire resource → start recording
    const resourceId = await agoraRecording.acquireResource(channelName);
    const sid = await agoraRecording.startRecording(channelName, resourceId);

    session.isRecorded = true;
    session.recordingStartedAt = new Date();
    session.recordingResourceId = resourceId;
    session.recordingSid = sid;
    await session.save();

    res.json({ success: true, message: 'Cloud recording started', sessionId: session._id, resourceId, sid });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/:id/recording/stop — stop Agora Cloud Recording + save URL
router.post('/:id/recording/stop', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const startTime = session.recordingStartedAt || session.createdAt;
    const endTime = new Date();
    const durationSeconds = Math.round((endTime - startTime) / 1000);

    let recordingUrl = session.recordingUrl || '';

    const agoraRecording = require('../services/agoraCloudRecording');

    if (agoraRecording.isConfigured() && session.recordingResourceId && session.recordingSid) {
      const channelName = `lms_${session.courseId?.toString()}`;
      const result = await agoraRecording.stopRecording(channelName, session.recordingResourceId, session.recordingSid);
      recordingUrl = result.mp4Url || '';
    }

    session.recordingUrl = recordingUrl;
    session.recordingEndedAt = endTime;
    session.recordingDuration = durationSeconds;
    session.recordingResourceId = undefined;
    session.recordingSid = undefined;
    await session.save();

    // If session is linked to a lesson, save recording URL there too
    if (recordingUrl && (session.linkedLessonId || session.lessonId)) {
      const lId = session.linkedLessonId || session.lessonId;
      try {
        const Course = require('../models/Course');
        const course = await Course.findById(session.courseId);
        if (course) {
          let updated = false;
          course.modules = course.modules.map(mod => ({
            ...mod.toObject(),
            lessons: mod.lessons.map(lesson => {
              if (lesson._id?.toString() === lId) {
                updated = true;
                return { ...lesson.toObject(), videoUrl: recordingUrl, recordingAvailable: true };
              }
              return lesson;
            }),
          }));
          if (updated) await course.save();
        }
      } catch (_) {}
    }

    res.json({
      success: true,
      recording: {
        sessionId: session._id,
        recordingUrl,
        durationFormatted: `${Math.floor(durationSeconds / 60)}m ${durationSeconds % 60}s`,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/:id/end-and-save — end session, save transcript, link recording to lesson
router.post('/:id/end-and-save', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { lessonId, moduleId } = req.body;

    const session = await LiveSession.findById(toId(req.params.id)).lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const durationMinutes = Math.round((Date.now() - new Date(session.createdAt).getTime()) / 60000);

    // Mark session as completed
    await LiveSession.findByIdAndUpdate(toId(req.params.id), {
      status: 'completed',
      duration: durationMinutes,
    });

    // Build chat transcript
    const chatMessages = session.chatMessages || [];
    const transcript = chatMessages.map(m =>
      `[${new Date(m.timestamp).toLocaleTimeString()}] ${m.userName}: ${m.message}`
    ).join('\n');

    const sessionSummary = {
      title: session.title,
      date: new Date().toISOString(),
      duration: durationMinutes,
      attendees: (session.attendees || []).length,
      chatTranscript: transcript,
      sessionId: session._id,
      recordingUrl: session.recordingUrl || '',
    };

    const courseId = session.courseId?._id || session.courseId;
    const resolvedLessonId = lessonId || session.linkedLessonId;
    const resolvedModuleId = moduleId || session.linkedModuleId;

    // Update the lesson in the course document (if linked)
    if (resolvedLessonId) {
      try {
        const Course = require('../models/Course');
        const course = await Course.findById(courseId);
        if (course) {
          let lessonUpdated = false;
          course.modules = (course.modules || []).map(mod => ({
            ...mod.toObject(),
            lessons: mod.lessons.map(lesson => {
              if (lesson._id?.toString() === resolvedLessonId) {
                lessonUpdated = true;
                return {
                  ...lesson.toObject(),
                  type: 'live',
                  liveSessionId: session._id,
                  liveSessionDate: new Date(),
                  chatTranscript: transcript,
                  sessionSummary: JSON.stringify(sessionSummary),
                  // If recording was done, save URL; otherwise keep existing
                  ...(session.recordingUrl ? {
                    videoUrl: session.recordingUrl,
                    recordingAvailable: true,
                  } : {}),
                };
              }
              return lesson;
            }),
          }));
          if (lessonUpdated) await course.save();
        }
      } catch (_) {}
    }

    // Always save transcript to LessonNote (even without a lessonId — use sessionId as key)
    const LessonNote = require('../models/LessonNote');
    const transcriptKey = resolvedLessonId || `session_${session._id}`;
    await LessonNote.findOneAndUpdate(
      { lessonId: transcriptKey, courseId, type: 'transcript' },
      {
        lessonId: transcriptKey,
        courseId,
        moduleId: resolvedModuleId || '',
        content: [
          `## Live Session: ${session.title}`,
          `**Date:** ${new Date().toLocaleDateString()}`,
          `**Duration:** ${durationMinutes} minutes`,
          `**Attendees:** ${sessionSummary.attendees}`,
          session.recordingUrl ? `**Recording:** [Watch](${session.recordingUrl})` : '',
          '',
          '### Chat Transcript',
          transcript || 'No messages during this session.',
        ].filter(l => l !== null).join('\n'),
        type: 'transcript',
      },
      { upsert: true }
    ).catch(() => {});

    res.json({
      success: true,
      message: resolvedLessonId ? 'Session saved and linked to lesson' : 'Session ended. Transcript saved.',
      sessionSummary,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PATCH /live-sessions/:id/set-recording-url — save Cloudinary recording URL after browser upload
router.patch('/:id/set-recording-url', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { recordingUrl } = req.body;
    if (!recordingUrl) return res.status(400).json({ success: false, message: 'recordingUrl required' });

    const session = await LiveSession.findByIdAndUpdate(
      toId(req.params.id),
      { recordingUrl, isRecorded: true, recordingEndedAt: new Date() },
      { new: true }
    );
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    // Also update linked lesson if any
    if (session.linkedLessonId || session.lessonId) {
      const lId = session.linkedLessonId || session.lessonId;
      try {
        const Course = require('../models/Course');
        const course = await Course.findById(session.courseId);
        if (course) {
          course.modules = course.modules.map(mod => ({
            ...mod.toObject(),
            lessons: mod.lessons.map(lesson => {
              if (lesson._id?.toString() === lId) {
                return { ...lesson.toObject(), videoUrl: recordingUrl, recordingAvailable: true };
              }
              return lesson;
            }),
          }));
          await course.save();
        }
      } catch (_) {}
    }

    res.json({ success: true, recordingUrl });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /live-sessions/:id/transcript — fetch saved chat transcript for a session
router.get('/:id/transcript', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sessionId = req.params.id;
    const LessonNote = require('../models/LessonNote');

    // Try both keys: plain sessionId (when lessonId was passed) or session_${id}
    let note = await LessonNote.findOne({ lessonId: sessionId, type: 'transcript' }).lean();
    if (!note) {
      note = await LessonNote.findOne({ lessonId: `session_${sessionId}`, type: 'transcript' }).lean();
    }

    if (note) {
      return res.json({ success: true, transcript: note.content });
    }

    // Fall back: build transcript directly from session chat messages
    const session = await LiveSession.findById(toId(sessionId)).lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const chatMessages = session.chatMessages || [];
    if (chatMessages.length === 0) {
      return res.json({ success: true, transcript: 'No messages were sent during this session.' });
    }

    const lines = [
      `## Live Session: ${session.title}`,
      `**Duration:** ${session.duration || 0} minutes`,
      `**Attendees:** ${(session.attendees || []).length}`,
      '',
      '### Chat',
      ...chatMessages.map(m =>
        `[${new Date(m.timestamp).toLocaleTimeString()}] ${m.userName}: ${m.message}`
      ),
    ];

    res.json({ success: true, transcript: lines.join('\n') });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
