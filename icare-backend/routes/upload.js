const express = require('express');
const router = express.Router();
const crypto = require('crypto');
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
    const resourceType = isPdf ? 'auto' : 'image';
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
    const resourceType = isPdf ? 'auto' : 'image';
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

// GET /api/upload/doc-url?url=<encoded_cloudinary_url>
// Returns a signed delivery URL for Cloudinary raw/document resources.
// Required because some Cloudinary accounts restrict raw file public delivery (returns 401).
// Signed URLs bypass delivery restrictions by embedding a timed auth signature.
router.get('/doc-url', protect, async (req, res) => {
  try {
    const rawUrl = decodeURIComponent(req.query.url || '');
    if (!rawUrl) return res.status(400).json({ success: false, message: 'url required' });

    // If not a Cloudinary URL, return as-is (nothing to sign)
    if (!rawUrl.includes('res.cloudinary.com')) {
      return res.json({ success: true, url: rawUrl });
    }

    // Parse resource_type and public_id from URL
    // Format: https://res.cloudinary.com/{cloud}/{resource_type}/upload/[v123/]{public_id}
    const match = rawUrl.match(/res\.cloudinary\.com\/[^/]+\/([^/]+)\/upload\/(?:v\d+\/)?(.+)$/);
    if (!match) return res.json({ success: true, url: rawUrl });

    const resourceType = match[1]; // 'raw', 'image', 'video', 'auto'
    const publicId = match[2];     // 'icare/quiz/docs/filename.pdf'

    // Bypass the Cloudinary SDK's private_download_url because it incorrectly includes
    // `resource_type` and `format` in the HMAC signature, but Cloudinary's download endpoint
    // only signs: attachment, expires_at, public_id, timestamp.
    // Extra params in the signature cause Cloudinary to return "Resource not found" (its
    // deliberate security response to invalid signatures, not a real 404).
    const apiKey    = cloudinary.config().api_key;
    const apiSecret = process.env.CLOUDINARY_API_SECRET || cloudinary.config().api_secret;
    const cloudName = cloudinary.config().cloud_name;
    if (!apiSecret) return res.json({ success: true, url: rawUrl });

    const resolvedType = resourceType === 'auto' ? 'raw' : resourceType;
    const timestamp  = Math.floor(Date.now() / 1000);
    const expiresAt  = timestamp + 7200; // 2 hours

    const paramsToSign = { expires_at: expiresAt, public_id: publicId, timestamp, type: 'upload' };
    const signature = cloudinary.utils.api_sign_request(paramsToSign, apiSecret);

    const qs = new URLSearchParams({
      public_id:  publicId,
      type:       'upload',
      expires_at: String(expiresAt),
      timestamp:  String(timestamp),
      api_key:    apiKey,
      signature,
    }).toString();

    const downloadUrl = `https://api.cloudinary.com/v1_1/${cloudName}/${resolvedType}/download?${qs}`;
    console.log(`doc-url manual-sign: type=${resolvedType} pid=${publicId}`);
    res.json({ success: true, url: downloadUrl });
  } catch (e) {
    console.error('doc-url error:', e);
    // Fallback — return original URL so the app doesn't break
    res.json({ success: true, url: decodeURIComponent(req.query.url || '') });
  }
});

