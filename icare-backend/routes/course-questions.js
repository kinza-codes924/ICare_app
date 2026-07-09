const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const CourseQuestion = require('../models/CourseQuestion');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// GET /api/course-questions/course/:courseId — get all questions for a course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const questions = await CourseQuestion.find({ courseId: toId(req.params.courseId) })
      .sort({ createdAt: -1 })
      .lean();
    res.json({ success: true, questions, count: questions.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/course-questions/ask — post a new question
router.post('/ask', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, question } = req.body;
    if (!courseId || !question) {
      return res.status(400).json({ success: false, message: 'courseId and question are required' });
    }
    const q = await CourseQuestion.create({
      courseId: toId(courseId),
      userId: toId(req.user.id),
      question,
    });
    res.status(201).json({ success: true, question: q });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /api/course-questions/:id/answer — instructor answers a question
router.put('/:id/answer', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { answer } = req.body;
    if (!answer) return res.status(400).json({ success: false, message: 'answer is required' });
    const q = await CourseQuestion.findByIdAndUpdate(
      toId(req.params.id),
      { $set: { answer, answeredBy: toId(req.user.id), answeredAt: new Date(), isAnswered: true } },
      { new: true },
    );
    if (!q) return res.status(404).json({ success: false, message: 'Question not found' });
    res.json({ success: true, question: q });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/course-questions/unanswered — get unanswered questions (instructor)
router.get('/unanswered', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const questions = await CourseQuestion.find({ isAnswered: false }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, questions, count: questions.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /api/course-questions/:id
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await CourseQuestion.findByIdAndDelete(toId(req.params.id));
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
