const express = require('express');
const router = express.Router();
const consultationV2Controller = require('../controllers/consultationV2Controller');

// Get consultation by appointment ID
router.get('/by-appointment/:appointmentId', consultationV2Controller.getConsultationByAppointment);

// Start consultation
router.post('/start-v2', consultationV2Controller.startConsultation);

// Send message
router.post('/:consultationId/messages', consultationV2Controller.sendMessage);

// Get messages
router.get('/:consultationId/messages', consultationV2Controller.getMessages);

// End consultation
router.post('/:consultationId/end', consultationV2Controller.endConsultation);

// Get consultation details
router.get('/:consultationId', consultationV2Controller.getConsultation);

// Get timer status
router.get('/:consultationId/timer', consultationV2Controller.getTimerStatus);

// Save doctor's notes (PATCH or PUT)
router.patch('/:consultationId/notes', consultationV2Controller.saveDoctorNotes);
router.put('/:consultationId/notes', consultationV2Controller.saveDoctorNotes);

module.exports = router;
