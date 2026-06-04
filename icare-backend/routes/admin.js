const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const PharmacyOrder = require('../models/PharmacyOrder');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

function isNoReferrerReason(raw) {
  if (raw == null) return false;
  const n = String(raw).toLowerCase().replace(/[_-]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (!n) return false;
  return n === 'no referrer' || n.includes('no referrer');
}

// Admin-only middleware
function adminOnly(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ success: false, message: 'Admin access required' });
  }
  next();
}

// ─── ENSURE ADMIN EXISTS (called on startup) ──────────────────────────────────
async function ensureAdminExists() {
  try {
    await connectMongoDB();
    const existing = await User.findOne({ email: 'admin@icare.com' });
    if (!existing) {
      const hashed = await bcrypt.hash('adminPassword123', 10);
      await User.create({
        username: 'Admin',
        name: 'Admin',
        email: 'admin@icare.com',
        password: hashed,
        role: 'admin',
        is_approved: true,
        is_active: true,
      });
      console.log('✅ Admin user created: admin@icare.com');
    } else if (existing.role !== 'admin') {
      await User.findByIdAndUpdate(existing._id, { $set: { role: 'admin', is_active: true, is_approved: true } });
      console.log('✅ Existing user promoted to admin: admin@icare.com');
    }
  } catch (err) {
    console.error('⚠️  ensureAdminExists error:', err.message);
  }
}

// Run on first request, not at module load (Vercel serverless safe)
let adminEnsured = false;
const ensureAdminMiddleware = async (req, res, next) => {
  if (!adminEnsured) {
    adminEnsured = true;
    await ensureAdminExists();
  }
  next();
};
router.use(ensureAdminMiddleware);

// ─── PENDING USERS ────────────────────────────────────────────────────────────
// GET /api/admin/pending-users
router.get('/pending-users', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const users = await User.find({
      is_approved: false,
      role: { $nin: ['admin', 'patient'] },
    }).select('-password').lean();

    const result = users.map(u => ({
      _id: u._id.toString(),
      name: u.name || u.username || '',
      email: u.email || '',
      role: u.role || '',
      phone: u.phone || '',
      createdAt: u.createdAt,
    }));

    res.json({ success: true, users: result, count: result.length, pendingUsers: result });
  } catch (err) {
    console.error('pending-users error:', err);
    res.json({ success: true, users: [], count: 0, pendingUsers: [] });
  }
});

// ─── APPROVED USERS ───────────────────────────────────────────────────────────
// GET /api/admin/approved-users?role=Doctor
router.get('/approved-users', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { role } = req.query;

    const query = { is_approved: { $ne: false }, is_active: { $ne: false } };
    if (role) {
      // Case-insensitive role match
      query.role = { $regex: new RegExp(`^${role}$`, 'i') };
    }

    const users = await User.find(query).select('-password').lean();
    const result = users.map(u => ({
      _id: u._id.toString(),
      name: u.name || u.username || '',
      email: u.email || '',
      role: u.role || '',
      phone: u.phone || '',
      createdAt: u.createdAt,
      isApproved: true,
    }));

    res.json({ success: true, users: result, count: result.length });
  } catch (err) {
    console.error('approved-users error:', err);
    res.json({ success: true, users: [], count: 0 });
  }
});

// ─── ALL USERS ────────────────────────────────────────────────────────────────
router.get('/users', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { role, status } = req.query;
    const query = {};
    if (role) query.role = { $regex: new RegExp(`^${role}$`, 'i') };
    if (status === 'pending') query.is_approved = false;
    if (status === 'approved') query.is_approved = { $ne: false };

    const users = await User.find(query).select('-password').lean();
    const result = users.map(u => ({
      _id: u._id.toString(),
      name: u.name || u.username || '',
      email: u.email || '',
      role: u.role || '',
      phone: u.phone || '',
      createdAt: u.createdAt,
      isApproved: u.is_approved !== false,
      isActive: u.is_active !== false,
    }));

    res.json({ success: true, users: result, count: result.length });
  } catch (err) {
    console.error('admin users error:', err);
    res.json({ success: true, users: [], count: 0 });
  }
});

// ─── APPROVE USER ─────────────────────────────────────────────────────────────
router.put('/approve/:userId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findByIdAndUpdate(
      toId(req.params.userId),
      { $set: { is_approved: true, is_active: true } },
      { new: true }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User approved', user: { _id: user._id.toString(), email: user.email, role: user.role } });
  } catch (err) {
    console.error('approve user error:', err);
    res.status(500).json({ success: false, message: 'Failed to approve user' });
  }
});

