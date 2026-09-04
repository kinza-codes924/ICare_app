const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String },
  name: { type: String },
  email: { type: String, required: true, lowercase: true, trim: true },
  phone: { type: String },
  password: { type: String, required: true },
  role: {
    type: String,
    // Both cases are genuinely in the data — a `distinct('role')` returns
    // 'Patient' alongside 'patient', and 'Laboratory' alongside 'lab'. The app
    // compares against the capitalised forms in most places and lowercases at
    // the comparison site elsewhere. With only the lowercase values listed
    // here, ANY save() on one of those accounts failed validation, which is
    // what silently swallowed review gamification awards
    // ("role: `Patient` is not a valid enum value"). Listing what exists is
    // the non-destructive fix; normalising the column would break every
    // === 'Patient' check in the codebase.
    enum: [
      'patient', 'doctor', 'lab', 'pharmacy', 'admin', 'instructor', 'student', 'receptionist',
      'Patient', 'Doctor', 'Laboratory', 'Pharmacy', 'Admin', 'Instructor', 'Student',
    ],
    default: 'patient',
  },
  // Multi-role support: all roles this account is approved for.
  // Empty/missing means the single `role` above is the only one.
  roles: [{ type: String }],
  // Roles requested (e.g. a second Work-With-Us application under a role
  // this same email doesn't have yet) but not yet approved by admin. Kept
  // separate from `roles` so an approved account isn't granted a new role
  // silently — admin must explicitly approve it via the pending-users flow.
  pendingRoles: [{ type: String }],
  mrNumber: { type: String, unique: true, sparse: true }, // Medical Record Number (auto-generated for patients)
  // Email ownership check at signup. Accounts created before this existed
  // have it undefined, which login treats as verified — only new signups
  // are gated, so nobody gets locked out retroactively.
  emailVerified: { type: Boolean },
  // Stored as a SHA-256 hash, never the plain code: a database dump then
  // can't be used to complete someone else's pending signup.
  emailOtpHash: { type: String },
  emailOtpExpiresAt: { type: Date },
  emailOtpAttempts: { type: Number, default: 0 },
  emailOtpLastSentAt: { type: Date },
  is_approved: { type: Boolean, default: true },
  is_active: { type: Boolean, default: true },
  // Virtual hospital compat fields
  isApproved: { type: Boolean, default: true },
  isActive: { type: Boolean, default: true },
  // Push notifications
  fcm_tokens: [{ type: String }],
  notification_preferences: {
    new_orders:       { type: Boolean, default: true },
    order_dispatched: { type: Boolean, default: true },
    delivery_updates: { type: Boolean, default: true },
    system_alerts:    { type: Boolean, default: true },
    booking_updates:  { type: Boolean, default: true },
    doctor_messages:  { type: Boolean, default: true },
    promotions:       { type: Boolean, default: false },
    sound_notifications: { type: Boolean, default: true },
  },
}, {
  timestamps: true,
  strict: false, // Accept any extra fields from virtual hospital accounts
});

// Index for fast lookup
userSchema.index({ email: 1 });
userSchema.index({ username: 1 });

module.exports = mongoose.models.User || mongoose.model('User', userSchema);
