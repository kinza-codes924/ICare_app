// Flattens a LifestyleAdvice document into one HTML fragment.
//
// Lives here rather than in routes/prescription-v2.js because the prescription
// email (controllers/prescriptionV2Controller.js) needs the same summary, and
// that route file already requires the controller — importing it back would be
// circular.
async function buildLifestyleHtml(lifestyleAdviceId) {
  if (!lifestyleAdviceId) return '';
  try {
    const LifestyleAdvice = require('../models/LifestyleAdvice');
    const la = await LifestyleAdvice.findById(lifestyleAdviceId).lean();
    if (!la) return '';

    const list = (v) => (Array.isArray(v) ? v.filter(Boolean).join(', ') : '');
    const lines = [];
    const push = (label, ...parts) => {
      const body = parts.filter(Boolean).join(' — ');
      if (body) lines.push(`<strong>${label}:</strong> ${body}`);
    };

    if (la.diet) push('Diet', la.diet.recommendations, list(la.diet.foodsToInclude) && `Include: ${list(la.diet.foodsToInclude)}`, list(la.diet.foodsToAvoid) && `Avoid: ${list(la.diet.foodsToAvoid)}`, la.diet.mealTiming, la.diet.hydration);
    if (la.exercise) push('Exercise', la.exercise.type, la.exercise.frequency, la.exercise.duration, la.exercise.intensity, list(la.exercise.precautions));
    if (la.sleep) push('Sleep', la.sleep.recommendedHours, la.sleep.sleepSchedule, list(la.sleep.sleepHygieneTips));
    // Schema (and the Flutter model) use the short keys; the longer
    // *Management / *Cessation names were never stored under those spellings,
    // so these four sections silently printed nothing.
    const stress = la.stress || la.stressManagement;
    const smoking = la.smoking || la.smokingCessation;
    const alcohol = la.alcohol || la.alcoholModeration;
    const weight = la.weight || la.weightManagement;

    if (stress) push('Stress', list(stress.techniques), stress.recommendations);
    if (smoking) push('Smoking', smoking.plan, smoking.timeline, list(smoking.resources));
    if (alcohol) push('Alcohol', alcohol.recommendations, alcohol.limits);
    if (weight) push('Weight', weight.targetWeight && `Target: ${weight.targetWeight}`, weight.plan, weight.timeline);
    if (Array.isArray(la.otherAdvice) && la.otherAdvice.filter(Boolean).length) push('Other', list(la.otherAdvice));

    return lines.join('<br/>');
  } catch (_) {
    return '';
  }
}

// Referral + follow-up, flattened the same way.
function buildReferralFollowUpHtml(rf) {
  if (!rf) return '';
  const lines = [];
  const referral = [rf.referralType, rf.referralSpecialty, rf.referralNotes].filter(Boolean).join(' — ');
  if (referral) lines.push(`<strong>Referral:</strong> ${referral}`);

  const followDate = rf.followUpDate ? new Date(rf.followUpDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
  const follow = [rf.followUpDuration, followDate, rf.followUpNotes].filter(Boolean).join(' — ');
  if (follow) lines.push(`<strong>Follow-Up:</strong> ${follow}`);

  return lines.join('<br/>');
}

module.exports = { buildLifestyleHtml, buildReferralFollowUpHtml };
