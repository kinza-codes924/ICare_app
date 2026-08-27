const crypto = require('crypto');
const { sendEmail } = require('./email');

const OTP_TTL_MINUTES = 10;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 5;

// Six digits, generated from a CSPRNG rather than Math.random() — this is an
// account-ownership proof, so a predictable sequence would defeat the point.
function generateOtp() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

// Only the hash is ever stored. A database dump can't be replayed to complete
// someone else's pending signup.
function hashOtp(otp) {
  return crypto.createHash('sha256').update(String(otp)).digest('hex');
}

// Constant-time compare so response timing doesn't leak how much of a guess
// was correct.
function otpMatches(submitted, storedHash) {
  if (!storedHash) return false;
  const a = Buffer.from(hashOtp(submitted), 'hex');
  const b = Buffer.from(storedHash, 'hex');
  if (a.length !== b.length) return false;
  try {
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

function otpEmailHtml({ name, otp }) {
  return `
    <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#f8fafc;">
      <div style="background:#0036BC;padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">
        <div style="background:#fff;display:inline-block;border-radius:12px;padding:8px 16px;margin-bottom:14px;">
          <img src="https://icare.com.co/assets/assets/images/logo.png" alt="iCare" style="height:44px;display:block;"/>
        </div>
        <h2 style="color:#fff;margin:0;font-size:21px;">Verify your email</h2>
      </div>
      <div style="background:#fff;padding:32px;border-radius:0 0 12px 12px;box-shadow:0 4px 20px rgba(0,0,0,0.06);">
        <p style="color:#374151;font-size:15px;margin-top:0;">Hi <strong>${name || 'there'}</strong>,</p>
        <p style="color:#374151;font-size:14px;">Enter this code in the app to finish creating your iCare account:</p>
        <div style="text-align:center;margin:26px 0;">
          <div style="display:inline-block;background:#EFF6FF;color:#0036BC;font-size:34px;font-weight:800;letter-spacing:9px;padding:16px 28px;border-radius:12px;font-family:monospace;">${otp}</div>
        </div>
        <p style="color:#64748b;font-size:13px;text-align:center;">This code expires in ${OTP_TTL_MINUTES} minutes.</p>
        <div style="background:#FEF3C7;border-radius:8px;padding:12px 16px;margin:22px 0;">
          <p style="color:#92400E;font-size:13px;margin:0;">Didn't try to sign up? You can ignore this email — no account is created until the code is entered.</p>
        </div>
        <hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">
        <p style="color:#94A3B8;font-size:12px;text-align:center;margin:0;">
          iCare Healthcare Platform &nbsp;|&nbsp;
          <a href="https://icare.com.co" style="color:#0036BC;text-decoration:none;">icare.com.co</a>
        </p>
      </div>
    </div>`;
}

async function sendOtpEmail({ to, name, otp }) {
  return sendEmail({
    to,
    subject: `${otp} is your iCare verification code`,
    html: otpEmailHtml({ name, otp }),
  });
}

module.exports = {
  OTP_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  MAX_ATTEMPTS,
  generateOtp,
  hashOtp,
  otpMatches,
  sendOtpEmail,
};
