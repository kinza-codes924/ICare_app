const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const Rating = require('../models/Rating');
const DoctorProfile = require('../models/DoctorProfile');
const PharmacyProfile = require('../models/PharmacyProfile');
const LabProfile = require('../models/LabProfile');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

async function updateAggregateRating(targetId, targetType) {
  try {
    const results = await Rating.aggregate([
      { $match: { target_id: targetId } },
      { $group: { _id: null, avg: { $avg: '$rating' }, count: { $sum: 1 } } },
    ]);
    const avgRating = results[0]?.avg || 0;
    const totalReviews = results[0]?.count || 0;

    let Model;
    if (targetType === 'doctor') Model = DoctorProfile;
    else if (targetType === 'pharmacy') Model = PharmacyProfile;
    else if (targetType === 'lab') Model = LabProfile;
    else return;

    await Model.findOneAndUpdate({ user_id: targetId }, { $set: { rating: avgRating, total_reviews: totalReviews } });
  } catch (error) {
    console.error('Update aggregate rating error:', error);
  }
}

// ─── CREATE RATING ────────────────────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const reviewerId = toId(req.user.id);
    const { targetId, targetType, referenceId, referenceType, rating, comment } = req.body;

    if (!targetId || !targetType || !rating) {
      return res.status(400).json({ success: false, message: 'Target ID, target type, and rating are required' });
    }
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5' });
    }

    if (referenceId && referenceType) {
      const existing = await Rating.findOne({ reviewer_id: reviewerId, reference_id: referenceId, reference_type: referenceType });
      if (existing) {
        return res.status(400).json({ success: false, message: 'You have already rated this' });
      }
    }

    const targetObjId = toId(targetId);
    const newRating = await Rating.create({
      reviewer_id: reviewerId,
      target_id: targetObjId,
      target_type: targetType,
      reference_id: referenceId,
      reference_type: referenceType,
      rating,
      comment,
    });

    await updateAggregateRating(targetObjId, targetType);

    res.status(201).json({ success: true, message: 'Rating submitted successfully', rating: { ...newRating.toObject(), _id: newRating._id.toString() } });
  } catch (error) {
    console.error('Create rating error:', error);
    res.status(500).json({ success: false, message: 'Failed to submit rating' });
  }
});

// ─── GET RATINGS FOR TARGET ───────────────────────────────────────────────────
router.get('/target/:targetId', async (req, res) => {
  try {
    await connectMongoDB();
    const targetId = toId(req.params.targetId);
    const { limit = 50, offset = 0 } = req.query;

    const ratings = await Rating.find({ target_id: targetId })
      .sort({ createdAt: -1 })
      .skip(parseInt(offset))
      .limit(parseInt(limit))
      .lean();

    const reviewerIds = [...new Set(ratings.map(r => r.reviewer_id.toString()))];
    const reviewers = await User.find({ _id: { $in: reviewerIds.map(id => toId(id)) } }).lean();
    const rMap = {};
    reviewers.forEach(r => { rMap[r._id.toString()] = r; });

    const total = await Rating.countDocuments({ target_id: targetId });

    const result = ratings.map(r => ({
      ...r,
      _id: r._id.toString(),
      reviewer_name: rMap[r.reviewer_id.toString()]?.username || rMap[r.reviewer_id.toString()]?.name,
    }));

    res.json({ success: true, ratings: result, total });
  } catch (error) {
    console.error('Get ratings error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch ratings' });
  }
});

// ─── GET AGGREGATE ────────────────────────────────────────────────────────────
router.get('/aggregate/:targetId', async (req, res) => {
  try {
    await connectMongoDB();
    const targetId = toId(req.params.targetId);
    const results = await Rating.aggregate([
      { $match: { target_id: targetId } },
      {
        $group: {
          _id: null,
          totalReviews: { $sum: 1 },
          averageRating: { $avg: '$rating' },
          five: { $sum: { $cond: [{ $eq: ['$rating', 5] }, 1, 0] } },
          four: { $sum: { $cond: [{ $eq: ['$rating', 4] }, 1, 0] } },
          three: { $sum: { $cond: [{ $eq: ['$rating', 3] }, 1, 0] } },
          two: { $sum: { $cond: [{ $eq: ['$rating', 2] }, 1, 0] } },
          one: { $sum: { $cond: [{ $eq: ['$rating', 1] }, 1, 0] } },
        },
      },
    ]);

    const data = results[0] || { totalReviews: 0, averageRating: 0, five: 0, four: 0, three: 0, two: 0, one: 0 };

    res.json({
      success: true,
      aggregate: {
        totalReviews: data.totalReviews,
        averageRating: parseFloat((data.averageRating || 0).toFixed(2)),
        distribution: { 5: data.five, 4: data.four, 3: data.three, 2: data.two, 1: data.one },
      },
    });
  } catch (error) {
    console.error('Get aggregate rating error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch aggregate rating' });
  }
});

// ─── MY RATINGS ───────────────────────────────────────────────────────────────
router.get('/my-ratings', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const ratings = await Rating.find({ reviewer_id: userId }).sort({ createdAt: -1 }).lean();

    const targetIds = [...new Set(ratings.map(r => r.target_id.toString()))];
    const targets = await User.find({ _id: { $in: targetIds.map(id => toId(id)) } }).lean();
    const tMap = {};
    targets.forEach(t => { tMap[t._id.toString()] = t; });

    const result = ratings.map(r => ({
      ...r,
      _id: r._id.toString(),
      target_name: tMap[r.target_id.toString()]?.username || tMap[r.target_id.toString()]?.name,
    }));

    res.json({ success: true, ratings: result });
  } catch (error) {
    console.error('Get my ratings error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch your ratings' });
  }
});

// ─── UPDATE RATING ────────────────────────────────────────────────────────────
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { rating, comment } = req.body;

    if (rating && (rating < 1 || rating > 5)) {
      return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5' });
    }

    const existing = await Rating.findOne({ _id: toId(req.params.id), reviewer_id: userId });
    if (!existing) return res.status(404).json({ success: false, message: 'Rating not found or access denied' });

    const update = {};
    if (rating !== undefined) update.rating = rating;
    if (comment !== undefined) update.comment = comment;

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    Object.assign(existing, update);
    await existing.save();

    await updateAggregateRating(existing.target_id, existing.target_type);

    res.json({ success: true, message: 'Rating updated successfully', rating: { ...existing.toObject(), _id: existing._id.toString() } });
  } catch (error) {
    console.error('Update rating error:', error);
    res.status(500).json({ success: false, message: 'Failed to update rating' });
  }
});

// ─── DELETE RATING ────────────────────────────────────────────────────────────
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const existing = await Rating.findOne({ _id: toId(req.params.id), reviewer_id: userId });
    if (!existing) return res.status(404).json({ success: false, message: 'Rating not found or access denied' });

    const { target_id, target_type } = existing;
    await existing.deleteOne();
    await updateAggregateRating(target_id, target_type);

    res.json({ success: true, message: 'Rating deleted successfully' });
  } catch (error) {
    console.error('Delete rating error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete rating' });
  }
});

module.exports = router;
