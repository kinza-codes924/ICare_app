// Local disk storage for documents (verification IDs, quiz/assignment files,
// PDFs) — replaces Vercel Blob entirely. Files land under a directory the
// backend owns and nginx serves read-only at /uploads/, so a stored URL is a
// plain public https link that opens straight in the browser (no proxy, no
// token dance — which is exactly what broke when the Vercel Blob token became
// [SENSITIVE] and every doc returned "Access denied").
//
// UPLOAD_DIR: where bytes are written. Defaults to /opt/icare/uploads, which
// nginx maps to https://icare.com.co/uploads/. Override via UPLOAD_DIR if the
// server layout differs.
// PUBLIC_BASE_URL: the origin the stored URL is built from (same var the rest
// of the backend already uses for outgoing links).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const UPLOAD_DIR = process.env.UPLOAD_DIR || '/opt/icare/uploads';
const PUBLIC_BASE = (process.env.PUBLIC_BASE_URL || 'https://icare.com.co').replace(/\/+$/, '');
// Public URL path nginx serves UPLOAD_DIR at.
const URL_PREFIX = '/uploads';

// Keep the original filename readable but strip anything that could escape the
// folder or confuse a URL. A short random prefix prevents collisions without
// relying on a DB lookup.
function safeName(originalname) {
  const base = String(originalname || 'file').replace(/[^a-zA-Z0-9._-]/g, '_').slice(-120);
  return `${Date.now()}-${crypto.randomBytes(4).toString('hex')}-${base}`;
}

// Writes a buffer under UPLOAD_DIR/<subdir>/ and returns { url, name, path }.
// `url` is the public https link to store in the DB.
function saveBuffer(buffer, originalname, subdir = 'docs') {
  // Confine subdir to a single safe path segment — never let a caller-supplied
  // value walk out of UPLOAD_DIR.
  const cleanSub = String(subdir).replace(/[^a-zA-Z0-9_-]/g, '_') || 'docs';
  const dir = path.join(UPLOAD_DIR, cleanSub);
  fs.mkdirSync(dir, { recursive: true });

  const fileName = safeName(originalname);
  const fullPath = path.join(dir, fileName);
  fs.writeFileSync(fullPath, buffer);

  return {
    url: `${PUBLIC_BASE}${URL_PREFIX}/${cleanSub}/${fileName}`,
    name: originalname,
    path: fullPath,
  };
}

module.exports = { saveBuffer, UPLOAD_DIR, URL_PREFIX };
