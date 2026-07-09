const Consultation = require('../models/Consultation');
const ConsultationMessage = require('../models/ConsultationMessage');
const User = require('../models/User');

// Start a new consultation
exports.startConsultation = async (req, res) => {
  try {
    const { patientId, reason, isForSelf, patientName, patientAge, patientGender } = req.body;
    const doctorId = req.user.id;

    // Generate unique channel name
    const channelName = `consultation_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const consultation = await Consultation.create({
      patientId,
      doctorId,
      reason,
      isForSelf,
      patientName,
      patientAge,
      patientGender,
      channelName,
      status: 'active'
    });

    // Get doctor details for consent message
    const doctor = await User.findById(doctorId);

    // Auto-send consent message
    await ConsultationMessage.create({
      consultationId: consultation._id,
      senderId: doctorId,
      senderName: doctor.name,
      senderRole: 'doctor',
      message: `Hi, I am Dr. ${doctor.name}. I confirm that telehealth has limitations and some emergencies require in-person visits.`,
      isSystemMessage: false
    });

    res.json({
      success: true,
      consultation: consultation,
      message: 'Consultation started successfully'
    });
  } catch (error) {
    console.error('Start consultation error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get consultation details
exports.getConsultation = async (req, res) => {
  try {
    const { consultationId } = req.params;

    const consultation = await Consultation.findById(consultationId)
      .populate('patientId', 'name email phone')
      .populate('doctorId', 'name email phone specialization');

    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Check if user has access to this consultation
    const userId = req.user.id;
    if (consultation.patientId._id.toString() !== userId &&
        consultation.doctorId._id.toString() !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    res.json({
      success: true,
      consultation
    });
  } catch (error) {
    console.error('Get consultation error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Send message in consultation
exports.sendMessage = async (req, res) => {
  try {
    const { consultationId } = req.params;
    const { message, attachmentUrl } = req.body;
    const userId = req.user.id;

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Check if user is part of this consultation
    const isPatient = consultation.patientId.toString() === userId;
    const isDoctor = consultation.doctorId.toString() === userId;

    if (!isPatient && !isDoctor) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    const user = await User.findById(userId);
    const senderRole = isDoctor ? 'doctor' : 'patient';

    const newMessage = await ConsultationMessage.create({
      consultationId,
      senderId: userId,
      senderName: user.name,
      senderRole,
      message,
      attachmentUrl
    });

    res.json({
      success: true,
      message: newMessage
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get messages for consultation
exports.getMessages = async (req, res) => {
  try {
    const { consultationId } = req.params;
    const userId = req.user.id;

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Check access
    if (consultation.patientId.toString() !== userId &&
        consultation.doctorId.toString() !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    const messages = await ConsultationMessage.find({ consultationId })
      .sort({ timestamp: 1 });

    res.json({
      success: true,
      messages
    });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// End consultation
exports.endConsultation = async (req, res) => {
  try {
    const { consultationId } = req.params;
    const userId = req.user.id;

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Only doctor or patient can end consultation
    if (consultation.patientId.toString() !== userId &&
        consultation.doctorId.toString() !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    // Check if doctor has completed prescription (if doctor is ending)
    const isDoctor = consultation.doctorId.toString() === userId;
    if (isDoctor && !consultation.hasPrescription) {
      return res.status(400).json({
        success: false,
        message: 'Please complete the prescription before ending consultation'
      });
    }

    // Check minimum duration (10 minutes = 600 seconds)
    const currentDuration = Math.floor((Date.now() - consultation.startTime) / 1000);
    if (isDoctor && currentDuration < 600) {
      return res.status(400).json({
        success: false,
        message: 'Consultation must be at least 10 minutes long'
      });
    }

    consultation.status = 'completed';
    consultation.endTime = new Date();
    await consultation.save();

    // Send system message
    await ConsultationMessage.create({
      consultationId,
      senderId: userId,
      senderName: 'System',
      senderRole: isDoctor ? 'doctor' : 'patient',
      message: 'Consultation ended',
      isSystemMessage: true
    });

    res.json({
      success: true,
      message: 'Consultation ended successfully'
    });
  } catch (error) {
    console.error('End consultation error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Upload attachment — Cloudinary
exports.uploadAttachment = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }
    const cloudinary = require('../config/cloudinary');
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'icare/consultation-attachments', resource_type: 'auto' },
        (err, result) => (err ? reject(err) : resolve(result))
      );
      stream.end(req.file.buffer);
    });
    res.json({ success: true, url: result.secure_url });
  } catch (error) {
    console.error('Upload attachment error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get user's consultations
exports.getMyConsultations = async (req, res) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;

    const query = {
      $or: [
        { patientId: userId },
        { doctorId: userId }
      ]
    };

    if (status) {
      query.status = status;
    }

    const consultations = await Consultation.find(query)
      .populate('patientId', 'name email')
      .populate('doctorId', 'name email specialization')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      consultations
    });
  } catch (error) {
    console.error('Get my consultations error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
