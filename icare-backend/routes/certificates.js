const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const Certificate = require('../models/Certificate');
const Enrollment = require('../models/Enrollment');
const Course = require('../models/Course');
const User = require('../models/User');
const { sendEmail } = require('../utils/email');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// Only the course owner (instructor_id) or a co-teacher explicitly marked
// role: 'lead' may issue/approve certificates. Normal instructors are blocked.
async function assertLeadInstructor(courseId, userId) {
  const course = await Course.findById(courseId).select('instructor_id coTeachers').lean();
  if (!course) return { ok: false, status: 404, message: 'Course not found' };
  const uid = userId.toString();
  if (course.instructor_id?.toString() === uid) return { ok: true, course };
  const coTeacher = (course.coTeachers || []).find(t => t.userId?.toString() === uid);
  const isLeadRole = (coTeacher?.role || '').toLowerCase() === 'lead' || (coTeacher?.role || '').toLowerCase() === 'lead instructor';
  if (isLeadRole && (coTeacher.status ?? 'accepted') === 'accepted') return { ok: true, course };
  return { ok: false, status: 403, message: 'Only the Lead Instructor can issue or approve certificates' };
}

// GET /api/certificates/ready/:courseId — Lead Instructor sees students who
// finished every module but don't have a Certificate document yet (nobody
// has hit "Issue Certificate" for them). Distinct from /pending, which is
// for certificates that already exist and are awaiting approval.
router.get('/ready/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const perm = await assertLeadInstructor(req.params.courseId, req.user.id);
    if (!perm.ok) return res.status(perm.status).json({ success: false, message: perm.message });

    const completedEnrollments = await Enrollment.find({
      courseId: toId(req.params.courseId),
      isCompleted: true,
    }).populate('userId', 'name username email').lean();

    const existingCerts = await Certificate.find({ courseId: toId(req.params.courseId) }).select('studentId enrollmentId').lean();
    const certifiedStudentIds = new Set(existingCerts.map(c => c.studentId?.toString()));

    const ready = completedEnrollments
      .filter(e => !certifiedStudentIds.has(e.userId?._id?.toString()))
      .map(e => ({
        enrollmentId: e._id,
        studentId: e.userId?._id,
        studentName: e.userId?.name || e.userId?.username || 'Student',
        completedAt: e.completedAt,
      }));

    res.json({ success: true, ready });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

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

    const existingCert = await Certificate.findById(toId(req.params.id)).select('courseId').lean();
    if (!existingCert) return res.status(404).json({ success: false, message: 'Not found' });
    const perm = await assertLeadInstructor(existingCert.courseId, req.user.id);
    if (!perm.ok) return res.status(perm.status).json({ success: false, message: perm.message });

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

    const perm = await assertLeadInstructor(course._id, req.user.id);
    if (!perm.ok) return res.status(perm.status).json({ success: false, message: perm.message });

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
    const qrCodeData = `https://www.icare.com.co/verify?code=${verificationCode}`;

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

    // Tell the student their certificate exists — previously this route only
    // created the Certificate doc, so a student had no way to know one was
    // ready short of manually checking My Certificates. Only notify here for
    // the instant-approved case; the 'pending' case is notified by the
    // /:id/approve route once actually approved, not at issue time.
    if (certificate.approvalStatus === 'approved') {
      const Notification = require('../models/Notification');
      await Notification.create({
        userId: student._id,
        type: 'general',
        title: 'Certificate Ready!',
        message: `Your certificate for "${course.title}" is ready. Check My Certificates.`,
        data: { type: 'certificate_issued', courseId: course._id, certificateId: certificate._id },
      }).catch(() => {});

      if (student.email) {
        sendEmail({
          to: student.email,
          subject: `Your certificate for ${course.title} is ready`,
          html: `<p>Hi ${student.name || 'there'},</p>
                 <p>Congratulations on completing <b>${course.title}</b>! Your certificate is now available in your iCare account under <b>My Certificates</b>.</p>
                 <p>— iCare Team</p>`,
        }).catch(e => console.error('Certificate-ready email failed:', e.message));
      }
    }

    res.json({ success: true, certificate });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/certificates/register — register a client-generated certificate code
// The Flutter app generates the PDF (with QR code) locally; this saves the code
// so /verify/:code can authenticate it later.
router.post('/register', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const {
      verificationCode, enrollmentId, courseId,
      studentName, courseName, instructorName, completionDate, template,
    } = req.body;
    if (!verificationCode) {
      return res.status(400).json({ success: false, message: 'verificationCode required' });
    }

    // Already registered → idempotent success
    const existing = await Certificate.findOne({ verificationCode }).lean();
    if (existing) return res.json({ success: true, certificate: existing, message: 'Already registered' });

    if (courseId) {
      const isLead = (await assertLeadInstructor(toId(courseId), req.user.id)).ok;
      if (!isLead) {
        // Not the lead instructor — this must be the enrolled student
        // registering their own completed-course certificate. Require the
        // instructor to have actually released it (and, if there's an
        // enrollment on record, that it's marked complete) so a stray call
        // to this endpoint can't manufacture a certificate for an
        // in-progress course.
        const course = await Course.findById(toId(courseId)).select('certificateReleased').lean();
        if (!course || course.certificateReleased !== true) {
          return res.status(403).json({ success: false, message: 'Certificate has not been released for this course yet' });
        }
        if (enrollmentId) {
          const enrollment = await Enrollment.findById(toId(enrollmentId)).select('progress.completed userId').lean();
          if (enrollment && enrollment.userId?.toString() !== req.user.id?.toString()) {
            return res.status(403).json({ success: false, message: 'Not your enrollment' });
          }
          if (enrollment && enrollment.progress?.completed !== true) {
            return res.status(403).json({ success: false, message: 'Course not yet completed' });
          }
        }
      }
    }

    const certNumber = `ICARE-${new Date().getFullYear()}-${Math.floor(100000 + Math.random() * 900000)}`;
    const certificate = await Certificate.create({
      enrollmentId: toId(enrollmentId) || new mongoose.Types.ObjectId(),
      studentId: toId(req.user.id),
      courseId: toId(courseId) || new mongoose.Types.ObjectId(),
      certificateNumber: certNumber,
      verificationCode,
      studentName: studentName || 'Student',
      courseName: courseName || 'Course',
      instructorName: instructorName || 'Instructor',
      completionDate: completionDate ? new Date(completionDate) : new Date(),
      template: template || 'classic',
      qrCodeData: `https://www.icare.com.co/verify?code=${verificationCode}`,
      approvalStatus: 'approved',
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

// GET /api/certificates/my — Get my certificates (approved only — a student
// shouldn't see a certificate count/tile before their course is actually
// complete and the certificate has cleared approval)
router.get('/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const certificates = await Certificate.find({
      studentId: toId(req.user.id),
      approvalStatus: 'approved',
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
