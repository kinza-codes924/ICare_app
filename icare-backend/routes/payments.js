// ─── Safepay Payment Gateway (Express Checkout) ──────────────────────────────
// Flow: create session -> redirect user to hosted checkout -> webhook + verify -> fulfill.
// SAFETY RULES enforced here:
//  1. Amount is ALWAYS calculated server-side from the DB (client amount is never trusted).
//  2. Fulfillment (enrollment etc.) happens ONLY after Safepay confirms TRACKER_ENDED / payment.succeeded.
//  3. Amount returned by Safepay is re-checked against our Payment record (mismatch -> ALERT, no fulfill).
//  4. Webhook signature (HMAC-SHA512, X-SFPY-SIGNATURE) is verified before anything else.
//  5. Idempotent: duplicate webhooks / double verify can never double-fulfill (fulfilled flag).
//  6. Every step is logged to PaymentLog (append-only) + console for Vercel logs.
//
// ENV required (Vercel project `icare-backend`):
//   SAFEPAY_API_KEY        = sec_... (public key from dashboard Developer > API)
//   SAFEPAY_SECRET_KEY     = secret key from dashboard Developer > API
//   SAFEPAY_WEBHOOK_SECRET = shared secret from dashboard Developers > Endpoints (View shared secret)
//   SAFEPAY_ENV            = sandbox | production   (default sandbox)

const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');
const mongoose = require('mongoose');

const Payment = require('../models/Payment');
const PaymentLog = require('../models/PaymentLog');
const Course = require('../models/Course');
const Enrollment = require('../models/Enrollment');
const { Voucher, applyVoucherDiscount } = require('./vouchers');

// ─── Config helpers ───────────────────────────────────────────────────────────
const SAFEPAY_ENV = () => (process.env.SAFEPAY_ENV === 'production' ? 'production' : 'sandbox');
const SAFEPAY_HOST = () =>
  SAFEPAY_ENV() === 'production' ? 'https://api.getsafepay.com' : 'https://sandbox.api.getsafepay.com';

const toId = (v) => {
  try { return new mongoose.Types.ObjectId(String(v)); } catch { return null; }
};

// ─── Logging (DB + console; DB failure must never break the payment flow) ─────
async function plog({ paymentId = null, tracker = null, userId = null, step, level = 'INFO', message = null, payload = null }) {
  const line = `[SAFEPAY][${level}][${step}] payment=${paymentId || '-'} tracker=${tracker || '-'} ${message || ''}`;
  if (level === 'ALERT' || level === 'ERROR') console.error(line, payload || '');
  else console.log(line, payload ? JSON.stringify(payload).slice(0, 500) : '');
  try {
    await PaymentLog.create({ paymentId, safepayTracker: tracker, userId, step, level, message, payload });
  } catch (e) {
    console.error('[SAFEPAY][ERROR][LOG_WRITE_FAILED]', e.message);
  }
}

