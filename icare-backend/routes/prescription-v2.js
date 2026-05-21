const express = require('express');
const router = express.Router();
const prescriptionV2Controller = require('../controllers/prescriptionV2Controller');

// Save prescription draft
router.post('/consultations/:consultationId/prescription/draft', prescriptionV2Controller.savePrescriptionDraft);

// Get prescription draft
router.get('/consultations/:consultationId/prescription/draft', prescriptionV2Controller.getPrescriptionDraft);

// Complete prescription
router.post('/consultations/:consultationId/prescription/complete', prescriptionV2Controller.completePrescription);

// Get completed prescription by consultationId (fallback when prescriptionId not stored on consultation)
router.get('/consultations/:consultationId/prescription/completed', prescriptionV2Controller.getCompletedPrescriptionByConsultation);

// Get prescription by ID
router.get('/prescriptions/:prescriptionId', prescriptionV2Controller.getPrescription);

// Get patient prescriptions
router.get('/patients/:patientId/prescriptions', prescriptionV2Controller.getPatientPrescriptions);

// Get doctor prescriptions
router.get('/doctors/:doctorId/prescriptions', prescriptionV2Controller.getDoctorPrescriptions);

// Update prescription status
router.patch('/prescriptions/:prescriptionId/status', prescriptionV2Controller.updatePrescriptionStatus);

module.exports = router;
