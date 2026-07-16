// Google Drive backup for LMS live-session recordings.
//
// Recordings still play from Cloudinary/Vercel Blob inside the app (Drive's
// share links don't stream reliably in an HTML5 <video> tag for larger
// files — Google serves a virus-scan interstitial instead of the raw
// stream past a certain size). This module additionally copies each
// finished recording into a specific Google Drive folder for the client's
// own long-term archival, alongside (not instead of) the in-app copy.
//
// Auth is OAuth2 (3-legged), not the account password — Google has not
// supported password-based API access in years. One-time setup:
//   1. Google Cloud Console (console.cloud.google.com), signed in as the
//      target Gmail account:
//        - Create/select a project.
//        - Enable the "Google Drive API".
//        - OAuth consent screen: External, add the Gmail account as a
//          test user (or publish it — test mode is fine for this).
//        - Credentials > Create Credentials > OAuth client ID > type
//          "Desktop app". Note the Client ID + Client Secret.
//   2. Get a refresh token via Google's OAuth Playground
//      (developers.google.com/oauthplayground):
//        - Gear icon > "Use your own OAuth credentials" > paste the
//          Client ID + Secret from step 1.
//        - Step 1: find "Drive API v3", check
//          https://www.googleapis.com/auth/drive.file > Authorize APIs >
//          sign in as the target Gmail account > Allow.
//        - Step 2: "Exchange authorization code for tokens" > copy the
//          Refresh Token.
//   3. In Google Drive (as that same account), create/choose the target
//      folder, open it, copy the folder id from the URL
//      (drive.google.com/drive/folders/<FOLDER_ID>).
//   4. Set on the backend (Vercel env vars for icare-backend):
//        GOOGLE_DRIVE_CLIENT_ID
//        GOOGLE_DRIVE_CLIENT_SECRET
//        GOOGLE_DRIVE_REFRESH_TOKEN
//        GOOGLE_DRIVE_FOLDER_ID
//
// If these aren't set, uploadRecordingToDrive() is a no-op (returns null)
// so recording-finalize still succeeds normally without Drive configured.

const { google } = require('googleapis');
const { Readable } = require('stream');

function isConfigured() {
  return !!(
    process.env.GOOGLE_DRIVE_CLIENT_ID &&
    process.env.GOOGLE_DRIVE_CLIENT_SECRET &&
    process.env.GOOGLE_DRIVE_REFRESH_TOKEN &&
    process.env.GOOGLE_DRIVE_FOLDER_ID
  );
}

function getDriveClient() {
  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_DRIVE_CLIENT_ID,
    process.env.GOOGLE_DRIVE_CLIENT_SECRET
  );
  oauth2Client.setCredentials({ refresh_token: process.env.GOOGLE_DRIVE_REFRESH_TOKEN });
  return google.drive({ version: 'v3', auth: oauth2Client });
}

// Uploads a recording buffer to the configured Drive folder. Returns
// { fileId, webViewLink } on success, or null if Drive isn't configured
// (caller should treat this as "skip, not an error").
async function uploadRecordingToDrive(buffer, filename, mimeType = 'video/mp4') {
  if (!isConfigured()) return null;

  const drive = getDriveClient();
  const stream = Readable.from(buffer);

  const res = await drive.files.create({
    requestBody: {
      name: filename,
      parents: [process.env.GOOGLE_DRIVE_FOLDER_ID],
    },
    media: {
      mimeType,
      body: stream,
    },
    fields: 'id, webViewLink',
  });

  return { fileId: res.data.id, webViewLink: res.data.webViewLink };
}

// Fetches a Cloudinary/Blob URL's bytes and copies them into Drive —
// used when the finalize call already uploaded to Cloudinary and we just
// want a Drive backup copy of the same file, without re-reading the
// (already-consumed) multipart stream.
async function backupUrlToDrive(url, filename, mimeType = 'video/mp4') {
  if (!isConfigured()) return null;
  // Node 18+ (Vercel's runtime) has a built-in global fetch — no extra dependency needed.
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Fetch for Drive backup failed: ${resp.status}`);
  const buffer = Buffer.from(await resp.arrayBuffer());
  return uploadRecordingToDrive(buffer, filename, mimeType);
}

module.exports = { isConfigured, uploadRecordingToDrive, backupUrlToDrive };
