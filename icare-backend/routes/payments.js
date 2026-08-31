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
const { authMiddleware, roleMiddleware, platformAdminOnly } = require('../middleware/auth');
const mongoose = require('mongoose');

const Payment = require('../models/Payment');
const PaymentLog = require('../models/PaymentLog');
const Course = require('../models/Course');
const Enrollment = require('../models/Enrollment');
const Appointment = require('../models/Appointment');
const DoctorProfile = require('../models/DoctorProfile');
const LabTestRequest = require('../models/LabTestRequest');
const PharmacyOrder = require('../models/PharmacyOrder');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { sendEmail } = require('../utils/email');
const { Voucher, applyVoucherDiscount } = require('./vouchers');
const { computeEffectivePrice, buildInstallmentSchedule } = require('../utils/installments');

// ─── Config helpers ───────────────────────────────────────────────────────────
const SAFEPAY_ENV = () => (process.env.SAFEPAY_ENV === 'production' ? 'production' : 'sandbox');
const SAFEPAY_HOST = () =>
  SAFEPAY_ENV() === 'production' ? 'https://api.getsafepay.com' : 'https://sandbox.api.getsafepay.com';
const SAFEPAY_CHECKOUT_HOST = () =>
  SAFEPAY_ENV() === 'production' ? 'https://getsafepay.com' : 'https://sandbox.api.getsafepay.com';

