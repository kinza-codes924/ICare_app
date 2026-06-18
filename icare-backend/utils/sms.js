// Brevo Transactional SMS — uses same API key as email.
// Requires SMS credits on Brevo account (paid add-on).

function toE164(phone) {
  const digits = phone.replace(/\D/g, '');
  // Pakistani local format: 03XXXXXXXXX → +923XXXXXXXXX
  if (digits.startsWith('0') && digits.length === 11) {
    return '+92' + digits.slice(1);
  }
  // Already has country code without +
  if (!phone.startsWith('+')) return '+' + digits;
  return phone;
}

async function sendSms({ to, message }) {
  const recipient = toE164(to);
  const res = await fetch('https://api.brevo.com/v3/transactionalSMS/sms', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender: 'iCare',
      recipient,
      content: message,
      type: 'transactional',
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Brevo SMS error: ${err}`);
  }
  return res.json();
}

module.exports = { sendSms };
