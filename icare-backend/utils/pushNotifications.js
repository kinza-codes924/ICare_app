const admin = require('firebase-admin');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');

let _adminInitialized = false;

function _initAdmin() {
  if (_adminInitialized || admin.apps.length > 0) {
    _adminInitialized = true;
    return;
  }
  try {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
      : null;
    if (serviceAccount) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      _adminInitialized = true;
    }
  } catch (e) {
    console.warn('⚠️ Firebase Admin init skipped:', e.message);
  }
}

/**
 * Send a push notification to a specific user (by userId).
 * Silently no-ops if Firebase Admin is not configured.
 */
async function sendToUser(userId, { title, body, data = {} }) {
  try {
    _initAdmin();
    if (!_adminInitialized) return;
    await connectMongoDB();
    const user = await User.findById(userId).select('fcmToken').lean();
    if (!user?.fcmToken) return;
    await admin.messaging().send({
      token: user.fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    });
  } catch (e) {
    console.warn('⚠️ Push notification failed:', e.message);
  }
}

module.exports = { sendToUser };
