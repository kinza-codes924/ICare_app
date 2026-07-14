const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const LabProfile = require('../models/LabProfile');
const LabTestRequest = require('../models/LabTestRequest');
const { authMiddleware } = require('../middleware/auth');
const { sendToUser } = require('../services/notificationService');
const { sendEmail } = require('../utils/email');

const _reportUpload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

function _uploadToCloudinary(buffer, folder, resourceType = 'image') {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: resourceType },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });
}

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

function _labReportEmailHtml({ patientName, testName, dateStr, reportUrl, reportPageUrl, reportNotes }) {
  return `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;background:#f8fafc;">
  <div style="background:#0B2D6E;padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">
    <h2 style="color:#fff;margin:0;font-size:22px;">🔬 Lab Report Ready</h2>
    <p style="color:rgba(255,255,255,0.75);margin:6px 0 0;font-size:14px;">Your test results are now available</p>
  </div>
  <div style="background:#fff;padding:32px;border-radius:0 0 12px 12px;box-shadow:0 4px 20px rgba(0,0,0,0.06);">
    <p style="color:#374151;font-size:15px;margin:0 0 6px;">Dear <strong>${patientName}</strong>,</p>
    <p style="color:#374151;font-size:14px;line-height:1.6;margin:0 0 20px;">Your <strong>${testName}</strong> results are ready. Please find the details below.</p>

    <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 20px;">
      <tr>
        <td width="50%" style="padding:12px;background:#EFF6FF;border:1px solid #DBEAFE;border-radius:6px;vertical-align:top;">
          <p style="margin:0 0 4px;color:#1e40af;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;">Patient</p>
          <p style="margin:0;color:#0f172a;font-size:14px;font-weight:600;">${patientName}</p>
        </td>
        <td width="4%" style="padding:0;"> </td>
        <td width="46%" style="padding:12px;background:#EFF6FF;border:1px solid #DBEAFE;border-radius:6px;vertical-align:top;">
          <p style="margin:0 0 4px;color:#1e40af;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;">Date</p>
          <p style="margin:0;color:#0f172a;font-size:14px;font-weight:600;">${dateStr}</p>
        </td>
      </tr>
    </table>

    <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 20px;border:1px solid #DBEAFE;border-radius:8px;overflow:hidden;">
      <tr style="background:#EFF6FF;">
        <td style="padding:12px 16px;color:#1e40af;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;" colspan="2">Test Details</td>
      </tr>
      <tr style="background:#fff;">
        <td style="padding:10px 16px;color:#64748b;font-size:13px;width:35%;">Test Name</td>
        <td style="padding:10px 16px;color:#0f172a;font-size:13px;font-weight:600;">${testName}</td>
      </tr>
      <tr style="background:#f8fafc;">
        <td style="padding:10px 16px;color:#64748b;font-size:13px;">Report Date</td>
        <td style="padding:10px 16px;color:#0f172a;font-size:13px;font-weight:600;">${dateStr}</td>
      </tr>
      <tr style="background:#fff;">
        <td style="padding:10px 16px;color:#64748b;font-size:13px;">Status</td>
        <td style="padding:10px 16px;"><span style="background:#DCFCE7;color:#166534;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:700;">Results Ready ✅</span></td>
      </tr>
    </table>

    ${reportNotes ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 20px;border-left:4px solid #0B2D6E;border-radius:4px;background:#f8fafc;"><tr><td style="padding:14px 18px;"><p style="margin:0 0 4px;color:#64748b;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;">Lab Notes</p><p style="margin:0;color:#374151;font-size:14px;">${reportNotes}</p></td></tr></table>` : ''}

    <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px;">
      <tr>
        ${reportUrl ? `<td style="padding:0 6px 0 0;"><a href="${reportUrl}" style="display:block;background:#0B2D6E;color:#fff;padding:13px 0;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;text-align:center;">📄 Download PDF Report</a></td>` : ''}
        <td style="padding:0 0 0 ${reportUrl ? '6px' : '0'};"><a href="${reportPageUrl}" style="display:block;background:#fff;color:#0B2D6E;padding:12px 0;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;text-align:center;border:2px solid #0B2D6E;">🔬 View Full Report</a></td>
      </tr>
    </table>
    <p style="color:#94a3b8;font-size:12px;text-align:center;margin:8px 0 20px;">Click "View Full Report" to open a printable lab report — save it as PDF from your browser.</p>

    <p style="color:#64748b;font-size:13px;margin:0 0 4px;">You can also view your report anytime in the <strong>iCare app</strong> under Lab Reports.</p>
    <hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">
    <p style="color:#94a3b8;font-size:12px;text-align:center;margin:0;">iCare Healthcare Platform &nbsp;|&nbsp; <a href="https://www.icare.com.co" style="color:#0B2D6E;text-decoration:none;">www.icare.com.co</a></p>
  </div>
