const express = require('express');
const router  = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware }  = require('../middleware/auth');
const Attendance  = require('../models/Attendance');
const Enrollment  = require('../models/Enrollment');
const User        = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ── INSTRUCTOR: create attendance session ─────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, sessionTitle, sessionDate, records } = req.body;
    if (!courseId || !sessionDate) return res.status(400).json({ success: false, message: 'courseId and sessionDate required' });
    const session = await Attendance.create({
      courseId, instructorId: req.user.id,
      sessionTitle: sessionTitle || 'Class Session',
      sessionDate: new Date(sessionDate),
      records: records || [],
    });
    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get all sessions for a course ─────────────────────────────────────────────
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sessions = await Attendance.find({ courseId: toId(req.params.courseId) })
      .sort({ sessionDate: -1 }).lean();
    res.json({ success: true, sessions });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: my attendance for a course ───────────────────────────────────────
router.get('/course/:courseId/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const studentId = req.user.id;
    const sessions  = await Attendance.find({ courseId: toId(req.params.courseId) })
      .sort({ sessionDate: -1 }).lean();
    const result = sessions.map(s => {
      const rec = s.records.find(r => r.studentId?.toString() === studentId);
      return {
        sessionId:    s._id,
        sessionTitle: s.sessionTitle,
        sessionDate:  s.sessionDate,
        status:       rec?.status || 'absent',
      };
    });
    const total   = result.length;
    const present = result.filter(r => r.status === 'present').length;
    res.json({ success: true, attendance: result, total, present, percentage: total ? Math.round((present/total)*100) : 0 });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: full attendance report for a course ──────────────────────────
router.get('/course/:courseId/report', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sessions = await Attendance.find({ courseId: toId(req.params.courseId) })
      .sort({ sessionDate: 1 }).lean();
    const enrollments = await Enrollment.find({ courseId: toId(req.params.courseId) })
      .populate('userId', 'name email username').lean();

    const students = enrollments.map(e => {
      const user = e.userId;
      const studentId = user?._id?.toString() ?? e.userId?.toString();
      const name = user?.name || user?.username || 'Student';
      const email = user?.email || '';

      let present = 0, late = 0, absent = 0;
      const sessionRows = sessions.map(s => {
        const rec = s.records.find(r => r.studentId?.toString() === studentId);
        const status = rec?.status || 'absent';
        if (status === 'present') present++;
        else if (status === 'late') late++;
        else absent++;
        return { sessionId: s._id, sessionTitle: s.sessionTitle, sessionDate: s.sessionDate, status };
      });
      const total = sessions.length;
      const pct = total ? Math.round(((present + late * 0.5) / total) * 100) : 0;
      return { studentId, name, email, present, late, absent, total, percentage: pct, sessions: sessionRows };
    });

    res.json({ success: true, sessions: sessions.map(s => ({ _id: s._id, sessionTitle: s.sessionTitle, sessionDate: s.sessionDate })), students });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: mark single student attendance in a session ───────────────────
router.put('/:sessionId/mark', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { studentId, status } = req.body;
    if (!studentId || !status) return res.status(400).json({ success: false, message: 'studentId and status required' });
    const session = await Attendance.findById(toId(req.params.sessionId));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    const idx = session.records.findIndex(r => r.studentId?.toString() === studentId);
    if (idx >= 0) {
      session.records[idx].status = status;
    } else {
      session.records.push({ studentId: toId(studentId), status });
    }
    session.markModified('records');
    await session.save();
    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: update attendance for a session ───────────────────────────────
router.put('/:sessionId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { records } = req.body;
    const session = await Attendance.findById(toId(req.params.sessionId));
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    session.records = records;
    await session.save();
    res.json({ success: true, session });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