// Flutter uses POST /admin/approve-user/:id
router.post('/approve-user/:userId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findByIdAndUpdate(
      toId(req.params.userId),
      { $set: { is_approved: true, is_active: true } },
      { new: true }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User approved', user: { _id: user._id.toString(), email: user.email, role: user.role } });
  } catch (err) {
    console.error('approve-user error:', err);
    res.status(500).json({ success: false, message: 'Failed to approve user' });
  }
});

// ─── REJECT / DEACTIVATE USER ─────────────────────────────────────────────────
router.put('/reject/:userId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findByIdAndUpdate(
      toId(req.params.userId),
      { $set: { is_approved: false, is_active: false } },
      { new: true }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User rejected/deactivated' });
  } catch (err) {
    console.error('reject user error:', err);
    res.status(500).json({ success: false, message: 'Failed to reject user' });
  }
});

// Flutter uses POST /admin/reject-user/:id
router.post('/reject-user/:userId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findByIdAndUpdate(
      toId(req.params.userId),
      { $set: { is_approved: false, is_active: false } },
      { new: true }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User rejected' });
  } catch (err) {
    console.error('reject-user error:', err);
    res.status(500).json({ success: false, message: 'Failed to reject user' });
  }
});

// ─── PHARMACY REJECTION STATS (Admin dashboard / compliance) ────────────────
// Includes all rejections; use noReferrerRejections vs otherRejections for reporting.
router.get('/pharmacy-rejection-stats', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const rejected = await PharmacyOrder.find({ status: 'rejected' }).select('rejection_reason cancellation_reason prescription_id').lean();

    let noReferrerRejections = 0;
    for (const o of rejected) {
      const r = o.rejection_reason || o.cancellation_reason || '';
      if (isNoReferrerReason(r)) noReferrerRejections += 1;
    }

    const totalPharmacyRejections = rejected.length;
    const otherRejections = totalPharmacyRejections - noReferrerRejections;
    const withPrescriptionId = rejected.filter((o) => !!o.prescription_id).length;

    res.json({
      success: true,
      totals: {
        totalPharmacyRejections,
        noReferrerRejections,
        otherRejections,
        withPrescriptionId,
      },
    });
  } catch (err) {
    console.error('pharmacy-rejection-stats error:', err);
    res.status(500).json({ success: false, message: err.message || 'Failed to load stats' });
  }
});

// ─── STATS ────────────────────────────────────────────────────────────────────
router.get('/stats', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const [total, patients, doctors, labs, pharmacies, pending] = await Promise.all([
      User.countDocuments({ is_active: { $ne: false } }),
      User.countDocuments({ role: { $regex: /^patient$/i }, is_active: { $ne: false } }),
      User.countDocuments({ role: { $regex: /^doctor$/i }, is_active: { $ne: false } }),
      User.countDocuments({ role: { $regex: /^lab$/i }, is_active: { $ne: false } }),
      User.countDocuments({ role: { $regex: /^pharmacy$/i }, is_active: { $ne: false } }),
      User.countDocuments({ is_approved: false }),
    ]);
    res.json({ success: true, stats: { total, patients, doctors, labs, pharmacies, pending } });
  } catch (err) {
    res.json({ success: true, stats: { total: 0, patients: 0, doctors: 0, labs: 0, pharmacies: 0, pending: 0 } });
  }
});

// ─── FALLBACK — catch any other /api/admin/* calls ───────────────────────────
// ─── LEAVE REQUESTS (Admin) ───────────────────────────────────────────────────
const DoctorProfile = require('../models/DoctorProfile');

