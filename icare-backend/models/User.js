const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String },
  name: { type: String },
  email: { type: String, required: true, lowercase: true, trim: true },
  phone: { type: String },
  password: { type: String, required: true },
  role: {
    type: String,
    enum: ['patient', 'doctor', 'lab', 'pharmacy', 'admin', 'instructor', 'student'],
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
