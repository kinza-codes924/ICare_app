// Base URL for links that go OUT of the app — prescription PDFs, lab reports,
// pharmacy receipts embedded in emails.
//
// These used to be hardcoded to the Vercel deployment. Emails are permanent:
// a link baked into one sent months ago still has to resolve, so this is the
// one place to change if the host ever moves again.
//
// Set PUBLIC_BASE_URL in .env to override.
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || 'https://icare.com.co').replace(/\/+$/, '');

module.exports = { PUBLIC_BASE_URL };
