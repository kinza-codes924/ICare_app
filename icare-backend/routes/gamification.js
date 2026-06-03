const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');

const POINT_RULES = {
  log_health_metric: 5,
  complete_appointment: 20,
  complete_lab_test: 15,
  complete_program: 50,
  daily_goal: 10,
  streak_bonus: 25,
  rate_doctor: 5,
  redeem_consultation: -100,
  redeem_lab_discount: -150,
};

const BADGES = [
  { id: 'first_steps', name: 'First Steps', icon: '👣', description: 'Complete your first health entry', threshold: 1, type: 'metric_logs' },
  { id: 'health_tracker', name: 'Health Tracker', icon: '📊', description: 'Log 7 health metrics', threshold: 7, type: 'metric_logs' },
  { id: 'dedicated', name: 'Dedicated', icon: '💪', description: 'Log 30 health metrics', threshold: 30, type: 'metric_logs' },
  { id: 'first_consult', name: 'First Consult', icon: '🩺', description: 'Complete your first appointment', threshold: 1, type: 'completedAppointments' },
  { id: 'regular_patient', name: 'Regular Patient', icon: '🏥', description: 'Complete 5 appointments', threshold: 5, type: 'completedAppointments' },
  { id: 'lab_explorer', name: 'Lab Explorer', icon: '🔬', description: 'Complete your first lab test', threshold: 1, type: 'completedLabTests' },
  { id: 'learner', name: 'Learner', icon: '📚', description: 'Complete your first program', threshold: 1, type: 'completedPrograms' },
  { id: 'centurion', name: 'Centurion', icon: '🏆', description: 'Earn 100 points', threshold: 100, type: 'points' },
  { id: 'streak_7', name: '7-Day Streak', icon: '🔥', description: 'Log health data 7 days in a row', threshold: 7, type: 'streak' },
];

function computeBadges(stats, points, streak) {
  return BADGES.map(badge => {
    let progress = 0;
    if (badge.type === 'points') progress = points;
    else if (badge.type === 'streak') progress = streak;
    else progress = stats[badge.type] || 0;
    return { ...badge, earned: progress >= badge.threshold };
  });
}

// GET /api/gamification/my-stats
router.get('/my-stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const gam = user.gamification || {};
    const points = gam.points || 0;
    const history = gam.history || [];
    const streak = gam.streak || 0;
    const stats = gam.stats || {
      completedAppointments: 0,
      completedLabTests: 0,
      completedPrograms: 0,
      metric_logs: 0,
    };

    const availableBadges = computeBadges(stats, points, streak);
    const earnedBadges = availableBadges.filter(b => b.earned);

    res.json({
      success: true,
      points,
      streak,
      stats,
      badges: earnedBadges,
      availableBadges,
      history: history.slice(-50).reverse(),
      redemptions: (gam.redemptions || []).slice(-20).reverse(),
    });
  } catch (err) {
    console.error('Gamification stats error:', err);
    res.status(500).json({ success: false, message: 'Failed to load stats' });
  }
});

// POST /api/gamification/award-points
router.post('/award-points', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const { points, reason } = req.body;
    const awardPts = parseInt(points) || POINT_RULES[reason] || 0;
    if (awardPts === 0) return res.json({ success: true, message: 'No points to award', totalPoints: 0 });

    const historyEntry = { points: awardPts, reason: reason || 'manual', date: new Date().toISOString() };

    const updated = await User.findByIdAndUpdate(
      req.user.id,
      {
        $inc: { 'gamification.points': awardPts },
        $push: { 'gamification.history': { $each: [historyEntry], $slice: -200 } },
      },
      { new: true, strict: false }
    ).lean();

    if (!updated) return res.status(404).json({ success: false });

    res.json({ success: true, totalPoints: updated.gamification?.points || 0, awardedPoints: awardPts });
  } catch (err) {
    console.error('Award points error:', err);
    res.status(500).json({ success: false, message: 'Failed to award points' });
  }
});

