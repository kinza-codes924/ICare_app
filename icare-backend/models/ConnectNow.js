const mongoose = require('mongoose');

const connectNowSchema = new mongoose.Schema({
  patientId: { type: String, required: true },
  patientName: { type: String, required: true },
  channelName: { type: String, required: true },
  targetDoctorId: { type: String, default: null },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'expired', 'cancelled'],
    default: 'pending',
  },
  acceptedBy: {
    doctorId: String,
    doctorName: String,
  },
  appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment' },
  createdAt: { type: Date, default: Date.now, expires: 300 }, // auto-delete after 5 min
});

module.exports = mongoose.model('ConnectNow', connectNowSchema);
