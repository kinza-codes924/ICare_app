const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const InstructorProfile = require('../models/InstructorProfile');
const Course = require('../models/Course');
const Precaution = require('../models/Precaution');
const Enrollment = require('../models/Enrollment');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ── STATS ────────────────────────────────────────────────────────────────────
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructorId = toId(req.user.id);
    if (!instructorId) return res.status(400).json({ success: false, message: 'Invalid user' });
    const [totalCourses, totalPrecautions, courseList] = await Promise.all([
      Course.countDocuments({ instructor_id: instructorId, is_active: true }),
      Precaution.countDocuments({ instructor_id: instructorId, is_active: true }),
      Course.find({ instructor_id: instructorId }).select('assigned_to rating').lean(),
    ]);
    const totalStudents = new Set(courseList.flatMap(c => c.assigned_to.map(String))).size;
    const ratings = courseList.filter(c => c.rating > 0).map(c => c.rating);
    const avgRating = ratings.length ? (ratings.reduce((a, b) => a + b, 0) / ratings.length).toFixed(1) : 0;
    res.json({ success: true, stats: { totalCourses, totalStudents, avgRating: parseFloat(avgRating), totalPrecautions } });
  } catch (e) {
    console.error('Stats error:', e);
    res.status(500).json({ success: false, message: 'Failed to get stats' });
  }
});