// ─── Safepay HTTP helpers (Node 18+ global fetch) ──────────────────────────────
async function safepayPost(path, body) {
  const res = await fetch(`${SAFEPAY_HOST()}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-SFPY-MERCHANT-SECRET': process.env.SAFEPAY_SECRET_KEY || '',
    },
    body: JSON.stringify(body || {}),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = json?.status?.message || json?.message || `Safepay HTTP ${res.status}`;
    const err = new Error(msg);
    err.safepay = json;
    throw err;
  }
  return json;
}

async function safepayGet(path) {
  const res = await fetch(`${SAFEPAY_HOST()}${path}`, {
    headers: { 'X-SFPY-MERCHANT-SECRET': process.env.SAFEPAY_SECRET_KEY || '' },
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json?.status?.message || `Safepay HTTP ${res.status}`);
    err.safepay = json;
    throw err;
  }
  return json;
}

// ─── Server-side amount calculation per payment type ──────────────────────────
// Returns { amount (PKR rupees), description, voucherCode } or throws.
async function calculateAmount({ type, refId, voucherCode, userId }) {
  if (type === 'course') {
    const course = await Course.findById(refId).lean();
    if (!course) throw new Error('Course not found');
    let amount = course.isFree ? 0 : (course.discountedPrice || course.price || 0);
    let appliedVoucher = null;
    if (voucherCode) {
      const voucher = await Voucher.findOne({ code: String(voucherCode).trim().toUpperCase() });
      if (!voucher) throw new Error('Invalid voucher code');
      if (voucher.usedBy) throw new Error('This voucher has already been used');
      if (voucher.expiresAt && new Date() > voucher.expiresAt) throw new Error('Voucher has expired');
      if (voucher.courseId && voucher.courseId.toString() !== String(refId)) {
        throw new Error('Voucher is not valid for this course');
      }
      amount = applyVoucherDiscount(voucher, course.price || 0);
      appliedVoucher = voucher.code;
    }
    return { amount: Math.max(0, Number(amount) || 0), description: `Course: ${course.title || refId}`, voucherCode: appliedVoucher };
  }
  // Future: appointment / lab / pharmacy amount calculation goes here.
  throw new Error(`Payment type '${type}' not supported yet`);
}

// ─── Fulfillment: executes the business action exactly once ───────────────────
async function fulfillPayment(payment) {
  if (payment.fulfilled) {
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'DUPLICATE_IGNORED', message: 'Already fulfilled — idempotent skip' });
    return { alreadyFulfilled: true };
  }

  if (payment.type === 'course') {
    let enrollment;
    try {
      enrollment = await Enrollment.create({
        userId: payment.userId,
        courseId: payment.refId,
        amountPaid: payment.amount,
        voucherCode: payment.voucherCode || null,
      });
    } catch (e) {
      if (e.code === 11000) {
        enrollment = await Enrollment.findOne({ userId: payment.userId, courseId: payment.refId });
        await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'DUPLICATE_IGNORED', level: 'WARN', message: 'Enrollment already existed' });
      } else throw e;
    }

    // Redeem voucher only now (after real payment)
    if (payment.voucherCode) {
      const voucher = await Voucher.findOne({ code: payment.voucherCode });
      if (voucher && !voucher.usedBy) {
        voucher.usedBy = payment.userId;
        voucher.usedAt = new Date();
        await voucher.save();
      }
    }

    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    payment.fulfillmentRef = enrollment?._id || null;
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Enrollment ${enrollment?._id} created for course ${payment.refId}` });
    return { enrollment };
  }

  throw new Error(`No fulfillment handler for type '${payment.type}'`);
}

// ─── Mark payment paid after Safepay confirmation (shared by webhook + verify) ─
async function markPaidAndFulfill(payment, safepayData, source) {
  // Amount integrity check
  const spAmount = safepayData?.purchase_totals?.quote_amount?.amount
    ?? safepayData?.amount ?? null;
  if (spAmount !== null && Number(spAmount) !== Number(payment.amountLowest)) {
    await plog({
      paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId,
      step: 'AMOUNT_MISMATCH', level: 'ALERT',
      message: `Safepay amount ${spAmount} != expected ${payment.amountLowest} — NOT fulfilling`,
      payload: { safepayData, source },
    });
    return { ok: false, reason: 'amount_mismatch' };
  }

  if (payment.status !== 'paid') {
    payment.status = 'paid';
    payment.paidAt = new Date();
    payment.safepayState = safepayData?.state || 'TRACKER_ENDED';
    payment.safepayResponse = safepayData || null;
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'STATUS_CHANGED', message: `-> paid (via ${source})` });
  }
  const result = await fulfillPayment(payment);
  return { ok: true, ...result };
}

