const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const multer = require('multer');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const LiveSession = require('../models/LiveSession');
const Enrollment = require('../models/Enrollment');
const cloudinary = require('../config/cloudinary');
const { uploadRecordingToDrive, backupUrlToDrive, getOrCreateCourseFolder, isConfigured: driveConfigured } = require('../utils/googleDrive');

const jibriUpload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 2 * 1024 * 1024 * 1024 } });

// Shared by jibri-recording-complete (fresh recording) and the
// /:id/retry-drive-backup route (retrying a session whose Drive backup
// never completed — see that route's comment for why this could happen).
// MUST be awaited by callers, not fired-and-forgotten — see the comment at
// the jibri-recording-complete call site for why.
async function backupSessionRecordingToDrive(session, { fileBuffer, sourceUrl } = {}) {
  if (!driveConfigured()) return { ok: false, reason: 'not_configured' };
  try {
    const Course = require('../models/Course');
    const course = await Course.findById(session.courseId).select('title driveFolderId');
    let folderId = course?.driveFolderId;
    if (!folderId && course) {
      folderId = await getOrCreateCourseFolder(course.title);
      await Course.updateOne({ _id: course._id }, { $set: { driveFolderId: folderId } });
    }

    // e.g. "abc course - Fundamentals lesson-1 - 16 Jul 2026, 10-13 PM.mp4"
    const dt = new Date();
    const dateStr = dt.toLocaleString('en-US', {
      timeZone: 'Asia/Karachi',
      day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true,
    }).replace(':', '-');
    const sanitize = (s) => (s || '').replace(/[\\/:*?"<>|]/g, '-').trim();
    const driveFilename = `${sanitize(course?.title) || 'Course'} - ${sanitize(session.title) || 'recording'} - ${dateStr}.mp4`;
    const result = fileBuffer
      ? await uploadRecordingToDrive(fileBuffer, driveFilename, 'video/mp4', folderId)
      : await backupUrlToDrive(sourceUrl, driveFilename, 'video/mp4', folderId);
    if (!result) return { ok: false, reason: 'upload_returned_null' };

    session.driveBackupUrl = result.webViewLink;
    await session.save();
    console.log(`Drive backup saved for session ${session._id}: ${result.webViewLink}`);

    // Propagate to the module-embedded lesson entry too, if this session is
    // linked to one — the /end route already wrote a snapshot when the
    // session finished, but the Drive upload finishes after that, so
    // driveBackupUrl never made it into the lesson object the classroom UI
    // reads (it only ever checked session.driveBackupUrl on the standalone
    // LiveSession doc, which the module-lesson tile doesn't see).
    if (session.linkedLessonId) {
      await Course.updateOne(
        { _id: session.courseId },
        { $set: {
            'modules.$[].lessons.$[lesson].driveBackupUrl': result.webViewLink,
            'modules.$[].lessons.$[lesson].recordingUrl': session.recordingUrl || sourceUrl,
          } },
        { arrayFilters: [{ 'lesson._id': toId(session.linkedLessonId) }] }
      );
    }
    return { ok: true, url: result.webViewLink };
  } catch (e) {
    // Drive backup failing must never fail the whole recording-finalize
    // request — recordingUrl (Cloudinary/Blob) has already saved
    // successfully by this point regardless.
    console.error(`Drive backup failed for session ${session._id}:`, e.message);
    return { ok: false, reason: e.message };
  }
}

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// Mark a student PRESENT for today's run of a live session.
// One Attendance doc per live-session per day; enrolled students with no record count as absent.
async function markLivePresent(session, studentId) {
  try {
    const Attendance = require('../models/Attendance');
    const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(); dayEnd.setHours(23, 59, 59, 999);
    let att = await Attendance.findOne({
      liveSessionId: session._id.toString(),
      sessionDate: { $gte: dayStart, $lte: dayEnd },
    });
    if (!att) {
      att = await Attendance.create({
        courseId: session.courseId,
        instructorId: session.instructorId,
        sessionTitle: session.title || 'Live Session',
        sessionDate: new Date(),
        liveSessionId: session._id.toString(),
        records: [],
      });
    }
    if (!att.records.some(r => r.studentId?.toString() === studentId.toString())) {
      att.records.push({ studentId, status: 'present' });
      await att.save();
    }
  } catch (e) {
    console.warn('auto-attendance error:', e.message);
  }
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

    // Opportunistic cleanup: a 'live' session that never received a graceful
    // end signal (server crash, instructor closing the tab, network drop
    // right as the instructor tried to end it, etc) stays 'live' forever
    // unless something happens to poll /active for it afterwards.
    const staleHeartbeatThreshold = new Date(Date.now() - 5 * 60 * 1000);
    const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000);
    const staleSessions = await LiveSession.find(
      {
        courseId: toId(req.params.courseId),
        status: 'live',
        $or: [
          { instructorHeartbeat: { $lt: staleHeartbeatThreshold } },
          { instructorHeartbeat: null, createdAt: { $lt: threeHoursAgo } },
        ],
      },
      { linkedLessonId: 1 }
    ).lean().catch(() => []);

    if (staleSessions.length) {
      await LiveSession.updateMany(
        { _id: { $in: staleSessions.map(s => s._id) } },
        { status: 'ended' }
      ).catch(() => {});

      // Same reason as end-and-save's own status write (courseProgress.js's
      // recheckModuleCompletion only unlocks a module-embedded live lesson
      // once status:'ended' is set) — but /end-and-save is a single
      // fire-once call from the INSTRUCTOR's own device at the exact moment
      // their connection may be dying (tab closing, network dropping). If
      // that call never lands, this is the only other place that ever marks
      // the lesson done, so a flaky-connection instructor no longer
      // permanently strands every student's module unlock for that session.
      const Course = require('../models/Course');
      const lessonIds = staleSessions.map(s => s.linkedLessonId).filter(Boolean);
      if (lessonIds.length) {
        await Course.updateOne(
          { _id: toId(req.params.courseId) },
          { $set: { 'modules.$[].lessons.$[lesson].status': 'ended' } },
          { arrayFilters: [{ 'lesson._id': { $in: lessonIds.map(toId).filter(Boolean) } }] }
        ).catch(() => {});
      }
    }

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
// ── IMPORTANT: /course/:courseId/active and /course/:courseId/set-live must be
// ── defined BEFORE /:id to prevent Express treating 'course' as an :id param.

// GET /live-sessions/course/:courseId/active — check if any session is currently live
// CRITICAL: no-cache headers prevent Vercel CDN from returning stale 304 responses
router.get('/course/:courseId/active', authMiddleware, async (req, res) => {
  try {
    // Prevent Vercel CDN caching — always hit the actual backend
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('Surrogate-Control', 'no-store');

    await connectMongoDB();
    console.log(`[LIVE-SESSIONS] Checking active for courseId: ${req.params.courseId}`);
    const session = await LiveSession.findOne({
      courseId: toId(req.params.courseId),
      status: 'live',
    }).lean();

    console.log(`[LIVE-SESSIONS] Found session: ${session ? session._id : 'none'}`);

    if (session) {
      // Auto-expire: no instructor heartbeat for 90s means instructor left without ending
      const ninetySecsAgo = new Date(Date.now() - 90 * 1000);
      const heartbeat = session.instructorHeartbeat;
      const sessionAge = Date.now() - new Date(session.createdAt).getTime();
      // Grace period: first 60s after creation, heartbeat may not have arrived yet
      const pastGracePeriod = sessionAge > 60 * 1000;
      if (pastGracePeriod && heartbeat && new Date(heartbeat) < ninetySecsAgo) {
        await LiveSession.findByIdAndUpdate(session._id, { status: 'ended' });
        console.log(`[LIVE-SESSIONS] Auto-expired stale session ${session._id} (last heartbeat: ${heartbeat})`);
        console.log(`[LIVE-SESSIONS] Returning: isLive=false (auto-expired)`);
        return res.json({ success: true, isLive: false, session: null });
      }

      // Hard cap: use heartbeat if available, else createdAt — prevents old reactivated sessions from expiring
      const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000);
      const lastActivity = heartbeat ? new Date(heartbeat) : new Date(session.createdAt);
      if (lastActivity < threeHoursAgo) {
        await LiveSession.findByIdAndUpdate(session._id, { status: 'ended' });
        console.log(`[LIVE-SESSIONS] Hard-cap expired session ${session._id} (lastActivity: ${lastActivity})`);
        console.log(`[LIVE-SESSIONS] Returning: isLive=false (hard-cap)`);
        return res.json({ success: true, isLive: false, session: null });
      }
    }

    console.log(`[LIVE-SESSIONS] Returning: isLive=${!!session}`);
    res.json({ success: true, isLive: !!session, session: session || null });
  } catch (e) {
    console.error(`[LIVE-SESSIONS] Error checking active for ${req.params.courseId}:`, e);
    res.status(500).json({ success: false, isLive: false });
  }
});

// POST /live-sessions/:id/heartbeat — instructor pings every 30s while in session
router.post('/:id/heartbeat', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await LiveSession.findByIdAndUpdate(toId(req.params.id), {
      instructorHeartbeat: new Date(),
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false });
  }
});

