const EnhancedPrescription = require('../models/EnhancedPrescription');
const { connectMongoDB } = require('../config/mongodb');
const LifestyleAdvice = require('../models/LifestyleAdvice');
const Consultation = require('../models/Consultation');

// Save prescription draft
exports.savePrescriptionDraft = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const prescriptionData = req.body;

    // Verify consultation exists
    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Check if draft already exists
    let prescription = await EnhancedPrescription.findOne({
      consultationId,
      status: 'draft'
    });

    // Ensure doctorNotes has a default value
    if (!prescriptionData.doctorNotes) {
      prescriptionData.doctorNotes = '';
    }

    if (prescription) {
      // Update existing draft
      Object.assign(prescription, prescriptionData);
      prescription.isComplete = false;
      await prescription.save();
    } else {
      // Create new draft
      prescription = new EnhancedPrescription({
        ...prescriptionData,
        consultationId,
        patientId: consultation.patientId,
        doctorId: consultation.doctorId,
        status: 'draft',
        isComplete: false,
        prescribedAt: new Date()
      });
      await prescription.save();
    }

    res.json({
      success: true,
      prescriptionId: prescription._id,
      prescription,
      message: 'Prescription draft saved successfully'
    });
  } catch (error) {
    console.error('Error saving prescription draft:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save prescription draft',
      error: error.message
    });
  }
};

// Get prescription draft
exports.getPrescriptionDraft = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;

    const prescription = await EnhancedPrescription.findOne({
      consultationId,
      status: 'draft'
    })
      .populate('patientHistoryId')
      .populate('lifestyleAdviceId');

    if (!prescription) {
      return res.json({
        success: true,
        prescription: null,
        message: 'No draft found'
      });
    }

    res.json({
      success: true,
      prescription
    });
  } catch (error) {
    console.error('Error getting prescription draft:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get prescription draft',
      error: error.message
    });
  }
};

// Complete prescription
exports.completePrescription = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;
    const prescriptionData = req.body;

    // Verify consultation exists
    const consultation = await Consultation.findById(consultationId);
    if (!consultation) {
      return res.status(404).json({
        success: false,
        message: 'Consultation not found'
      });
    }

    // Find existing draft or create new
    let prescription = await EnhancedPrescription.findOne({
      consultationId,
      status: 'draft'
    });

    // Ensure doctorNotes has a default value
    if (!prescriptionData.doctorNotes) {
      prescriptionData.doctorNotes = '';
    }

    // Safe field assignment — only update allowed fields, skip patientId/doctorId to avoid CastError
    const safeFields = ['soapNotes', 'diagnoses', 'medicines', 'labTests',
      'referralFollowUp', 'lifestyleAdvice', 'doctorNotes', 'vitalSigns',
      'chiefComplaint', 'historyOfPresentIllness', 'clinicalFindings'];

    if (prescription) {
      for (const field of safeFields) {
        if (prescriptionData[field] !== undefined) {
          prescription[field] = prescriptionData[field];
        }
      }
    } else {
      prescription = new EnhancedPrescription({
        consultationId,
        patientId: consultation.patientId,
        doctorId: consultation.doctorId,
        prescribedAt: new Date(),
        status: 'draft',
        isComplete: false,
      });
      for (const field of safeFields) {
        if (prescriptionData[field] !== undefined) {
          prescription[field] = prescriptionData[field];
        }
      }
    }

    // Ensure doctorNotes
    if (!prescription.doctorNotes) prescription.doctorNotes = '';

    // Validate — require at least one clinical item
    const hasMeds = prescription.medicines && prescription.medicines.length > 0;
    const hasDiagnoses = prescription.diagnoses && prescription.diagnoses.length > 0;
    const hasLabTests = prescription.labTests && prescription.labTests.length > 0;
    const hasNotes = prescription.doctorNotes && prescription.doctorNotes.trim().length > 0;
    const hasSoap = prescription.soapNotes && (
      (prescription.soapNotes.subjective && prescription.soapNotes.subjective.trim()) ||
      (prescription.soapNotes.assessment && prescription.soapNotes.assessment.trim())
    );

    if (!hasMeds && !hasDiagnoses && !hasLabTests && !hasNotes && !hasSoap) {
      return res.status(400).json({
        success: false,
        message: 'Please add at least one item: diagnosis, medication, lab test, or doctor notes'
      });
    }

    // Mark as complete
    prescription.isComplete = true;
    prescription.status = 'active';
    const expirationDate = new Date();
    expirationDate.setDate(expirationDate.getDate() + 30);
    prescription.expiresAt = expirationDate;

    await prescription.save();

    // Notify patient that a new prescription is ready
    if (prescription.patientId) {
      try {
        const Notification = require('../models/Notification');
        await Notification.create({
          userId: prescription.patientId,
          type: 'prescription',
          title: 'New Prescription',
          message: 'Your doctor has sent you a new prescription. Tap to view details.',
          data: { prescriptionId: prescription._id.toString(), consultationId },
          read: false,
        });
      } catch (notifErr) { console.error('Prescription notification error:', notifErr.message); }
    }

    // Update consultation — non-blocking
    Consultation.findByIdAndUpdate(
      consultationId,
      { $set: { prescriptionId: prescription._id, hasPrescription: true } },
      { new: true }
    ).catch(e => console.error('Consultation update warning:', e.message));

    res.json({
      success: true,
      prescriptionId: prescription._id,
      prescription,
      message: 'Prescription completed successfully'
    });
  } catch (error) {
    console.error('Error completing prescription:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to complete prescription',
      error: error.message
    });
  }
};