</div>`;
}

// ─── HAVERSINE DISTANCE (km) ──────────────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─── GET ALL LABS ─────────────────────────────────────────────────────────────
async function getAllLabs() {
  await connectMongoDB();
  const users = await User.find({ role: { $in: ['lab', 'Lab', 'laboratory', 'Laboratory'] }, is_active: { $ne: false } }).lean();
  const ids = users.map(u => u._id);
  const profiles = await LabProfile.find({ user_id: { $in: ids } }).lean();
  const pMap = {};
  profiles.forEach(p => { pMap[p.user_id.toString()] = p; });

  return users.map(u => {
    const p = pMap[u._id.toString()] || {};
    return {
      id: u._id.toString(), _id: u._id.toString(),
      name: u.username || u.name, email: u.email, phone: u.phone,
      lab_name: p.lab_name, license_number: p.license_number,
      accreditation: p.accreditation, services: p.services,
      operating_hours: p.operating_hours, address: p.address, city: p.city,
      latitude: p.latitude ?? null, longitude: p.longitude ?? null,
      lat: p.latitude ?? null, lng: p.longitude ?? null,
      drap_compliance: p.drap_compliance, createdAt: u.createdAt,
      homeSample: p.home_sample ?? true,
      home_sample: p.home_sample ?? true,
      rating: p.rating ?? 0, total_reviews: p.total_reviews ?? 0,
      availableTests: p.availableTests || p.available_tests || [],
      description: p.description || '',
      homeSampleAvailable: p.homeSampleAvailable ?? p.home_sample ?? true,
      workingHours: p.workingHours || p.operating_hours || '8AM - 10PM',
    };
  });
}

router.get('/', async (req, res) => {
  try {
    const labs = await getAllLabs();
    res.json({ success: true, labs, laboratories: labs });
  } catch (error) {
    console.error(error);
    res.json({ success: true, labs: [], laboratories: [] });
  }
});

router.get('/get_all_laboratories', async (req, res) => {
  try {
    const labs = await getAllLabs();
    res.json({ success: true, laboratories: labs, labs });
  } catch (error) {
    console.error(error);
    res.json({ success: true, laboratories: [], labs: [] });
  }
});

// ─── GET NEARBY LABS ──────────────────────────────────────────────────────────
// GET /laboratories/nearby?lat=31.5&lng=74.3&radius=20
router.get('/nearby', async (req, res) => {
  try {
    await connectMongoDB();
    const userLat = parseFloat(req.query.lat);
    const userLng = parseFloat(req.query.lng);
    const radius = parseFloat(req.query.radius) || 20;

    if (isNaN(userLat) || isNaN(userLng)) {
      return res.status(400).json({ success: false, message: 'lat and lng are required' });
    }

    const allLabs = await getAllLabs();
    const labs = allLabs
      .map(l => {
        const distance = (l.latitude != null && l.longitude != null)
          ? haversineKm(userLat, userLng, l.latitude, l.longitude)
          : null;
        return { ...l, distance_km: distance };
      })
      .filter(l => l.distance_km === null || l.distance_km <= radius)
      .sort((a, b) => {
        if (a.distance_km === null) return 1;
        if (b.distance_km === null) return -1;
        return a.distance_km - b.distance_km;
      });

    res.json({ success: true, laboratories: labs, labs, count: labs.length });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to fetch nearby labs' });
  }
});

// ─── LAB PROFILE ──────────────────────────────────────────────────────────────
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    console.log('🔍 LAB PROFILE - User ID:', userId);
    
    const user = await User.findById(userId).lean();
    console.log('🔍 LAB PROFILE - User found:', user?.username || user?.name);
    
    const profile = await LabProfile.findOne({ user_id: userId }).lean() || {};
    console.log('🔍 LAB PROFILE - Profile found:', profile.lab_name);

    const lab = {
      id: user._id.toString(), _id: user._id.toString(),
      username: user.username || user.name, email: user.email, phone: user.phone,
      profilePicture: user.profilePicture || null,
      ...profile,
      // Re-assert user._id AFTER spread so profile._id never overrides it
      _id: user._id.toString(),
      id: user._id.toString(),
      user_id: undefined,
    };
    
    console.log('✅ LAB PROFILE - Returning lab with _id:', lab._id);
    res.json({ success: true, laboratory: lab, profile: lab });
  } catch (error) {
    console.error('❌ LAB PROFILE - Error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch profile' });
  }
});

router.post('/add_laboratory_details', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const {
      labName, lab_name, licenseNumber, license_number,
      accreditation, services, operatingHours, operating_hours,
      address, city, drapCompliance, drap_compliance,
      latitude, longitude,
      ownerName, labEmail, labPhoneNumber, description, title,
      homeSampleAvailable, workingHours, doctors, collectors,
    } = req.body;

    const update = {};
    const finalLabName = labName || lab_name;
    if (finalLabName) update.lab_name = finalLabName;
    if (licenseNumber || license_number) update.license_number = licenseNumber || license_number;
    if (accreditation !== undefined) update.accreditation = accreditation;
    if (services !== undefined) update.services = services;
    const hours = operatingHours || operating_hours;
    if (hours) update.operating_hours = hours;
    if (address !== undefined) update.address = address;
    if (city !== undefined) update.city = city;
    const drapVal = drapCompliance ?? drap_compliance;
    if (drapVal !== undefined) update.drap_compliance = drapVal;
    if (latitude != null) update.latitude = parseFloat(latitude);
    if (longitude != null) update.longitude = parseFloat(longitude);
    if (ownerName !== undefined) update.ownerName = ownerName;
    if (labEmail !== undefined) update.labEmail = labEmail;
    if (labPhoneNumber !== undefined) update.labPhoneNumber = labPhoneNumber;
    if (description !== undefined) update.description = description;
    if (title !== undefined) update.title = title;
    if (homeSampleAvailable !== undefined) update.homeSampleAvailable = homeSampleAvailable;
    if (workingHours !== undefined) update.workingHours = workingHours;
    if (doctors !== undefined) update.doctors = doctors;
    if (collectors !== undefined) update.collectors = collectors;
    const { documents, availableTests } = req.body;
    if (documents !== undefined) update.documents = documents;
    if (availableTests !== undefined) update.availableTests = availableTests;

    const profile = await LabProfile.findOneAndUpdate(
      { user_id: userId },
      { $set: update },
      { new: true, upsert: true }
    );

    // Save profilePicture and lab name to User model so auth state reflects it
    const { profilePicture } = req.body;
    const userUpdate = {};
    if (profilePicture !== undefined) userUpdate.profilePicture = profilePicture;
    if (finalLabName) { userUpdate.name = finalLabName; userUpdate.username = finalLabName; }
    if (Object.keys(userUpdate).length > 0) {
      await User.findByIdAndUpdate(userId, { $set: userUpdate });
    }

    const result = { ...profile.toObject(), _id: profile._id.toString() };
    res.json({ success: true, message: 'Lab profile saved', laboratory: result, existingProfile: result });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to save lab profile' });
  }
});

router.put('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'lab') {
      return res.status(403).json({ success: false, message: 'Only labs can update lab profiles' });
    }
    const userId = toId(req.user.id);
    const { labName, licenseNumber, accreditation, services, operatingHours, address, city, drapCompliance } = req.body;

    const update = {};
    if (labName) update.lab_name = labName;
    if (licenseNumber) update.license_number = licenseNumber;
    if (accreditation !== undefined) update.accreditation = accreditation;
    if (services !== undefined) update.services = services;
    if (operatingHours) update.operating_hours = operatingHours;
    if (address !== undefined) update.address = address;
    if (city !== undefined) update.city = city;
    if (drapCompliance !== undefined) update.drap_compliance = drapCompliance;

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    const profile = await LabProfile.findOneAndUpdate(
      { user_id: userId },
      { $set: update },
      { new: true, upsert: true }
    );

    res.json({ success: true, message: 'Lab profile updated', profile });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to update lab profile' });
  }
});

// ─── STATS ────────────────────────────────────────────────────────────────────
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [total, pending, completed, todayCount, completedDocs] = await Promise.all([
      LabTestRequest.countDocuments({ lab_id: userId }),
      LabTestRequest.countDocuments({ lab_id: userId, status: { $in: ['pending'] } }),
      LabTestRequest.countDocuments({ lab_id: userId, status: { $in: ['completed', 'reporting_done', 'reporting-done'] } }),
      LabTestRequest.countDocuments({ lab_id: userId, createdAt: { $gte: today } }),
      LabTestRequest.find({ lab_id: userId, status: { $in: ['completed', 'reporting_done', 'reporting-done'] } }, { total_amount: 1, price: 1 }).lean(),
    ]);

    const revenue = completedDocs.reduce((sum, r) => sum + (r.total_amount || r.price || 0), 0);
    res.json({ success: true, stats: { todayRequests: todayCount, totalRequests: total, pendingRequests: pending, completedRequests: completed, revenue: Math.round(revenue) } });
  } catch (error) {
    console.error(error);
    res.json({ success: true, stats: { todayRequests: 0, totalRequests: 0, pendingRequests: 0, completedRequests: 0, revenue: 0 } });
  }
});

// ─── BOOKINGS ─────────────────────────────────────────────────────────────────
router.get('/bookings/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const [bookings, authUser] = await Promise.all([
      LabTestRequest.find({ patient_id: userId }).sort({ createdAt: -1 }).lean(),
      User.findById(userId).lean(),
    ]);
    const authPatientName = authUser?.name || authUser?.username || '';

    const labIds = [...new Set(bookings.map(b => b.lab_id?.toString()).filter(Boolean))];
    const labs = labIds.length > 0 ? await User.find({ _id: { $in: labIds.map(id => toId(id)) } }).lean() : [];
    const labProfiles = labIds.length > 0 ? await LabProfile.find({ user_id: { $in: labIds.map(id => toId(id)) } }).lean() : [];
    const lMap = {};
    labs.forEach(l => { lMap[l._id.toString()] = l; });
    const lpMap = {};
    labProfiles.forEach(p => { lpMap[p.user_id.toString()] = p; });

    const result = bookings.map(b => {
      const resolvedName = b.patient_name_override || authPatientName || 'Patient';
      return {
        ...b,
        _id: b._id.toString(),
        patientName: resolvedName,
        patient_name: resolvedName,
        // camelCase aliases for Flutter
        prescriptionId: b.prescription_id?.toString() || b.medical_record_id?.toString() || null,
        medicalRecordId: b.prescription_id?.toString() || b.medical_record_id?.toString() || null,
        testName: b.test_type,
        testType: b.test_type,
        date: b.test_date,
        reportUrl: b.report_url,
        reportNotes: b.report_notes,
        bookingNumber: b._id.toString().slice(-6).toUpperCase(),
        isAbnormal: b.is_abnormal || false,
        criticalAlert: b.critical_alert || false,
        laboratory: {
          _id: lMap[b.lab_id?.toString()]?._id?.toString(),
          labName: lpMap[b.lab_id?.toString()]?.lab_name || lMap[b.lab_id?.toString()]?.username || lMap[b.lab_id?.toString()]?.name || 'Laboratory',
          city: lpMap[b.lab_id?.toString()]?.city || '',
        },
      };
    });
    res.json({ success: true, bookings: result });
  } catch (error) {
    console.error(error);
    res.json({ success: true, bookings: [] });
  }
});

router.get('/bookings/:bookingId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const booking = await LabTestRequest.findOne({
      _id: toId(req.params.bookingId),
      $or: [{ patient_id: userId }, { lab_id: userId }],
    }).lean();

    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

    const [patient, lab, labProfile] = await Promise.all([
      User.findById(booking.patient_id).lean(),
      User.findById(booking.lab_id).lean(),
      LabProfile.findOne({ user_id: booking.lab_id }).lean(),
    ]);

    res.json({
      success: true,
      booking: {
        ...booking,
        _id: booking._id.toString(),
        patient_name: patient?.username || patient?.name,
        patient_email: patient?.email,
        lab_username: lab?.username || lab?.name,
        lab_name: labProfile?.lab_name,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to fetch booking' });
  }
});

router.put('/bookings/:bookingId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    let { status, results, testDate, date, reportNotes, reportUrl, approvedByDoctor, sampleCollectedBy } = req.body;

    // Normalize status: accept both underscore and hyphen variants
    // Store with underscore for consistency
    if (status) {
      status = status.replace(/-/g, '_');
    }

    const update = {};
    if (status) update.status = status;
    if (results) update.results = results;
    if (testDate || date) update.test_date = testDate || date;
    if (reportNotes !== undefined) update.report_notes = reportNotes;
    if (reportUrl) update.report_url = reportUrl;
    if (approvedByDoctor !== undefined) update.approvedByDoctor = approvedByDoctor;
    if (sampleCollectedBy !== undefined) update.sampleCollectedBy = sampleCollectedBy;

    // Auto-set status to reporting_done when results are submitted without explicit status
    if (results && !status) {
      update.status = 'reporting_done';
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    // ── Payment gate: no sample collection / processing / results until the
    //    payment has cleared (card paid or cash marked collected). Only
    //    applies to bookings that went through the payment flow
    //    (paymentMethod set) — legacy and lab walk-in bookings are exempt.
    const GATED_STATUSES = ['sample_collected', 'processing', 'awaiting_reports', 'reporting_done', 'completed'];
    if (update.status && GATED_STATUSES.includes(update.status)) {
      const existing = await LabTestRequest.findById(toId(req.params.bookingId))
        .select('paymentStatus paymentMethod price').lean();
      const price = Number(existing?.price) || 0;
      if (price > 0 && existing?.paymentMethod && existing?.paymentStatus !== 'paid') {
        const hint = existing.paymentMethod === 'cash'
          ? 'Mark the cash as collected first.'
          : 'The patient has not completed the online payment yet.';
        return res.status(402).json({
          success: false,
          code: 'PAYMENT_REQUIRED',
          message: `Payment pending — ${hint}`,
        });
      }
    }

    const booking = await LabTestRequest.findOneAndUpdate(
      { _id: toId(req.params.bookingId), $or: [{ patient_id: userId }, { lab_id: userId }] },
      { $set: update },
      { new: true }
    );

    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found or access denied' });

    // ── Notify patient when results are ready ─────────────────────────────────────
    if ((update.status === 'reporting_done' || update.status === 'completed') && booking.patient_id) {
      const testName = booking.test_type || 'Lab Test';
      sendToUser(booking.patient_id, {
        title: '🔬 Lab Results Ready',
        body: `Your ${testName} results are now available. Tap to view your report.`,
        data: { bookingId: booking._id.toString(), type: 'lab_result' },
        type: 'system_alert',
      }).catch(() => {});

      // ── Email patient with lab report ────────────────────────────────────────
      try {
        const patientUser = await User.findById(booking.patient_id).select('email name username').lean();
        const patientEmail = booking.patient_email || patientUser?.email;
        if (patientEmail) {
          const rUrl = booking.report_url || update.report_url;
          const rNotes = booking.report_notes || update.report_notes || '';
          const patientName = patientUser?.name || patientUser?.username || 'Patient';
          const dateStr = new Date().toLocaleDateString('en-PK', { day: 'numeric', month: 'long', year: 'numeric' });
          const reportPageUrl = `https://icare-backend-inky.vercel.app/api/labs/report/${booking._id}`;
          await sendEmail({
            to: patientEmail,
            subject: `iCare — Your ${testName} Report is Ready`,
            html: _labReportEmailHtml({ patientName, testName, dateStr, reportUrl: rUrl, reportPageUrl, reportNotes: rNotes }),
          });
        }
      } catch (emailErr) { console.error('[Lab] Email error:', emailErr.message); }
    }
    // ── Award gamification points to patient on lab test completion ─────────────
    if ((update.status === 'completed' || update.status === 'reporting_done') && booking.patient_id) {
      try {
        const User = require('../models/User');
        const pat = await User.findById(booking.patient_id);
        if (pat && pat.role === 'Patient') {
          if (!pat.gamification) pat.gamification = { points: 0, stats: {}, history: [] };
          pat.gamification.points = (pat.gamification.points || 0) + 15;
          pat.gamification.stats = pat.gamification.stats || {};
          pat.gamification.stats.completedLabTests = (pat.gamification.stats.completedLabTests || 0) + 1;
          pat.gamification.history = pat.gamification.history || [];
          pat.gamification.history.push({ points: 15, reason: 'complete_lab_test', date: new Date().toISOString() });
          pat.markModified('gamification');
          await pat.save();
        }
      } catch (_) {}
    }
    // ── Notify referring doctor when results are submitted ────────────────────────
    if ((update.status === 'reporting_done' || update.status === 'completed') && booking.doctor_id) {
      const testName = booking.test_type || 'Lab Test';
      sendToUser(booking.doctor_id, {
        title: '📋 Lab Results Available',
        body: `${testName} results for your patient are ready. Tap to review.`,
        data: { bookingId: booking._id.toString(), type: 'lab_result' },
        type: 'doctor_message',
      }).catch(() => {});
    }

    res.json({ 
      success: true, 
      message: 'Booking updated', 
      booking: { 
        ...booking.toObject(), 
        _id: booking._id.toString(),
        status: booking.status?.replace(/-/g, '_') ?? booking.status,
      } 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to update booking' });
  }
});

