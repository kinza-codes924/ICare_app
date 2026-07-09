const mongoose = require('mongoose');
const Consultation = require('../models/Consultation');
const ConsultationMessage = require('../models/ConsultationMessage');
const EnhancedPrescription = require('../models/EnhancedPrescription');
const User = require('../models/User');
const { connectMongoDB } = require('../config/mongodb');

const isValidObjectId = (id) => id && mongoose.Types.ObjectId.isValid(id);

// Start consultation with appointment
exports.startConsultation = async (req, res) => {
  try {
    console.log('🔵 START CONSULTATION REQUEST:', JSON.stringify(req.body, null, 2));

    await connectMongoDB();
    const { appointmentId, patientId, doctorId, reason, channelName } = req.body;

    // Validate required fields
    if (!doctorId || !isValidObjectId(doctorId)) {
      console.error('❌ Missing or invalid doctorId:', doctorId);
      return res.status(400).json({
        success: false,
        message: 'Valid Doctor ID is required'
      });
    }

    if (!patientId || !isValidObjectId(patientId)) {
      console.error('❌ Missing or invalid patientId:', patientId);
      return res.status(400).json({
        success: false,
        message: 'Valid Patient ID is required'
      });
    }

    // Only use appointmentId if it's a valid ObjectId (not a channel name or empty string)
    const validAppointmentId = isValidObjectId(appointmentId) ? appointmentId : null;

    console.log('✅ Validation passed. appointmentId valid:', !!validAppointmentId);

    // Check if consultation already exists for this appointment
    if (validAppointmentId) {
      const existingConsultation = await Consultation.findOne({
        appointmentId: validAppointmentId,
        status: { $in: ['pending', 'active'] }
      });

      if (existingConsultation) {
        console.log('✅ Found existing consultation:', existingConsultation._id);
        return res.json({
          success: true,
          consultationId: existingConsultation._id,
          consultation: existingConsultation,
          message: 'Consultation already started'
        });
      }
    }

    console.log('✅ No existing consultation. Creating new one...');

    // Build consultation document — only include appointmentId if valid
    const consultationData = {
      patientId,
      doctorId,
      channelName: channelName || `consultation_${Date.now()}_${patientId}`,
      reason: reason || 'Video consultation',
      status: 'active',
      startTime: new Date()
    };
    if (validAppointmentId) {
      consultationData.appointmentId = validAppointmentId;
    }

    const consultation = new Consultation(consultationData);
    await consultation.save();
    console.log('✅ Consultation created:', consultation._id);

    // Get doctor details for consent message
    const doctor = await User.findById(doctorId);
    const doctorName = doctor ? doctor.name : 'Doctor';
    console.log('✅ Doctor found:', doctorName);

    // Auto-send consent message from doctor (message 1)
    const consentMessage = new ConsultationMessage({
      consultationId: consultation._id,
      senderId: doctorId,
      senderName: doctorName,
      senderRole: 'doctor',
      message: `Hi, I am Dr. ${doctorName}. This telehealth consultation is confidential and intended for medical guidance only. By continuing, you consent to a virtual consultation, understand its limitations compared to in-person examination, and agree to share accurate health information. In case of emergency, please contact local emergency services immediately.`,
      isSystemMessage: true,
      timestamp: new Date()
    });

    await consentMessage.save();

    // Auto-send follow-up greeting (message 2)
    const greetingMessage = new ConsultationMessage({
      consultationId: consultation._id,
      senderId: doctorId,
      senderName: doctorName,
      senderRole: 'doctor',
      message: `How can I help you?`,
      isSystemMessage: false,
      timestamp: new Date(Date.now() + 1000) // 1 second after consent
    });

    await greetingMessage.save();
    console.log('✅ Consent + greeting messages sent');

    res.json({
      success: true,
      consultationId: consultation._id,
      consultation,
      message: 'Consultation started successfully'
    });
  } catch (error) {
    console.error('❌ ERROR STARTING CONSULTATION:', error);
    console.error('❌ ERROR STACK:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Failed to start consultation',
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

// Send message
exports.sendMessage = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const { senderId, senderName, senderRole, message, attachmentUrl, isSystemMessage } = req.body;

    // Validate required fields
    if (!senderId || !senderName || !senderRole || !message) {
      return res.status(400).json({
        success: false,
        message: 'Sender ID, name, role, and message are required'
      });
    }

    // Verify consultation exists
    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Create message
    const consultationMessage = new ConsultationMessage({
      consultationId,
      senderId,
      senderName,
      senderRole,
      message,
      attachmentUrl,
      isSystemMessage: isSystemMessage || false,
      timestamp: new Date()
    });

    await consultationMessage.save();

    res.json({
      success: true,
      messageId: consultationMessage._id,
      message: consultationMessage
    });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send message',
      error: error.message
    });
  }
};

