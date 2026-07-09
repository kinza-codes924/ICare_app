const express = require('express');
const router = express.Router();
const { authMiddleware: protect } = require('../middleware/auth');
const consultationController = require('../controllers/consultationController');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');

// Memory storage — Cloudinary uploads from buffer (Vercel-safe)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter(req, file, cb) {
    if (/jpeg|jpg|png|pdf/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only images and PDFs are allowed'));
  },
});

// Start consultation
router.post('/start', protect, consultationController.startConsultation);

// Get consultation details
router.get('/:consultationId', protect, consultationController.getConsultation);

// Send message
router.post('/:consultationId/messages', protect, consultationController.sendMessage);

// Get messages
router.get('/:consultationId/messages', protect, consultationController.getMessages);

// End consultation
router.post('/:consultationId/end', protect, consultationController.endConsultation);

// Upload attachment
router.post('/upload', protect, upload.single('file'), consultationController.uploadAttachment);

// Get my consultations
router.get('/', protect, consultationController.getMyConsultations);

module.exports = router;