router.get('/:labId/bookings', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const labId = toId(req.params.labId);
    const { status } = req.query;

    // Normalize status filter: accept both underscore and hyphen variants
    const normalizeStatus = (s) => s?.replace(/_/g, '-');
    const denormalizeStatus = (s) => s?.replace(/-/g, '_');

    const query = { lab_id: labId };
    if (status && status !== 'all') {
      // Support comma-separated statuses AND normalize underscore/hyphen
      const statuses = status.split(',').map(s => s.trim()).filter(Boolean);
      const normalized = [];
      statuses.forEach(s => {
        normalized.push(s);
        const alt = s.includes('_') ? s.replace(/_/g, '-') : s.replace(/-/g, '_');
        if (alt !== s) normalized.push(alt);
      });
      query.status = normalized.length === 1 ? normalized[0] : { $in: normalized };
    }

    console.log('🔍 LAB BOOKINGS FETCH - Lab ID:', labId);
    console.log('🔍 LAB BOOKINGS FETCH - Query:', JSON.stringify(query));

    const bookings = await LabTestRequest.find(query).sort({ createdAt: -1 }).lean();
    console.log('✅ LAB BOOKINGS FETCH - Found', bookings.length, 'bookings');

    const patientIds = [...new Set(bookings.map(b => b.patient_id?.toString()).filter(Boolean))];
    const patients = await User.find({ _id: { $in: patientIds.map(id => toId(id)) } }).lean();
    const pMap = {};
    patients.forEach(p => { pMap[p._id.toString()] = p; });

    const result = bookings.map(b => {
      const pid = b.patient_id?.toString();
      const pUser = pid ? pMap[pid] : null;
      // Walk-in override takes priority so the actual patient name is always correct
      const resolvedName = b.patient_name_override ||
        (pUser?.name && pUser.name.trim() ? pUser.name.trim() : null) ||
        (pUser?.username && pUser.username.trim() ? pUser.username.trim() : null) ||
        b.contact || '';
      return {
      ...b,
      _id: b._id.toString(),
      // Normalize status to underscore for Flutter consistency
      status: b.status?.replace(/-/g, '_')?.toLowerCase() ?? b.status,
      patient_name: resolvedName,
      patientName: resolvedName,
      patient_email: pUser?.email,
      patient_phone: b.patient_phone || b.contact || pUser?.phone,
      patient_age: b.patient_age || null,
      patient_gender: b.patient_gender || null,
      patient_address: b.patient_address || null,
      // camelCase aliases for Flutter
      testName: b.test_type,
      testType: b.test_type,
      date: b.test_date,
      reportNotes: b.report_notes,
      reportUrl: b.report_url,
      bookingNumber: b._id.toString().slice(-6).toUpperCase(),
      isAbnormal: b.is_abnormal || false,
      // Include urgency fields
      urgency: b.urgency || 'Normal',
      is_urgent: b.is_urgent || b.urgency === 'Urgent' || false,
      collectionType: b.collection_type || 'in-lab',
      collection_type: b.collection_type || 'in-lab',
    };});
    res.json({ success: true, bookings: result });
  } catch (error) {
    console.error('❌ LAB BOOKINGS FETCH - Error:', error);
    res.json({ success: true, bookings: [] });
  }
});