// ── PROFILE ──────────────────────────────────────────────────────────────────
router.get('/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const user = await User.findById(userId).lean();
    let profile = await InstructorProfile.findOne({ user_id: userId }).lean();
    if (!profile) profile = await InstructorProfile.create({ user_id: userId });
    res.json({
      success: true,
      instructor: {
        _id: profile._id.toString(),
        user_id: userId.toString(),
        name: user?.name || user?.username || '',
        email: user?.email || '',
        profilePicture: user?.profilePicture || null,
        ...profile,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/add_instructor_details', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const update = {};
    const fields = ['bio', 'specialization', 'experience_years', 'profile_image', 'qualification', 'experience', 'gender', 'age', 'address', 'specialties', 'languages', 'availabilityDays', 'availabilityTime'];
    fields.forEach(f => { if (req.body[f] !== undefined) update[f] = req.body[f]; });
    const profile = await InstructorProfile.findOneAndUpdate({ user_id: userId }, { $set: update }, { new: true, upsert: true });
    // Save profilePicture and name to User model
    const userUpdate = {};
    if (req.body.profilePicture !== undefined) userUpdate.profilePicture = req.body.profilePicture;
    if (req.body.name) { userUpdate.name = req.body.name; userUpdate.username = req.body.name; }
    if (Object.keys(userUpdate).length > 0) await User.findByIdAndUpdate(userId, { $set: userUpdate });
    res.json({ success: true, instructor: profile });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.get('/get_all_instructors', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructors = await InstructorProfile.find().lean();
    const userIds = instructors.map(i => i.user_id);
    const users = await User.find({ _id: { $in: userIds } }).lean();
    const userMap = {};
    users.forEach(u => { userMap[u._id.toString()] = u; });
    const result = instructors.map(p => {
      const u = userMap[p.user_id.toString()] || {};
      return { _id: p._id.toString(), user_id: p.user_id.toString(), name: u.name || u.username || '', email: u.email || '', ...p };
    });
    res.json({ success: true, instructors: result });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── MY COURSES (token-based, no query param needed) ──────────────────────────
router.get('/my-courses', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructorId = toId(req.user.id);
    if (!instructorId) return res.status(400).json({ success: false, message: 'Invalid user id in token' });
    const courses = await Course.find({
      is_active: { $ne: false },
      $or: [
        { instructor_id: instructorId },
        // Only surface co-taught courses the invite was actually accepted
        // for — a pending invite shouldn't grant a "My Courses" entry
        // before the invited teacher has accepted it. status doesn't exist
        // on co-teacher entries added before this field was introduced, so
        // treat "no status field" as accepted too (grandfathered in).
        { coTeachers: { $elemMatch: { userId: instructorId, status: { $in: ['accepted', null] } } } },
        { coTeachers: { $elemMatch: { userId: instructorId, status: { $exists: false } } } },
      ],
    }).lean();
    // Tag co-taught courses so the frontend can distinguish them
    const userId = instructorId.toString();

    // Real enrolled-student counts (Course docs don't store this field)
    const counts = await Enrollment.aggregate([
      { $match: { courseId: { $in: courses.map(c => c._id) } } },
      { $group: { _id: '$courseId', count: { $sum: 1 } } },
    ]);
    const countMap = {};
    counts.forEach(c => { countMap[c._id.toString()] = c.count; });

    const tagged = courses.map(c => ({
      ...c,
      isCoTeacher: c.instructor_id?.toString() !== userId,
      enrolledCount: countMap[c._id.toString()] || 0,
    }));
    res.json({ success: true, courses: tagged, count: tagged.length });
  } catch (e) {
    console.error('GET /my-courses error:', e.message, e.name);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── COURSES ──────────────────────────────────────────────────────────────────
router.get('/courses', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const filter = { is_active: true };
    // instructorId can be user_id (ObjectId) — validate before using
    if (req.query.instructorId) {
      const id = toId(req.query.instructorId);
      if (!id) return res.status(400).json({ success: false, message: 'Invalid instructorId' });
      filter.instructor_id = id;
    }
    if (req.query.q) filter.title = { $regex: req.query.q, $options: 'i' };
    if (req.query.visibility) filter.visibility = req.query.visibility;
    const courses = await Course.find(filter).lean();
    res.json({ success: true, courses, count: courses.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/courses', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const data = { ...req.body, instructor_id: toId(req.user.id) };
    if (data.isPublished === true) data.visibility = 'public';
    if (!data.visibility) data.visibility = 'private';
    // Sync thumbnail fields
    if (data.thumbnail && !data.thumbnail_url) data.thumbnail_url = data.thumbnail;
    if (data.thumbnail_url && !data.thumbnail) data.thumbnail = data.thumbnail_url;
    // Sanitize modules to avoid schema validation errors
    if (Array.isArray(data.modules)) {
      data.modules = data.modules.map((m, mi) => ({
        title: m.title || `Module ${mi + 1}`,
        description: m.description || '',
        order: m.order ?? mi,
        lessons: Array.isArray(m.lessons) ? m.lessons.map((l, li) => ({
          title: l.title || `Lesson ${li + 1}`,
          content: l.content || '',
          videoUrl: l.videoUrl || l.video_url || '',
          duration: Number(l.duration || l.duration_minutes || 0),
          order: l.order ?? li,
          resources: Array.isArray(l.resources) ? l.resources : [],
        })) : [],
        quiz: m.quiz || null,
      }));
    }
    const course = await Course.create(data);
    res.status(201).json({ success: true, course });
  } catch (e) {
    console.error('POST /instructors/courses error:', e.message, e.name, e.stack);
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/courses/assign', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, targetUserId } = req.body;
    const course = await Course.findByIdAndUpdate(
      toId(courseId),
      { $addToSet: { assigned_to: toId(targetUserId) } },
      { new: true }
    );
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.get('/courses/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/courses/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const update = { ...req.body };
    // Keep visibility and isPublished in sync
    if (update.visibility === 'public') update.isPublished = true;
    if (update.visibility === 'private') update.isPublished = false;
    if (update.isPublished === true) update.visibility = 'public';
    if (update.isPublished === false && !update.visibility) update.visibility = 'private';
    const course = await Course.findByIdAndUpdate(toId(req.params.id), { $set: update }, { new: true });
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/courses/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Course.findByIdAndUpdate(toId(req.params.id), { is_active: false });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── PRECAUTIONS ───────────────────────────────────────────────────────────────
router.get('/precautions', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const filter = { is_active: true };
    if (req.query.instructorId) filter.instructor_id = toId(req.query.instructorId);
    const precautions = await Precaution.find(filter).lean();
    res.json({ success: true, precautions, count: precautions.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/precautions', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const p = await Precaution.create({ ...req.body, instructor_id: toId(req.user.id) });
    res.status(201).json({ success: true, precaution: p });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.get('/precautions/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const p = await Precaution.findById(toId(req.params.id)).lean();
    if (!p) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, precaution: p });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/precautions/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const p = await Precaution.findByIdAndUpdate(toId(req.params.id), { $set: req.body }, { new: true });
    if (!p) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, precaution: p });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/precautions/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Precaution.findByIdAndUpdate(toId(req.params.id), { is_active: false });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── VIDEO / THUMBNAIL URL STORE (no file upload — URL-based) ─────────────────
// POST /api/instructors/videos/upload  { videoUrl: "https://..." }
router.post('/videos/upload', authMiddleware, async (req, res) => {
  try {
    const { videoUrl } = req.body;
    if (!videoUrl) {
      return res.status(400).json({ success: false, message: 'videoUrl is required' });
    }
    // Just return the URL back — no storage needed, URL is saved in lesson
    return res.json({ success: true, videoUrl });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/instructors/thumbnails/upload  { thumbnailUrl: "https://..." }
router.post('/thumbnails/upload', authMiddleware, async (req, res) => {
  try {
    const { thumbnailUrl } = req.body;
    if (!thumbnailUrl) {
      return res.status(400).json({ success: false, message: 'thumbnailUrl is required' });
    }
    return res.json({ success: true, thumbnailUrl });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ASSIGNED LEARNERS ─────────────────────────────────────────────────────────
router.get('/assigned-learners', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructorId = toId(req.user.id);
    const courses = await Course.find({ instructor_id: instructorId, is_active: true }).select('title assigned_to').lean();
    const allUserIds = [...new Set(courses.flatMap(c => c.assigned_to.map(String)))];
    const users = await User.find({ _id: { $in: allUserIds.map(toId) } }).select('username name email role').lean();
    const learners = users.map(u => ({
      _id: u._id.toString(),
      name: u.name || u.username,
      email: u.email,
      role: u.role,
      enrolledCourses: courses.filter(c => c.assigned_to.map(String).includes(u._id.toString())).map(c => ({ _id: c._id.toString(), title: c.title })),
    }));
    res.json({ success: true, learners, count: learners.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── GET INSTRUCTOR BY ID (must be last to avoid matching named routes) ──────
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const id = toId(req.params.id);
    if (!id) return res.status(400).json({ success: false, message: 'Invalid ID' });
    const profile = await InstructorProfile.findById(id).lean();
    if (!profile) return res.status(404).json({ success: false, message: 'Not found' });
    const user = await User.findById(profile.user_id).lean() || {};
    res.json({ success: true, instructor: { _id: profile._id.toString(), name: user.name || user.username || '', email: user.email || '', ...profile } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
