const mongoose = require('mongoose');

const studentVerificationSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  documents: [{
    type: { type: String, required: true }, // 'id_card', 'student_id', 'license', 'certificate', 'other'
    url: { type: String, required: true },
    fileName: String,
    uploadedAt: { type: Date, default: Date.now }
  }],
  status: { 
    type: String, 
    enum: ['pending', 'approved', 'rejected'], 
    default: 'pending' 
  },
  reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  reviewedAt: Date,
  rejectionReason: String,
  verificationLevel: { 
    type: String, 
    enum: ['limited', 'full'], 
    default: 'limited' 
  },
}, { timestamps: true });

module.exports = mongoose.models.StudentVerification || mongoose.model('StudentVerification', studentVerificationSchema);
