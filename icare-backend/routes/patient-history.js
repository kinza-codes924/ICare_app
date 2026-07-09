const express = require('express');
const router = express.Router();
const patientHistoryController = require('../controllers/patientHistoryController');

// Create patient history (POST only)
router.post('/create', patientHistoryController.createPatientHistory);

// Explicitly block GET /create so it never falls through to /:historyId
router.get('/create', (req, res) => {
  res.status(405).json({ success: false, message: 'Method Not Allowed. Use POST /create' });
});

// Get patient history by patient ID
router.get('/patient/:patientId', patientHistoryController.getPatientHistory);

// Get latest history for patient — must be BEFORE /:historyId
router.get('/patient/:patientId/latest', patientHistoryController.getLatestHistory);

// Get history by consultation ID
router.get('/consultation/:consultationId', patientHistoryController.getHistoryByConsultation);

// Update patient history — must be BEFORE /:historyId GET
router.put('/:historyId/update', patientHistoryController.updatePatientHistory);

// Get history by ID — keep LAST so it doesn't swallow other routes
router.get('/:historyId', patientHistoryController.getHistoryById);

module.exports = router;
