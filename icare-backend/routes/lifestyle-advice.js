const express = require('express');
const router = express.Router();
const lifestyleAdviceController = require('../controllers/lifestyleAdviceController');

// Get lifestyle advice templates
router.get('/templates', lifestyleAdviceController.getTemplates);

// Create lifestyle advice
router.post('/create', lifestyleAdviceController.createLifestyleAdvice);

// Get lifestyle advice by consultation ID
router.get('/consultation/:consultationId', lifestyleAdviceController.getAdviceByConsultation);

// Get lifestyle advice by prescription ID
router.get('/prescription/:prescriptionId', lifestyleAdviceController.getAdviceByPrescription);

// Get lifestyle advice by ID
router.get('/:adviceId', lifestyleAdviceController.getAdviceById);

// Update lifestyle advice
router.put('/:adviceId/update', lifestyleAdviceController.updateLifestyleAdvice);

module.exports = router;
