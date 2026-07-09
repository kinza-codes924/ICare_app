const nodemailer = require('nodemailer');

// Primary: Resend API (HTTP — works on Vercel serverless, no SMTP issues)
// Fallback: Nodemailer Gmail SMTP port 465
// Last resort: Brevo HTTP API

async function sendViaResend({ to, subject, html }) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'iCare <onboarding@resend.dev>',
      to: Array.isArray(to) ? to : [to],
      subject,
      html,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Resend error: ${err}`);
  }
  return res.json();
}

async function sendViaSmtp({ to, subject, html }) {
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    requireTLS: true,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
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
      sender: { name: 'iCare', email: 'icareofficialapp@gmail.com' },
      to: [{ email: Array.isArray(to) ? to[0] : to }],
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
  const errors = [];

  // 1. Try Resend (HTTP API — most reliable on Vercel)
  if (process.env.RESEND_API_KEY) {
    try {
      await sendViaResend({ to, subject, html });
      return;
    } catch (e) {
      errors.push(`Resend: ${e.message}`);
      console.error('Resend failed:', e.message);
    }
  }

  // 2. Try Gmail SMTP
  if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
    try {
      await sendViaSmtp({ to, subject, html });
      return;
    } catch (e) {
      errors.push(`SMTP: ${e.message}`);
      console.error('SMTP failed:', e.message);
    }
  }

  // 3. Try Brevo
  if (process.env.BREVO_API_KEY) {
    try {
      await sendViaBrevo({ to, subject, html });
      return;
    } catch (e) {
      errors.push(`Brevo: ${e.message}`);
      console.error('Brevo failed:', e.message);
    }
  }

  throw new Error(`All email providers failed: ${errors.join(' | ')}`);
};

module.exports = { sendEmail };