// POST /api/gamification/log-metric — award points when patient logs a health metric
router.post('/log-metric', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');

    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    // Read current state to compute streak
    const current = await User.findById(req.user.id).lean();
    if (!current) return res.status(404).json({ success: false });

    const gam = current.gamification || {};
    const lastLog = gam.lastLogDate || null;

    let newStreak = gam.streak || 0;
    let streakBonus = 0;

    if (lastLog !== today) {
      newStreak = lastLog === yesterday ? (gam.streak || 0) + 1 : 1;
      if (newStreak === 7) streakBonus = 25;
    }

    const historyEntries = [{ points: 5, reason: 'log_health_metric', date: new Date().toISOString() }];
    if (streakBonus > 0) {
      historyEntries.push({ points: 25, reason: 'streak_bonus', date: new Date().toISOString() });
    }

    const updateOps = {
      $inc: {
        'gamification.points': 5 + streakBonus,
        'gamification.stats.metric_logs': 1,
      },
      $push: {
        'gamification.history': { $each: historyEntries, $slice: -200 },
      },
      $set: {
        'gamification.streak': newStreak,
      },
    };

    if (lastLog !== today) {
      updateOps.$set['gamification.lastLogDate'] = today;
    }

    const updated = await User.findByIdAndUpdate(
      req.user.id,
      updateOps,
      { new: true, strict: false }
    ).lean();

    res.json({
      success: true,
      pointsAwarded: 5 + streakBonus,
      totalPoints: updated?.gamification?.points || 0,
      streak: updated?.gamification?.streak || newStreak,
      streakBonus,
    });
  } catch (err) {
    console.error('Log metric points error:', err);
    res.status(500).json({ success: false, message: 'Failed' });
  }
});

// POST /api/gamification/redeem
router.post('/redeem', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const { rewardId } = req.body;
    const costs = { free_consultation: 100, lab_discount: 150 };
    const cost = costs[rewardId];
    if (!cost) return res.status(400).json({ success: false, message: 'Invalid reward' });

    const current = await User.findById(req.user.id).lean();
    if (!current) return res.status(404).json({ success: false });

    const currentPoints = current.gamification?.points || 0;
    if (currentPoints < cost) {
      return res.status(400).json({ success: false, message: `Not enough points. Need ${cost}, have ${currentPoints}.` });
    }

    const historyEntry = { points: -cost, reason: `redeem_${rewardId}`, date: new Date().toISOString() };
    const redemptionEntry = { rewardId, redeemedAt: new Date().toISOString(), cost };

    const updated = await User.findByIdAndUpdate(
      req.user.id,
      {
        $inc: { 'gamification.points': -cost },
        $push: {
          'gamification.history': { $each: [historyEntry], $slice: -200 },
          'gamification.redemptions': redemptionEntry,
        },
      },
      { new: true, strict: false }
    ).lean();

    const codes = { free_consultation: 'ICARE-FREE-CONSULT', lab_discount: 'ICARE-LAB-15OFF' };
    res.json({
      success: true,
      message: 'Reward redeemed!',
      remainingPoints: updated?.gamification?.points || 0,
      code: codes[rewardId],
    });
  } catch (err) {
    console.error('Redeem error:', err);
    res.status(500).json({ success: false, message: 'Failed to redeem reward' });
  }
});

// GET /api/gamification/leaderboard
router.get('/leaderboard', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const users = await User.find(
      { role: 'patient', 'gamification.points': { $gt: 0 } },
      { name: 1, 'gamification.points': 1, 'gamification.badges': 1 }
    ).sort({ 'gamification.points': -1 }).limit(20).lean();

    const leaderboard = users.map((u, i) => ({
      rank: i + 1,
      name: u.name || 'Anonymous',
      points: u.gamification?.points || 0,
      badgeCount: (u.gamification?.badges || []).length,
    }));

    res.json({ success: true, leaderboard });
  } catch (err) {
    console.error('Leaderboard error:', err);
    res.status(500).json({ success: false, leaderboard: [] });
  }
});

module.exports = router;