// Appointment.appointment_date/time are stored as raw 'YYYY-MM-DD'/'HH:MM'
// strings — format them for admin-facing display (order-details drill-down).
const formatApptDate = (d) => {
  if (!d) return null;
  const parsed = new Date(`${d}T00:00:00`);
  if (isNaN(parsed.getTime())) return d;
  return parsed.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
};
const formatApptTime = (t) => {
  if (!t) return null;
  const [h, m] = String(t).split(':').map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return t;
  const period = h >= 12 ? 'PM' : 'AM';
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${hour12}:${String(m).padStart(2, '0')} ${period}`;
};

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
    // status.message is just "fail" — the real reason lives in status.errors[]
    const errors = Array.isArray(json?.status?.errors) ? json.status.errors.join('; ') : '';
    const msg = errors || json?.status?.message || json?.message || `Safepay HTTP ${res.status}`;
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

// Notifies a doctor (in-app + email) about a new appointment booking, and —
// if that doctor belongs to a standalone iCare Clinic (DoctorProfile.clinicId
// set) — also notifies every admin scoped to that clinic. Client's explicit
// requirement: standalone clinics need a clinic-level alert, not just the
// individual doctor's personal inbox, since front-desk/admin staff manage
// bookings for the whole clinic. Independent telehealth doctors (no
// clinicId) only get their own notification, unchanged from before.
async function notifyAppointmentBooked(appt, { cashPending = false } = {}) {
  if (!appt?.doctor_id) return;
  try {
    const DoctorProfile = require('../models/DoctorProfile');
    const ClinicAdminProfile = require('../models/ClinicAdminProfile');
    const [doctor, patient, doctorProfile] = await Promise.all([
      User.findById(appt.doctor_id).select('email name').lean(),
      User.findById(appt.patient_id).select('name').lean(),
      DoctorProfile.findOne({ user_id: appt.doctor_id }).select('clinicId').lean(),
    ]);
    const patientName = appt.patient_name || patient?.name || 'A patient';
    const dateStr = appt.appointment_date || '';
    const timeStr = appt.appointment_time || '';
    const whenStr = dateStr ? ` for ${dateStr}${timeStr ? ` at ${timeStr}` : ''}` : '';
    const title = cashPending ? 'New Appointment Booked — Pay at Clinic' : 'New Appointment Booked';
    const message = cashPending
      ? `${patientName} booked an appointment${whenStr} and will pay in cash at the clinic.`
      : `${patientName} booked an appointment${whenStr} and payment is confirmed.`;

    const recipients = [{ userId: appt.doctor_id, email: doctor?.email, name: doctor?.name }];

    const clinicId = doctorProfile?.clinicId;
    if (clinicId) {
      const clinicAdminProfiles = await ClinicAdminProfile.find({ clinicId }).lean();
      if (clinicAdminProfiles.length) {
        const admins = await User.find({ _id: { $in: clinicAdminProfiles.map(p => p.user_id) } })
          .select('email name').lean();
        for (const admin of admins) {
          recipients.push({ userId: admin._id, email: admin.email, name: admin.name });
        }
      }
    }

    await Promise.all(recipients.map(r => Promise.all([
      Notification.create({
        userId: r.userId,
        type: 'appointment',
        title,
        message,
        data: { appointmentId: appt._id.toString() },
      }).catch(() => {}),
      r.email
        ? sendEmail({
            to: r.email,
            subject: `${title} — iCare`,
            html: `<p>Hi ${r.name || ''},</p><p><b>${patientName}</b> has booked an appointment${whenStr}${cashPending ? ' and will pay in cash at the clinic.' : ' and the payment has been confirmed.'}</p><p>Please check your iCare dashboard for details.</p>`,
          }).catch(() => {})
        : Promise.resolve(),
    ])));
  } catch (notifErr) {
    console.error('notifyAppointmentBooked error:', notifErr.message);
  }
}

// Emails the patient a PDF invoice right after their appointment payment
// confirms — client's explicit request: "jo online booking kar raha hai
// uski RASEED (receipt) niklegi... PDF FORM mein uski email hum invoice
// bhijwani hai". Best-effort: never breaks the payment flow if it fails
// (matches notifyAppointmentBooked's own try/catch-and-log pattern).
async function sendAppointmentInvoiceEmail(payment, appt) {
  if (!appt) return;
  try {
    const patient = await User.findById(appt.patient_id).select('email name').lean();
    if (!patient?.email) return;
    const { buildAppointmentInvoiceBuffer } = require('./invoices');
    const pdfBuffer = await buildAppointmentInvoiceBuffer(appt);
    await sendEmail({
      to: patient.email,
      subject: 'Your iCare Appointment Invoice',
      html: `<p>Hi ${patient.name || ''},</p><p>Thank you for your payment — your invoice for this appointment is attached as a PDF.</p><p>You can also view it anytime from your iCare dashboard record.</p>`,
      attachments: [{
        filename: `icare-invoice-${appt._id}.pdf`,
        content: pdfBuffer,
        contentType: 'application/pdf',
      }],
    });
  } catch (e) {
    console.error('sendAppointmentInvoiceEmail error:', e.message);
  }
}

// ─── Server-side amount calculation per payment type ──────────────────────────
// Returns { amount, originalAmount, payeeId, description, voucherCode } or throws.
// payeeId = who receives the money (instructor/doctor/lab/pharmacy) — powers
// the admin per-entity revenue report.
async function calculateAmount({ type, refId, voucherCode, userId, installmentIndex, method }) {
  if (type === 'course') {
    const course = await Course.findById(refId).lean();
    if (!course) throw new Error('Course not found');
    // Never let an already-enrolled user pay again for the same course.
    const existingEnrollment = await Enrollment.findOne({ userId: toId(userId), courseId: refId }).lean();
    if (existingEnrollment) throw new Error('Already enrolled in this course');
    const original = computeEffectivePrice(course);
    let amount = original;
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
    // Installment-enabled courses: "purchase" always means "pay installment 1"
    // — the full schedule is generated at fulfillment time, not here. The
    // instructor-defined plan's first row is the amount due on enrollment.
    if (course.installmentPlanEnabled && Array.isArray(course.installmentPlan)
        && course.installmentPlan.length >= 2 && !voucherCode) {
      amount = Number(course.installmentPlan[0].amount) || 0;
    }
    return {
      amount: Math.max(0, Number(amount) || 0),
      originalAmount: Math.max(0, Number(original) || 0),
      payeeId: course.instructor_id || null,
      description: `Course: ${course.title || refId}`,
      voucherCode: appliedVoucher,
    };
  }

  if (type === 'course_installment') {
    const course = await Course.findById(refId).lean();
    if (!course) throw new Error('Course not found');
    const enrollment = await Enrollment.findOne({ userId: toId(userId), courseId: refId });
    if (!enrollment) throw new Error('No enrollment found for this course');
    if (!enrollment.installmentPlanEnabled) throw new Error('This course does not have an installment plan');
    const idx = Number(installmentIndex);
    const inst = enrollment.installments.find((i) => i.index === idx);
    if (!inst) throw new Error('Invalid installment index');
    if (inst.status === 'paid') throw new Error('This installment is already paid');
    return {
      amount: Math.max(0, Number(inst.amount) || 0),
      originalAmount: Math.max(0, Number(inst.amount) || 0),
      payeeId: course.instructor_id || null,
      description: `Course: ${course.title || refId} — Installment ${idx} of ${enrollment.installments.length}`,
      voucherCode: null,
    };
  }

  if (type === 'appointment') {
    const appt = await Appointment.findById(refId).lean();
    if (!appt) throw new Error('Appointment not found');
    if (appt.patient_id?.toString() !== String(userId)) throw new Error('Not your appointment');
    if (appt.paymentStatus === 'paid') throw new Error('This appointment is already paid');
    const profile = await DoctorProfile.findOne({ user_id: appt.doctor_id }).lean();
    const fee = Number(profile?.consultation_fee) || 0;
    // 5% off for paying online, but only for an iCare Clinic appointment —
    // that is the one where cash-at-clinic is the alternative the discount is
    // meant to steer away from. A telehealth consultation has no cash option
    // and is charged in full. Must mirror _onlineDiscountApplies in
    // select_payment_method.dart, or the patient sees one price and is
    // charged another.
    const isClinicAppointment = !!(profile?.clinicId && String(profile.clinicId).trim());
    const amount = isClinicAppointment ? Math.round(fee * 0.95) : fee;
    return {
      amount, originalAmount: fee,
      payeeId: appt.doctor_id || null,
      description: 'Doctor consultation fee',
      voucherCode: null,
    };
  }

  if (type === 'lab') {
    const booking = await LabTestRequest.findById(refId).lean();
    if (!booking) throw new Error('Lab booking not found');
    if (booking.patient_id?.toString() !== String(userId)) throw new Error('Not your booking');
    if (booking.paymentStatus === 'paid') throw new Error('This booking is already paid');
    const price = Number(booking.price) || 0;
    return {
      amount: price, originalAmount: price,
      payeeId: booking.lab_id || null,
      description: `Lab test: ${booking.test_type || refId}`,
      voucherCode: null,
    };
  }

  if (type === 'pharmacy') {
    const order = await PharmacyOrder.findById(refId).lean();
    if (!order) throw new Error('Order not found');
    if (order.patient_id?.toString() !== String(userId)) throw new Error('Not your order');
    if (order.paymentStatus === 'paid') throw new Error('This order is already paid');
    const total = (Number(order.total_amount) || 0) + (Number(order.delivery_fee) || 0);
    return {
      amount: total, originalAmount: total,
      payeeId: order.pharmacy_id || null,
      description: `Pharmacy order ${order.order_number || refId}`,
      voucherCode: null,
    };
  }

  if (type === 'reception') {
    const Consultation = require('../models/Consultation');
    const consultation = await Consultation.findById(refId).lean();
    if (!consultation) throw new Error('Consultation not found');
    // Ownership check differs from every other type: the payer here is the
    // receptionist who ran the walk-in visit, not a patient (a walk-in guest
    // has no patient User account at all) — so check receptionistId instead
    // of a patient_id/userId match.
    if (consultation.receptionistId?.toString() !== String(userId)) throw new Error('Not your consultation');
    if (consultation.paymentStatus === 'paid') throw new Error('This visit is already paid');
    const proceduresTotal = (consultation.procedures || []).reduce((sum, p) => sum + (Number(p.price) || 0), 0);
    const subtotal = (Number(consultation.consultationFee) || 0) + proceduresTotal;
    // SRB (Sindh Revenue Board) sales tax on services — not FBR. Rate is
    // whatever the receptionist set via PUT /reception/consultations/:id/tax
    // (defaults to 15 on the schema); recomputed here, never trusted from
    // the client, and persisted back onto the consultation so the invoice
    // PDF shows the exact figure that was actually charged.
    const taxRate = Number(consultation.taxRate) || 0;
    const taxAmount = subtotal * (taxRate / 100);
    const total = subtotal + taxAmount;
    await Consultation.findByIdAndUpdate(refId, { $set: { taxAmount } });
    return {
      amount: total, originalAmount: total,
      payeeId: consultation.doctorId || null,
      description: `Walk-in visit: ${consultation.patientName || refId}`,
      voucherCode: null,
    };
  }

  if (type === 'standalone_invoice') {
    const StandaloneInvoice = require('../models/StandaloneInvoice');
    const invoice = await StandaloneInvoice.findById(refId).lean();
    if (!invoice) throw new Error('Invoice not found');
    // Same ownership shape as reception — the payer is the receptionist who
    // created the invoice, there's no patient/doctor involved at all.
    if (invoice.receptionistId?.toString() !== String(userId)) throw new Error('Not your invoice');
    if (invoice.paymentStatus === 'paid') throw new Error('This invoice is already paid');
    // Totals were already computed server-side at creation time
    // (POST /reception/invoices) — reuse them rather than recomputing, so
    // a later items/tax-rate change (there isn't one, but this keeps the
    // charged amount pinned to what the printed invoice actually shows).
    return {
      amount: invoice.totalAmount, originalAmount: invoice.totalAmount,
      payeeId: null,
      description: `Invoice: ${invoice.clientName}`,
      voucherCode: null,
    };
  }

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

    // Installment-enabled courses: generate the full N-row schedule now that
    // installment 1 (this payment) has actually cleared. Guarded by
    // installments.length so a duplicate webhook fulfillment never
    // regenerates it (idempotent).
    if (enrollment && (!enrollment.installments || enrollment.installments.length === 0)) {
      const course = await Course.findById(payment.refId).lean();
      if (course?.installmentPlanEnabled && Array.isArray(course.installmentPlan)
          && course.installmentPlan.length >= 2 && !payment.voucherCode) {
        enrollment.installmentPlanEnabled = true;
        enrollment.installments = buildInstallmentSchedule({
          plan: course.installmentPlan,
          enrollmentDate: enrollment.createdAt || new Date(),
          firstPaymentId: payment._id,
        });
        await enrollment.save();
      }
    }

    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    payment.fulfillmentRef = enrollment?._id || null;
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Enrollment ${enrollment?._id} created for course ${payment.refId}` });
    return { enrollment };
  }

  if (payment.type === 'course_installment') {
    const enrollment = await Enrollment.findOne({ userId: payment.userId, courseId: payment.refId });
    if (!enrollment) {
      await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILL_ERROR', level: 'ALERT', message: `No enrollment found for installment payment, course ${payment.refId}` });
      throw new Error('No enrollment found for installment payment');
    }
    const inst = enrollment.installments.find((i) => i.index === payment.installmentIndex);
    if (inst) {
      inst.status = 'paid';
      inst.paidAt = new Date();
      inst.paymentId = payment._id;
    }
    const wasLocked = enrollment.installmentLocked;
    if (wasLocked) {
      enrollment.installmentLocked = false;
      enrollment.installmentLockedAt = null;
    }
    await enrollment.save();

    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    payment.fulfillmentRef = enrollment._id;
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Installment ${payment.installmentIndex} paid for course ${payment.refId}` });

    if (wasLocked) {
      const course = await Course.findById(payment.refId).select('title').lean();
      const student = await User.findById(payment.userId).select('email name').lean();
      Notification.create({
        userId: payment.userId, type: 'payment',
        title: 'Course Unlocked',
        message: `Your access to "${course?.title || 'your course'}" has been restored — installment ${payment.installmentIndex} is now paid.`,
        data: { subType: 'installment_paid', courseId: payment.refId, installmentIndex: payment.installmentIndex },
      }).catch(() => {});
      if (student?.email) {
        sendEmail({
          to: student.email,
          subject: `Course unlocked — ${course?.title || 'installment paid'}`,
          html: `<p>Hi ${student.name || 'Student'},</p><p>Installment ${payment.installmentIndex} for <b>${course?.title || ''}</b> has been received and your course access is restored.</p>`,
        }).catch(() => {});
      }
    }
    return { enrollment };
  }

  if (payment.type === 'appointment') {
    // Connect Now (instant consultation) creates the Appointment already
    // 'in_progress' — paying for it must NOT downgrade it back to
    // 'confirmed' (that status is only for scheduled bookings awaiting
    // their time slot). Only bump 'pending' -> 'confirmed'.
    const appt = await Appointment.findById(payment.refId).lean();
    const update = { paymentStatus: 'paid' };
    if (!appt || appt.status === 'pending') update.status = 'confirmed';
    await Appointment.findByIdAndUpdate(payment.refId, update);
    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Appointment ${payment.refId} confirmed & marked paid` });

    // Client requested a clear "new booking" alert on the doctor's side —
    // previously only the patient got an email/notification, the doctor had
    // to happen to open the dashboard. Fire here, once, right when the
    // booking actually becomes real (paid/confirmed), not at creation time
    // when it could still be abandoned mid-payment. For standalone-clinic
    // doctors this also alerts the clinic's admin(s), per client request.
    await notifyAppointmentBooked(appt);
    await sendAppointmentInvoiceEmail(payment, appt);
    return {};
  }

  if (payment.type === 'lab') {
    await LabTestRequest.findByIdAndUpdate(payment.refId, {
      paymentStatus: 'paid',
      paymentMethod: payment.method,
      status: 'confirmed',
    });
    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Lab booking ${payment.refId} confirmed & marked paid` });
    return {};
  }

  if (payment.type === 'pharmacy') {
    await PharmacyOrder.findByIdAndUpdate(payment.refId, {
      paymentStatus: 'paid',
      paymentMethod: payment.method,
      status: 'confirmed',
    });
    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Pharmacy order ${payment.refId} confirmed & marked paid` });
    return {};
  }

  if (payment.type === 'reception') {
    const Consultation = require('../models/Consultation');
    await Consultation.findByIdAndUpdate(payment.refId, { paymentStatus: 'paid' });
    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Walk-in visit ${payment.refId} marked paid` });
    return {};
  }

  if (payment.type === 'standalone_invoice') {
    const StandaloneInvoice = require('../models/StandaloneInvoice');
    await StandaloneInvoice.findByIdAndUpdate(payment.refId, { paymentStatus: 'paid' });
    payment.fulfilled = true;
    payment.fulfilledAt = new Date();
    await payment.save();
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'FULFILLED', message: `Invoice ${payment.refId} marked paid` });
    return {};
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
// Body: { type: 'course'|'appointment'|'lab'|'pharmacy'|'reception', refId, voucherCode?,
//         method?: 'safepay'|'cash'|'card', redirectUrl, cancelUrl }
// method 'cash'/'card' (lab: cash at collection / pharmacy: cash on delivery /
// reception: cash or card collected in-person at the front desk) skips the
// gateway; staff later confirms via POST /:id/cash-collected.
router.post('/create', authMiddleware, async (req, res) => {
  let payment = null;
  try {
    await connectMongoDB();
    const { type, refId, voucherCode, redirectUrl, cancelUrl, installmentIndex } = req.body;
    const method = ['cash', 'card'].includes(req.body.method) ? req.body.method : 'safepay';
    const userId = toId(req.user.id);

    if (!type || !refId) return res.status(400).json({ success: false, message: 'type and refId required' });
    const rId = toId(refId);
    if (!rId) return res.status(400).json({ success: false, message: 'Invalid refId' });
    if (method !== 'safepay' && !['lab', 'pharmacy', 'reception', 'standalone_invoice', 'appointment'].includes(type)) {
      return res.status(400).json({ success: false, message: 'Cash/card payment is only available for lab tests, pharmacy orders, reception visits, standalone invoices, and appointments' });
    }
    if (method === 'card' && !['reception', 'standalone_invoice'].includes(type)) {
      return res.status(400).json({ success: false, message: 'Card payment is only available for reception visits and standalone invoices' });
    }
    if (method === 'safepay' && (!process.env.SAFEPAY_API_KEY || !process.env.SAFEPAY_SECRET_KEY)) {
      await plog({ userId, step: 'ERROR', level: 'ERROR', message: 'SAFEPAY keys not configured in env' });
      return res.status(500).json({ success: false, message: 'Payment gateway not configured' });
    }
    if (type === 'course_installment' && !(Number.isInteger(Number(installmentIndex)) && Number(installmentIndex) >= 1)) {
      return res.status(400).json({ success: false, message: 'installmentIndex is required for course_installment payments' });
    }

    await plog({ userId, step: 'PAYMENT_CREATE_REQUESTED', payload: { type, refId, method, voucherCode: voucherCode || null } });

    // 1. Server-side amount
    const { amount, originalAmount, payeeId, description, voucherCode: appliedVoucher } =
      await calculateAmount({ type, refId: rId, voucherCode, userId, installmentIndex: Number(installmentIndex) || undefined, method });
    await plog({ userId, step: 'AMOUNT_CALCULATED', message: `${description} = PKR ${amount} (original ${originalAmount})` });

    // Free (or 100% voucher) — no gateway needed; client should call the normal endpoint.
    if (amount <= 0) {
      return res.json({ success: true, free: true, amount: 0, message: 'No payment required' });
    }

    const amountLowest = Math.round(amount * 100); // PKR lowest denomination
    const discountAmount = Math.max(0, (Number(originalAmount) || amount) - amount);

    // ── CASH / CARD: record the pending payment + flag the booking/order ─────
    if (method === 'cash' || method === 'card') {
      payment = await Payment.create({
        userId, type, refId: rId, payeeId: payeeId || null,
        method,
        currency: 'PKR', amount, amountLowest,
        originalAmount: originalAmount ?? amount, discountAmount,
        voucherCode: appliedVoucher || null,
        safepayTracker: `${method}_${new mongoose.Types.ObjectId().toString()}`,
        safepayEnvironment: null,
        status: 'pending',
        notes: `${description} (${method})`,
      });
      if (type === 'reception') {
        const Consultation = require('../models/Consultation');
        await Consultation.findByIdAndUpdate(rId, { paymentStatus: 'unpaid' });
      } else if (type === 'standalone_invoice') {
        // Already 'unpaid' by default — nothing to flag here, fulfillPayment
        // flips it to 'paid' once the receptionist confirms collection.
      } else if (type === 'appointment') {
        // Cash-at-clinic: the booking isn't "paid" yet, but the doctor (and
        // clinic admin, if standalone-clinic) still need to know it exists
        // so they can expect the patient and confirm cash on arrival —
        // payment confirmation (fulfillPayment) won't fire until then, so
        // notify here at booking time instead.
        // Mark it as a deliberate cash booking. The doctor's appointment list
        // hides unpaid 'pending' rows (a patient who bailed at the payment step
        // used to leave one behind that looked like a real request) — this flag
        // is what separates "chose to pay at the clinic" from "never paid".
        await Appointment.findByIdAndUpdate(rId, { $set: { paymentMethod: 'cash' } });
        const appt = await Appointment.findById(rId).lean();
        await notifyAppointmentBooked(appt, { cashPending: true });
      } else {
        const Model = type === 'lab' ? LabTestRequest : PharmacyOrder;
        await Model.findByIdAndUpdate(rId, { paymentMethod: method, paymentStatus: 'cash_pending' });
      }
      await plog({ paymentId: payment._id, userId, step: 'STATUS_CHANGED', message: `${method} payment registered — awaiting collection (${type})` });
      return res.json({ success: true, cash: true, paymentId: payment._id, amount, currency: 'PKR' });
    }

    // 2. Create local Payment record first (audit trail even if Safepay call fails)
    payment = await Payment.create({
      userId, type, refId: rId, payeeId: payeeId || null,
      method: 'safepay',
      currency: 'PKR', amount, amountLowest,
      originalAmount: originalAmount ?? amount, discountAmount,
      voucherCode: appliedVoucher || null,
      installmentIndex: type === 'course_installment' ? Number(installmentIndex) : null,
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
      // NOTE: Safepay only accepts whitelisted metadata keys ("unsupported
      // meta key ..." otherwise) — order_id is the documented one. It carries
      // our Payment _id; type/refId live on the Payment record itself.
      metadata: { order_id: payment._id.toString() },
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
    // Embed our own payment id on top of whatever redirect/cancel URL the
    // client passed, so the page Safepay lands the browser back on (which
    // may be a fresh tab with no in-memory app state) can look up exactly
    // this payment and route accordingly, instead of only showing a generic
    // "go to dashboard" message.
    // MUST be a path segment, not a query param — Safepay appends its own
    // "?tracker=..." to this URL blindly (verified against the live
    // sandbox: it does NOT check for an existing "?" first), which would
    // mangle "...?pid=xxx?tracker=yyy" into one unparsable query string.
    const withPid = (url) => {
      if (!url) return '';
      return `${url.replace(/\/+$/, '')}/${payment._id}`;
    };
    const params = new URLSearchParams({
      tracker,
      tbt,
      environment: SAFEPAY_ENV(),
      source: 'hosted',
      redirect_url: withPid(redirectUrl),
      cancel_url: withPid(cancelUrl),
    });
    const checkoutUrl = `${SAFEPAY_CHECKOUT_HOST()}/embedded/?${params.toString()}`;
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
      return res.json({ success: true, status: 'paid', fulfilled: true, paymentId: payment._id, type: payment.type, refId: payment.refId?.toString() });
    }
    if (!payment.safepayTracker) return res.json({ success: true, status: payment.status, fulfilled: false, paymentId: payment._id, type: payment.type, refId: payment.refId?.toString() });

    const report = await safepayGet(`/reporter/api/v1/payments/${payment.safepayTracker}`);
    // Reporter returns the tracker object DIRECTLY in data (no data.tracker
    // nesting) — verified against the live sandbox response.
    const trackerData = report?.data?.tracker || report?.data;
    const state = trackerData?.state;
    await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'VERIFY_RESULT', message: `state=${state}` });

    if (state === 'TRACKER_ENDED') {
      const r = await markPaidAndFulfill(payment, trackerData, 'verify');
      if (!r.ok) return res.status(409).json({ success: false, message: 'Payment verification failed (amount mismatch). Support has been alerted.' });
      return res.json({ success: true, status: 'paid', fulfilled: true, paymentId: payment._id, type: payment.type, refId: payment.refId?.toString() });
    }

    res.json({ success: true, status: payment.status, safepayState: state, fulfilled: false, paymentId: payment._id, type: payment.type, refId: payment.refId?.toString() });
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

        // An appointment row is created up-front (before payment) so the slot
        // can be held — but if payment then fails/gets cancelled, that pending
        // row was never cleaned up, so it kept showing as "booked" in My
        // Appointments even though the patient never actually paid. Cancel it
        // here, but only if it's still genuinely unpaid — never touch one a
        // separate successful payment (e.g. a retry) already marked paid.
        if (payment.type === 'appointment' && payment.refId) {
          await Appointment.findOneAndUpdate(
            { _id: payment.refId, paymentStatus: { $ne: 'paid' } },
            { $set: { status: 'cancelled' } }
          ).catch(() => {});
        }
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

// ─── POST /api/payments/:id/cash-collected ────────────────────────────────────
// Lab/pharmacy staff (the payee) or an admin confirms the cash was received.
// This is the fulfillment trigger for cash payments — labs must do this
// BEFORE moving a booking to sample collection.
router.post('/:id/cash-collected', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const payment = await Payment.findById(toId(req.params.id));
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (!['cash', 'card'].includes(payment.method)) {
      return res.status(400).json({ success: false, message: 'Not a cash or card payment' });
    }
    const isAdmin = (req.user.role || '').toLowerCase() === 'admin';
    const isPayee = payment.payeeId && payment.payeeId.toString() === String(req.user.id);
    // A reception payment's payeeId is the doctor, but it's the receptionist
    // who ran the visit and confirms in-person collection — check the
    // Consultation's receptionistId too, not just payeeId.
    let isReceptionist = false;
    if (payment.type === 'reception') {
      const Consultation = require('../models/Consultation');
      const consultation = await Consultation.findById(payment.refId).select('receptionistId').lean();
      isReceptionist = consultation?.receptionistId?.toString() === String(req.user.id);
    } else if (payment.type === 'standalone_invoice') {
      const StandaloneInvoice = require('../models/StandaloneInvoice');
      const invoice = await StandaloneInvoice.findById(payment.refId).select('receptionistId').lean();
      isReceptionist = invoice?.receptionistId?.toString() === String(req.user.id);
    }
    if (!isAdmin && !isPayee && !isReceptionist) {
      await plog({ paymentId: payment._id, userId: toId(req.user.id), step: 'ERROR', level: 'ALERT', message: 'cash-collected attempted by non-payee' });
      return res.status(403).json({ success: false, message: 'Only the receiving staff can confirm collection' });
    }
    if (payment.status === 'paid' && payment.fulfilled) {
      return res.json({ success: true, status: 'paid', message: 'Already collected' });
    }

    payment.status = 'paid';
    payment.paidAt = new Date();
    payment.cashCollectedAt = new Date();
    payment.cashCollectedBy = toId(req.user.id);
    await payment.save();
    await plog({ paymentId: payment._id, userId: toId(req.user.id), step: 'STATUS_CHANGED', message: `-> paid (cash collected by ${req.user.id})` });
    await fulfillPayment(payment);

    res.json({ success: true, status: 'paid', paymentId: payment._id });
  } catch (e) {
    console.error('cash-collected error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── POST /api/payments/cash-collected-by-ref ─────────────────────────────────
// Same as /:id/cash-collected but looked up by { type, refId } — lab/pharmacy
// screens have the booking/order id, not the payment id.
router.post('/cash-collected-by-ref', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { type, refId } = req.body;
    if (!type || !refId) return res.status(400).json({ success: false, message: 'type and refId required' });
    const payment = await Payment.findOne({
      type, refId: toId(refId), method: 'cash',
    }).sort({ createdAt: -1 });
    if (!payment) return res.status(404).json({ success: false, message: 'No cash payment found for this booking' });

    const isAdmin = (req.user.role || '').toLowerCase() === 'admin';
    const isPayee = payment.payeeId && payment.payeeId.toString() === String(req.user.id);
    if (!isAdmin && !isPayee) {
      return res.status(403).json({ success: false, message: 'Only the receiving lab/pharmacy can confirm cash collection' });
    }
    if (payment.status === 'paid' && payment.fulfilled) {
      return res.json({ success: true, status: 'paid', message: 'Already collected' });
    }

    payment.status = 'paid';
    payment.paidAt = new Date();
    payment.cashCollectedAt = new Date();
    payment.cashCollectedBy = toId(req.user.id);
    await payment.save();
    await plog({ paymentId: payment._id, userId: toId(req.user.id), step: 'STATUS_CHANGED', message: `-> paid (cash collected via by-ref by ${req.user.id})` });
    await fulfillPayment(payment);

    res.json({ success: true, status: 'paid', paymentId: payment._id });
  } catch (e) {
    console.error('cash-collected-by-ref error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── POST /api/payments/reconcile-mine ────────────────────────────────────────
// Self-healing: re-checks the logged-in user's recent unresolved Safepay
// payments directly with Safepay and fulfills any that actually completed.
// Covers the case where the user paid but closed the polling tab before the
// app could confirm (and the webhook didn't land).
router.post('/reconcile-mine', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const since = new Date(Date.now() - 48 * 60 * 60 * 1000);
    const pendings = await Payment.find({
      userId: toId(req.user.id),
      method: 'safepay',
      status: { $in: ['created', 'pending'] },
      safepayTracker: { $ne: null },
      createdAt: { $gte: since },
    }).sort({ createdAt: -1 }).limit(10);

    let fulfilled = 0;
    for (const payment of pendings) {
      try {
        const report = await safepayGet(`/reporter/api/v1/payments/${payment.safepayTracker}`);
        const trackerData = report?.data?.tracker || report?.data;
        if (trackerData?.state === 'TRACKER_ENDED') {
          const r = await markPaidAndFulfill(payment, trackerData, 'reconcile');
          if (r.ok) fulfilled++;
        }
      } catch (e) {
        await plog({ paymentId: payment._id, tracker: payment.safepayTracker, userId: payment.userId, step: 'ERROR', level: 'WARN', message: `reconcile check failed: ${e.message}` });
      }
    }
    res.json({ success: true, checked: pendings.length, fulfilled });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/pending-cash — payee's cash payments awaiting collection
// Lab/pharmacy dashboards call this to show "Cash Collected" buttons.
router.get('/pending-cash', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const payments = await Payment.find({
      payeeId: toId(req.user.id),
      method: 'cash',
      status: 'pending',
    }).sort({ createdAt: -1 }).limit(200).lean();
    res.json({ success: true, payments });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/report — admin revenue report ─────────────────────────
// Query: ?type=course|appointment|lab|pharmacy & payeeId= & status=paid &
//        from=ISO & to=ISO & minAmount= & maxAmount=
// Returns the filtered payment list (with payer/payee names) PLUS per-payee
// totals so admin can see "is pharmacy/doctor/lab/instructor ke kitne paise".
router.get('/report', authMiddleware, platformAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const q = {};
    if (req.query.type) q.type = req.query.type;
    if (req.query.payeeId) q.payeeId = toId(req.query.payeeId);
    if (req.query.method) q.method = req.query.method;
    q.status = req.query.status || 'paid'; // default: only money actually received
    if (req.query.status === 'all') delete q.status;
    if (req.query.from || req.query.to) {
      q.createdAt = {};
      if (req.query.from) q.createdAt.$gte = new Date(req.query.from);
      if (req.query.to) q.createdAt.$lte = new Date(req.query.to);
    }
    if (req.query.minAmount || req.query.maxAmount) {
      q.amount = {};
      if (req.query.minAmount) q.amount.$gte = Number(req.query.minAmount);
      if (req.query.maxAmount) q.amount.$lte = Number(req.query.maxAmount);
    }

    // Search by recipient name — "Doctor Kamran ko search kar sakoon" — find
    // matching doctor/lab/pharmacy/instructor users first, then restrict the
    // payment query to those payeeIds (combined with any other filter above).
    const searchTerm = (req.query.search || '').trim();
    if (searchTerm) {
      const matches = await User.find({
        role: { $in: ['doctor', 'lab', 'pharmacy', 'instructor'] },
        $or: [
          { name: { $regex: searchTerm, $options: 'i' } },
          { username: { $regex: searchTerm, $options: 'i' } },
        ],
      }).select('_id').lean();
      const matchIds = matches.map(m => m._id);
      if (matchIds.length === 0) {
        // No recipient matches this name — short-circuit to an empty result
        // instead of an unfiltered query.
        return res.json({ success: true, payments: [], totals: [], grandTotal: 0, grandDiscount: 0, grandCount: 0 });
      }
      q.payeeId = req.query.payeeId ? toId(req.query.payeeId) : { $in: matchIds };
    }

    const limit = Math.min(Number(req.query.limit) || 300, 1000);
    const payments = await Payment.find(q).sort({ createdAt: -1 }).limit(limit).lean();

    // Resolve payer + payee names in one query each
    const userIds = [...new Set(payments.flatMap(p => [p.userId, p.payeeId].filter(Boolean).map(String)))];
    const users = await User.find({ _id: { $in: userIds.map(toId).filter(Boolean) } })
      .select('name username email role').lean();
    const uMap = {};
    users.forEach(u => { uMap[u._id.toString()] = u; });

    const list = payments.map(p => ({
      ...p,
      payerName: uMap[p.userId?.toString()]?.name || uMap[p.userId?.toString()]?.username || null,
      payeeName: uMap[p.payeeId?.toString()]?.name || uMap[p.payeeId?.toString()]?.username || null,
      payeeRole: uMap[p.payeeId?.toString()]?.role || null,
    }));

    // Per-payee totals (aggregation over the SAME filter, not just the page)
    const totalsAgg = await Payment.aggregate([
      { $match: { ...q, payeeId: q.payeeId || { $ne: null } } },
      { $group: {
          _id: { payeeId: '$payeeId', type: '$type' },
          totalAmount: { $sum: '$amount' },
          totalDiscount: { $sum: '$discountAmount' },
          count: { $sum: 1 },
      } },
      { $sort: { totalAmount: -1 } },
      { $limit: 200 },
    ]);
    const payeeIds = [...new Set(totalsAgg.map(t => t._id.payeeId?.toString()).filter(Boolean))];
    const payeeUsers = await User.find({ _id: { $in: payeeIds.map(toId).filter(Boolean) } })
      .select('name username role').lean();
    const pMap = {};
    payeeUsers.forEach(u => { pMap[u._id.toString()] = u; });
    const totals = totalsAgg.map(t => ({
      payeeId: t._id.payeeId,
      type: t._id.type,
      payeeName: pMap[t._id.payeeId?.toString()]?.name || pMap[t._id.payeeId?.toString()]?.username || 'Unknown',
      payeeRole: pMap[t._id.payeeId?.toString()]?.role || null,
      totalAmount: t.totalAmount,
      totalDiscount: t.totalDiscount,
      count: t.count,
    }));

    // Grand totals over the filter
    const grandAgg = await Payment.aggregate([
      { $match: q },
      { $group: { _id: null, totalAmount: { $sum: '$amount' }, totalDiscount: { $sum: '$discountAmount' }, count: { $sum: 1 } } },
    ]);
    const grand = grandAgg[0] || { totalAmount: 0, totalDiscount: 0, count: 0 };

    res.json({
      success: true,
      payments: list,
      totals,
      grandTotal: grand.totalAmount,
      grandDiscount: grand.totalDiscount,
      grandCount: grand.count,
    });
  } catch (e) {
    console.error('payments report error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/:id/order-details — full underlying order (admin) ─────
// "Shopify jaisa" drill-down: resolves the payment's type+refId to the FULL
// underlying document (course/appointment/lab booking/pharmacy order) with
// names populated, so admin can verify the payment against real order data
// without needing role-specific screen access.
router.get('/:id/order-details', authMiddleware, platformAdminOnly, async (req, res) => {
  try {
    await connectMongoDB();
    const payment = await Payment.findById(toId(req.params.id)).lean();
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });

    let order = null;
    if (payment.type === 'course') {
      const course = await Course.findById(payment.refId).lean();
      if (course) {
        const instructor = course.instructor_id ? await User.findById(course.instructor_id).select('name username').lean() : null;
        order = {
          title: course.title, description: course.description,
          price: course.price, discountedPrice: course.discountedPrice, isFree: course.isFree,
          instructorName: instructor?.name || instructor?.username || null,
        };
      }
    } else if (payment.type === 'appointment') {
      const appt = await Appointment.findById(payment.refId).lean();
      if (appt) {
        const [patient, doctor] = await Promise.all([
          User.findById(appt.patient_id).select('name username phone').lean(),
          User.findById(appt.doctor_id).select('name username').lean(),
        ]);
        const isInstant = !!appt.channel_name?.startsWith('connect_now_');
        order = {
          patientName: patient?.name || patient?.username || null,
          patientPhone: patient?.phone || null,
          doctorName: doctor?.name || doctor?.username || null,
          date: formatApptDate(appt.appointment_date),
          time: formatApptTime(appt.appointment_time),
          consultationType: isInstant ? 'Instant Consultation' : (appt.consultation_type || 'Scheduled'),
          status: appt.status,
          notes: isInstant ? 'Instant consultation via Connect Now' : (appt.notes || null),
        };
      }
    } else if (payment.type === 'lab') {
      const booking = await LabTestRequest.findById(payment.refId).lean();
      if (booking) {
        const [patient, lab] = await Promise.all([
          User.findById(booking.patient_id).select('name username phone').lean(),
          User.findById(booking.lab_id).select('name username').lean(),
        ]);
        order = {
          patientName: patient?.name || patient?.username || booking.patient_name_override || null,
          patientPhone: patient?.phone || booking.patient_phone || null,
          labName: lab?.name || lab?.username || null,
          testType: booking.test_type, testDate: booking.test_date,
          collectionType: booking.collection_type, urgency: booking.urgency,
          status: booking.status, reportUrl: booking.report_url || null,
        };
      }
    } else if (payment.type === 'pharmacy') {
      const order_ = await PharmacyOrder.findById(payment.refId).lean();
      if (order_) {
        const [patient, pharmacy] = await Promise.all([
          User.findById(order_.patient_id).select('name username phone').lean(),
          User.findById(order_.pharmacy_id).select('name username').lean(),
        ]);
        order = {
          patientName: patient?.name || patient?.username || order_.patientName || null,
          patientPhone: patient?.phone || order_.contact || null,
          pharmacyName: pharmacy?.name || pharmacy?.username || null,
          orderNumber: order_.order_number, status: order_.status,
          deliveryAddress: order_.delivery_address, deliveryOption: order_.deliveryOption,
          items: (order_.items || []).map(i => ({
            name: i.product_name, quantity: i.quantity, price: i.price,
          })),
          totalAmount: order_.total_amount, deliveryFee: order_.delivery_fee,
        };
      }
    }

    if (!order) {
      return res.status(404).json({ success: false, message: 'The underlying order record could not be found (it may have been deleted).' });
    }
    res.json({ success: true, type: payment.type, order });
  } catch (e) {
    console.error('order-details error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/my — user's own payment history ───────────────────────
router.get('/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const payments = await Payment.find({ userId: toId(req.user.id) }).sort({ createdAt: -1 }).limit(100).lean();

    const courseRefIds = [...new Set(
      payments.filter((p) => p.type === 'course' || p.type === 'course_installment').map((p) => p.refId?.toString())
    )].filter(Boolean);
    const [courses, enrollments] = await Promise.all([
      Course.find({ _id: { $in: courseRefIds } }).select('title').lean(),
      Enrollment.find({ userId: toId(req.user.id), courseId: { $in: courseRefIds } }).select('courseId installments').lean(),
    ]);
    const titleById = {};
    courses.forEach((c) => { titleById[c._id.toString()] = c.title; });
    const installmentCountById = {};
    enrollments.forEach((e) => { installmentCountById[e.courseId.toString()] = e.installments?.length || 0; });

    const enriched = payments.map((p) => {
      let displayLabel = p.notes;
      const courseTitle = titleById[p.refId?.toString()];
      if (courseTitle) {
        if (p.type === 'course_installment') {
          const total = installmentCountById[p.refId?.toString()];
          displayLabel = `${courseTitle} — Installment ${p.installmentIndex}${total ? ` of ${total}` : ''}`;
        } else if (p.type === 'course') {
          displayLabel = courseTitle;
        }
      }
      return { ...p, displayLabel };
    });

    res.json({ success: true, payments: enriched });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ─── GET /api/payments/logs — admin audit trail ───────────────────────────────
// Query: ?paymentId=&tracker=&level=&limit=
router.get('/logs', authMiddleware, platformAdminOnly, async (req, res) => {
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
router.get('/all', authMiddleware, platformAdminOnly, async (req, res) => {
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