router.post('/:labId/bookings', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const patientId = toId(req.user.id);
    const labId = toId(req.params.labId);
    const { testType, test_type, testDate, date, notes } = req.body;
    const finalTest = testType || test_type;
    
    console.log('🔍 LAB BOOKING - Patient ID:', patientId);
    console.log('🔍 LAB BOOKING - Lab ID from URL:', labId);
    console.log('🔍 LAB BOOKING - Test type:', finalTest);
    console.log('🔍 LAB BOOKING - Request body:', req.body);
    
    if (!finalTest) return res.status(400).json({ success: false, message: 'Test type is required' });

    // Calculate price: Rs. 3000 per test
    const testCount = finalTest.split(',').filter(t => t.trim()).length;
    const price = testCount * 3000;

    const { urgency, is_urgent, collectionType, collection_type, turnaroundTime, source, patientName, patient_name, contact, address,
      patientAge, patient_age, patientGender, patient_gender, patientPhone, patient_phone, patientAddress, patient_address,
      mrNumber, referredBy, prescriptionDate, specimenIds, sampleCollectedBy,
      prescriptionId, medicalRecordId, preferred_time, preferredTime } = req.body;
    const finalPreferredTime = preferredTime || preferred_time || null;

    const finalPrescriptionId = prescriptionId || medicalRecordId || null;

    const booking = await LabTestRequest.create({
      patient_id: patientId,
      lab_id: labId,
      test_type: finalTest,
      test_date: testDate || date || null,
      price: price,
      status: 'pending',
      urgency: urgency || (is_urgent ? 'Urgent' : 'Normal'),
      is_urgent: is_urgent || urgency === 'Urgent' || false,
      collection_type: collectionType || collection_type || 'in-lab',
      turnaround_time: turnaroundTime || null,
      source: finalPrescriptionId ? 'prescription' : (source || 'online'),
      patient_name_override: patientName || patient_name || null,
      patient_age: patientAge || patient_age || null,
      patient_gender: patientGender || patient_gender || null,
      patient_phone: patientPhone || patient_phone || contact || null,
      patient_address: patientAddress || patient_address || address || null,
      ...(mrNumber ? { mrNumber } : {}),
      ...(referredBy ? { referredBy } : {}),
      ...(prescriptionDate ? { prescriptionDate } : {}),
      ...(specimenIds ? { specimenIds } : {}),
      ...(sampleCollectedBy ? { sampleCollectedBy } : {}),
      ...(finalPrescriptionId ? { medical_record_id: finalPrescriptionId } : {}),
      ...(finalPreferredTime ? { preferred_time: finalPreferredTime } : {}),
    });

    console.log('✅ LAB BOOKING - Created booking:', booking._id.toString());
    console.log('✅ LAB BOOKING - Booking lab_id:', booking.lab_id.toString());
    console.log('✅ LAB BOOKING - Booking patient_id:', booking.patient_id.toString());

    // Fetch patient info to include in response
    const patient = await User.findById(patientId).lean();
    const patientNameFromDB = patient?.username || patient?.name || 'Unknown';

    res.status(201).json({
      success: true,
      message: 'Booking created',
      booking: {
        ...booking.toObject(),
        _id: booking._id.toString(),
        patient_name: patientNameFromDB,
        patient_email: patient?.email,
      }
    });
  } catch (error) {
    console.error('❌ LAB BOOKING - Error:', error);
    res.status(500).json({ success: false, message: 'Failed to create booking' });
  }
});

