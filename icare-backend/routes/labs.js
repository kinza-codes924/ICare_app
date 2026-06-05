const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const LabProfile = require('../models/LabProfile');
const LabTestRequest = require('../models/LabTestRequest');
const { authMiddleware } = require('../middleware/auth');
const { sendToUser } = require('../services/notificationService');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
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

    // Save profilePicture to User model
    const { profilePicture } = req.body;
    if (profilePicture !== undefined) {
      await User.findByIdAndUpdate(userId, { $set: { profilePicture } });
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
    const bookings = await LabTestRequest.find({ patient_id: userId }).sort({ createdAt: -1 }).lean();
    const labIds = [...new Set(bookings.map(b => b.lab_id.toString()))];
    const labs = await User.find({ _id: { $in: labIds.map(id => toId(id)) } }).lean();
    const labProfiles = await LabProfile.find({ user_id: { $in: labIds.map(id => toId(id)) } }).lean();
    const lMap = {};
    labs.forEach(l => { lMap[l._id.toString()] = l; });
    const lpMap = {};
    labProfiles.forEach(p => { lpMap[p.user_id.toString()] = p; });

    const result = bookings.map(b => ({
      ...b,
      _id: b._id.toString(),
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
        _id: lMap[b.lab_id.toString()]?._id?.toString(),
        labName: lpMap[b.lab_id.toString()]?.lab_name || lMap[b.lab_id.toString()]?.username || lMap[b.lab_id.toString()]?.name || 'Laboratory',
        city: lpMap[b.lab_id.toString()]?.city || '',
      },
    }));
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
    let { status, results, testDate, date, reportNotes, reportUrl } = req.body;
    
    // Normalize status: accept both underscore and hyphen variants
    // Store with underscore for consistency
    if (status) {
      status = status.replace(/-/g, '_');
    }
    
    const update = {};
    if (status) update.status = status;
    if (results) update.results = results;
    if (testDate || date) update.test_date = testDate || date;
    if (reportNotes) update.report_notes = reportNotes;
    if (reportUrl) update.report_url = reportUrl;

    // Auto-set status to reporting_done when results are submitted without explicit status
    if (results && !status) {
      update.status = 'reporting_done';
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
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
      const resolvedName = b.patient_name_override || pUser?.username || pUser?.name || 'Unknown';
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
      mrNumber, referredBy, prescriptionDate, specimenIds, sampleCollectedBy } = req.body;

    const booking = await LabTestRequest.create({
      patient_id: patientId,
      lab_id: labId,
      test_type: finalTest,
      test_date: testDate || date || null,
      price: price,
      status: req.body.status || 'pending',
      urgency: urgency || (is_urgent ? 'Urgent' : 'Normal'),
      is_urgent: is_urgent || urgency === 'Urgent' || false,
      collection_type: collectionType || collection_type || 'in-lab',
      turnaround_time: turnaroundTime || null,
      source: source || 'online',
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
router.post('/bookings/:bookingId/upload-report', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { reportUrl, reportNotes } = req.body;
    const booking = await LabTestRequest.findByIdAndUpdate(
      toId(req.params.bookingId),
      { $set: { report_url: reportUrl, report_notes: reportNotes || '', status: 'reporting_done' } },
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
