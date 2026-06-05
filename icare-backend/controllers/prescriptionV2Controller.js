const fs = require('fs');
const path = require('path');
const EnhancedPrescription = require('../models/EnhancedPrescription');
const { connectMongoDB } = require('../config/mongodb');
const LifestyleAdvice = require('../models/LifestyleAdvice');
const Consultation = require('../models/Consultation');
const User = require('../models/User');
const { sendEmail } = require('../utils/email');

let _logoB64 = '';
try { _logoB64 = fs.readFileSync(path.join(__dirname, '..', 'logo_b64.txt'), 'utf8').trim(); } catch (_) {}

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

      // Send prescription email to patient
      try {
        const patient = await User.findById(prescription.patientId).lean();
        if (patient?.email && patient?.prescriptionEmailEnabled !== false) {
          const medsHtml = (prescription.medicines || []).map((m, i) =>
            `<tr>
              <td style="padding:8px 12px;border-bottom:1px solid #f1f5f9;">${i + 1}. ${m.medicineName || m.name || 'Medicine'}</td>
              <td style="padding:8px 12px;border-bottom:1px solid #f1f5f9;color:#64748b;">${m.dosage || m.dose || ''}</td>
              <td style="padding:8px 12px;border-bottom:1px solid #f1f5f9;color:#64748b;">${m.frequency || ''}</td>
              <td style="padding:8px 12px;border-bottom:1px solid #f1f5f9;color:#64748b;">${m.duration || ''}</td>
            </tr>`
          ).join('');
          const labsHtml = (prescription.labTests || []).map(t =>
            `<li style="margin-bottom:4px;color:#374151;">${t.testName || t.name || t}</li>`
          ).join('');
          const diagnosesHtml = (prescription.diagnoses || []).map(d =>
            `<span style="display:inline-block;background:#EFF6FF;color:#1D4ED8;padding:3px 10px;border-radius:20px;font-size:13px;margin:2px;">${d.diagnosis || d.name || d}</span>`
          ).join('');

          console.log('[Prescription] Sending email to:', patient.email);
          await sendEmail({
            to: patient.email,
            subject: 'iCare — Your Prescription is Ready',
            html: `
              <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;background:#f8fafc;">
                <div style="background:#0036BC;padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">
                  <div style="background:#fff;display:inline-block;border-radius:12px;padding:8px 16px;margin-bottom:14px;"><img src="https://www.icare.com.co/assets/assets/images/logo.png" alt="iCare" style="height:48px;display:block;"/></div>
                  <h2 style="color:#fff;margin:0;font-size:22px;">iCare Prescription</h2>
                  <p style="color:rgba(255,255,255,0.8);margin:4px 0 0;font-size:14px;">Your doctor has completed your prescription</p>
                </div>
                <div style="background:#fff;padding:32px;border-radius:0 0 12px 12px;box-shadow:0 4px 20px rgba(0,0,0,0.06);">
                  <p style="color:#374151;font-size:15px;">Dear <strong>${patient.name || patient.username || 'Patient'}</strong>,</p>
                  <p style="color:#374151;font-size:14px;">Your doctor has issued a prescription for you. Please find the details below.</p>
                  ${diagnosesHtml ? `<div style="margin:16px 0;"><strong style="color:#0F172A;font-size:14px;">Diagnosis:</strong><br/><div style="margin-top:8px;">${diagnosesHtml}</div></div>` : ''}
                  ${medsHtml ? `
                  <div style="margin:20px 0;">
                    <strong style="color:#0F172A;font-size:14px;">Medicines:</strong>
                    <table style="width:100%;border-collapse:collapse;margin-top:10px;font-size:13px;">
                      <thead><tr style="background:#f8fafc;">
                        <th style="padding:8px 12px;text-align:left;color:#64748b;font-weight:600;">Medicine</th>
                        <th style="padding:8px 12px;text-align:left;color:#64748b;font-weight:600;">Dosage</th>
                        <th style="padding:8px 12px;text-align:left;color:#64748b;font-weight:600;">Frequency</th>
                        <th style="padding:8px 12px;text-align:left;color:#64748b;font-weight:600;">Duration</th>
                      </tr></thead>
                      <tbody>${medsHtml}</tbody>
                    </table>
                  </div>` : ''}
                  ${labsHtml ? `
                  <div style="margin:20px 0;">
                    <strong style="color:#0F172A;font-size:14px;">Lab Tests Ordered:</strong>
                    <ul style="margin-top:8px;padding-left:20px;">${labsHtml}</ul>
                  </div>` : ''}
                  ${prescription.doctorNotes ? `<div style="background:#f8fafc;border-left:3px solid #0036BC;padding:12px 16px;margin:20px 0;border-radius:4px;"><strong style="color:#0F172A;font-size:13px;">Doctor's Notes:</strong><p style="color:#374151;font-size:13px;margin:4px 0 0;">${prescription.doctorNotes}</p></div>` : ''}
                  <div style="background:#FEF3C7;border-radius:8px;padding:12px 16px;margin:20px 0;">
                    <p style="color:#92400E;font-size:13px;margin:0;">This prescription is valid for <strong>30 days</strong>. Open the iCare app to order medicines or book lab tests.</p>
                  </div>
                  <p style="color:#94A3B8;font-size:12px;margin-top:24px;">— iCare Health Technologies</p>
                </div>
              </div>
            `,
          });
        }
        console.log('[Prescription] Email sent successfully to:', patient.email);
      } catch (emailErr) { console.error('[Prescription] Email FAILED:', emailErr.message); }
    }

    // Award gamification points to patient for completing consultation
    if (prescription.patientId) {
      try {
        const patientForPoints = await User.findById(prescription.patientId);
        if (patientForPoints && patientForPoints.role === 'Patient') {
          if (!patientForPoints.gamification) patientForPoints.gamification = { points: 0, stats: {}, history: [] };
          patientForPoints.gamification.points = (patientForPoints.gamification.points || 0) + 20;
          patientForPoints.gamification.stats = patientForPoints.gamification.stats || {};
          patientForPoints.gamification.stats.completedAppointments = (patientForPoints.gamification.stats.completedAppointments || 0) + 1;
          patientForPoints.gamification.history = patientForPoints.gamification.history || [];
          patientForPoints.gamification.history.push({ points: 20, reason: 'complete_appointment', date: new Date().toISOString() });
          patientForPoints.markModified('gamification');
          await patientForPoints.save();
        }
      } catch (_) {}
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
