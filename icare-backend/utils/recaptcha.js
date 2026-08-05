// reCAPTCHA v3 server-side verification. Returns { ok, score, reason } —
// never throws, so a Google outage or missing token can't itself take down
// login. Score threshold follows Google's own documented default (0.5);
// below that we flag the attempt but still allow it through for now
// (soft-enforcement) since scores need real traffic to calibrate and a
// hard block on day one would risk locking out legitimate users.
async function verifyRecaptcha(token, expectedAction) {
  const secret = process.env.RECAPTCHA_SECRET_KEY;
  if (!secret) return { ok: true, score: null, reason: 'not_configured' };
  if (!token) return { ok: true, score: null, reason: 'no_token' };

  try {
    const res = await fetch('https://www.google.com/recaptcha/api/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ secret, response: token }).toString(),
    });
    const data = await res.json();
    if (!data.success) return { ok: true, score: null, reason: 'verify_failed', errors: data['error-codes'] };
    if (expectedAction && data.action !== expectedAction) {
      return { ok: true, score: data.score, reason: 'action_mismatch' };
    }
    const score = typeof data.score === 'number' ? data.score : null;
    return { ok: score === null || score >= 0.5, score, reason: score !== null && score < 0.5 ? 'low_score' : 'ok' };
  } catch (e) {
    return { ok: true, score: null, reason: 'request_error' };
  }
}

module.exports = { verifyRecaptcha };