// Analytics stub
router.all('/:labId/analytics/:metric', authMiddleware, async (req, res) => {
  res.json({ success: true, analytics: {}, metrics: {}, trends: [], performance: [], revenue: {}, analysis: {}, comparison: {}, stats: {} });
});

// ─── REQUESTS (legacy) ────────────────────────────────────────────────────────
router.get('/requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const query = req.user.role === 'lab' ? { lab_id: userId } : { patient_id: userId };
    const requests = await LabTestRequest.find(query).sort({ createdAt: -1 }).lean();
    const result = requests.map(r => ({ ...r, _id: r._id.toString() }));
    res.json({ success: true, requests: result, bookings: result });
  } catch (error) {
    console.error(error);
    res.json({ success: true, requests: [], bookings: [] });
  }
});

router.post('/requests', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const patientId = toId(req.user.id);
    const { labId, lab_id, testType, test_type, testDate, date } = req.body;
    const finalLab = toId(labId || lab_id);
    const finalTest = testType || test_type;
    if (!finalLab || !finalTest) {
      return res.status(400).json({ success: false, message: 'Lab and test type are required' });
    }
    const request = await LabTestRequest.create({ patient_id: patientId, lab_id: finalLab, test_type: finalTest, test_date: testDate || date || null, status: 'pending' });
    res.status(201).json({ success: true, message: 'Lab test request created', request: { ...request.toObject(), _id: request._id.toString() } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to create lab request' });
  }
});

