// Flattens a LifestyleAdvice document for the three places it is rendered.
//
// Lives here rather than in routes/prescription-v2.js because the prescription
// email (controllers/prescriptionV2Controller.js) needs the same summary, and
// that route file already requires the controller — importing it back would be
// circular.
//
// Sections are built once and formatted twice. The PDF renders plain text, so
// it must NOT be handed the HTML version and stripped: doing that glued every
// heading to its body ("DietFollow DASH diet…", "occursSleep7-9 hours").
async function lifestyleSections(lifestyleAdviceId) {
  if (!lifestyleAdviceId) return [];
  try {
    const LifestyleAdvice = require('../models/LifestyleAdvice');
    const la = await LifestyleAdvice.findById(lifestyleAdviceId).lean();
    if (!la) return [];

    const list = (v) => (Array.isArray(v) ? v.filter(Boolean).join(', ') : '');
    const out = [];
    const push = (label, ...parts) => {
      const body = parts.filter(Boolean).join(' • ');
      if (body) out.push({ label, body });
    };

    // Schema (and the Flutter model) use the short keys; the longer
    // *Management / *Cessation names were never stored under those spellings,
    // so these four sections silently printed nothing.
    const stress = la.stress || la.stressManagement;
    const smoking = la.smoking || la.smokingCessation;
    const alcohol = la.alcohol || la.alcoholModeration;
    const weight = la.weight || la.weightManagement;

    if (la.diet) push('Diet', la.diet.recommendations, list(la.diet.foodsToInclude) && `Include: ${list(la.diet.foodsToInclude)}`, list(la.diet.foodsToAvoid) && `Avoid: ${list(la.diet.foodsToAvoid)}`, la.diet.mealTiming, la.diet.hydration);
    if (la.exercise) push('Exercise', la.exercise.type, la.exercise.frequency, la.exercise.duration, la.exercise.intensity, list(la.exercise.precautions));
    if (la.sleep) push('Sleep', la.sleep.recommendedHours, la.sleep.sleepSchedule, list(la.sleep.sleepHygieneTips));
    if (stress) push('Stress', list(stress.techniques), stress.recommendations);
    if (smoking) push('Smoking', smoking.plan, smoking.timeline, list(smoking.resources));
    if (alcohol) push('Alcohol', alcohol.recommendations, alcohol.limits);
    if (weight) push('Weight', weight.targetWeight && `Target: ${weight.targetWeight}`, weight.plan, weight.timeline);
    if (Array.isArray(la.otherAdvice) && la.otherAdvice.filter(Boolean).length) push('Other', list(la.otherAdvice));

    return out;
  } catch (_) {
    return [];
  }
}

const htmlBlock = (label, body) =>
  `<div style="margin:0 0 10px 0;">` +
  `<div style="font-weight:700;color:#0F172A;margin-bottom:2px;">${label}</div>` +
  `<div style="color:#374151;padding-left:12px;border-left:2px solid #E2E8F0;">${body}</div>` +
  `</div>`;

async function buildLifestyleHtml(lifestyleAdviceId) {
  const sections = await lifestyleSections(lifestyleAdviceId);
  return sections.map((s) => htmlBlock(s.label, s.body)).join('');
}

/// Plain text for the PDF — one section per line, heading kept separate.
async function buildLifestyleText(lifestyleAdviceId) {
  const sections = await lifestyleSections(lifestyleAdviceId);
  return sections.map((s) => `${s.label}: ${s.body}`).join('\n');
}

function referralFollowUpSections(rf) {
  if (!rf) return [];
  const out = [];
  const referral = [rf.referralType, rf.referralSpecialty, rf.referralNotes].filter(Boolean).join(' • ');
  if (referral) out.push({ label: 'Referral', body: referral });

  const followDate = rf.followUpDate
    ? new Date(rf.followUpDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
    : '';
  const follow = [rf.followUpDuration, followDate, rf.followUpNotes].filter(Boolean).join(' • ');
  if (follow) out.push({ label: 'Follow-Up', body: follow });

  return out;
}

function buildReferralFollowUpHtml(rf) {
  return referralFollowUpSections(rf).map((s) => htmlBlock(s.label, s.body)).join('');
}

function buildReferralFollowUpText(rf) {
  return referralFollowUpSections(rf).map((s) => `${s.label}: ${s.body}`).join('\n');
}

module.exports = {
  buildLifestyleHtml,
  buildLifestyleText,
  buildReferralFollowUpHtml,
  buildReferralFollowUpText,
};
