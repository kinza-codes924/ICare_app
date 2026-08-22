const jwt = require('jsonwebtoken');

const authMiddleware = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token'
    });
  }
};

const roleMiddleware = (...allowedRoles) => {
  // Case-insensitive: some accounts (esp. admin) have their role stored/
  // returned with different casing ('Admin' vs 'admin') than the DB enum.
  const allowedLower = allowedRoles.map(r => String(r).toLowerCase());
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    if (!allowedLower.includes(String(req.user.role || '').toLowerCase())) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Insufficient permissions.'
      });
    }

    next();
  };
};

// Platform-wide admin routes only. A clinic-admin account is literally
// role:'admin' in the User model (see ClinicAdminProfile) — nothing about
// the role string itself distinguishes it from the real platform admin.
// This checks role:'admin' the same way roleMiddleware('admin') does, then
// additionally rejects if a ClinicAdminProfile exists for that user, even
// though the role matches. Every platform-admin-only route must use this,
// not roleMiddleware('admin') directly, or a clinic-scoped admin can reach
// platform-wide data (other clinics' doctors, the global user list, etc).
const platformAdminOnly = async (req, res, next) => {
  if (!req.user || String(req.user.role || '').toLowerCase() !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Admin access required',
    });
  }
  try {
    const { connectMongoDB } = require('../config/mongodb');
    const ClinicAdminProfile = require('../models/ClinicAdminProfile');
    await connectMongoDB();
    const profile = await ClinicAdminProfile.findOne({ user_id: req.user.id }).select('_id').lean();
    if (profile) {
      return res.status(403).json({
        success: false,
        message: 'This admin account is scoped to a clinic and cannot access platform-wide admin routes.',
      });
    }
    next();
  } catch (error) {
    return res.status(503).json({
      success: false,
      message: 'Could not verify admin scope — please retry.',
    });
  }
};

module.exports = { authMiddleware, roleMiddleware, platformAdminOnly };