router.put('/requests/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { status, results } = req.body;
    const update = {};
    if (status) update.status = status;
    if (results) update.results = results;

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    const request = await LabTestRequest.findOneAndUpdate(
      { _id: toId(req.params.id), $or: [{ patient_id: userId }, { lab_id: userId }] },
      { $set: update },
      { new: true }
    );

    if (!request) return res.status(404).json({ success: false, message: 'Request not found or access denied' });
    res.json({ success: true, message: 'Request updated', request: { ...request.toObject(), _id: request._id.toString() } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to update request' });
  }
});

// ─── RATE BOOKING ─────────────────────────────────────────────────────────────
router.post('/bookings/:bookingId/rate', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { rating, comment } = req.body;
    const booking = await LabTestRequest.findByIdAndUpdate(
      toId(req.params.bookingId),
      { $set: { rating: Number(rating) || 0, ratingComment: comment || '', ratedAt: new Date() } },
      { new: true }
    );
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
    // Recalculate lab average rating
    try {
      const labUserId = booking.labId || booking.lab_id;
      if (labUserId) {
        const ratedBookings = await LabTestRequest.find({
          $or: [{ labId: labUserId }, { lab_id: labUserId }],
          rating: { $gt: 0 }
        }).lean();
        if (ratedBookings.length > 0) {
          const avg = ratedBookings.reduce((s, b) => s + (b.rating || 0), 0) / ratedBookings.length;
          await LabProfile.findOneAndUpdate(
            { user_id: labUserId },
            { $set: { rating: Math.round(avg * 10) / 10, total_reviews: ratedBookings.length } },
            { upsert: false }
          );
        }
      }
    } catch (_) {}
    res.json({ success: true, message: 'Rating submitted', booking: { ...booking.toObject(), _id: booking._id.toString() } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to submit rating' });
  }
});

