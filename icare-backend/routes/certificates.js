const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const Certificate = require('../models/Certificate');
const Enrollment = require('../models/Enrollment');
const Course = require('../models/Course');
const User = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// GET /api/certificates/pending/:courseId — instructor sees pending approvals
router.get('/pending/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const certs = await Certificate.find({ courseId: toId(req.params.courseId), approvalStatus: 'pending' })
      .sort({ createdAt: -1 }).lean();
    res.json({ success: true, certificates: certs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /api/certificates/:id/approve — Lead Instructor approves/rejects a certificate
router.put('/:id/approve', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { action, note } = req.body; // action: 'approve' | 'reject'
    if (!['approve', 'reject'].includes(action)) return res.status(400).json({ success: false, message: 'action must be approve or reject' });

    const cert = await Certificate.findByIdAndUpdate(
      toId(req.params.id),
      {
        approvalStatus: action === 'approve' ? 'approved' : 'rejected',
        approvedBy: req.user.id,
        approvedAt: new Date(),
        approvalNote: note || '',
      },
      { new: true }
    ).lean();

    if (!cert) return res.status(404).json({ success: false, message: 'Not found' });

    // Notify student
    if (action === 'approve') {
      const Notification = require('../models/Notification');
      await Notification.create({
        userId: cert.studentId,
        type: 'general',
        title: 'Certificate Approved!',
        message: `Your certificate for "${cert.courseName}" has been approved.`,
        data: { courseId: cert.courseId, certificateId: cert._id },
      }).catch(() => {});
    }

    res.json({ success: true, certificate: cert });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/certificates — Issue certificate when student completes course
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { enrollmentId, courseId, studentId, template } = req.body;

    let enrollment;

    if (enrollmentId) {
      enrollment = await Enrollment.findById(toId(enrollmentId))
        .populate('userId', 'name username email')
        .populate('courseId')
        .lean();
    } else if (courseId && studentId) {
      // Find enrollment by courseId + studentId
      enrollment = await Enrollment.findOne({
        courseId: toId(courseId),
        userId: toId(studentId),
      })
        .populate('userId', 'name username email')
        .populate('courseId')
        .lean();
    }

    if (!enrollment) {
      return res.status(404).json({ success: false, message: 'Enrollment not found' });
    }

    const course = enrollment.courseId;
    const student = enrollment.userId;

    if (!course || !student) {
      return res.status(422).json({ success: false, message: 'Course or student data missing in enrollment' });
    }

    // Get instructor name
    const instructor = await User.findById(course.instructor_id).lean();
    const instructorName = instructor?.name || instructor?.username || 'Instructor';

    // Check if certificate already exists (use enrollment._id which is always available)
    const existing = await Certificate.findOne({
      $or: [
        { enrollmentId: enrollment._id },
        { studentId: student._id, courseId: course._id },
      ],
    }).lean();

    if (existing) {
      return res.json({ success: true, certificate: existing, message: 'Certificate already issued' });
    }

    // Generate certificate
    const certNumber = `ICARE-${new Date().getFullYear()}-${Math.floor(100000 + Math.random() * 900000)}`;
    const verificationCode = Math.random().toString(36).substring(2, 15).toUpperCase();
    const qrCodeData = `https://icare-app-ten.vercel.app/verify?code=${verificationCode}`;

    // Courses that require manual approval start in 'pending' status
    const requiresApproval = course.requiresCertificateApproval === true;

    const certificate = await Certificate.create({
      enrollmentId: enrollment._id,
      studentId: student._id,
      courseId: course._id,
      certificateNumber: certNumber,
      verificationCode,
      studentName: student.name || student.username,
      courseName: course.title,
      instructorName,
      completionDate: enrollment.progress?.completedAt || new Date(),
      template: template || 'classic',
      qrCodeData,
      approvalStatus: requiresApproval ? 'pending' : 'approved',
    });

    res.json({ success: true, certificate });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/certificates/verify/:code — Verify certificate by QR code
router.get('/verify/:code', async (req, res) => {
  try {
    await connectMongoDB();
    const code = req.params.code;
    const certificate = await Certificate.findOne({
      $or: [
        { verificationCode: code },
        { verificationCode: code.toUpperCase() },
        { certificateNumber: code },
        { certificateNumber: code.toUpperCase() },
      ],
    }).lean();

    if (!certificate) {
      return res.status(404).json({
        success: false,
        message: 'Certificate not found',
        valid: false,
      });
    }

    // Update verification tracking
    await Certificate.findByIdAndUpdate(certificate._id, {
      $inc: { verificationCount: 1 },
      lastVerifiedAt: new Date(),
    });

    res.json({
      success: true,
      valid: true,
      message: 'Certificate is authentic',
      certificate: {
        certificateId: certificate.certificateNumber,
        studentName: certificate.studentName,
        courseName: certificate.courseName,
        instructorName: certificate.instructorName,
        completionDate: certificate.completionDate,
        issuedAt: certificate.issuedAt,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/certificates/my — Get my certificates
router.get('/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const certificates = await Certificate.find({
      studentId: toId(req.user.id),
    }).sort({ issuedAt: -1 }).lean();

    res.json({ success: true, certificates, count: certificates.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/certificates/course/:courseId — Get certificates for a course (instructor)
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const certificates = await Certificate.find({
      courseId: toId(req.params.courseId),
    }).sort({ issuedAt: -1 }).lean();

    res.json({ success: true, certificates, count: certificates.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
