const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const Product = require('../models/Product');
const Course = require('../models/Course');

const SAMPLE_PRODUCTS = [
  { name: 'Panadol (Paracetamol 500mg)', generic_name: 'Paracetamol', manufacturer: 'GSK Pakistan', price: 35, stock_quantity: 200, medicine_category: 'OTC', requires_prescription: false, description: 'Pain reliever and fever reducer' },
  { name: 'Brufen (Ibuprofen 400mg)', generic_name: 'Ibuprofen', manufacturer: 'Abbott Pakistan', price: 85, stock_quantity: 150, medicine_category: 'OTC', requires_prescription: false, description: 'Anti-inflammatory pain reliever' },
  { name: 'Augmentin (Amoxicillin 625mg)', generic_name: 'Amoxicillin+Clavulanate', manufacturer: 'GSK Pakistan', price: 420, stock_quantity: 80, medicine_category: 'OTC', requires_prescription: true, description: 'Antibiotic for bacterial infections' },
  { name: 'Risek (Omeprazole 20mg)', generic_name: 'Omeprazole', manufacturer: 'Getz Pharma', price: 180, stock_quantity: 120, medicine_category: 'OTC', requires_prescription: false, description: 'Acid reflux and stomach ulcer treatment' },
  { name: 'Glucophage (Metformin 500mg)', generic_name: 'Metformin', manufacturer: 'Merck Pakistan', price: 95, stock_quantity: 100, medicine_category: 'OTC', requires_prescription: true, description: 'Diabetes management medication' },
  { name: 'Lipitor (Atorvastatin 20mg)', generic_name: 'Atorvastatin', manufacturer: 'Pfizer Pakistan', price: 320, stock_quantity: 60, medicine_category: 'OTC', requires_prescription: true, description: 'Cholesterol lowering medication' },
  { name: 'Disprin (Aspirin 300mg)', generic_name: 'Aspirin', manufacturer: 'Reckitt Pakistan', price: 25, stock_quantity: 300, medicine_category: 'OTC', requires_prescription: false, description: 'Pain relief and blood thinner' },
  { name: 'ORS Sachet (Oral Rehydration)', generic_name: 'ORS', manufacturer: 'National Pharma', price: 15, stock_quantity: 500, medicine_category: 'OTC', requires_prescription: false, description: 'Rehydration therapy for diarrhea' },
  { name: 'Flagyl (Metronidazole 400mg)', generic_name: 'Metronidazole', manufacturer: 'Sanofi Pakistan', price: 110, stock_quantity: 90, medicine_category: 'OTC', requires_prescription: true, description: 'Antibiotic for gut infections' },
  { name: 'Ventolin Inhaler (Salbutamol)', generic_name: 'Salbutamol', manufacturer: 'GSK Pakistan', price: 280, stock_quantity: 40, medicine_category: 'OTC', requires_prescription: true, description: 'Bronchodilator for asthma relief' },
];

