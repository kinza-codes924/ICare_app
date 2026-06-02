const nodemailer = require('nodemailer');

// Primary: Nodemailer via Gmail SMTP (EMAIL_USER / EMAIL_PASS env vars)
// Fallback: Brevo HTTP API (BREVO_API_KEY env var)

async function sendViaSmtp({ to, subject, html }) {
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    tls: { rejectUnauthorized: false },
  });

  await transporter.sendMail({
    from: `"iCare" <${process.env.EMAIL_USER}>`,
    to,
    subject,
    html,
  });
}

async function sendViaBrevo({ to, subject, html }) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender: { name: 'iCare', email: process.env.EMAIL_USER || 'icareofficialapp@gmail.com' },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Brevo error: ${err}`);
  }
  return res.json();
}

const sendEmail = async ({ to, subject, html }) => {
  // Try SMTP first (Gmail), fall back to Brevo
  if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
    try {
      await sendViaSmtp({ to, subject, html });
      return;
    } catch (smtpErr) {
      console.error('SMTP email failed, trying Brevo:', smtpErr.message);
    }
  }
  await sendViaBrevo({ to, subject, html });
};

module.exports = { sendEmail };