// POST /live-sessions/course/:courseId/set-live — instructor marks session live
router.post('/course/:courseId/set-live', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { sessionId, isLive, title } = req.body;

    if (!isLive) {
      // Ending: mark all live sessions for this course as ended
      await LiveSession.updateMany({ courseId: toId(req.params.courseId), status: 'live' }, { status: 'ended' });
      return res.json({ success: true });
    }

    // Check if a session is already live for this course (started by another instructor/co-teacher)
    const existingLive = await LiveSession.findOne({
      courseId: toId(req.params.courseId),
      status: 'live',
    }).lean();

    if (existingLive) {
      // Another instructor already started — co-teacher joins the same session room
      console.log(`set-live: co-teacher joining existing session=${existingLive._id}`);
      return res.json({ success: true, sessionId: existingLive._id.toString() });
    }

    // No active session — this instructor is starting fresh
    // Resolve title: use provided title, or inherit from the scheduled session template
    let sessionTitle = title || 'Live Session';
    if (sessionId && sessionId !== req.params.courseId) {
      const template = await LiveSession.findById(toId(sessionId)).select('title scheduledAt').lean();
      if (template?.title) sessionTitle = template.title;
      // A session scheduled for a specific future time can't be started
      // early — "Go Live" stays locked client-side too, but the backend
      // is the real gate since the client's clock/lock state can't be trusted.
      if (template?.scheduledAt && new Date(template.scheduledAt) > new Date()) {
        return res.status(403).json({
          success: false,
          message: `This session is scheduled for ${new Date(template.scheduledAt).toISOString()} and cannot be started early.`,
          scheduledAt: template.scheduledAt,
        });
      }
    }

    // Create a fresh LiveSession document — each go-live gets a new _id,
    // which ensures attendance is tracked separately per session run.
    const resultSession = await LiveSession.create({
      courseId: toId(req.params.courseId),
      instructorId: toId(req.user.id),
      status: 'live',
      instructorHeartbeat: new Date(),
      title: sessionTitle,
      scheduledAt: new Date(),
      startedAt: new Date(),
      attendees: [],
      waitingStudents: [],
      raisedHands: [],
      chatMessages: [],
      polls: [],
    });

    console.log(`set-live: course=${req.params.courseId} new session=${resultSession._id}`);
    res.json({ success: true, sessionId: resultSession._id.toString() });
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

    // Auto-attendance: student joined → mark present for today's session
    if (!isInstructor) await markLivePresent(session, studentId);

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

// ── STUDENT/INSTRUCTOR: Leave session (removes from attendees + waiting) ────
router.post('/:id/leave', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    await LiveSession.findByIdAndUpdate(toId(req.params.id), {
      $pull: { attendees: userId, waitingStudents: userId },
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Feature 4: Record student join timestamp ─────────────────────────────────
router.post('/:id/record-join', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Attendance = require('../models/Attendance');
    const session = await LiveSession.findById(toId(req.params.id)).lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const studentId = toId(req.user.id);
    const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0);
    const dayEnd   = new Date(); dayEnd.setHours(23, 59, 59, 999);

    let att = await Attendance.findOne({
      liveSessionId: session._id.toString(),
      sessionDate: { $gte: dayStart, $lte: dayEnd },
    });

    if (!att) {
      att = await Attendance.create({
        courseId: session.courseId,
        instructorId: session.instructorId,
        sessionTitle: session.title || 'Live Session',
        sessionDate: new Date(),
        liveSessionId: session._id.toString(),
        records: [],
      });
    }

    const existing = att.records.find(r => r.studentId?.toString() === studentId.toString());
    if (existing) {
      // Update joinedAt if not set yet
      if (!existing.joinedAt) existing.joinedAt = new Date();
    } else {
      att.records.push({ studentId, status: 'present', joinedAt: new Date() });
    }
    await att.save();

    res.json({ success: true, joinedAt: new Date() });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Feature 4: Record student leave timestamp ────────────────────────────────
router.post('/:id/record-leave', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const Attendance = require('../models/Attendance');
    const studentId = toId(req.user.id);
    const leftAt = new Date();

    const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0);
    const dayEnd   = new Date(); dayEnd.setHours(23, 59, 59, 999);

    const att = await Attendance.findOne({
      liveSessionId: req.params.id,
      sessionDate: { $gte: dayStart, $lte: dayEnd },
    });

    if (att) {
      const record = att.records.find(r => r.studentId?.toString() === studentId.toString());
      if (record) {
        record.leftAt = leftAt;
        if (record.joinedAt) {
          record.durationMinutes = Math.round((leftAt - new Date(record.joinedAt)) / 60000);
        }
        await att.save();
      }
    }

    res.json({ success: true, leftAt });
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

    // Recordings are archived to Google Drive (see jibri-recording-complete)
    // and remain playable from the Live Sessions list via recordingUrl —
    // they're intentionally no longer auto-attached as a Course Content
    // lesson's video.

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

// ── Screen share: broadcast who is currently sharing (or clear it) ─────────
router.post('/:id/screen-share', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { uid } = req.body; // Agora numeric uid as string, or null to clear
    await LiveSession.findByIdAndUpdate(toId(req.params.id), {
      screenSharingUid: uid || null,
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Report which Agora uid this participant was assigned for this call ─────
// Called once right after a participant joins Agora (uid:0 join means Agora
// picks a random numeric uid server-side — there's no way to derive it from
// the backend userId). Every OTHER participant's poll then uses this
// mapping to label the correct video tile with the correct name, instead of
// guessing by list order (which caused wrong names on tiles / tiles
// disappearing when a new participant joined).
router.post('/:id/set-my-uid', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { agoraUid } = req.body;
    if (!agoraUid) return res.status(400).json({ success: false, message: 'agoraUid required' });
    const userId = toId(req.user.id);
    const sessionId = toId(req.params.id);

    // Replace this user's existing entry (if any) rather than appending —
    // a participant may leave and rejoin the same session and get a new uid.
    await LiveSession.findByIdAndUpdate(sessionId, {
      $pull: { participantUids: { userId } },
    });
    await LiveSession.findByIdAndUpdate(sessionId, {
      $push: { participantUids: { userId, agoraUid: String(agoraUid) } },
    });
    res.json({ success: true });
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
    if (!session.attendees.some(a => a.toString() === studentId.toString())) {
      session.attendees.push(studentId);
    }

    await session.save();
    await markLivePresent(session, studentId);

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
    const admitted = [...session.waitingStudents];
    admitted.forEach(studentId => {
      if (!session.attendees.includes(studentId)) {
        session.attendees.push(studentId);
      }
    });

    session.waitingStudents = [];
    await session.save();
    for (const studentId of admitted) {
      await markLivePresent(session, studentId);
    }

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

// (routes moved above /:id — see near top of file)

// POST /live-sessions/notify-start — notify enrolled students when instructor goes live
router.post('/notify-start', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, sessionId, instructorName, sessionTitle } = req.body;

    // Find all enrolled students for this course.
    // Enrollment has no `status` field (only isCompleted/completedAt), so a
    // prior filter on status:{$in:['active','enrolled']} matched zero
    // documents and silently no-op'd every "go live" notify call.
    const enrollments = await Enrollment.find({
      courseId: toId(courseId),
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

    // Recordings are archived to Google Drive and remain playable from the
    // Live Sessions list via recordingUrl — intentionally no longer
    // auto-attached as a Course Content lesson's video (legacy Agora path).

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
    const { lessonId, moduleId, chatTranscript } = req.body;

    const session = await LiveSession.findById(toId(req.params.id)).lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    // Use startedAt (set on go-live) — createdAt can be days old for reused session docs
    const durationMinutes = Math.round((Date.now() - new Date(session.startedAt || session.createdAt).getTime()) / 60000);

    const resolvedLessonId = lessonId || session.linkedLessonId;
    const resolvedModuleId = moduleId || session.linkedModuleId;

    // Mark session as completed
    await LiveSession.findByIdAndUpdate(toId(req.params.id), {
      status: 'completed',
      duration: durationMinutes,
      // Persist the lesson link onto the session itself (not just used
      // in-request below) — a session joined straight from a module-lesson
      // tile (not pre-scheduled via syncLiveSessions) previously never got
      // linkedLessonId set at all, so backupSessionRecordingToDrive's later
      // async lesson-backfill (which only has the LiveSession doc to work
      // from, long after this request has finished) silently found nothing
      // to update — even though the LiveSession itself ended up with a
      // working recordingUrl/driveBackupUrl. Confirmed live: a WEEK 5
      // session had recordingUrl+driveBackupUrl set but its lesson stayed
      // stuck on "Recording is processing" forever because linkedLessonId
      // was never set on the session doc.
      ...(resolvedLessonId ? { linkedLessonId: resolvedLessonId } : {}),
      ...(resolvedModuleId ? { linkedModuleId: resolvedModuleId } : {}),
    });

    // Build chat transcript — prefer server-recorded chatMessages (has
    // resolved user names + exact timestamps). If the server-side array is
    // empty (e.g. a message's POST /chat call hadn't committed yet when this
    // request landed) but the client sent its own local chat log, fall back
    // to that instead of silently saving "no messages".
    const chatMessages = session.chatMessages || [];
    let transcript = chatMessages.map(m =>
      `[${new Date(m.timestamp).toLocaleTimeString()}] ${m.userName}: ${m.message}`
    ).join('\n');
    if (!transcript && Array.isArray(chatTranscript) && chatTranscript.length > 0) {
      transcript = chatTranscript.map(m =>
        `[${m.time || ''}] ${m.sender || 'User'}: ${m.text || ''}`
      ).join('\n');
    }

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

    // Update the lesson in the course document (if linked) — atomic
    // positional update so a concurrent /set-recording-url write (from the
    // recording upload, which runs in parallel with this call) can't clobber
    // this write or vice versa. Both previously did a read→modify→save on
    // the whole Course doc, which is a classic lost-update race: whichever
    // finished last would silently discard the other's field (this is why
    // chatTranscript sometimes went missing even though it was computed here).
    if (resolvedLessonId) {
      try {
        const Course = require('../models/Course');
        const setFields = {
          'modules.$[].lessons.$[lesson].type': 'live',
          'modules.$[].lessons.$[lesson].liveSessionId': session._id,
          'modules.$[].lessons.$[lesson].liveSessionDate': new Date(),
          // The classroom UI's module-lesson tile derives "Ready · waiting
          // for instructor" vs "Recording available" purely from this
          // status field (classroom_course_view.dart _buildLessonTile) —
          // it was never written here, so an ended session's module lesson
          // stayed stuck showing "waiting for instructor" forever even once
          // the recording existed.
          'modules.$[].lessons.$[lesson].status': 'ended',
          'modules.$[].lessons.$[lesson].chatTranscript': transcript,
          'modules.$[].lessons.$[lesson].sessionSummary': JSON.stringify(sessionSummary),
          // Overwrite the pre-set planned duration with how long the
          // session actually ran, once it's known — the module-content
          // list previously only ever showed the instructor's original
          // estimate (e.g. "15 min") even after the session had long since
          // ended and its real length was known.
          'modules.$[].lessons.$[lesson].duration': durationMinutes,
        };
        if (session.recordingUrl) {
          setFields['modules.$[].lessons.$[lesson].videoUrl'] = session.recordingUrl;
          // The classroom UI's module-lesson tile reads recordingUrl (see
          // classroom_course_view.dart), not videoUrl — this was the actual
          // reason a module-embedded live session's recording never showed
          // up as available, even once Jibri had finished uploading it.
          setFields['modules.$[].lessons.$[lesson].recordingUrl'] = session.recordingUrl;
          setFields['modules.$[].lessons.$[lesson].recordingAvailable'] = true;
        }
        if (session.driveBackupUrl) {
          setFields['modules.$[].lessons.$[lesson].driveBackupUrl'] = session.driveBackupUrl;
        }
        await Course.updateOne(
          { _id: courseId },
          { $set: setFields },
          { arrayFilters: [{ 'lesson._id': toId(resolvedLessonId) }] }
        );
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

    // Recordings are archived to Google Drive and remain playable from the
    // Live Sessions list via recordingUrl — intentionally no longer
    // auto-attached as a Course Content lesson's video.

    res.json({ success: true, recordingUrl });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /live-sessions/:id/transcript — fetch saved chat transcript for a session
// ── PUT /:id/reschedule — reschedule with announcement ──────────────────────
router.put('/:id/reschedule', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { newDate, reason } = req.body;
    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const oldDate = session.scheduledAt;
    session.scheduledAt = new Date(newDate);
    session.status = 'rescheduled';
    if (!session.log) session.log = [];
    session.log.push({ action: 'rescheduled', oldDate, newDate: session.scheduledAt, reason: reason || '', by: req.user.id, at: new Date() });
    await session.save();

    // Announce to course
    try {
      const Announcement = require('../models/Announcement');
      await Announcement.create({
        courseId: session.courseId,
        instructorId: req.user.id,
        title: `📅 Session Rescheduled: ${session.title}`,
        body: `The live session "${session.title}" has been rescheduled to ${new Date(newDate).toLocaleString()}. ${reason ? 'Reason: ' + reason : ''}`,
        type: 'session_rescheduled',
        sessionId: session._id,
      });
    } catch (_) {}

    // Push to enrolled students
    try {
      const { sendToUser } = require('../utils/pushNotifications');
      const enrollments = await Enrollment.find({ courseId: session.courseId }).select('userId').lean();
      await Promise.all(enrollments.map(e => sendToUser(e.userId, {
        title: '📅 Session Rescheduled',
        body: `"${session.title}" rescheduled to ${new Date(newDate).toLocaleString()}`,
        data: { type: 'session_rescheduled', sessionId: session._id.toString() },
      }).catch(() => {})));
    } catch (_) {}

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── PUT /:id/cancel — cancel with announcement ───────────────────────────────
router.put('/:id/cancel', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { reason } = req.body;
    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    session.status = 'cancelled';
    if (!session.log) session.log = [];
    session.log.push({ action: 'cancelled', reason: reason || '', by: req.user.id, at: new Date() });
    await session.save();

    // Announce to course
    try {
      const Announcement = require('../models/Announcement');
      await Announcement.create({
        courseId: session.courseId,
        instructorId: req.user.id,
        title: `❌ Session Cancelled: ${session.title}`,
        body: `The live session "${session.title}" has been cancelled. ${reason ? 'Reason: ' + reason : ''}`,
        type: 'session_cancelled',
        sessionId: session._id,
      });
    } catch (_) {}

    // Push to enrolled students
    try {
      const { sendToUser } = require('../utils/pushNotifications');
      const enrollments = await Enrollment.find({ courseId: session.courseId }).select('userId').lean();
      await Promise.all(enrollments.map(e => sendToUser(e.userId, {
        title: '❌ Session Cancelled',
        body: `"${session.title}" has been cancelled. ${reason ? reason : ''}`,
        data: { type: 'session_cancelled', sessionId: session._id.toString() },
      }).catch(() => {})));
    } catch (_) {}

    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

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

// ── WHITEBOARD ───────────────────────────────────────────────────────────────

// GET /:id/whiteboard — fetch all strokes + permission list
router.get('/:id/whiteboard', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(req.params.id)
      .select('whiteboardStrokes whiteboardPermissions instructorId whiteboardOpen')
      .lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    res.json({
      success: true,
      strokes: session.whiteboardStrokes || [],
      permissions: (session.whiteboardPermissions || []).map(id => id.toString()),
      whiteboardOpen: session.whiteboardOpen === true,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /:id/whiteboard/stroke — add a stroke
router.post('/:id/whiteboard/stroke', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = (req.user.id || req.user._id || req.user.userId || '').toString();
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
    const session = await LiveSession.findById(req.params.id)
      .select('instructorId whiteboardPermissions')
      .lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const instructorId = session.instructorId?.toString() || '';
    const isInstructor = instructorId && instructorId === userId;
    const hasPermission = (session.whiteboardPermissions || []).some(id => id.toString() === userId);
    if (!isInstructor && !hasPermission) {
      return res.status(403).json({ success: false, message: 'No drawing permission' });
    }

    const stroke = { ...req.body, userId, addedAt: new Date() };
    await LiveSession.findByIdAndUpdate(req.params.id, {
      $push: { whiteboardStrokes: stroke }
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /:id/whiteboard/stroke/last — undo last stroke by current user
router.delete('/:id/whiteboard/stroke/last', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = (req.user.id || req.user._id || req.user.userId || '').toString();
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
    const session = await LiveSession.findById(req.params.id).select('whiteboardStrokes instructorId').lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const strokes = session.whiteboardStrokes || [];
    for (let i = strokes.length - 1; i >= 0; i--) {
      if (strokes[i].userId?.toString() === userId) {
        await LiveSession.findByIdAndUpdate(req.params.id, {
          $pull: { whiteboardStrokes: { id: strokes[i].id } }
        });
        return res.json({ success: true });
      }
    }
    res.json({ success: true, message: 'Nothing to undo' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /:id/whiteboard/clear — clear all strokes (instructor only)
router.post('/:id/whiteboard/clear', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = (req.user.id || req.user._id || req.user.userId || '').toString();
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
    const session = await LiveSession.findById(req.params.id).select('instructorId').lean();
    // If session not found or no instructorId, still allow clear (session may be new)
    if (session && session.instructorId) {
      const instructorId = session.instructorId.toString();
      if (instructorId !== userId) {
        return res.status(403).json({ success: false, message: 'Only instructor can clear' });
      }
    }
    await LiveSession.findByIdAndUpdate(req.params.id, { $set: { whiteboardStrokes: [] } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /:id/whiteboard/permission — grant or revoke a student's drawing permission
router.put('/:id/whiteboard/permission', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = (req.user.id || req.user._id || req.user.userId || '').toString();
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
    const session = await LiveSession.findById(req.params.id).select('instructorId').lean();
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    if (session.instructorId && session.instructorId.toString() !== userId) {
      return res.status(403).json({ success: false, message: 'Only instructor can manage permissions' });
    }
    const { studentId, grant } = req.body;
    const studentObjId = toId(studentId);
    if (!studentObjId) return res.status(400).json({ success: false, message: 'Invalid studentId' });
    if (grant) {
      await LiveSession.findByIdAndUpdate(req.params.id, {
        $addToSet: { whiteboardPermissions: studentObjId }
      });
    } else {
      await LiveSession.findByIdAndUpdate(req.params.id, {
        $pull: { whiteboardPermissions: studentObjId }
      });
    }
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/jibri-recording-complete — called by Jibri finalize script on droplet.
// Accepts JSON {sessionId, url} (Vercel Blob) OR multipart file (legacy Cloudinary path).
router.post('/jibri-recording-complete', jibriUpload.single('file'), async (req, res) => {
  try {
    const secret = (req.headers['x-jibri-secret'] || '').trim();
    const expected = (process.env.JIBRI_UPLOAD_SECRET || '').trim();
    if (!secret || !expected || secret !== expected) {
      return res.status(401).json({ success: false, message: 'Invalid or missing secret' });
    }
    const sessionId = req.body.sessionId;
    if (!sessionId) {
      return res.status(400).json({ success: false, message: 'sessionId is required' });
    }
    if (!req.file && !req.body.url) {
      return res.status(400).json({ success: false, message: 'file or url is required' });
    }

    await connectMongoDB();
    const session = await LiveSession.findById(toId(sessionId));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    let finalUrl;
    if (req.body.url) {
      finalUrl = (req.body.url + '').trim();
    } else {
      const uploadResult = await new Promise((resolve, reject) => {
        const stream = cloudinary.uploader.upload_stream(
          { resource_type: 'video', folder: 'icare/lms-recordings' },
          (err, result) => (err ? reject(err) : resolve(result))
        );
        stream.end(req.file.buffer);
      });
      finalUrl = uploadResult.secure_url;
    }

    if (!session.recordings) session.recordings = [];
    session.recordings.push({ url: finalUrl, createdAt: new Date() });
    session.recordingUrl = finalUrl;
    session.isRecorded = true;
    await session.save();

    // Google Drive backup is intentionally NOT done here anymore. It used
    // to be awaited in this same request, but downloading + re-uploading a
    // real class-length recording (15-20+ min) routinely blew past this
    // function's maxDuration (60s, vercel.json) — Vercel kills the function
    // mid-upload, so driveBackupUrl never gets set even though the video is
    // genuinely sitting in Drive by then (confirmed live: client checked
    // Drive directly and found the file while the app was still stuck on
    // "processing"). finalize.sh now calls the dedicated
    // jibri-drive-backup endpoint as its own follow-up step, immediately
    // after this response — same Jibri-secret auth, own fresh 60s budget,
    // and finalize.sh already has no time pressure (--max-time 600 on its
    // Blob upload proves that).

    // Recordings are archived to Google Drive (via finalize.sh's follow-up
    // call to jibri-drive-backup) and remain playable
    // from the Live Sessions list via recordingUrl — per the client's
    // request, they're intentionally no longer auto-attached as a Course
    // Content lesson's video.

    console.log(`Jibri recording saved for session ${sessionId}: ${finalUrl}`);
    res.json({ success: true, url: finalUrl });
  } catch (e) {
    console.error('jibri-recording-complete error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/jibri-drive-backup — called by Jibri finalize.sh as a
// separate follow-up step right after jibri-recording-complete, so the
// Drive download+reupload gets its own fresh maxDuration budget instead of
// competing with the recording-complete request's — see the comment on
// jibri-recording-complete for why that was blowing the 60s limit on real
// class-length recordings. Same X-Jibri-Secret auth as
// jibri-recording-complete (no new secret needed on the Jitsi server).
router.post('/jibri-drive-backup', async (req, res) => {
  try {
    const secret = (req.headers['x-jibri-secret'] || '').trim();
    const expected = (process.env.JIBRI_UPLOAD_SECRET || '').trim();
    if (!secret || !expected || secret !== expected) {
      return res.status(401).json({ success: false, message: 'Invalid or missing secret' });
    }
    const sessionId = req.body.sessionId;
    if (!sessionId) {
      return res.status(400).json({ success: false, message: 'sessionId is required' });
    }

    await connectMongoDB();
    const session = await LiveSession.findById(toId(sessionId));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    if (!session.recordingUrl) {
      return res.status(400).json({ success: false, message: 'No recordingUrl to back up yet' });
    }
    if (session.driveBackupUrl) {
      return res.json({ success: true, alreadyBackedUp: true, url: session.driveBackupUrl });
    }

    const result = await backupSessionRecordingToDrive(session, { sourceUrl: session.recordingUrl });
    if (!result.ok) return res.status(502).json({ success: false, message: result.reason || 'Drive backup failed' });
    res.json({ success: true, url: result.url });
  } catch (e) {
    console.error('jibri-drive-backup error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /live-sessions/:id/retry-drive-backup — instructor-triggerable retry
// for a session whose recordingUrl saved fine but driveBackupUrl never got
// set (e.g. a pre-fix session from before jibri-recording-complete started
// awaiting the Drive upload — those are permanently stuck at "processing"
// with no code path left that will ever revisit them on its own).
router.post('/:id/retry-drive-backup', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const session = await LiveSession.findById(toId(req.params.id));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    if (session.instructorId && session.instructorId.toString() !== req.user.id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Only the session instructor can retry this' });
    }
    if (!session.recordingUrl) {
      return res.status(400).json({ success: false, message: 'This session has no recording to back up' });
    }
    if (session.driveBackupUrl) {
      return res.json({ success: true, alreadyBackedUp: true, url: session.driveBackupUrl });
    }
    const result = await backupSessionRecordingToDrive(session, { sourceUrl: session.recordingUrl });
    if (!result.ok) return res.status(502).json({ success: false, message: result.reason || 'Drive backup failed' });
    res.json({ success: true, url: result.url });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