// GET /api/upload/doc-stream?url=<encoded_cloudinary_url>&token=<jwt>
// Streams the Cloudinary file content directly to the browser.
// Uses token in query string so url_launcher can open this as a plain browser URL.
// This completely bypasses Cloudinary CDN delivery restrictions because the backend
// fetches the file via the authenticated Cloudinary API and proxies the bytes.
router.get('/doc-stream', async (req, res) => {
  // Verify JWT from query param (needed because browser navigates directly to this URL)
  const token = req.query.token;
  if (!token) return res.status(401).send('Unauthorized');
  try {
    const jwt = require('jsonwebtoken');
    jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return res.status(401).send('Unauthorized');
  }

  const rawUrl = decodeURIComponent(req.query.url || '');
  if (!rawUrl) return res.status(400).send('url required');

  // Non-Cloudinary URLs: just redirect
  if (!rawUrl.includes('res.cloudinary.com')) {
    return res.redirect(rawUrl);
  }

  // Parse: https://res.cloudinary.com/{cloud}/{resource_type}/upload/[v123/]{public_id}
  const match = rawUrl.match(/res\.cloudinary\.com\/([^/]+)\/([^/]+)\/upload\/(?:v\d+\/)?(.+)$/);
  if (!match) return res.redirect(rawUrl);

  const cldCloud    = match[1];
  const resourceType = match[2] === 'auto' ? 'raw' : match[2];
  const publicId    = match[3]; // e.g. icare/quiz/docs/d7mk0u0lnuum1uxodch2.pdf

  const apiKey    = cloudinary.config().api_key;
  const apiSecret = process.env.CLOUDINARY_API_SECRET || cloudinary.config().api_secret;
  if (!apiSecret) return res.redirect(rawUrl);

  const timestamp = Math.floor(Date.now() / 1000);
  const expiresAt = timestamp + 7200;

  // Use the SDK's api_sign_request which correctly filters falsy values and sorts params.
  // The /download endpoint expects: expires_at, public_id, timestamp, type=upload (no resource_type, no format).
  const paramsToSign = { expires_at: expiresAt, public_id: publicId, timestamp, type: 'upload' };
  const signature = cloudinary.utils.api_sign_request(paramsToSign, apiSecret);

  const qs = new URLSearchParams({
    public_id:  publicId,
    type:       'upload',
    expires_at: String(expiresAt),
    timestamp:  String(timestamp),
    api_key:    apiKey,
    signature,
  }).toString();

  const downloadApiUrl = `https://api.cloudinary.com/v1_1/${cldCloud}/${resourceType}/download?${qs}`;
  console.log(`doc-stream: Admin API download type=${resourceType} pid=${publicId}`);

  // Helper to stream a successful fetch response back to client
  const streamResponse = async (fileRes) => {
    const ct = fileRes.headers.get('content-type') || 'application/octet-stream';
    const fileName = decodeURIComponent(publicId.split('/').pop() || 'document');
    const disposition = req.query.download === '1' ? 'attachment' : 'inline';
    res.setHeader('Content-Type', ct);
    res.setHeader('Content-Disposition', `${disposition}; filename="${fileName}"`);
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.setHeader('Access-Control-Allow-Origin', '*');
    const buf = await fileRes.arrayBuffer();
    return res.send(Buffer.from(buf));
  };

  try {
    // Attempt 1: Admin API download (bypasses CDN delivery restrictions entirely)
    const fileRes = await fetch(downloadApiUrl, { redirect: 'follow' });
    if (fileRes.ok) {
      return await streamResponse(fileRes);
    }
    const body1 = await fileRes.text();
    console.error(`doc-stream Admin API ${fileRes.status}:`, body1);

    // Attempt 2: Signed CDN URL (works when delivery requires signed-only, not fully blocked)
    const signedCdnUrl = cloudinary.url(publicId, {
      resource_type: resourceType,
      type: 'upload',
      sign_url: true,
      secure: true,
    });
    console.log(`doc-stream: Signed CDN fallback: ${signedCdnUrl}`);
    const cdnRes = await fetch(signedCdnUrl, { redirect: 'follow' });
    if (cdnRes.ok) {
      return await streamResponse(cdnRes);
    }
    const body2 = await cdnRes.text();
    console.error(`doc-stream Signed CDN ${cdnRes.status}:`, body2.slice(0, 200));

    // Both failed — fall through to error response
    return res.status(502).json({ error: 'Unable to fetch file from storage', adminStatus: fileRes.status, cdnStatus: cdnRes.status });
  } catch (e) {
    console.error('doc-stream error:', e);
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