// Get completed prescription by consultationId (fallback lookup)
exports.getCompletedPrescriptionByConsultation = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;

    // Look for any non-draft prescription for this consultation
    const prescription = await EnhancedPrescription.findOne({
      consultationId,
      status: { $ne: 'draft' }
    })
      .sort({ createdAt: -1 })
      .populate('patientId', 'name email phone age gender')
      .populate('doctorId', 'name email phone specialization pmdcLicense')
      .populate('patientHistoryId')
      .populate('lifestyleAdviceId')
      .populate('assignedCourseIds', 'title description');

    if (!prescription) {
      // Try any status as last resort
      const anyPrescription = await EnhancedPrescription.findOne({ consultationId })
        .sort({ createdAt: -1 })
        .populate('patientId', 'name email phone age gender')
        .populate('doctorId', 'name email phone specialization pmdcLicense')
        .populate('patientHistoryId')
        .populate('lifestyleAdviceId')
        .populate('assignedCourseIds', 'title description');

      if (!anyPrescription) {
        return res.status(404).json({ success: false, message: 'No prescription found for this consultation' });
      }
      return res.json({ success: true, prescription: anyPrescription });
    }

    res.json({ success: true, prescription });
  } catch (error) {
    console.error('Error getting prescription by consultation:', error);
    res.status(500).json({ success: false, message: 'Failed to get prescription', error: error.message });
  }
};

// Get prescription by ID
exports.getPrescription = async (req, res) => {
  try {
    await connectMongoDB();
    const { prescriptionId } = req.params;

    const prescription = await EnhancedPrescription.findById(prescriptionId)
      .populate('patientId', 'name email phone age gender')
      .populate('doctorId', 'name email phone specialization pmdcLicense')
      .populate('patientHistoryId')
      .populate('lifestyleAdviceId')
      .populate('assignedCourseIds', 'title description');

    if (!prescription) {
      return res.status(404).json({
        success: false,
        message: 'Prescription not found'
      });
    }

    res.json({
      success: true,
      prescription
    });
  } catch (error) {
    console.error('Error getting prescription:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get prescription',
      error: error.message
    });
  }
};

// Get patient prescriptions
exports.getPatientPrescriptions = async (req, res) => {
  try {
    await connectMongoDB();
    const { patientId } = req.params;
    const { status, limit = 20, skip = 0 } = req.query;

    const query = { patientId, isComplete: true };
    if (status) {
      query.status = status;
    }

    const prescriptions = await EnhancedPrescription.find(query)
      .populate('doctorId', 'name specialization')
      .sort({ prescribedAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await EnhancedPrescription.countDocuments(query);

    res.json({
      success: true,
      prescriptions,
      count: prescriptions.length,
      total
    });
  } catch (error) {
    console.error('Error getting patient prescriptions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get patient prescriptions',
      error: error.message
    });
  }
};

// Get doctor prescriptions
exports.getDoctorPrescriptions = async (req, res) => {
  try {
    await connectMongoDB();
    const { doctorId } = req.params;
    const { status, limit = 20, skip = 0 } = req.query;

    const query = { doctorId, isComplete: true };
    if (status) {
      query.status = status;
    }

    const prescriptions = await EnhancedPrescription.find(query)
      .populate('patientId', 'name age gender')
      .sort({ prescribedAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await EnhancedPrescription.countDocuments(query);

    res.json({
      success: true,
      prescriptions,
      count: prescriptions.length,
      total
    });
  } catch (error) {
    console.error('Error getting doctor prescriptions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get doctor prescriptions',
      error: error.message
    });
  }
};

// Update prescription status
exports.updatePrescriptionStatus = async (req, res) => {
  try {
    await connectMongoDB();
    const { prescriptionId } = req.params;
    const { status } = req.body;

    if (!['active', 'expired', 'cancelled'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status'
      });
    }

    const prescription = await EnhancedPrescription.findById(prescriptionId);
    if (!prescription) {
      return res.status(404).json({
        success: false,
        message: 'Prescription not found'
      });
    }

    prescription.status = status;
    await prescription.save();

    res.json({
      success: true,
      prescription,
      message: 'Prescription status updated successfully'
    });
  } catch (error) {
    console.error('Error updating prescription status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update prescription status',
      error: error.message
    });
  }
};
