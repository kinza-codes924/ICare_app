const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const prescriptionV2Controller = require('../controllers/prescriptionV2Controller');

// Save prescription draft
router.post('/consultations/:consultationId/prescription/draft', prescriptionV2Controller.savePrescriptionDraft);

// Get prescription draft
router.get('/consultations/:consultationId/prescription/draft', prescriptionV2Controller.getPrescriptionDraft);

// Complete prescription
router.post('/consultations/:consultationId/prescription/complete', prescriptionV2Controller.completePrescription);

// Get completed prescription by consultationId (fallback when prescriptionId not stored on consultation)
router.get('/consultations/:consultationId/prescription/completed', prescriptionV2Controller.getCompletedPrescriptionByConsultation);

// Get prescription by ID
router.get('/prescriptions/:prescriptionId', prescriptionV2Controller.getPrescription);

// Get patient prescriptions
router.get('/patients/:patientId/prescriptions', prescriptionV2Controller.getPatientPrescriptions);

// Get doctor prescriptions
router.get('/doctors/:doctorId/prescriptions', prescriptionV2Controller.getDoctorPrescriptions);

// Update prescription status
router.patch('/prescriptions/:prescriptionId/status', prescriptionV2Controller.updatePrescriptionStatus);

// ─── One-off migration: repair prescribedAt written as local wall-clock ──────
// Until 2026-08-25 the Flutter client sent `prescribedAt: DateTime.now()`
// serialised without a timezone marker, so Mongo stored the doctor's local
// PKT time as if it were UTC — every read then shifted it again (+5h), and a
// 7:39 PM prescription displayed as 12:39 AM the next day.
//
// Neither field is reliably the good one — the drift runs in both directions
// depending on when the row was written:
//   • older rows: createdAt is +5h ahead of prescribedAt (createdAt is wrong)
//   • recent rows: prescribedAt is +5h ahead of createdAt (prescribedAt wrong)
// In both cases the *earlier* of the two is the true UTC instant, because the
// corruption only ever adds the doctor's UTC offset — it never subtracts. So
// the repair sets both fields to min(prescribedAt, createdAt).
//
// Rows whose two timestamps agree within a few minutes are left untouched.
//
// GET with ?secret=… → dry run (reports what would change, writes nothing).
// POST with ?secret=…&apply=true → performs the update.
async function repairPrescribedAt(req, res) {
  // Deliberately not CRON_SECRET — Vercel reserves that name for its own cron
  // signing and rejects a build if its value has any surrounding whitespace.
  const expected = (process.env.MIGRATION_SECRET || '').trim();
  const secret = (req.query.secret || req.headers['x-migration-secret'] || '').toString().trim();
  if (!expected || secret !== expected) {
    return res.status(403).json({ success: false, message: 'Forbidden' });
  }

  try {
    await connectMongoDB();
    const EnhancedPrescription = require('../models/EnhancedPrescription');

    const apply = req.method === 'POST' && req.query.apply === 'true';
    const SKEW_MS = 5 * 60 * 1000; // ignore sub-5-minute differences

    const rows = await EnhancedPrescription.find({
      prescribedAt: { $ne: null },
      createdAt: { $ne: null },
    }).select('_id prescribedAt createdAt').lean();

    const drifted = rows.filter(
      r => Math.abs(new Date(r.prescribedAt) - new Date(r.createdAt)) > SKEW_MS
    );

    // The true instant is the earlier of the two — corruption only ever adds
    // the doctor's UTC offset, so the inflated field is always the later one.
    const plan = drifted.map(r => {
      const p = new Date(r.prescribedAt);
      const c = new Date(r.createdAt);
      const truth = p < c ? p : c;
      return {
        _id: r._id,
        truth,
        fixes: p < c ? 'createdAt' : 'prescribedAt',
        driftHours: +(Math.abs(p - c) / 3600000).toFixed(2),
      };
    });

    // Drift histogram — a clean diagnosis shows one dominant bucket (5h)
    const buckets = {};
    for (const p of plan) buckets[p.driftHours] = (buckets[p.driftHours] || 0) + 1;

    const sample = plan.slice(0, 10).map(p => ({
      id: p._id.toString(),
      correctedTo: p.truth,
      fieldRepaired: p.fixes,
      driftHours: p.driftHours,
    }));

    if (!apply) {
      return res.json({
        success: true,
        dryRun: true,
        totalPrescriptions: rows.length,
        wouldUpdate: plan.length,
        driftHistogram: buckets,
        sample,
        note: 'POST to this URL with &apply=true to write the changes.',
      });
    }

    // Native driver, not the Mongoose model: `timestamps: true` marks
    // createdAt immutable, so a model-level updateOne silently drops it and
    // only prescribedAt gets written.
    const col = EnhancedPrescription.collection;
    let updated = 0;
    for (const p of plan) {
      const r = await col.updateOne(
        { _id: p._id },
        { $set: { prescribedAt: p.truth, createdAt: p.truth } }
      );
      if (r.modifiedCount) updated++;
    }

    res.json({
      success: true,
      dryRun: false,
      totalPrescriptions: rows.length,
      updated,
      sample,
    });
  } catch (err) {
    console.error('repairPrescribedAt error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
}

router.get('/admin/repair-prescribed-at', repairPrescribedAt);
router.post('/admin/repair-prescribed-at', repairPrescribedAt);

// ─── Old email link redirect: /receipt → /pdf ────────────────────────────────
router.get('/prescriptions/:prescriptionId/receipt', (req, res) => {
  res.redirect(301, `/api/prescriptions-v2/prescriptions/${req.params.prescriptionId}/pdf`);
});

// PKT = UTC+5 — Vercel runs in UTC so .toLocaleString() with 'en-PK' still
// returns UTC on serverless. Hardcode the +5h shift instead.
function pktDate(d) {
  const pkt = new Date(d.getTime() + 5 * 60 * 60 * 1000);
  return pkt.toLocaleDateString('en-US', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
}
function pktTime(d) {
  const pkt = new Date(d.getTime() + 5 * 60 * 60 * 1000);
  return pkt.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: 'UTC' });
}

// Lifestyle advice lives in its own collection, linked by lifestyleAdviceId.
// Flatten whichever of its category sub-documents the doctor actually filled
// in into one readable block; returns '' when there is nothing to show, so
// the caller can omit the whole section.
const { buildLifestyleHtml, buildLifestyleText } = require('../utils/lifestyleSummary');

// The MR number is never stored — the app shows the last six characters of the
// patient id, so the printed and emailed copies derive it the same way rather
// than leaving the row blank.
function mrFromId(patientId) {
  const id = patientId ? patientId.toString() : '';
  return id.length >= 6 ? `MR-${id.slice(-6).toUpperCase()}` : '';
}

// ─── PRINTABLE PRESCRIPTION PAGE — kept for direct browser access ─────────────
router.get('/prescriptions/:prescriptionId/view', async (req, res) => {
  try {
    await connectMongoDB();
    const EnhancedPrescription = require('../models/EnhancedPrescription');
    const User = require('../models/User');

    const rx = await EnhancedPrescription.findById(new mongoose.Types.ObjectId(req.params.prescriptionId)).lean();
    if (!rx) return res.status(404).send('<h2>Prescription not found</h2>');

    const Consultation = require('../models/Consultation');
    const DoctorProfileModel = require('../models/DoctorProfile');
    const [patient, doctor, consultation, docProfile] = await Promise.all([
      rx.patientId ? User.findById(rx.patientId).select('name username mrNumber age gender').lean().catch(() => null) : null,
      User.findById(rx.doctorId).select('name username').lean().catch(() => null),
      rx.consultationId ? Consultation.findById(rx.consultationId).select('patientAge patientGender').lean().catch(() => null) : null,
      DoctorProfileModel.findOne({ user_id: rx.doctorId }).select('license_number specialization').lean().catch(() => null),
    ]);

    const patientName = patient?.name || patient?.username || rx.patientName || 'Patient';
    const doctorName = doctor?.name || doctor?.username || 'Doctor';
    // Age/gender live on the Consultation and the MR number on the User —
    // EnhancedPrescription carries neither, so reading only rx.* left these
    // rows blank on every printed prescription.
    // Age and gender live on the User; the MR number is not stored anywhere —
    // it is derived from the patient id, exactly as the in-app prescription
    // does it, so both copies show the same MR#.
    const ptAge = rx.patientAge || consultation?.patientAge || (patient?.age ? `${patient.age} yrs` : '');
    const ptGender = rx.patientGender || consultation?.patientGender || patient?.gender || '';
    const ptMr = rx.mrNumber || rx.patientMrNumber || patient?.mrNumber || mrFromId(rx.patientId);
    const drPmdc = rx.doctorPmdc || docProfile?.license_number || '';
    const drSpec = docProfile?.specialization || '';
    const dateObj = new Date(rx.prescribedAt || rx.createdAt || Date.now());
    const dateStr = pktDate(dateObj);
    const timeStr = pktTime(dateObj);
    const rxId = rx._id.toString().slice(-8).toUpperCase();

    const diagHtml = (rx.diagnoses || []).map(d => {
      const text = d.description || d.desc || d.diagnosis || d.name || (typeof d === 'string' ? d : '');
      return `<span style="display:inline-block;background:#FEF2F2;border:1px solid #FECACA;color:#991B1B;padding:4px 12px;border-radius:4px;font-size:12px;margin:2px 3px;">${text}</span>`;
    }).join('');

    const medsHtml = (rx.medicines || []).map((m, i) => {
      const name = m.medicineName || m.name || m.medicine || 'Medicine';
      const dose = m.dosage || m.dose || '';
      const freq = m.frequency || '';
      const dur = m.duration || '';
      const details = [dose ? `Dose: ${dose}` : '', freq ? `Frequency: ${freq}` : '', dur ? `Duration: ${dur}` : ''].filter(Boolean).join('  ');
      return `<div style="margin-bottom:8px;padding:10px 14px;background:#EFF6FF;border:1px solid #BFDBFE;border-radius:4px;">
        <p style="margin:0;font-size:13px;font-weight:700;color:#0f172a;">${i + 1}. ${name}</p>
        ${details ? `<p style="margin:4px 0 0;font-size:11px;color:#4B5563;">${details}</p>` : ''}
      </div>`;
    }).join('');

    const labsHtml = (rx.labTests || []).map(t => {
      const name = (typeof t === 'string') ? t : (t.testName || t.name || 'Lab Test');
      return `<li style="margin-bottom:6px;font-size:13px;color:#374151;">${name}</li>`;
    }).join('');

    // Referral / follow-up / lifestyle advice. These are all filled in on the
    // prescription form but none of them used to reach the printed page:
    // referral and lifestyle had no markup at all, and follow-up read a
    // top-level rx.followUpDate that the schema does not have (it lives under
    // referralFollowUp), so that block never rendered either.
    const rf = rx.referralFollowUp || {};
    const referralHtml = (rf.referralType && rf.referralType !== 'none')
      ? [
          `Referred to: ${rf.referralType}${rf.referralSpecialty ? ` — ${rf.referralSpecialty}` : ''}`,
          rf.referralNotes,
        ].filter(Boolean).join('<br/>')
      : '';
    const followUpHtml = (rf.followUpDate || (rf.followUpDuration && rf.followUpDuration !== 'none'))
      ? [
          rf.followUpDate ? `Next visit: ${pktDate(new Date(rf.followUpDate))}` : `Follow up in: ${rf.followUpDuration}`,
          rf.followUpNotes,
        ].filter(Boolean).join('<br/>')
      : '';

    const lifestyleHtml = await buildLifestyleHtml(rx.lifestyleAdviceId);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>iCare Prescription — ${rxId}</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:Arial,sans-serif;background:#f1f5f9;padding:24px;color:#1f2937;font-size:13px}
    .wrap{max-width:740px;margin:0 auto;background:#fff;border-radius:8px;box-shadow:0 2px 16px rgba(0,0,0,0.08);overflow:hidden}
    .hdr{padding:24px 32px 20px}
    .hdr-row{display:table;width:100%}
    .hdr-left{display:table-cell;vertical-align:top}
    .hdr-right{display:table-cell;vertical-align:top;text-align:right}
    .brand{font-size:26px;font-weight:900;color:#1D4ED8;line-height:1}
    .brand-sub{font-size:10px;color:#6B7280;margin-top:3px}
    .date-text{font-size:13px;font-weight:700;color:#1f2937}
    .time-text{font-size:11px;color:#6B7280;margin-top:2px}
    .divider{height:3px;background:#1D4ED8;margin:0}
    .body{padding:24px 32px}
    .pt-dr-row{display:table;width:100%;margin-bottom:20px}
    .pt-col,.dr-col{display:table-cell;width:50%;vertical-align:top;padding:12px}
    .col-label{font-size:8px;font-weight:700;color:#9CA3AF;text-transform:uppercase;letter-spacing:.6px;margin-bottom:6px}
    .col-name{font-size:15px;font-weight:800;color:#0f172a;margin-bottom:2px}
    .col-sub{font-size:11px;color:#6B7280}
    .sec-title{font-size:9px;font-weight:800;color:#1D4ED8;text-transform:uppercase;letter-spacing:.6px;margin-bottom:10px}
    .sec{margin-bottom:20px}
    .validity-box{background:#FFFBEB;border:1px solid #FDE68A;border-radius:6px;padding:10px 14px;margin-bottom:20px;font-size:12px;color:#92400E}
    .sig-row{display:table;width:100%;border-top:2px solid #e2e8f0;padding-top:16px;margin-top:8px}
    .sig-right{display:table-cell;text-align:right;vertical-align:bottom}
    .sig-line-elem{width:180px;border-top:1.5px solid #000;display:inline-block;margin-bottom:4px}
    .sig-name{font-size:13px;font-weight:700;color:#0f172a}
    .sig-sub{font-size:10px;color:#6B7280}
    .footer-box{background:#F3F4F6;border-radius:4px;padding:10px 14px;margin-top:16px;font-size:9px;color:#6B7280;text-align:center;line-height:1.5}
    .print-btn{display:block;margin:20px auto 0;padding:11px 36px;background:#1D4ED8;color:#fff;border:none;border-radius:8px;font-size:14px;font-weight:700;cursor:pointer}
    @media print{.print-btn{display:none}body{background:#fff;padding:0}.wrap{box-shadow:none;border-radius:0}}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hdr">
      <div class="hdr-row">
        <div class="hdr-left">
          <div class="brand">iCare</div>
          <div class="brand-sub">RM Health Solutions (Private) Limited<br/>iCare Telemedicine Platform</div>
        </div>
        <div class="hdr-right">
          <div class="date-text">${dateStr}</div>
          <div class="time-text">${timeStr}</div>
        </div>
      </div>
    </div>
    <div class="divider"></div>

    <div class="body">
      <div class="pt-dr-row">
        <div class="pt-col">
          <div class="col-label">Patient</div>
          <div class="col-name">${patientName}</div>
          ${ptAge ? `<div class="col-sub">Age: ${ptAge}${ptGender ? '  |  Gender: ' + ptGender : ''}</div>` : ''}
          ${ptMr ? `<div class="col-sub" style="font-weight:700;">MR#: ${ptMr}</div>` : ''}
        </div>
        <div class="dr-col">
          <div class="col-label">Doctor</div>
          <div class="col-name">Dr. ${doctorName}</div>
          ${drSpec ? `<div class="col-sub">${drSpec}</div>` : ''}
          ${drPmdc ? `<div class="col-sub">PMDC: ${drPmdc}</div>` : ''}
          ${rx.doctorPhone ? `<div class="col-sub">Phone: ${rx.doctorPhone}</div>` : ''}
        </div>
      </div>

      ${diagHtml ? `<div class="sec"><div class="sec-title">Diagnosis</div><div>${diagHtml}</div></div>` : ''}

      ${medsHtml ? `<div class="sec"><div class="sec-title">Rx&nbsp;&nbsp;Medications</div>${medsHtml}</div>` : ''}

      ${labsHtml ? `<div class="sec"><div class="sec-title">Lab Tests</div><ul style="padding-left:20px;margin:0;">${labsHtml}</ul></div>` : ''}

      ${rx.doctorNotes ? `<div class="sec"><div class="sec-title">Doctor Notes</div><p style="font-size:12px;color:#374151;line-height:1.6;margin:0;">${rx.doctorNotes}</p></div>` : ''}

      ${lifestyleHtml ? `<div class="sec"><div class="sec-title">Lifestyle Advice</div><p style="font-size:12px;color:#374151;line-height:1.6;margin:0;">${lifestyleHtml}</p></div>` : ''}

      ${referralHtml ? `<div class="sec"><div class="sec-title">Referral</div><p style="font-size:12px;color:#374151;line-height:1.6;margin:0;">${referralHtml}</p></div>` : ''}

      ${followUpHtml ? `<div class="sec"><div class="sec-title">Follow-Up</div><p style="font-size:13px;color:#374151;margin:0;">${followUpHtml}</p></div>` : ''}

      <div class="validity-box">⚠️ This prescription is valid for <strong>30 days</strong> from the date of issue.</div>

      <!-- No signature line: these are issued electronically, so the doctor
           is identified by PMDC registration number rather than a signature. -->
      <div class="sig-row">
        <div class="sig-right">
          <div class="sig-name">${drPmdc ? `PMDC Reg. No. ${drPmdc}` : `Dr. ${doctorName}`}</div>
          <div class="sig-sub">Electronically Generated</div>
        </div>
      </div>

      <div class="footer-box">
        This prescription has been electronically generated and authenticated via iCare — RM Health Solutions (Private) Limited.<br/>
        Valid only for the stated patient and date. &nbsp;|&nbsp; <strong>www.icare.com.co</strong> &nbsp;|&nbsp; Prescription Ref: ${rxId}
      </div>

      <button class="print-btn" onclick="window.print()">🖨️ Print / Save as PDF</button>
    </div>
  </div>
</body>
</html>`;
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } catch (e) {
    console.error('[Prescription] Receipt error:', e.message);
    res.status(500).send('<h2>Error loading prescription</h2>');
  }
});

// ─── PDF DOWNLOAD — direct prescription PDF download (public, no auth) ──────────
router.get('/prescriptions/:prescriptionId/pdf', async (req, res) => {
  try {
    await connectMongoDB();
    const EnhancedPrescription = require('../models/EnhancedPrescription');
    const User = require('../models/User');
    const PDFDocument = require('pdfkit');

    const rx = await EnhancedPrescription.findById(new mongoose.Types.ObjectId(req.params.prescriptionId)).lean();
    if (!rx) return res.status(404).json({ success: false, message: 'Prescription not found' });

    const DoctorProfile = require('../models/DoctorProfile');
    const { resolveClinicAddress } = require('../utils/clinicAddresses');
    const ConsultationModel = require('../models/Consultation');
    const [patient, doctor, doctorProfile, consultation] = await Promise.all([
      rx.patientId ? User.findById(rx.patientId).select('name username mrNumber age gender').lean().catch(() => null) : null,
      User.findById(rx.doctorId).select('name username').lean().catch(() => null),
      DoctorProfile.findOne({ user_id: rx.doctorId }).lean().catch(() => null),
      rx.consultationId ? ConsultationModel.findById(rx.consultationId).select('patientAge patientGender').lean().catch(() => null) : null,
    ]);
    const clinicAddress = resolveClinicAddress(doctorProfile);

    const patientName = patient?.name || patient?.username || rx.patientName || 'Patient';
    const doctorName = doctor?.name || doctor?.username || 'Doctor';
    // Same resolution as the HTML view — these fields do not live on the
    // prescription document itself.
    // Age and gender live on the User; the MR number is not stored anywhere —
    // it is derived from the patient id, exactly as the in-app prescription
    // does it, so both copies show the same MR#.
    const ptAge = rx.patientAge || consultation?.patientAge || (patient?.age ? `${patient.age} yrs` : '');
    const ptGender = rx.patientGender || consultation?.patientGender || patient?.gender || '';
    const ptMr = rx.mrNumber || rx.patientMrNumber || patient?.mrNumber || mrFromId(rx.patientId);
    const drPmdc = rx.doctorPmdc || doctorProfile?.license_number || '';
    const drSpec = doctorProfile?.specialization || '';
    const dateObj = new Date(rx.prescribedAt || rx.createdAt || Date.now());
    const dateStr = pktDate(dateObj);
    const timeStr = pktTime(dateObj);
    const rxId = rx._id.toString().slice(-8).toUpperCase();

    // ── Build PDF ──────────────────────────────────────────────────────────────
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    const path = require('path');
    const fs   = require('fs');

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="iCare-Prescription-${rxId}.pdf"`);
    doc.pipe(res);

    const BLUE = '#1D4ED8';
    const DARK = '#0f172a';
    const GREY = '#6B7280';
    const RED  = '#991B1B';
    const pageWidth = doc.page.width - 100; // margins on both sides

    // ── Header ─────────────────────────────────────────────────────────────────
    const logoPath = path.join(__dirname, '../assets/logo.png');
    const logoExists = fs.existsSync(logoPath);

    if (logoExists) {
      // Logo top-left (height 60px, width auto)
      doc.image(logoPath, 50, 36, { height: 60 });
      // Brand text right of logo
      const textX = 122;
      doc.fontSize(22).fillColor(BLUE).font('Helvetica-Bold').text('iCare', textX, 44);
      doc.fontSize(8.5).fillColor(GREY).font('Helvetica')
         .text('RM Health Solutions (Private) Limited', textX, 70)
         .text('iCare Telemedicine Platform', textX, 82);
    } else {
      // Fallback — no logo image
      doc.fontSize(26).fillColor(BLUE).font('Helvetica-Bold').text('iCare', 50, 50);
      doc.fontSize(9).fillColor(GREY).font('Helvetica')
         .text('RM Health Solutions (Private) Limited', 50, 82)
         .text('iCare Telemedicine Platform', 50, 94);
    }

    // Date top-right
    doc.fontSize(11).fillColor(DARK).font('Helvetica-Bold')
       .text(dateStr, 50, 44, { align: 'right', width: pageWidth });
    doc.fontSize(9).fillColor(GREY).font('Helvetica')
       .text(timeStr, 50, 60, { align: 'right', width: pageWidth });

    // Blue divider
    const divY = 108;
    doc.rect(50, divY, pageWidth, 3).fill(BLUE);

    // ── Patient / Doctor columns ───────────────────────────────────────────────
    const colY = divY + 16;
    const colW = (pageWidth - 20) / 2;

    // Patient column
    doc.fontSize(7).fillColor(GREY).font('Helvetica-Bold').text('PATIENT', 50, colY);
    doc.fontSize(13).fillColor(DARK).font('Helvetica-Bold').text(patientName, 50, colY + 12);
    let ptY = colY + 28;
    if (ptAge) {
      const ageGender = `Age: ${ptAge}${ptGender ? '  |  Gender: ' + ptGender : ''}`;
      doc.fontSize(9).fillColor(GREY).font('Helvetica').text(ageGender, 50, ptY);
      ptY += 13;
    }
    if (ptMr) {
      doc.fontSize(9).fillColor(DARK).font('Helvetica-Bold').text(`MR# ${ptMr}`, 50, ptY);
    }

    // Doctor column
    const drX = 50 + colW + 20;
    doc.fontSize(7).fillColor(GREY).font('Helvetica-Bold').text('DOCTOR', drX, colY);
    doc.fontSize(13).fillColor(DARK).font('Helvetica-Bold').text(`Dr. ${doctorName}`, drX, colY + 12);
    let drY = colY + 28;
    if (drSpec) {
      doc.fontSize(9).fillColor(GREY).font('Helvetica').text(drSpec, drX, drY);
      drY += 13;
    }
    if (drPmdc) {
      doc.fontSize(9).fillColor(GREY).font('Helvetica').text(`PMDC: ${drPmdc}`, drX, drY);
      drY += 13;
    }
    if (rx.doctorPhone) {
      doc.fontSize(9).fillColor(GREY).font('Helvetica').text(`Phone: ${rx.doctorPhone}`, drX, drY);
      drY += 13;
    }
    if (clinicAddress) {
      const addrColW = pageWidth - colW - 20;
      doc.fontSize(8).fillColor(GREY).font('Helvetica').text(clinicAddress, drX, drY, { width: addrColW });
      drY += doc.heightOfString(clinicAddress, { width: addrColW });
    }

    // thin divider after patient/doctor block
    let curY = Math.max(ptY, drY) + 24;

    // This page is laid out by absolute Y with no page-break handling at all.
    // Once the content outgrew one page — which a full lab-test list plus
    // lifestyle advice does easily — curY simply kept counting past the bottom
    // margin, and every later draw call landed off-page, so pdfkit scattered
    // the rest across blank pages. One prescription was coming out as four.
    // Start a fresh page deliberately when the next block will not fit.
    const PAGE_TOP = 50;
    const pageBottom = () => doc.page.height - 60;
    const ensureSpace = (needed) => {
      if (curY + needed > pageBottom()) {
        doc.addPage();
        curY = PAGE_TOP;
      }
    };
    doc.rect(50, curY, pageWidth, 0.5).fill('#e2e8f0');
    curY += 12;

    // ── Diagnosis ──────────────────────────────────────────────────────────────
    const diagnoses = rx.diagnoses || [];
    if (diagnoses.length > 0) {
      ensureSpace(40);
      doc.fontSize(8).fillColor(BLUE).font('Helvetica-Bold').text('DIAGNOSIS', 50, curY);
      curY += 14;
      diagnoses.forEach((d) => {
        const text = d.description || d.desc || d.diagnosis || d.name || (typeof d === 'string' ? d : '');
        if (!text) return;
        const tw = doc.widthOfString(text, { fontSize: 10 }) + 16;
        ensureSpace(28);
        doc.rect(50, curY - 3, tw, 18).fill('#FEF2F2').stroke('#FECACA');
        doc.fontSize(10).fillColor(RED).font('Helvetica').text(text, 58, curY + 1);
        curY += 24;
      });
      curY += 4;
    }

    // ── Medications ────────────────────────────────────────────────────────────
    const medicines = rx.medicines || [];
    if (medicines.length > 0) {
      ensureSpace(40);
      doc.fontSize(8).fillColor(BLUE).font('Helvetica-Bold').text('Rx   MEDICATIONS', 50, curY);
      curY += 14;
      medicines.forEach((m, i) => {
        const name = m.medicineName || m.name || m.medicine || 'Medicine';
        const dose = m.dosage || m.dose || '';
        const freq = m.frequency || '';
        const dur  = m.duration || '';
        const details = [dose && `Dose: ${dose}`, freq && `Frequency: ${freq}`, dur && `Duration: ${dur}`].filter(Boolean).join('   ');

        // card background
        ensureSpace(details ? 50 : 36);
        doc.rect(50, curY - 4, pageWidth, details ? 34 : 22).fill('#EFF6FF').stroke('#BFDBFE');
        doc.fontSize(11).fillColor(DARK).font('Helvetica-Bold').text(`${i + 1}. ${name}`, 62, curY);
        if (details) {
          doc.fontSize(9).fillColor(GREY).font('Helvetica').text(details, 62, curY + 14);
        }
        curY += details ? 44 : 30;
      });
      curY += 4;
    }

    // ── Lab Tests ──────────────────────────────────────────────────────────────
    const labTests = rx.labTests || [];
    if (labTests.length > 0) {
      ensureSpace(40);
      doc.fontSize(8).fillColor(BLUE).font('Helvetica-Bold').text('LAB TESTS', 50, curY);
      curY += 14;
      labTests.forEach((t) => {
        const name = typeof t === 'string' ? t : (t.testName || t.name || 'Lab Test');
        ensureSpace(20);
        doc.fontSize(10).fillColor(DARK).font('Helvetica').text(`•  ${name}`, 60, curY);
        curY += 16;
      });
      curY += 4;
    }

    // ── Doctor Notes ───────────────────────────────────────────────────────────
    if (rx.doctorNotes) {
      ensureSpace(40);
      doc.fontSize(8).fillColor(BLUE).font('Helvetica-Bold').text('DOCTOR NOTES', 50, curY);
      curY += 12;
      doc.fontSize(10).fillColor(DARK).font('Helvetica').text(rx.doctorNotes, 50, curY, { width: pageWidth });
      curY += doc.heightOfString(rx.doctorNotes, { width: pageWidth }) + 10;
    }

    // ── Lifestyle Advice / Referral / Follow-up ────────────────────────────────
    // Same three sections the HTML view gained: referral and lifestyle had no
    // output at all here, and follow-up read a top-level rx.followUpDate the
    // schema does not have (it lives under referralFollowUp), so it never
    // printed even when the doctor set one.
    // Advance by pdfkit's own cursor rather than by a measured height. When a
    // block is long enough to flow onto a new page, pdfkit starts that page
    // itself and doc.y follows it — while a hand-computed curY kept counting
    // down the old page, pushing everything after it past the bottom and
    // spawning blank pages. Lifestyle advice became long enough to trigger it,
    // which is how one prescription turned into four pages.
    const pdfSection = (title, body) => {
      if (!body) return;
      doc.fontSize(8).fillColor(BLUE).font('Helvetica-Bold').text(title, 50, curY);
      doc.fontSize(10).fillColor(DARK).font('Helvetica').text(body, 50, doc.y + 2, { width: pageWidth });
      curY = doc.y + 10;
    };

    const stripTags = (s) => s.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '');
    const rfPdf = rx.referralFollowUp || {};

    // Plain-text build, not the HTML one stripped — stripping glued each
    // heading onto its body ("DietFollow DASH diet…", "occursSleep7-9 hours").
    pdfSection('LIFESTYLE ADVICE', await buildLifestyleText(rx.lifestyleAdviceId));

    if (rfPdf.referralType && rfPdf.referralType !== 'none') {
      pdfSection('REFERRAL', [
        `Referred to: ${rfPdf.referralType}${rfPdf.referralSpecialty ? ` — ${rfPdf.referralSpecialty}` : ''}`,
        rfPdf.referralNotes,
      ].filter(Boolean).join('\n'));
    }

    if (rfPdf.followUpDate || (rfPdf.followUpDuration && rfPdf.followUpDuration !== 'none')) {
      pdfSection('FOLLOW-UP', [
        rfPdf.followUpDate ? `Next visit: ${pktDate(new Date(rfPdf.followUpDate))}` : `Follow up in: ${rfPdf.followUpDuration}`,
        rfPdf.followUpNotes,
      ].filter(Boolean).join('\n'));
    }

    // ── Attribution block (bottom, right-aligned) ─────────────────────────────
    // No signature line — these are issued electronically, so the doctor is
    // identified by PMDC registration number rather than a signature.
    curY += 20;
    doc.rect(50, curY, pageWidth, 0.5).fill('#e2e8f0');
    curY += 16;
    const sigLineX = doc.page.width - 50 - 180;
    const attribText = drPmdc ? `PMDC Reg. No. ${drPmdc}` : `Dr. ${doctorName}`;
    doc.fontSize(11).fillColor(DARK).font('Helvetica-Bold').text(attribText, sigLineX, curY, { width: 180, align: 'center' });
    curY += doc.heightOfString(attribText, { width: 180 }) + 3;
    doc.fontSize(9).fillColor(GREY).font('Helvetica').text('Electronically Generated', sigLineX, curY, { width: 180, align: 'center' });

    // ── Footer disclaimer ──────────────────────────────────────────────────────
    const footerY = doc.page.height - 80;
    doc.rect(50, footerY, pageWidth, 44).fill('#F3F4F6');
    doc.fontSize(8).fillColor(GREY).font('Helvetica')
       .text(
         `This prescription has been electronically generated and authenticated via iCare — RM Health Solutions (Private) Limited.\nValid only for the stated patient and date.  |  www.icare.com.co  |  Prescription Ref: ${rxId}`,
         58, footerY + 8, { width: pageWidth - 16, align: 'center' }
       );

    doc.end();
  } catch (e) {
    console.error('[Prescription] PDF error:', e.message);
    if (!res.headersSent) res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
