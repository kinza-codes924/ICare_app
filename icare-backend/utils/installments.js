// Shared helpers for the Early Bird discount + Installment plan feature.
// Used by routes/payments.js, routes/courses.js, and routes/lms-installments.js
// so eligibility/schedule math is computed identically everywhere.

// Adds exactly one calendar month to `date`, clamping to the last day of the
// target month instead of overflowing (e.g. Jan 31 + 1 month -> Feb 28/29,
// never Mar 3).
function addOneCalendarMonth(date) {
  const d = new Date(date);
  const day = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() + 1);
  const daysInTargetMonth = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(day, daysInTargetMonth));
  return d;
}

// The single place Early Bird eligibility is computed. Returns the price a
// student would pay right now — Early Bird applied only while still within
// its deadline.
function computeEffectivePrice(course) {
  let base = course.isFree ? 0 : (course.discountedPrice || course.price || 0);
  if (
    course.earlyBirdEnabled &&
    course.earlyBirdDeadline &&
    new Date() < new Date(course.earlyBirdDeadline)
  ) {
    base = Math.max(0, base - (course.earlyBirdAmount || 0));
  }
  return base;
}

function isEarlyBirdActive(course) {
  return !!(
    course.earlyBirdEnabled &&
    course.earlyBirdDeadline &&
    new Date() < new Date(course.earlyBirdDeadline)
  );
}

// Generates the installment schedule for an enrollment from the course's
// instructor-defined plan. Each plan row is {amount, daysAfterEnrollment};
// row 1 (daysAfterEnrollment 0) IS the purchase and is pre-marked 'paid',
// rows 2..N start 'pending' and are due enrollmentDate + daysAfterEnrollment.
function buildInstallmentSchedule({ plan, enrollmentDate, firstPaymentId }) {
  const rows = Array.isArray(plan) ? plan : [];
  const start = new Date(enrollmentDate);

  return rows.map((row, i) => {
    const index = i + 1;
    const days = Math.max(0, Math.floor(row.daysAfterEnrollment || 0));
    const dueDate = new Date(start);
    dueDate.setDate(dueDate.getDate() + days);

    return {
      index,
      amount: Number(row.amount) || 0,
      dueDate,
      status: index === 1 ? 'paid' : 'pending',
      paidAt: index === 1 ? new Date() : null,
      paymentId: index === 1 ? firstPaymentId || null : null,
      dueReminderSentAt: null,
      overdueLockNotifiedAt: null,
    };
  });
}

module.exports = {
  addOneCalendarMonth,
  computeEffectivePrice,
  isEarlyBirdActive,
  buildInstallmentSchedule,
};
