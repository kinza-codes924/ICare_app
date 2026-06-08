const express = require('express');
const router = express.Router();
const multer = require('multer');
const { v2: cloudinary } = require('cloudinary');
const { authMiddleware: protect } = require('../middleware/auth');

// Use memory storage — Cloudinary uploads from buffer (Vercel-safe, no disk writes)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter(req, file, cb) {
    if (/jpeg|jpg|png|gif|webp|pdf/.test(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only images and PDFs are allowed'));
    }
  },
});

// Helper — upload buffer to Cloudinary
function uploadToCloudinary(buffer, folder, resourceType = 'image') {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: resourceType },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });
}

// POST /api/upload — consultation chat attachments (images + PDFs)
router.post('/', protect, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file provided' });
    }
    const isPdf = req.file.mimetype === 'application/pdf';
    const resourceType = isPdf ? 'raw' : 'image';
    const folder = req.body.folder || 'icare/consultation-attachments';
    const result = await uploadToCloudinary(req.file.buffer, folder, resourceType);
    res.json({ success: true, url: result.secure_url, publicId: result.public_id, resourceType });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/upload/image  — general image upload (product photos, avatars, etc.)
router.post('/image', protect, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file provided' });
    }
    const folder = req.body.folder || 'icare/general';
    const result = await uploadToCloudinary(req.file.buffer, folder);
    res.json({ success: true, url: result.secure_url, publicId: result.public_id });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/upload/prescription  — prescription image OR PDF (patient/doctor side)
router.post('/prescription', protect, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file provided' });
    }
    // PDFs must use resource_type:'raw' so Cloudinary stores them as documents,
    // not images. Images use the default 'image' resource type.
    const isPdf = req.file.mimetype === 'application/pdf';
    const resourceType = isPdf ? 'raw' : 'image';
    const result = await uploadToCloudinary(req.file.buffer, 'icare/prescriptions', resourceType);
    res.json({ success: true, url: result.secure_url, publicId: result.public_id, resourceType });
  } catch (err) {
    console.error('Prescription upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/upload/product  — pharmacy product / medicine image
router.post('/product', protect, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file provided' });
    }
    const result = await uploadToCloudinary(req.file.buffer, 'icare/products');
    res.json({ success: true, url: result.secure_url, publicId: result.public_id });
  } catch (err) {
    console.error('Product upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/upload/sign — returns Cloudinary signature for direct client-side upload
// Frontend uses this to upload large files (videos/images/docs) directly to Cloudinary
// bypassing Vercel's 4.5MB body limit
// Query params: folder (optional), resource_type (optional: image|video|raw|auto)
router.get('/sign', protect, async (req, res) => {
  try {
    const apiSecret = process.env.CLOUDINARY_API_SECRET || cloudinary.config().api_secret;
    const apiKey = process.env.CLOUDINARY_API_KEY || cloudinary.config().api_key;
    const cloudName = cloudinary.config().cloud_name;

    // Fail fast if credentials are missing — prevents Cloudinary 401
    if (!apiSecret) {
      console.error('CLOUDINARY_API_SECRET is not set in environment variables');
      return res.status(500).json({ success: false, message: 'Server Cloudinary configuration is incomplete (missing API secret)' });
    }
    if (!apiKey || !cloudName) {
      console.error('Cloudinary api_key or cloud_name missing');
      return res.status(500).json({ success: false, message: 'Server Cloudinary configuration is incomplete' });
    }

    const folder = req.query.folder || 'icare/media';
    const resourceType = req.query.resource_type || 'auto';
    const timestamp = Math.round(Date.now() / 1000);
    const paramsToSign = { folder, timestamp };

    const signature = cloudinary.utils.api_sign_request(paramsToSign, apiSecret);

    console.log(`Cloudinary sign: cloud=${cloudName} folder=${folder} resource_type=${resourceType}`);

    res.json({
      success: true,
      signature,
      timestamp,
      api_key: apiKey,
      cloud_name: cloudName,
      folder,
      resource_type: resourceType,
    });
  } catch (err) {
    console.error('Sign error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
