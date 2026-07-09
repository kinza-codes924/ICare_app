const { getFirebaseAdmin } = require('../config/firebase');
const User = require('../models/User');

// Send FCM push notification to specific user(s)
async function sendToUser(userId, { title, body, data = {}, type = 'general' }) {
  try {
    const user = await User.findById(userId).select('fcm_tokens notification_preferences').lean();
    if (!user || !user.fcm_tokens || user.fcm_tokens.length === 0) return;

    // Check user's notification preference for this type
    const prefs = user.notification_preferences || {};
    const prefMap = {
      new_order: 'new_orders',
      order_dispatched: 'order_dispatched',
      delivery_update: 'delivery_updates',
      system_alert: 'system_alerts',
      booking_update: 'booking_updates',
      doctor_message: 'doctor_messages',
      promotion: 'promotions',
    };
    const prefKey = prefMap[type];
    if (prefKey && prefs[prefKey] === false) return; // user opted out

    const tokens = user.fcm_tokens.filter(Boolean);
    if (tokens.length === 0) return;

    await _sendMulticast(tokens, title, body, { ...data, type });
  } catch (err) {
    console.error('sendToUser error:', err.message);
  }
}

// Send to multiple userIds at once
async function sendToUsers(userIds, payload) {
  await Promise.all(userIds.map(id => sendToUser(id, payload)));
}

// Internal multicast helper
async function _sendMulticast(tokens, title, body, data = {}) {
  try {
    const admin = getFirebaseAdmin();
    const stringData = {};
    for (const [k, v] of Object.entries(data)) {
      stringData[k] = String(v ?? '');
    }
    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
      android: { priority: 'high', notification: { sound: 'default', channelId: 'icare_high_importance' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    // Remove invalid tokens
    const invalidIndexes = [];
    result.responses.forEach((r, i) => {
      if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
        invalidIndexes.push(tokens[i]);
      }
    });
    if (invalidIndexes.length > 0) {
      await User.updateMany({}, { $pull: { fcm_tokens: { $in: invalidIndexes } } });
    }
    return result;
  } catch (err) {
    console.error('FCM multicast error:', err.message);
  }
}

module.exports = { sendToUser, sendToUsers };