// GET /admin/leave-requests — list all pending leave requests from all doctors
router.get('/leave-requests', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const profiles = await DoctorProfile.find(
      { 'leaveRequests.0': { $exists: true } },
      { user_id: 1, leaveRequests: 1 }
    ).populate('user_id', 'name username email').lean();

    const all = [];
    for (const p of profiles) {
      const doctorName = p.user_id?.username || p.user_id?.name || 'Doctor';
      const doctorEmail = p.user_id?.email || '';
      for (const r of p.leaveRequests || []) {
        all.push({
          ...r,
          _id: r._id?.toString(),
          doctorId: p.user_id?._id?.toString(),
          doctorName,
          doctorEmail,
        });
      }
    }
    // Sort pending first, then by date desc
    all.sort((a, b) => {
      if (a.status === 'pending' && b.status !== 'pending') return -1;
      if (a.status !== 'pending' && b.status === 'pending') return 1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    res.json({ success: true, leaveRequests: all });
  } catch (e) {
    console.error('admin/leave-requests GET error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// PATCH /admin/leave-requests/:doctorId/:requestId — approve or reject a leave request
router.put('/leave-requests/:doctorId/:requestId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { status } = req.body; // 'approved' | 'rejected'
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be approved or rejected' });
    }

    const doctorId = toId(req.params.doctorId);
    if (!doctorId) return res.status(400).json({ success: false, message: 'Invalid doctor ID' });

    const requestId = toId(req.params.requestId);

    let updated;
    if (requestId) {
      // Try match by _id
      updated = await DoctorProfile.updateOne(
        { user_id: doctorId, 'leaveRequests._id': requestId },
        { $set: { 'leaveRequests.$.status': status, 'leaveRequests.$.reviewedAt': new Date(), 'leaveRequests.$.reviewedBy': req.user.id } }
      );
    }

    // Fallback: if no _id match (old records without _id), update all pending for this doctor
    if (!updated || updated.modifiedCount === 0) {
      await DoctorProfile.updateOne(
        { user_id: doctorId, 'leaveRequests.status': 'pending' },
        { $set: { 'leaveRequests.$.status': status, 'leaveRequests.$.reviewedAt': new Date() } }
      );
    }

    res.json({ success: true, message: `Leave request ${status}.` });
  } catch (e) {
    console.error('admin/leave-requests PATCH error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── CREDENTIAL VERIFICATION (Admin) ─────────────────────────────────────────

// GET /admin/credentials — list all pending credentials
router.get('/credentials', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const profiles = await DoctorProfile.find(
      { 'credentials.0': { $exists: true } },
      { user_id: 1, credentials: 1 }
    ).populate('user_id', 'name username email').lean();

    const all = [];
    for (const p of profiles) {
      const doctorName = p.user_id?.username || p.user_id?.name || 'Doctor';
      for (const c of p.credentials || []) {
        all.push({ ...c, _id: c._id?.toString(), doctorId: p.user_id?._id?.toString(), doctorName });
      }
    }
    res.json({ success: true, credentials: all });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PATCH /admin/credentials/:doctorId/:credId — verify or reject a credential
router.put('/credentials/:doctorId/:credId', authMiddleware, adminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const { status } = req.body; // 'verified' | 'rejected'
    if (!['verified', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be verified or rejected' });
    }
    const doctorId = toId(req.params.doctorId);
    const credId   = toId(req.params.credId);
    if (!doctorId || !credId) return res.status(400).json({ success: false, message: 'Invalid IDs' });

    await DoctorProfile.updateOne(
      { user_id: doctorId, 'credentials._id': credId },
      { $set: { 'credentials.$.status': status, 'credentials.$.updatedAt': new Date() } }
    );
    res.json({ success: true, message: `Credential ${status}.` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── CONTROLLED DRUG LIST (admin-managed by INN/generic name) ────────────────
const ControlledDrug = require('../models/ControlledDrug');

// GET all controlled drugs
router.get('/controlled-drugs', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const drugs = await ControlledDrug.find().sort({ genericName: 1 }).lean();
    res.json({ success: true, drugs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST add a generic/INN name to controlled list
router.post('/controlled-drugs', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { genericName, innName, schedule, notes } = req.body;
    if (!genericName?.trim()) return res.status(400).json({ success: false, message: 'genericName is required' });

    const drug = await ControlledDrug.findOneAndUpdate(
      { genericName: { $regex: `^${genericName.trim()}$`, $options: 'i' } },
      { $set: { genericName: genericName.trim(), innName: innName || '', schedule: schedule || '', notes: notes || '', addedBy: toId(req.user.id) } },
      { upsert: true, new: true }
    );

    // Retroactively update all products whose generic_name matches
    const Product = require('../models/Product');
    const updated = await Product.updateMany(
      { generic_name: { $regex: `^${genericName.trim()}$`, $options: 'i' } },
      { $set: { medicine_category: 'Controlled', requires_prescription: true } }
    );

    res.json({ success: true, drug, productsUpdated: updated.modifiedCount });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE remove from controlled list
router.delete('/controlled-drugs/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await ControlledDrug.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Removed from controlled drug list' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── SEED CONTROLLED MEDICINES (one-time, no auth needed for convenience) ─────
router.post('/seed-controlled-medicines', async (req, res) => {
  try {
    await connectMongoDB();
    const Product = require('../models/Product');

    const pharmacy = await User.findOne({ role: { $in: ['pharmacy', 'Pharmacy'] } }).lean();
    if (!pharmacy) return res.status(404).json({ success: false, message: 'No pharmacy found' });

    const medicines = [
      {
        pharmacy_id: pharmacy._id, name: 'Xanax (Alprazolam) 0.5mg', generic_name: 'Alprazolam',
        description: 'Controlled benzodiazepine for anxiety disorders.', category: 'psychiatric',
        medicine_category: 'Controlled', price: 450, stock_quantity: 50,
        manufacturer: 'Pfizer', requires_prescription: true, is_active: true,
      },
      {
        pharmacy_id: pharmacy._id, name: 'Tramadol HCl 50mg', generic_name: 'Tramadol Hydrochloride',
        description: 'Controlled opioid analgesic for moderate to severe pain.', category: 'analgesics',
        medicine_category: 'Controlled', price: 320, stock_quantity: 30,
        manufacturer: 'Searle Pakistan', requires_prescription: true, is_active: true,
      },
      {
        pharmacy_id: pharmacy._id, name: 'Codeine Phosphate 30mg', generic_name: 'Codeine',
        description: 'Controlled opioid for pain and cough suppression.', category: 'analgesics',
        medicine_category: 'Controlled', price: 280, stock_quantity: 20,
        manufacturer: 'Martin Dow', requires_prescription: true, is_active: true,
      },
    ];

    const results = [];
    for (const med of medicines) {
      const existing = await Product.findOne({ name: med.name, pharmacy_id: pharmacy._id });
      if (existing) {
        // Update medicine_category in case it was OTC before
        await Product.findByIdAndUpdate(existing._id, { $set: { medicine_category: 'Controlled', requires_prescription: true } });
        results.push({ name: med.name, status: 'updated to Controlled' });
        continue;
      }
      await Product.create(med);
      results.push({ name: med.name, status: 'added' });
    }

    // Also seed the admin ControlledDrug list with generic names
    const ControlledDrug = require('../models/ControlledDrug');
    const drugList = [
      { genericName: 'Alprazolam', innName: 'Alprazolam', schedule: 'Schedule IV', notes: 'Benzodiazepine — anxiety' },
      { genericName: 'Tramadol Hydrochloride', innName: 'Tramadol', schedule: 'Schedule IV', notes: 'Opioid analgesic' },
      { genericName: 'Codeine', innName: 'Codeine Phosphate', schedule: 'Schedule II', notes: 'Opioid — pain & cough' },
      { genericName: 'Diazepam', innName: 'Diazepam', schedule: 'Schedule IV', notes: 'Benzodiazepine' },
      { genericName: 'Morphine', innName: 'Morphine Sulfate', schedule: 'Schedule II', notes: 'Opioid analgesic' },
      { genericName: 'Methylphenidate', innName: 'Methylphenidate HCl', schedule: 'Schedule II', notes: 'ADHD stimulant' },
    ];
    const drugResults = [];
    for (const d of drugList) {
      await ControlledDrug.findOneAndUpdate(
        { genericName: { $regex: `^${d.genericName}$`, $options: 'i' } },
        { $set: d },
        { upsert: true }
      );
      drugResults.push(d.genericName);
    }

    res.json({ success: true, pharmacy: pharmacy.username || pharmacy.email, results, controlledDrugListSeeded: drugResults });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── TEST: get a sample prescription ID for dev/testing (no auth) ────────────
router.get('/test-prescription-id', async (req, res) => {
  try {
    await connectMongoDB();
    const EnhancedPrescription = require('../models/EnhancedPrescription');
    const rx = await EnhancedPrescription.findOne({}).lean();
    if (!rx) return res.json({ success: false, message: 'No prescriptions found in DB. Ask a doctor to create one first.' });
    res.json({ success: true, prescriptionId: rx._id.toString(), patientId: rx.patient_id?.toString(), doctorId: rx.doctor_id?.toString() });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.all('/{*path}', (req, res) => {
  res.json({ success: true, users: [], data: [], count: 0 });
});

module.exports = router;
