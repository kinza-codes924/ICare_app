const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const LessonNote = require('../models/LessonNote');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// GET /api/lesson-notes/:lessonId — get student's note for a lesson
router.get('/:lessonId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const note = await LessonNote.findOne({
      studentId: toId(req.user.id),
      lessonId: req.params.lessonId,
    }).lean();

    if (!note) {
      return res.json({ success: true, note: null });
    }

    res.json({ success: true, note });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/lesson-notes — create or update note
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, moduleId, lessonId, content } = req.body;

    if (!lessonId || !courseId || !moduleId) {
      return res.status(400).json({
        success: false,
        message: 'courseId, moduleId, and lessonId are required'
      });
    }

    // Upsert: update if exists, create if not
    const note = await LessonNote.findOneAndUpdate(
      { studentId: toId(req.user.id), lessonId },
      {
        studentId: toId(req.user.id),
        courseId: toId(courseId),
        moduleId,
        lessonId,
        content: content || '',
        lastEditedAt: new Date(),
      },
      { upsert: true, new: true }
    );

    res.json({ success: true, note });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/lesson-notes/course/:courseId — get all notes for a course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const notes = await LessonNote.find({
      studentId: toId(req.user.id),
      courseId: toId(req.params.courseId),
    }).lean();

    res.json({ success: true, notes, count: notes.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /api/lesson-notes/:lessonId — delete note
router.delete('/:lessonId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await LessonNote.findOneAndDelete({
      studentId: toId(req.user.id),
      lessonId: req.params.lessonId,
    });

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
