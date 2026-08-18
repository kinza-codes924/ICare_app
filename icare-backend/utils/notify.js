const Notification = require('../models/Notification');

// Creates a notification unless one with the same {userId, dedupKey} already
// exists. Callers pass a stable key like `cert_ready:${enrollmentId}` for
// events that can be rechecked/retriggered multiple times but should only
// ever produce one notification. Falls back to a plain create when no
// dedupKey is given, preserving existing call sites' behavior.
async function notifyOnce({ userId, dedupKey, ...fields }) {
  if (!dedupKey) return Notification.create({ userId, ...fields });
  try {
    return await Notification.findOneAndUpdate(
      { userId, dedupKey },
      { $setOnInsert: { userId, dedupKey, ...fields } },
      { upsert: true, new: true }
    );
  } catch (e) {
    if (e.code === 11000) return null; // race: another request already created it
    throw e;
  }
}

module.exports = { notifyOnce };