// ─── POST /api/payments/create ────────────────────────────────────────────────
// Body: { type: 'course', refId, voucherCode?, redirectUrl, cancelUrl }
router.post('/create', authMiddleware, async (req, res) => {
  let payment = null;
  try {
    await connectMongoDB();
    const { type, refId, voucherCode, redirectUrl, cancelUrl } = req.body;
    const userId = toId(req.user.id);

    if (!type || !refId) return res.status(400).json({ success: false, message: 'type and refId required' });
    const rId = toId(refId);
    if (!rId) return res.status(400).json({ success: false, message: 'Invalid refId' });
    if (!process.env.SAFEPAY_API_KEY || !process.env.SAFEPAY_SECRET_KEY) {
      await plog({ userId, step: 'ERROR', level: 'ERROR', message: 'SAFEPAY keys not configured in env' });
      return res.status(500).json({ success: false, message: 'Payment gateway not configured' });
    }

    await plog({ userId, step: 'PAYMENT_CREATE_REQUESTED', payload: { type, refId, voucherCode: voucherCode || null } });

    // 1. Server-side amount
    const { amount, description, voucherCode: appliedVoucher } = await calculateAmount({ type, refId: rId, voucherCode, userId });
    await plog({ userId, step: 'AMOUNT_CALCULATED', message: `${description} = PKR ${amount}` });

    // Free (or 100% voucher) — no gateway needed; client should call the normal endpoint.
    if (amount <= 0) {
      return res.json({ success: true, free: true, amount: 0, message: 'No payment required' });
    }

    const amountLowest = Math.round(amount * 100); // PKR lowest denomination

    // 2. Create local Payment record first (audit trail even if Safepay call fails)
    payment = await Payment.create({
      userId, type, refId: rId,
      currency: 'PKR', amount, amountLowest,
      voucherCode: appliedVoucher || null,
      safepayEnvironment: SAFEPAY_ENV(),
      status: 'created',
      notes: description,
    });

    // 3. Safepay payment session
    const session = await safepayPost('/order/payments/v3/', {
      merchant_api_key: process.env.SAFEPAY_API_KEY,
      intent: 'CYBERSOURCE',
      mode: 'payment',
      currency: 'PKR',
      amount: amountLowest,
      metadata: { payment_id: payment._id.toString(), type, ref_id: String(refId) },
    });
    const tracker = session?.data?.tracker?.token;
    if (!tracker) throw new Error('Safepay did not return a tracker token');

    payment.safepayTracker = tracker;
    payment.safepayState = session?.data?.tracker?.state || 'TRACKER_STARTED';
    payment.status = 'pending';
    await payment.save();
    await plog({ paymentId: payment._id, tracker, userId, step: 'SAFEPAY_SESSION_CREATED', payload: { state: payment.safepayState, amountLowest } });

    // 4. Auth token (TBT)
    const passport = await safepayPost('/client/passport/v1/token', {});
    const tbt = passport?.data;
    if (!tbt) throw new Error('Safepay did not return an auth token');

    // 5. Hosted Checkout URL
    const params = new URLSearchParams({
      tracker,
      tbt,
      environment: SAFEPAY_ENV(),
      source: 'hosted',
      redirect_url: redirectUrl || '',
      cancel_url: cancelUrl || '',
    });
    const checkoutUrl = `${SAFEPAY_HOST()}/embedded/?${params.toString()}`;
    await plog({ paymentId: payment._id, tracker, userId, step: 'CHECKOUT_URL_GENERATED' });

    res.json({ success: true, free: false, paymentId: payment._id, tracker, amount, currency: 'PKR', checkoutUrl });
  } catch (e) {
    await plog({ paymentId: payment?._id, userId: toId(req.user?.id), step: 'ERROR', level: 'ERROR', message: e.message, payload: e.safepay || null });
    if (payment) { payment.status = 'failed'; payment.notes = `create failed: ${e.message}`; await payment.save().catch(() => {}); }
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/:id/verify ─────────────────────────────────────────────
// Called by the frontend after redirect back from Safepay. Confirms with Safepay
// directly (never trusts the redirect alone) and fulfills if paid.
router.get('/:id/verify', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const payment = await Payment.findById(toId(req.params.id));
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (payment.userId.toString() !== String(req.user.id)) {
      await plog({ paymentId: payment._id, userId: toId(req.user.id), step: 'ERROR', level: 'ALERT', message: 'Verify attempted by different user' });
      return res.status(403).json({ success: false, message: 'Not your payment' });
    }

    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'VERIFY_REQUESTED' });

    if (payment.status === 'paid' && payment.fulfilled) {
      return res.json({ success: true, status: 'paid', fulfilled: true, paymentId: payment._id });
    }
    if (!payment.safepayTracker) return res.json({ success: true, status: payment.status, fulfilled: false });

    const report = await safepayGet(`/reporter/api/v1/payments/${payment.safepayTracker}`);
    const trackerData = report?.data?.tracker;
    const state = trackerData?.state;
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'VERIFY_RESULT', message: `state=${state}` });

    if (state === 'TRACKER_ENDED') {
      const r = await markPaidAndFulfill(payment, trackerData, 'verify');
      if (!r.ok) return res.status(409).json({ success: false, message: 'Payment verification failed (amount mismatch). Support has been alerted.' });
      return res.json({ success: true, status: 'paid', fulfilled: true, paymentId: payment._id });
    }

    res.json({ success: true, status: payment.status, safepayState: state, fulfilled: false, paymentId: payment._id });
  } catch (e) {
    await plog({ step: 'ERROR', level: 'ERROR', message: `verify: ${e.message}` });
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── POST /api/payments/webhook ───────────────────────────────────────────────
// Public endpoint hit by Safepay. HMAC-SHA512 signature in X-SFPY-SIGNATURE.
router.post('/webhook', async (req, res) => {
  try {
    await connectMongoDB();
    const signature = req.headers['x-sfpy-signature'];
    const body = req.body || {};
    // tracker may arrive as a string or as an object ({ token: 'track_...' })
    const rawTracker = body?.data?.tracker ?? body?.tracker ?? null;
    const tracker = typeof rawTracker === 'object' && rawTracker !== null
      ? (rawTracker.token || null)
      : rawTracker;

    await plog({ tracker, step: 'WEBHOOK_RECEIVED', payload: { type: body?.type, hasSignature: !!signature } });

    // 1. Signature verification (HMAC-SHA512 hex over raw JSON body)
    const secret = process.env.SAFEPAY_WEBHOOK_SECRET;
    if (!secret) {
      await plog({ tracker, step: 'ERROR', level: 'ERROR', message: 'SAFEPAY_WEBHOOK_SECRET not set — rejecting webhook' });
      return res.status(500).json({ success: false });
    }
    const raw = req.rawBody || Buffer.from(JSON.stringify(body));
    const expected = crypto.createHmac('sha512', secret).update(raw).digest('hex');
    const sigBuf = Buffer.from(String(signature || ''), 'utf8');
    const expBuf = Buffer.from(expected, 'utf8');
    const valid = sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf);

    if (!valid) {
      await plog({ tracker, step: 'WEBHOOK_SIGNATURE_INVALID', level: 'ALERT', message: 'Invalid or missing X-SFPY-SIGNATURE — ignored', payload: { signature: String(signature || '').slice(0, 32) } });
      return res.status(400).json({ success: false, message: 'Invalid signature' });
    }
    await plog({ tracker, step: 'WEBHOOK_SIGNATURE_VALID' });

    // 2. Find payment by tracker
    if (!tracker) return res.status(200).json({ success: true, message: 'No tracker in payload' });
    const payment = await Payment.findOne({ safepayTracker: tracker });
    if (!payment) {
      await plog({ tracker, step: 'WEBHOOK_RECEIVED', level: 'WARN', message: 'No local payment for this tracker' });
      return res.status(200).json({ success: true });
    }

    // 3. Acknowledge fast, then apply business logic
    const eventType = body?.type || (body?.data?.state === 'TRACKER_ENDED' ? 'payment.succeeded' : null);
    if (eventType === 'payment.succeeded') {
      await markPaidAndFulfill(payment, body?.data, 'webhook');
    } else if (eventType === 'payment.failed') {
      if (payment.status !== 'paid') {
        payment.status = 'failed';
        payment.safepayResponse = body?.data || null;
        await payment.save();
        await plog({ paymentId: payment._id, tracker, userId: payment.userId, step: 'STATUS_CHANGED', level: 'WARN', message: '-> failed (webhook)' });
      }
    } else {
      await plog({ paymentId: payment._id, tracker, step: 'WEBHOOK_RECEIVED', level: 'INFO', message: `Unhandled event type: ${eventType}` });
    }

    res.status(200).json({ success: true });
  } catch (e) {
    console.error('[SAFEPAY][ERROR][WEBHOOK]', e);
    await plog({ step: 'ERROR', level: 'ERROR', message: `webhook: ${e.message}` });
    res.status(500).json({ success: false });
  }
});