// ─── UPLOAD REPORT ────────────────────────────────────────────────────────────
router.post('/bookings/:bookingId/upload-report', authMiddleware, _reportUpload.single('report'), async (req, res) => {
  try {
    await connectMongoDB();
    let reportUrl = (req.body && req.body.reportUrl) || null;
    const reportNotes = (req.body && req.body.reportNotes) || '';

    // If a file was uploaded, push it to Cloudinary and get a persistent URL
    if (req.file) {
      const isPdf = req.file.mimetype === 'application/pdf';
      const resourceType = isPdf ? 'raw' : 'image';
      const result = await _uploadToCloudinary(req.file.buffer, 'icare/lab-reports', resourceType);
      reportUrl = result.secure_url;
    }

    const booking = await LabTestRequest.findByIdAndUpdate(
      toId(req.params.bookingId),
      { $set: { ...(reportUrl ? { report_url: reportUrl } : {}), report_notes: reportNotes, status: 'reporting_done' } },
      { new: true }
    );
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

    // Notify patient of uploaded report
    if (booking.patient_id) {
      const testName = booking.test_type || 'Lab Test';
      sendToUser(booking.patient_id, {
        title: '🔬 Lab Report Ready',
        body: `Your ${testName} report has been uploaded. Tap to view.`,
        data: { bookingId: booking._id.toString(), type: 'lab_result' },
        type: 'system_alert',
      }).catch(() => {});

      // Email patient with report download link
      try {
        const patientUser = await User.findById(booking.patient_id).select('email name username').lean();
        const patientEmail = booking.patient_email || patientUser?.email;
        if (patientEmail) {
          const testName = booking.test_type || 'Lab Test';
          const patientName = patientUser?.name || patientUser?.username || 'Patient';
          const dateStr = new Date().toLocaleDateString('en-PK', { day: 'numeric', month: 'long', year: 'numeric' });
          const reportPageUrl = `https://icare-backend-inky.vercel.app/api/labs/report/${booking._id}`;
          await sendEmail({
            to: patientEmail,
            subject: `iCare — Your ${testName} Report is Ready`,
            html: _labReportEmailHtml({ patientName, testName, dateStr, reportUrl, reportPageUrl, reportNotes: booking.report_notes || '' }),
          });
        }
      } catch (emailErr) { console.error('[Lab] Upload-report email error:', emailErr.message); }
    }
    if (booking.doctor_id) {
      const testName = booking.test_type || 'Lab Test';
      sendToUser(booking.doctor_id, {
        title: '📋 Lab Report Uploaded',
        body: `${testName} report for your patient is now available.`,
        data: { bookingId: booking._id.toString(), type: 'lab_result' },
        type: 'doctor_message',
      }).catch(() => {});
    }

    res.json({ success: true, message: 'Report uploaded', reportUrl, booking: { ...booking.toObject(), _id: booking._id.toString() } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to upload report' });
  }
});

// ─── PRINTABLE LAB REPORT PAGE (public, no auth) ─────────────────────────────
router.get('/report/:bookingId', async (req, res) => {
  try {
    await connectMongoDB();
    const booking = await LabTestRequest.findById(toId(req.params.bookingId)).lean();
    if (!booking) return res.status(404).send('<h2>Report not found</h2>');

    const [patientUser, labUser, labProfile] = await Promise.all([
      User.findById(booking.patient_id).select('name username phone email').lean().catch(() => null),
      User.findById(booking.lab_id).select('name username').lean().catch(() => null),
      LabProfile.findOne({ user_id: booking.lab_id }).lean().catch(() => null),
    ]);

    const patientName = booking.patient_name_override || patientUser?.name || patientUser?.username || 'Patient';
    const patientPhone = booking.patient_phone || patientUser?.phone || '—';
    const labName = labProfile?.lab_name || labUser?.username || labUser?.name || 'iCare Laboratory';
    const bookingNum = booking._id.toString().slice(-6).toUpperCase();
    const dateObj = booking.test_date ? new Date(booking.test_date) : new Date(booking.createdAt);
    const dateStr = dateObj.toLocaleDateString('en-PK', { day: 'numeric', month: 'long', year: 'numeric' });
    const testName = booking.test_type || 'Lab Test';
    const testList = testName.split(',').map(t => t.trim()).filter(Boolean);
    const results = Array.isArray(booking.results) ? booking.results : [];
    const notes = booking.report_notes || '';
    const doctors = Array.isArray(labProfile?.doctors) ? labProfile.doctors.filter(d => d.name) : [];
    const sampleCollectedBy = booking.sampleCollectedBy || '';

    const testsHtml = testList.map((t, i) => `
      <tr>
        <td style="padding:10px 14px;border-bottom:1px solid #f1f5f9;width:36px;">
          <span style="display:inline-block;background:#0B2D6E;color:#fff;width:22px;height:22px;border-radius:3px;text-align:center;line-height:22px;font-size:11px;font-weight:700;">${i + 1}</span>
        </td>
        <td style="padding:10px 14px;border-bottom:1px solid #f1f5f9;font-size:14px;font-weight:600;color:#0f172a;">${t}</td>
      </tr>`).join('');

    const resultsHtml = results.length > 0 ? `
      <div class="section">
        <h3>TEST RESULTS</h3>
        <table>
          <thead><tr>
            <th>TEST PARAMETER</th>
            <th>RESULT</th>
            <th>UNIT</th>
            <th>REFERENCE RANGE</th>
          </tr></thead>
          <tbody>
            ${results.map((r, i) => {
              const isAbn = r.isAbnormal || r.is_abnormal || r.abnormal;
              return `<tr style="background:${i % 2 === 0 ? '#fafafa' : '#fff'}">
                <td style="padding:9px 12px;border-bottom:1px solid #f1f5f9;">${r.testParameter || r.parameter || '—'}</td>
                <td style="padding:9px 12px;border-bottom:1px solid #f1f5f9;font-weight:700;color:${isAbn ? '#DC2626' : '#0f172a'};">${r.value || '—'}</td>
                <td style="padding:9px 12px;border-bottom:1px solid #f1f5f9;color:#64748b;">${r.unit || '—'}</td>
                <td style="padding:9px 12px;border-bottom:1px solid #f1f5f9;color:#64748b;font-size:12px;">${r.referenceRange || r.reference_range || '—'}</td>
              </tr>`;
            }).join('')}
          </tbody>
        </table>
        <p style="color:#64748b;font-size:12px;margin:8px 0 0;"><span style="color:#DC2626;font-weight:700;">■</span> Values outside reference range are flagged in red</p>
      </div>` : `
      <div style="background:#FFFBEB;border:1px solid #FDE68A;border-radius:8px;padding:14px 18px;margin:0 0 24px;font-size:13px;color:#92400E;">
        ⚠️ Detailed test results will be updated by the laboratory. Please contact the laboratory for individual parameter values.
      </div>`;

    const doctorsHtml = doctors.length > 0 ? `
      <div class="section">
        <h3>VERIFIED BY</h3>
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr>${doctors.map(d => `
            <td style="padding:0 8px 0 0;vertical-align:top;">
              <div style="border:1px solid #e2e8f0;border-radius:8px;padding:12px;">
                <p style="margin:0;font-weight:700;font-size:14px;color:#0f172a;">${d.name || ''}</p>
                ${d.designation ? `<p style="margin:3px 0 0;font-size:12px;color:#64748b;">${d.designation}</p>` : ''}
                ${d.education ? `<p style="margin:2px 0 0;font-size:12px;color:#64748b;">${d.education}</p>` : ''}
              </div>
            </td>`).join('')}
          </tr>
        </table>
      </div>` : '';

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>iCare — Lab Report ${bookingNum}</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:Arial,sans-serif;background:#f8fafc;padding:24px;color:#1f2937}
    .wrap{max-width:760px;margin:0 auto;background:#fff;border-radius:12px;box-shadow:0 4px 24px rgba(0,0,0,0.08);overflow:hidden}
    .hdr{padding:24px 32px;border-bottom:3px solid #0B2D6E;}
    .hdr-inner{display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:16px}
    .brand-name{font-size:26px;font-weight:900;color:#0B2D6E;letter-spacing:-0.5px}
    .brand-sub{font-size:11px;color:#64748b;margin-top:2px}
    .badge{background:#0B2D6E;color:#fff;padding:5px 14px;border-radius:4px;font-size:11px;font-weight:700;letter-spacing:.5px;display:inline-block;margin-bottom:6px}
    .report-meta p{font-size:11px;color:#64748b;margin:2px 0}
    .body{padding:28px 32px}
    .info-grid{display:table;width:100%;margin-bottom:24px}
    .info-col{display:table-cell;width:50%;vertical-align:top;padding:14px;background:#EFF6FF;border:1px solid #DBEAFE;border-radius:8px}
    .info-col:first-child{margin-right:12px}
    .info-label{font-size:9px;font-weight:700;color:#1e40af;text-transform:uppercase;letter-spacing:.8px;margin-bottom:8px}
    .info-row{display:flex;margin-bottom:5px}
    .info-key{width:100px;flex-shrink:0;font-size:11px;color:#64748b;font-weight:600}
    .info-val{font-size:11px;color:#0f172a}
    .section{margin-bottom:24px}
    .section h3{font-size:9px;font-weight:800;color:#0B2D6E;text-transform:uppercase;letter-spacing:.8px;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #EFF6FF}
    table{width:100%;border-collapse:collapse;font-size:13px}
    thead tr{background:#0B2D6E}
    th{padding:9px 12px;text-align:left;color:#fff;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.5px}
    .ftr{border-top:1px solid #e2e8f0;padding:16px 32px;background:#f8fafc}
    .ftr p{font-size:11px;color:#64748b;margin:3px 0}
    .print-btn{display:block;margin:24px auto;padding:12px 40px;background:#0B2D6E;color:#fff;border:none;border-radius:8px;font-size:15px;font-weight:700;cursor:pointer}
    @media print{.print-btn{display:none}body{background:#fff;padding:0}.wrap{box-shadow:none;border-radius:0}}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hdr">
      <div class="hdr-inner">
        <div>
          <div class="brand-name">iCare</div>
          <div class="brand-sub">Your Trusted Healthcare Platform</div>
        </div>
        <div class="report-meta" style="text-align:right">
          <span class="badge">LABORATORY REPORT</span>
          <p>Report No: <strong>${bookingNum}</strong></p>
          <p>Date: ${dateStr}</p>
        </div>
      </div>
    </div>

    <div class="body">
      <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
        <tr>
          <td style="vertical-align:top;padding:14px;background:#EFF6FF;border:1px solid #DBEAFE;border-radius:8px;width:48%;">
            <p style="font-size:9px;font-weight:700;color:#1e40af;text-transform:uppercase;letter-spacing:.8px;margin:0 0 8px;">Patient Information</p>
            <p style="font-size:11px;margin:3px 0;color:#0f172a;"><strong>Name:</strong> ${patientName}</p>
            <p style="font-size:11px;margin:3px 0;color:#0f172a;"><strong>Phone:</strong> ${patientPhone}</p>
            ${sampleCollectedBy ? `<p style="font-size:11px;margin:3px 0;color:#0f172a;"><strong>Collected By:</strong> ${sampleCollectedBy}</p>` : ''}
          </td>
          <td style="width:4%;"></td>
          <td style="vertical-align:top;padding:14px;background:#EFF6FF;border:1px solid #DBEAFE;border-radius:8px;width:48%;">
            <p style="font-size:9px;font-weight:700;color:#1e40af;text-transform:uppercase;letter-spacing:.8px;margin:0 0 8px;">Laboratory Information</p>
            <p style="font-size:11px;margin:3px 0;color:#0f172a;"><strong>Lab:</strong> ${labName}</p>
            <p style="font-size:11px;margin:3px 0;color:#0f172a;"><strong>Report Date:</strong> ${dateStr}</p>
          </td>
        </tr>
      </table>

      <div class="section">
        <h3>Tests Ordered</h3>
        <table><tbody>${testsHtml}</tbody></table>
      </div>

      ${resultsHtml}

      ${notes ? `<div class="section"><h3>Remarks / Notes</h3><div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:14px 18px;font-size:13px;line-height:1.6;color:#374151;">${notes}</div></div>` : ''}

      ${doctorsHtml}

      ${booking.report_url ? `<div style="text-align:center;margin:0 0 24px;"><a href="${booking.report_url}" style="display:inline-block;background:#0B2D6E;color:#fff;padding:12px 32px;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;">📄 Download Uploaded PDF Report</a></div>` : ''}

      <button class="print-btn" onclick="window.print()">🖨️ Print / Save as PDF</button>
    </div>

    <div class="ftr">
      ${sampleCollectedBy ? `<p>Sample Collected By: ${sampleCollectedBy}</p>` : ''}
      <p>This is an electronically generated report. | Processed by: ${labName}</p>
      <p style="font-weight:700;color:#0B2D6E;">Powered by iCare &nbsp;|&nbsp; www.icare.com.co</p>
    </div>
  </div>
</body>
</html>`;
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } catch (e) {
    console.error('[Lab] Report page error:', e.message);
    res.status(500).send('<h2>Error loading report</h2>');
  }
});

// ─── GET LAB BY ID (public) — MUST BE LAST to avoid matching /profile, /nearby etc.
router.get('/:labId', async (req, res) => {
  try {
    await connectMongoDB();
    const labId = toId(req.params.labId);
    if (!labId) {
      return res.status(400).json({ success: false, message: 'Invalid lab ID' });
    }

    const user = await User.findById(labId).lean();
    if (!user) {
      return res.status(404).json({ success: false, message: 'Lab not found' });
    }

    const profile = await LabProfile.findOne({ user_id: labId }).lean() || {};

    let availableTests = profile.available_tests || profile.availableTests || [];
    if (!availableTests || availableTests.length === 0) {
      availableTests = [
        { _id: 'cbc', name: 'Complete Blood Count (CBC)', price: 800 },
        { _id: 'lft', name: 'Liver Function Test (LFT)', price: 1500 },
        { _id: 'kft', name: 'Kidney Function Test (KFT)', price: 1200 },
        { _id: 'tsh', name: 'Thyroid Stimulating Hormone (TSH)', price: 1800 },
        { _id: 'hba1c', name: 'HbA1c (Glycated Hemoglobin)', price: 1400 },
        { _id: 'lipid', name: 'Lipid Profile', price: 1600 },
        { _id: 'urine', name: 'Urine Complete Examination', price: 600 },
        { _id: 'bs_fasting', name: 'Blood Sugar Fasting', price: 400 },
        { _id: 'bs_random', name: 'Blood Sugar Random', price: 400 },
        { _id: 'xray', name: 'Chest X-Ray', price: 1000 },
        { _id: 'ecg', name: 'ECG (Electrocardiogram)', price: 800 },
        { _id: 'dengue', name: 'Dengue NS1 Antigen', price: 2000 },
        { _id: 'covid', name: 'COVID-19 PCR Test', price: 3500 },
        { _id: 'hepatitis_b', name: 'Hepatitis B Surface Antigen', price: 1200 },
        { _id: 'hepatitis_c', name: 'Hepatitis C Antibody', price: 1200 },
      ];
    }

    const laboratory = {
      _id: user._id.toString(),
      id: user._id.toString(),
      name: profile.lab_name || user.username || user.name || 'Laboratory',
      labName: profile.lab_name || user.username || user.name || 'Laboratory',
      email: user.email,
      phone: user.phone,
      address: profile.address || 'Address not available',
      city: profile.city || '',
      latitude: profile.latitude || null,
      longitude: profile.longitude || null,
      operating_hours: profile.operating_hours || '8AM - 10PM',
      home_sample: profile.home_sample ?? true,
      homeSample: profile.home_sample ?? true,
      accreditation: profile.accreditation || '',
      availableTests,
    };

    res.json({ success: true, laboratory });
  } catch (error) {
    console.error('Get lab by ID error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch lab details' });
  }
});

module.exports = router;
