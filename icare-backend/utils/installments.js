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

// Generates the N-row installment schedule. Installment 1 is pre-marked
// 'paid' (it IS the purchase); installments 2..count start 'pending', each
// due exactly 1 calendar month after the previous one. The last installment
// absorbs any rounding remainder so the sum always equals totalAmount exactly.
function buildInstallmentSchedule({ totalAmount, count, firstDueDate, firstPaymentId }) {
  const n = Math.max(2, Math.floor(count));
  const perInstallment = Math.floor(totalAmount / n);
  const schedule = [];
  let dueDate = new Date(firstDueDate);
  let allocated = 0;

  for (let index = 1; index <= n; index++) {
    const isLast = index === n;
    const amount = isLast ? totalAmount - allocated : perInstallment;
    allocated += amount;

    schedule.push({
      index,
      amount,
      dueDate: new Date(dueDate),
      status: index === 1 ? 'paid' : 'pending',
      paidAt: index === 1 ? new Date() : null,
      paymentId: index === 1 ? firstPaymentId || null : null,
      dueReminderSentAt: null,
      overdueLockNotifiedAt: null,
    });

    dueDate = addOneCalendarMonth(dueDate);
  }

  return schedule;
}

module.exports = {
  addOneCalendarMonth,
  computeEffectivePrice,
  isEarlyBirdActive,
  buildInstallmentSchedule,
};
