const mongoose = require('mongoose');

const reminderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: {
    type: String,
    enum: ['doctor_assigned', 'self_created', 'appointment', 'medication', 'water', 'health_check'],
    default: 'self_created'
  },
  title: { type: String, required: true },
  message: { type: String, default: '' },
  scheduledFor: { type: Date },
  remindBeforeMinutes: { type: Number, default: 15 },
  isCompleted: { type: Boolean, default: false },
  notificationSent: { type: Boolean, default: false },
  // For doctor-assigned reminders (linked to prescription/consultation)
  prescriptionId: { type: mongoose.Schema.Types.ObjectId, ref: 'EnhancedPrescription' },
  consultationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Consultation' },
  // For self-created reminders
  recurrence: { type: String, enum: ['none', 'daily', 'weekly', 'monthly'], default: 'none' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

reminderSchema.index({ userId: 1, scheduledFor: 1 });
reminderSchema.index({ userId: 1, isCompleted: 1 });

module.exports = mongoose.models.Reminder || mongoose.model('Reminder', reminderSchema);