const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');
const LiveSession = require('../models/LiveSession');

// POST /api/jitsi/token — JWT for our self-hosted Jitsi server.
// Requires a real app-user JWT (authMiddleware) so the caller's identity is
// verified server-side — moderator status is NEVER taken from the client,
// only from the DB, so a student can't just claim to be the instructor.
router.post('/token', authMiddleware, async (req, res) => {
  try {
    // .trim() guards against trailing whitespace/newlines that can sneak in
    // when env vars are piped into `vercel env add` from PowerShell — JWT
    // signing needs a byte-exact match with the secret configured on the
    // Jitsi server, so any stray whitespace breaks verification silently.
    const appId = (process.env.JWT_APP_ID || '').trim();
    const secret = (process.env.JWT_APP_SECRET || '').trim();
    if (!appId || !secret) {
      return res.status(500).json({ success: false, message: 'JWT_APP_ID/JWT_APP_SECRET not configured' });
    }

    const room = ((req.body.room || '') + '').trim();
    if (!room) return res.status(400).json({ success: false, message: 'room is required' });

    const displayName = ((req.body.displayName || req.user.name || 'User') + '').trim().slice(0, 50) || 'User';
    const sessionId = req.body.sessionId ? ((req.body.sessionId) + '').trim() : '';

    let moderator = false;
    if (sessionId) {
      // LMS live session — moderator only if this user is the session's instructor.
      await connectMongoDB();
      const session = await LiveSession.findById(sessionId).lean().catch(() => null);
      if (session && session.instructorId?.toString() === req.user.id?.toString()) {
        moderator = true;
      }
      console.log(`[jitsi-token] room=${room} sessionId=${sessionId} userId=${req.user.id} userRole=${req.user.role} sessionInstructorId=${session?.instructorId?.toString() || 'N/A'} sessionFound=${!!session} -> moderator=${moderator}`);
    } else {
      // Doctor/patient consultation — moderator only for the doctor.
      const role = (req.user.role || '').toLowerCase();
      moderator = role === 'doctor';
      console.log(`[jitsi-token] room=${room} no sessionId, userId=${req.user.id} userRole=${req.user.role} -> moderator=${moderator}`);
    }

    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: appId,
      aud: appId,
      sub: 'vh.itserver.biz',
      room,
      nbf: now - 10,
      exp: now + 7200, // 2-hour token
      context: {
        user: {
          id: req.user.id,
          name: displayName,
          moderator,
        },
      },
    };

    const token = jwt.sign(payload, secret, { algorithm: 'HS256' });
    res.json({ success: true, token, moderator });
  } catch (e) {
    console.error('jitsi-token error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
