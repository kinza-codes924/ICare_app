/**
 * Temporary one-time route to seed lat/lng for all pharmacies and labs.
 * Call: GET /api/seed-locations?secret=icare_seed_2026
 * DELETE this file after running once.
 */
const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const PharmacyProfile = require('../models/PharmacyProfile');
const LabProfile = require('../models/LabProfile');

const KARACHI_AREAS = [
  { lat: 24.8607, lng: 67.0011, area: 'Clifton' },
  { lat: 24.9056, lng: 67.0822, area: 'Gulshan-e-Iqbal' },
  { lat: 24.8200, lng: 67.0300, area: 'DHA Phase 2' },
  { lat: 24.9400, lng: 67.1200, area: 'North Nazimabad' },
  { lat: 24.8800, lng: 67.0650, area: 'PECHS' },
  { lat: 24.8500, lng: 66.9900, area: 'Clifton Block 9' },
  { lat: 24.8700, lng: 67.0500, area: 'Saddar' },
  { lat: 24.9200, lng: 67.0400, area: 'Nazimabad' },
];

router.get('/', async (req, res) => {
  // Simple secret check to prevent accidental calls
  if (req.query.secret !== 'icare_seed_2026') {
    return res.status(403).json({ success: false, message: 'Forbidden' });
  }

  try {
    await connectMongoDB();
    const results = { pharmacies: [], labs: [] };

    // ── PHARMACIES ────────────────────────────────────────────────────────────
    const pharmacyUsers = await User.find({
      role: { $in: ['pharmacy', 'Pharmacy'] },
      is_active: { $ne: false },
    }).lean();

    for (let i = 0; i < pharmacyUsers.length; i++) {
      const user = pharmacyUsers[i];
      const profile = await PharmacyProfile.findOne({ user_id: user._id }).lean();

      if (profile?.latitude != null && profile?.longitude != null) {
        results.pharmacies.push({
          name: user.username || user.name,
          status: 'skipped — already has coordinates',
          lat: profile.latitude,
          lng: profile.longitude,
        });
        continue;
      }

      // Distribute across Karachi areas
      const area = KARACHI_AREAS[i % KARACHI_AREAS.length];
      const lat = parseFloat((area.lat + (Math.random() - 0.5) * 0.03).toFixed(6));
      const lng = parseFloat((area.lng + (Math.random() - 0.5) * 0.03).toFixed(6));

      await PharmacyProfile.findOneAndUpdate(
        { user_id: user._id },
        { $set: { latitude: lat, longitude: lng } },
        { upsert: true }
      );

      results.pharmacies.push({
        name: user.username || user.name,
        status: `seeded — ${area.area}`,
        lat,
        lng,
      });
    }

    // ── LABS ──────────────────────────────────────────────────────────────────
    const labUsers = await User.find({
      role: { $in: ['lab', 'Lab', 'laboratory', 'Laboratory'] },
      is_active: { $ne: false },
    }).lean();

    for (let i = 0; i < labUsers.length; i++) {
      const user = labUsers[i];
      const profile = await LabProfile.findOne({ user_id: user._id }).lean();

      if (profile?.latitude != null && profile?.longitude != null) {
        results.labs.push({
          name: user.username || user.name,
          status: 'skipped — already has coordinates',
          lat: profile.latitude,
          lng: profile.longitude,
        });
        continue;
      }

      const area = KARACHI_AREAS[i % KARACHI_AREAS.length];
      const lat = parseFloat((area.lat + (Math.random() - 0.5) * 0.03).toFixed(6));
      const lng = parseFloat((area.lng + (Math.random() - 0.5) * 0.03).toFixed(6));

      await LabProfile.findOneAndUpdate(
        { user_id: user._id },
        { $set: { latitude: lat, longitude: lng } },
        { upsert: true }
      );

      results.labs.push({
        name: user.username || user.name,
        status: `seeded — ${area.area}`,
        lat,
        lng,
      });
    }

    res.json({
      success: true,
      message: '✅ Locations seeded successfully',
      summary: {
        pharmacies_updated: results.pharmacies.filter(p => p.status.includes('seeded')).length,
        pharmacies_skipped: results.pharmacies.filter(p => p.status.includes('skipped')).length,
        labs_updated: results.labs.filter(l => l.status.includes('seeded')).length,
        labs_skipped: results.labs.filter(l => l.status.includes('skipped')).length,
      },
      details: results,
    });
  } catch (err) {
    console.error('Seed error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