// ─── GET /api/payments/my — user's own payment history ───────────────────────
router.get('/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const payments = await Payment.find({ userId: toId(req.user.id) }).sort({ createdAt: -1 }).limit(100).lean();
    res.json({ success: true, payments });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/logs — admin audit trail ───────────────────────────────
// Query: ?paymentId=&tracker=&level=&limit=
router.get('/logs', authMiddleware, roleMiddleware('admin'), async (req, res) => {
  try {
    await connectMongoDB();
    const q = {};
    if (req.query.paymentId) q.paymentId = toId(req.query.paymentId);
    if (req.query.tracker) q.safepayTracker = req.query.tracker;
    if (req.query.level) q.level = req.query.level;
    const limit = Math.min(Number(req.query.limit) || 200, 1000);
    const logs = await PaymentLog.find(q).sort({ createdAt: -1 }).limit(limit).lean();
    res.json({ success: true, logs, count: logs.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/all — admin: list payments ────────────────────────────
router.get('/all', authMiddleware, roleMiddleware('admin'), async (req, res) => {
  try {
    await connectMongoDB();
    const q = {};
    if (req.query.status) q.status = req.query.status;
    if (req.query.type) q.type = req.query.type;
    const payments = await Payment.find(q).sort({ createdAt: -1 }).limit(500).lean();
    res.json({ success: true, payments, count: payments.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
