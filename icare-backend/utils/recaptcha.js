// reCAPTCHA v2 ("I'm not a robot" checkbox) server-side verification.
// Returns { ok, reason } — never throws, so a Google outage or missing
// token can't itself take down login. v2's siteverify response has no
// score/action fields (unlike v3) — success/failure is the whole signal,
// and success already required the user to pass the visible challenge.
async function verifyRecaptcha(token) {
  const secret = process.env.RECAPTCHA_SECRET_KEY;
  if (!secret) return { ok: true, reason: 'not_configured' };
  if (!token) return { ok: false, reason: 'no_token' };

  try {
    const res = await fetch('https://www.google.com/recaptcha/api/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ secret, response: token }).toString(),
    });
    const data = await res.json();
    if (!data.success) return { ok: false, reason: 'verify_failed', errors: data['error-codes'] };
    return { ok: true, reason: 'ok' };
  } catch (e) {
    return { ok: true, reason: 'request_error' };
  }
}

module.exports = { verifyRecaptcha };