// Get messages
exports.getMessages = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const { limit = 100, skip = 0 } = req.query;

    // Verify consultation exists
    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Get messages
    const messages = await ConsultationMessage.find({ consultationId })
      .sort({ timestamp: 1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    res.json({
      success: true,
      messages,
      count: messages.length
    });
  } catch (error) {
    console.error('Error getting messages:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get messages',
      error: error.message
    });
  }
};

// End consultation
exports.endConsultation = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const { duration, prescriptionId } = req.body;

    // Verify consultation exists
    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Check if consultation is already ended
    if (consultation.status === 'completed') {
      return res.json({
        success: true,
        message: 'Consultation already ended',
        consultation
      });
    }

    // Validate minimum duration (10 minutes = 600 seconds)
    if (duration && duration < 600) {
      return res.status(400).json({
        success: false,
        message: 'Consultation must be at least 10 minutes long'
      });
    }

    // Check if prescription is complete (for doctor)
    if (prescriptionId) {
      const prescription = await EnhancedPrescription.findById(prescriptionId);
      if (prescription && !prescription.isComplete) {
        return res.status(400).json({
          success: false,
          message: 'Prescription must be completed before ending consultation'
        });
      }
    }

    // Update consultation
    consultation.status = 'completed';
    consultation.endTime = new Date();
    consultation.duration = duration || Math.floor((consultation.endTime - consultation.startTime) / 1000);
    if (prescriptionId) {
      consultation.prescriptionId = prescriptionId;
      consultation.hasPrescription = true;
    }

    await consultation.save();

    // Send system message
    const systemMessage = new ConsultationMessage({
      consultationId,
      senderId: consultation.doctorId,
      senderName: 'System',
      senderRole: 'doctor',
      message: 'Consultation has ended.',
      isSystemMessage: true,
      timestamp: new Date()
    });

    await systemMessage.save();

    res.json({
      success: true,
      message: 'Consultation ended successfully',
      consultation,
      duration: consultation.duration
    });
  } catch (error) {
    console.error('Error ending consultation:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to end consultation',
      error: error.message
    });
  }
};

// Get consultation by appointment ID
exports.getConsultationByAppointment = async (req, res) => {
  try {
    await connectMongoDB();
    const { appointmentId } = req.params;

    if (!isValidObjectId(appointmentId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid appointment ID'
      });
    }

    // Search across all statuses so completed appointments also return their consultation
    const consultation = await Consultation.findOne({ appointmentId })
      .sort({ createdAt: -1 }) // newest first in case multiple exist
      .populate('patientId', 'name email phone')
      .populate('doctorId', 'name email phone specialization')
      .lean(); // return plain object — prescriptionId stays as ObjectId string

    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'No consultation found for this appointment'
      });
    }

    // Ensure prescriptionId is always returned as a plain string, not a populated object
    const consultationObj = {
      ...consultation,
      prescriptionId: consultation.prescriptionId
        ? consultation.prescriptionId.toString()
        : null,
    };

    res.json({
      success: true,
      consultationId: consultation._id,
      consultation: consultationObj
    });
  } catch (error) {
    console.error('Error getting consultation by appointment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get consultation',
      error: error.message
    });
  }
};

// Get consultation details
exports.getConsultation = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;

    const consultation = await Consultation.findById(consultationId)
      .populate('patientId', 'name email phone')
      .populate('doctorId', 'name email phone specialization')
      .populate('prescriptionId');

    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    res.json({
      success: true,
      consultation
    });
  } catch (error) {
    console.error('Error getting consultation:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get consultation',
      error: error.message
    });
  }
};

// Get consultation timer status
exports.getTimerStatus = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    const now = new Date();
    const elapsed = Math.floor((now - consultation.startTime) / 1000);
    const minDuration = 600; // 10 minutes
    const maxDuration = 1800; // 30 minutes

    const canEnd = elapsed >= minDuration;
    const hasReachedMaximum = elapsed >= maxDuration;
    const remainingTime = maxDuration - elapsed;

    res.json({
      success: true,
      elapsed,
      canEnd,
      hasReachedMaximum,
      remainingTime: remainingTime > 0 ? remainingTime : 0,
      minDuration,
      maxDuration
    });
  } catch (error) {
    console.error('Error getting timer status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get timer status',
      error: error.message
    });
  }
};

// Save doctor notes during consultation
exports.saveDoctorNotes = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const { notes } = req.body;

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({ success: false, message: 'Consultation not found' });
    }

    consultation.doctorNotes = notes || '';
    await consultation.save();

    res.json({ success: true, message: 'Notes saved', doctorNotes: consultation.doctorNotes });
  } catch (error) {
    console.error('Error saving doctor notes:', error);
    res.status(500).json({ success: false, message: 'Failed to save notes', error: error.message });
  }
};