// POST /api/seed/products — seed sample products for all pharmacies that have none
router.post('/products', async (req, res) => {
  try {
    await connectMongoDB();

    // Find all pharmacy users
    const pharmacies = await User.find({ role: { $in: ['Pharmacy', 'pharmacy'] } }).lean();
    if (pharmacies.length === 0) {
      return res.json({ success: false, message: 'No pharmacies found in database' });
    }

    let totalCreated = 0;
    for (const pharmacy of pharmacies) {
      const existing = await Product.countDocuments({ pharmacy_id: pharmacy._id });
      if (existing > 0) continue; // skip pharmacies that already have products

      const docs = SAMPLE_PRODUCTS.map(p => ({ ...p, pharmacy_id: pharmacy._id, is_active: true }));
      await Product.insertMany(docs);
      totalCreated += docs.length;
    }

    res.json({
      success: true,
      message: `Seeded ${totalCreated} products across ${pharmacies.length} pharmacies`,
      pharmaciesCount: pharmacies.length,
      productsCreated: totalCreated,
    });
  } catch (err) {
    console.error('Seed products error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/seed/rm-courses — seed 8 RM Health Solutions courses for Healthcare Professionals
router.post('/rm-courses', async (req, res) => {
  try {
    await connectMongoDB();

    // Find admin user to act as instructor
    const admin = await User.findOne({ role: { $in: ['Admin', 'admin'] } }).lean();
    if (!admin) return res.status(400).json({ success: false, message: 'No admin user found to use as instructor' });

    const instructorId = admin._id;

    const rmCourses = [
      {
        title: 'Certificate in Implantology',
        description: 'Take your surgical skills to the next level and master the placement and restoration of dental implants with clinical precision and long-term success. This intensive 90-day hybrid course is designed for dental practitioners who want to confidently perform implant surgeries and deliver superior patient outcomes.\n\nBy combining AI-enabled digital learning with intensive localized hands-on workshops, we empower you to master every aspect of implant dentistry—from patient selection and surgical planning to final prosthetic delivery.',
        price: 150000,
        difficulty: 'Advanced',
        modules: [
          {
            title: 'Phase 1: Implant Foundations & Planning (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Implant Biology & Osseointegration', content: 'Understanding the biological basis of osseointegration, bone anatomy, and healing timelines.', order: 1 },
              { title: 'Module 2: Patient Selection & Medical Assessment', content: 'Identifying ideal and contraindicated candidates. Medical history review and risk stratification.', order: 2 },
              { title: 'Module 3: Digital Implant Planning (CBCT & Guides)', content: 'Using CBCT scans and implant planning software for safe, predictable placements. Introduction to surgical guides.', order: 3 },
              { title: 'Module 4: Implant Systems & Prosthetic Options', content: 'Comparing major implant systems, platforms, and the spectrum of restorations: single crowns, bridges, and full-arch.', order: 4 },
              { title: 'Module 5: Managing Complications & Failures', content: 'Peri-implantitis, bone loss, and implant failure—prevention, diagnosis, and remediation protocols.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Implant Surgery Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Surgical Simulation on Bone Models', content: 'Hands-on drilling protocols and implant placement on synthetic bone models replicating real clinical scenarios.', order: 1 },
              { title: 'Soft Tissue Management Workshop', content: 'Flap design, atraumatic extraction, and immediate implant placement techniques.', order: 2 },
              { title: 'Bone Grafting Fundamentals', content: 'Guided Bone Regeneration (GBR) principles and hands-on socket grafting practice.', order: 3 },
              { title: 'Abutment Selection & Impression Techniques', content: 'Selecting the correct abutment and taking implant-level impressions for the lab.', order: 4 },
              { title: 'Final Prosthetic Delivery & Occlusion', content: 'Fitting and torquing final crowns, bite adjustment, and maintenance protocols.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Mastering Aesthetic Dentistry',
        description: 'Elevate your clinical artistry and master the smile transformations that patients demand. This intensive 90-day hybrid course is designed for dental practitioners who want to move beyond functional restorations to achieve world-class aesthetic results.\n\nBy combining AI-enabled digital theory with localized hands-on workshops, we empower you to deliver predictable, minimally invasive, and stunning smile makeovers using the latest composite, porcelain, and chemical brightening technologies.',
        price: 150000,
        difficulty: 'Intermediate',
        modules: [
          {
            title: 'Phase 1: Science & Digital Artistry (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Digital Smile Design (DSD)', content: 'Analyzing facial symmetry and golden proportions using AI-driven software.', order: 1 },
              { title: 'Module 2: Advanced Bleaching & Whitening', content: 'The chemistry of peroxide, home vs. in-office protocols, and managing post-op sensitivity. Patient selection, and treatment options for discoloration.', order: 2 },
              { title: 'Module 3: Material Science & Adhesion', content: 'Mastering the chemistry of long-lasting, sensitivity-free bonds for composites and ceramics.', order: 3 },
              { title: 'Module 4: Color Science & Shading', content: 'Mastering the art of shade matching with traditional vs digital shade matching to match natural dentition.', order: 4 },
              { title: 'Module 5: Conservative Modalities', content: 'Understanding Enamel Micro-abrasion and Resin Infiltration (ICON) for white spot lesions.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Artistry Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Chemical Brightening Workshop', content: 'Clinical application of professional bleaching systems and customized tray fabrication.', order: 1 },
              { title: 'Composite Artistry', content: 'Master the polychromatic layering technique for invisible Class IV and Diastema closures.', order: 2 },
              { title: 'Veneer Preparations', content: 'Hands-on practice with various prep designs (Minimal-prep to No-prep veneers).', order: 3 },
              { title: 'Rubber Dam Mastery', content: 'Achieving the total isolation required for predictable aesthetic bonding.', order: 4 },
              { title: 'Gingival Aesthetics', content: '"Pink Aesthetics"—introduction to crown lengthening and soft tissue contouring for a harmonious smile.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Mastering Paediatric Dentistry',
        description: 'Equip yourself with the specialized skills needed to treat the most precious members of your practice. This intensive 90-day hybrid course is designed for general dental practitioners who want to master clinical excellence, advanced restorative techniques, and the critical art of sedation for children and adolescents.\n\nBy merging AI-enabled digital learning with intensive localized hands-on workshops, we provide the confidence to transform "fearful" appointments into successful clinical outcomes.',
        price: 150000,
        difficulty: 'Intermediate',
        modules: [
          {
            title: 'Phase 1: Foundations & Sedation Theory (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Behavior Management & Psychology', content: 'Modern techniques for managing anxiety and special-needs patients.', order: 1 },
              { title: 'Module 2: Pharmacological Management', content: 'Deep dive into Nitrous Oxide Sedation and the indications/protocols for General Anaesthesia (GA) in paediatric dentistry.', order: 2 },
              { title: 'Module 3: Paediatric Endodontics', content: 'Mastering pulpotomies and pulpectomies in primary and young permanent teeth.', order: 3 },
              { title: 'Module 4: Preventive & Interceptive Care', content: 'Space management, space maintainers, and fluoride therapies (SDF).', order: 4 },
              { title: 'Module 5: Dental Traumatology', content: 'Emergency management of avulsions and fractures in the primary and permanent dentition.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Paediatric Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Nitrous Oxide Machine Training', content: 'Practical workshop on machine setup, titration, monitoring, and safety protocols for conscious sedation.', order: 1 },
              { title: 'Stainless Steel Crowns (SSC)', content: 'Hands-on preparation and fitting for multi-surface decay in primary molars.', order: 2 },
              { title: 'Strip Crowns & Aesthetic Restorations', content: 'Mastering the "Art of the Smile" for the paediatric patient using celluloid strip crowns.', order: 3 },
              { title: 'Space Maintainer Lab', content: 'Practical workshop on designing and fitting band-and-loop space maintainers.', order: 4 },
              { title: 'Advanced Isolation & Extraction', content: 'Mastering rubber dam placement and atraumatic extraction protocols for children.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Mastering Modern Endodontics',
        description: 'Take the "guesswork" out of root canal therapy and transition from traditional hand-filing to advanced, predictable rotary endodontics. This intensive 90-day hybrid course is designed for general practitioners who want to master efficient cleaning, shaping, and 3D obturation of complex root canal systems.\n\nBy merging AI-enabled digital learning with intensive localized hands-on workshops, we provide the clinical precision required to handle curved canals, retreatment cases, and endodontic emergencies with zero stress.',
        price: 150000,
        difficulty: 'Advanced',
        modules: [
          {
            title: 'Phase 1: Access & Anatomy (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Internal Anatomy & Access Openings', content: 'Mastering "Straight-line access" and locating MB2 or hidden canals.', order: 1 },
              { title: 'Module 2: Endodontic Radiology & CBCT', content: 'Interpretation of periapical lesions and using 3D imaging for complex cases.', order: 2 },
              { title: 'Module 3: Glide Path & Cleaning', content: 'The science of irrigation protocols (NaOCl, EDTA, Activation) to ensure a sterile canal.', order: 3 },
              { title: 'Module 4: Biomechanics', content: 'Understanding the difference between Rotary and Reciprocation systems.', order: 4 },
              { title: 'Module 5: Emergency Endodontics', content: 'Managing "Hot pulps," flare-ups, and acute apical periodontitis.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Endodontic Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Access Cavity Workshop', content: 'Practicing precise access on extracted teeth and specialized endo-models.', order: 1 },
              { title: 'Rotary Mastery', content: 'Hands-on training with various motor systems and file sequences to avoid instrument separation.', order: 2 },
              { title: 'Apex Locator Training', content: 'Clinical protocols for using electronic apex locators to ensure perfect working lengths.', order: 3 },
              { title: 'Warm Vertical Compaction', content: 'Mastering 3D obturation techniques for dense, void-free fills.', order: 4 },
              { title: 'Post & Core Build-up', content: 'Hands-on placement of fiber posts to restore the endodontically treated tooth.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Digital Dentistry (CAD/CAM)',
        description: 'Step into the future of dentistry and eliminate the "analog" bottleneck of your practice. This intensive 90-day hybrid course is designed for dental practitioners who want to master the complete digital workflow—from high-precision intraoral scanning to in-office 3D printing and milling.\n\nBy merging AI-enabled digital learning with intensive localized hands-on workshops, we empower you to deliver "Same-Day Dentistry," increasing your clinical efficiency and providing a superior patient experience.',
        price: 150000,
        difficulty: 'Advanced',
        modules: [
          {
            title: 'Phase 1: The Digital Blueprint (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Foundations of Digital Dentistry', content: 'Hardware vs. Software—choosing the right scanner and milling unit for your budget.', order: 1 },
              { title: 'Module 2: Digital Impressions', content: 'Mastering the "Scan Path" for error-free intraoral impressions.', order: 2 },
              { title: 'Module 3: CAD Fundamentals', content: 'Introduction to tooth library selection and designing single-unit crowns, inlays, and onlays.', order: 3 },
              { title: 'Module 4: Material Science in CAD/CAM', content: 'Zirconia vs. Lithium Disilicate (e.Max) vs. Hybrid Resins—when and where to use them.', order: 4 },
              { title: 'Module 5: Digital Surgical Planning', content: 'Basics of designing 3D-printed surgical guides for implants.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Digital Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Intraoral Scanning Workshop', content: 'Live practice with leading scanners to master full-arch scanning and bite registration.', order: 1 },
              { title: 'CAD Design Lab', content: 'Intensive session on design software (Exocad/3Shape/CEREC) to create anatomically perfect restorations.', order: 2 },
              { title: '3D Printing & Post-Processing', content: 'Hands-on training with 3D printers for models, splints, and temporary crowns.', order: 3 },
              { title: 'Milling & Characterization', content: 'Watch the milling process and learn manual staining and glazing to make digital teeth look natural.', order: 4 },
              { title: 'Digital Workflow Integration', content: 'How to send digital files to labs and manage your in-office production queue.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Mastering Orthodontics',
        description: 'Transform your general practice by mastering the art and science of tooth movement. This comprehensive, 90-day hybrid course is designed specifically for general dental practitioners who want to integrate predictable, high-quality orthodontic treatments into their clinical repertoire.\n\nBy combining the flexibility of online learning with our AI enabled LMS system with intensive regional hands-on training, we ensure you gain the confidence to diagnose, plan, and execute orthodontic cases with precision.',
        price: 150000,
        difficulty: 'Intermediate',
        modules: [
          {
            title: 'Phase 1: Theoretical Excellence (Online – Months 1 & 2)',
            order: 1,
            lessons: [
              { title: 'Module 1: Facial Growth, Development & Biology of Tooth Movement', content: 'Essentials of craniofacial growth and the cellular mechanisms behind orthodontic tooth movement.', order: 1 },
              { title: 'Module 2: Advanced Orthodontic Diagnosis', content: 'Photography, Digital Cephalometrics, and Model Analysis.', order: 2 },
              { title: 'Module 3: Treatment Planning', content: 'Extraction vs. Non-Extraction and Anchorage Management.', order: 3 },
              { title: 'Module 4: Mechanics of Brackets & Archwire Sequencing', content: 'MBT/Roth bracket systems and NiTi to SS archwire sequencing.', order: 4 },
              { title: 'Module 5: Interdisciplinary Orthodontics', content: 'Finishing for long-term stability and coordination with other specialties.', order: 5 },
            ],
          },
          {
            title: 'Phase 2: The Clinical Bootcamp (Hands-On – Month 3)',
            order: 2,
            lessons: [
              { title: 'Precision Bonding', content: 'Master bracket placement on Typodonts.', order: 1 },
              { title: 'Wire Artistry', content: 'Practical sessions on cinch-backs, loops, and finishing bends.', order: 2 },
              { title: 'Advanced Techniques – TADs', content: 'Hands-on insertion of TADs (Temporary Anchorage Devices) on bone models.', order: 3 },
              { title: 'Live Demos & Case Discussions', content: 'Observation of clinical protocols and real-patient case discussions with expert faculty.', order: 4 },
            ],
          },
        ],
      },
      {
        title: 'Certificate in Research & Publication',
        description: 'Our Certificate in Research & Publication helps you design, conduct, and publish your research with expert guidance.\n\nLearn research methodology, data analysis, and scientific writing. Complete a submission-ready manuscript with full mentorship support.\n\nThis course is designed for students and healthcare professionals who want to learn research from scratch or publish their work with expert mentorship.',
        price: 50000,
        difficulty: 'Beginner',
        modules: [
          {
            title: 'Research Foundations & Methodology',
            order: 1,
            lessons: [
              { title: 'Research Design & Methodology', content: 'Types of research designs, formulating a research question, hypothesis, and study protocol.', order: 1 },
              { title: 'Ethics & IRB Approval', content: 'Ethical principles in research, informed consent, and navigating the institutional review board process.', order: 2 },
              { title: 'Data Analysis with SPSS', content: 'Hands-on introduction to statistical analysis using SPSS — descriptive stats, t-tests, chi-square, and regression.', order: 3 },
              { title: 'Scientific Writing (IMRAD)', content: 'Structuring your manuscript using the Introduction, Methods, Results, and Discussion format.', order: 4 },
              { title: 'Journal Selection & Publication Process', content: 'How to choose the right journal, understand impact factors, and navigate the submission and peer-review process.', order: 5 },
            ],
          },
        ],
      },
      {
        title: 'Certificate in Integrated Clinical Practice (CICP)',
        description: 'Enhance your clinical confidence with our Certificate in Integrated Clinical Practice, a structured 3-month course designed to help doctors manage real patients effectively.\n\nLearn OPD management, emergency care, infection control, and telemedicine practice. Ideal for MBBS graduates, GPs, and early-career clinicians.\n\nThe Certificate in Integrated Clinical Practice (CICP) is a 3-month online clinical training program designed for doctors who want to build confidence in real-world patient management, OPD practice, and emergency handling.',
        price: 30000,
        difficulty: 'Beginner',
        modules: [
          {
            title: 'Clinical Practice Essentials',
            order: 1,
            lessons: [
              { title: 'Clinical Decision-Making & Patient Safety', content: 'Frameworks for safe clinical decisions, error prevention, and patient safety culture in practice.', order: 1 },
              { title: 'Infection Control (Routine & Pandemic)', content: 'Standard precautions, PPE protocols, sterilization, and pandemic-specific infection control measures.', order: 2 },
              { title: 'OPD Management & Common Conditions', content: 'Efficient OPD workflow, managing common presentations, prescription writing, and follow-up planning.', order: 3 },
              { title: 'Emergency Handling (BLS, Shock, Asthma)', content: 'Basic Life Support, management of acute emergencies: anaphylaxis, shock, asthma, and cardiac arrest.', order: 4 },
              { title: 'Telemedicine & AI in Healthcare', content: 'Setting up a telemedicine practice, digital prescriptions, remote patient monitoring, and AI diagnostic tools.', order: 5 },
              { title: 'Healthcare Regulations in Pakistan', content: 'PMDC guidelines, medico-legal responsibilities, patient rights, and practice compliance essentials.', order: 6 },
            ],
          },
        ],
      },
    ];

    let created = 0;
    let skipped = 0;
    for (const courseData of rmCourses) {
      const exists = await Course.findOne({ title: courseData.title, isRmsCourse: true });
      if (exists) { skipped++; continue; }
      await Course.create({
        title: courseData.title,
        description: courseData.description,
        category: 'Medical Training',
        targetAudience: 'Doctor',
        difficulty: courseData.difficulty,
        visibility: 'public',
        isPublished: true,
        isRmsCourse: true,
        price: courseData.price,
        duration: courseData.title.includes('Research') ? 3 : courseData.title.includes('CICP') ? 3 : 3,
        courseType: 'self-paced',
        instructor_id: instructorId,
        modules: courseData.modules,
        is_active: true,
      });
      created++;
    }

    res.json({ success: true, message: `RM Health courses seeded: ${created} created, ${skipped} already existed.` });
  } catch (err) {
    console.error('Seed RM courses error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/seed — health check
router.all('/{*path}', (req, res) => {
  res.json({ success: true, message: 'Seed route. POST /api/seed/products to seed pharmacy inventory.' });
});

router.all('/', (req, res) => {
  res.json({ success: true, message: 'Seed route. POST /api/seed/products to seed pharmacy inventory.' });
});

module.exports = router;
