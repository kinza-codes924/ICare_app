import 'package:flutter/material.dart';
import 'package:icare/models/clinic.dart';

/// Shared 4-step patient journey used by every clinic unless a specialty
/// needs a different sequence — kept as a reusable const to avoid repeating
/// the same 4 objects 6 times.
const List<JourneyStep> _defaultJourney = [
  JourneyStep(
    title: 'Consultation',
    description: 'Meet your specialist and discuss your concerns in detail.',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  JourneyStep(
    title: 'Diagnosis',
    description: 'A thorough assessment to identify the right treatment plan.',
    icon: Icons.fact_check_outlined,
  ),
  JourneyStep(
    title: 'Treatment',
    description: 'Personalized care delivered using modern techniques.',
    icon: Icons.medical_services_outlined,
  ),
  JourneyStep(
    title: 'Follow-up',
    description: 'Ongoing support to track your progress and recovery.',
    icon: Icons.event_available_outlined,
  ),
];

/// iCare's branded specialty clinic network. Adding a new clinic (the client
/// has already named 5 more: Gynaecology, Physiotherapy, General Physician,
/// Digital X-ray, Psychiatry) means adding one entry here — no new screen.
const List<Clinic> kICareClinics = [
  Clinic(
    id: 'dental',
    name: 'iCare Dental & Aesthetic Centre',
    tagline: 'Complete Dental & Cosmetic Care',
    description:
        'From routine checkups to full smile makeovers — modern dental '
        'and aesthetic treatments under one roof.',
    location: 'Karachi',
    accentColor: Color(0xFF0D9488),
    icon: Icons.medical_services_rounded,
    specialtyFilter: 'Dentist',
    doctorId: '6a83634c9a3050a3d62f9a22',
    hoursLabel: 'Mon – Sat, 10:00 AM – 8:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Dental Implants',
        description: 'Permanent tooth replacement with titanium implants.',
        longDescription:
            'Titanium implants act as an artificial tooth root, topped with a '
            'natural-looking crown — a permanent, durable fix for missing '
            'teeth that protects your jawbone and bite alignment.',
      ),
      ClinicService(
        name: 'Teeth Whitening',
        description: 'In-clinic and take-home whitening treatments.',
        longDescription:
            'Professional-grade bleaching that lifts years of staining from '
            'coffee, tea, or smoking — done safely under supervision, with a '
            'take-home kit option to maintain your results.',
      ),
      ClinicService(
        name: 'Braces & Aligners',
        description: 'Traditional braces and clear aligner therapy.',
        longDescription:
            'Straighten misaligned teeth with metal braces or nearly-invisible '
            'clear aligners, tailored to your bite and lifestyle, with regular '
            'progress checkups throughout treatment.',
      ),
      ClinicService(
        name: 'Root Canal Treatment',
        description: 'Pain relief and tooth preservation.',
        longDescription:
            'Removes infected pulp to relieve pain and save a tooth that '
            'would otherwise need extraction — completed comfortably under '
            'local anesthesia in one to two visits.',
      ),
      ClinicService(
        name: 'Cosmetic Dentistry',
        description: 'Veneers, bonding, and smile design.',
        longDescription:
            'Veneers, bonding, and full smile design to reshape, brighten, or '
            'close gaps in your teeth — a custom plan built around the smile '
            'you want.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Ayesha K.',
        rating: 5,
        comment:
            'Got my root canal done here — completely painless and the staff '
            'explained every step. My smile after the whitening session is '
            'unbelievable!',
        dateLabel: 'June 2026',
      ),
      ClinicTestimonial(
        patientName: 'Bilal S.',
        rating: 5,
        comment:
            'Started my Invisalign treatment last month. Clean clinic, easy '
            'online booking, and the dentist actually listens.',
        dateLabel: 'May 2026',
      ),
      ClinicTestimonial(
        patientName: 'Fatima R.',
        rating: 4.5,
        comment:
            'Great experience with my dental implant. A bit of a wait for the '
            'appointment but worth it for the quality of care.',
        dateLabel: 'April 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'Is teeth whitening safe for sensitive teeth?',
        answer:
            'Yes — our dentists assess your sensitivity first and adjust the '
            'treatment or recommend a gentler take-home option if needed.',
      ),
      ClinicFaq(
        question: 'How long does a dental implant take to heal?',
        answer:
            'Healing typically takes 3–6 months before the final crown is '
            'placed, though this varies by patient and is monitored at '
            'follow-up visits.',
      ),
      ClinicFaq(
        question: 'Do you accept walk-ins?',
        answer:
            'We recommend booking an appointment online to guarantee your '
            'slot, but walk-ins are accommodated based on availability.',
      ),
    ],
  ),
  Clinic(
    id: 'derma',
    name: 'iCare Derma & Skin Care',
    tagline: 'Advanced Skin & Aesthetic Treatments',
    description:
        'Dermatologist-led skin, hair, and aesthetic treatments using '
        'modern, clinically-proven techniques.',
    location: 'Karachi',
    accentColor: Color(0xFFEC4899),
    icon: Icons.face_retouching_natural_rounded,
    specialtyFilter: 'Dermatologist',
    doctorId: '6a83634d9a3050a3d62f9a24',
    hoursLabel: 'Mon – Sat, 11:00 AM – 8:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Laser Hair Removal',
        description: 'Long-lasting hair reduction for all skin types.',
        longDescription:
            'Medical-grade laser technology targets hair follicles for '
            'long-lasting reduction, safe for all skin tones, with sessions '
            'spaced for optimal results.',
      ),
      ClinicService(
        name: 'PRP Therapy',
        description: 'Platelet-rich plasma treatment for skin and hair.',
        longDescription:
            'Your own platelet-rich plasma is used to stimulate collagen and '
            'hair follicle activity — a natural option for skin rejuvenation '
            'and hair thinning.',
      ),
      ClinicService(
        name: 'HydraFacial',
        description: 'Deep cleansing and hydrating facial treatment.',
        longDescription:
            'A multi-step facial that cleanses, exfoliates, and infuses the '
            'skin with hydrating serums for an instant, glowing refresh — no '
            'downtime required.',
      ),
      ClinicService(
        name: 'Acne Treatment',
        description: 'Customized plans for active acne and scarring.',
        longDescription:
            'Personalized treatment plans combining topical care, in-clinic '
            'procedures, and lifestyle guidance to control active breakouts '
            'and reduce scarring over time.',
      ),
      ClinicService(
        name: 'Botox & Fillers',
        description: 'Non-surgical anti-aging treatments.',
        longDescription:
            'Smooth fine lines and restore volume with precise, non-surgical '
            'injectable treatments — administered by trained dermatologists '
            'for a natural-looking result.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Sana M.',
        rating: 5,
        comment:
            'My acne scars have visibly faded after just 3 PRP sessions. '
            'The dermatologist genuinely cares about long-term results, not '
            'just quick fixes.',
        dateLabel: 'June 2026',
      ),
      ClinicTestimonial(
        patientName: 'Hamza T.',
        rating: 4.5,
        comment:
            'Did laser hair removal here — professional setup and the staff '
            'made sure I was comfortable throughout.',
        dateLabel: 'May 2026',
      ),
      ClinicTestimonial(
        patientName: 'Zainab A.',
        rating: 5,
        comment:
            'HydraFacial left my skin glowing for weeks. Booking online was '
            'super easy too.',
        dateLabel: 'March 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'How many sessions does laser hair removal need?',
        answer:
            'Most patients need 6–8 sessions spaced a few weeks apart for '
            'long-lasting results, depending on hair type and area.',
      ),
      ClinicFaq(
        question: 'Is there downtime after a HydraFacial?',
        answer:
            'None — you can return to your normal routine immediately, with '
            'skin looking noticeably refreshed right after the session.',
      ),
      ClinicFaq(
        question: 'Are Botox and fillers safe?',
        answer:
            'Yes, when administered by a qualified dermatologist in a '
            'clinical setting — we assess your skin and medical history '
            'before any procedure.',
      ),
    ],
  ),
  Clinic(
    id: 'mother_child',
    name: 'iCare Mother & Child Care Centre',
    tagline: 'Complete Care for Mother & Baby',
    description:
        'Prenatal to postnatal care and pediatric services for growing '
        'families.',
    location: 'Karachi',
    accentColor: Color(0xFF8B5CF6),
    icon: Icons.family_restroom_rounded,
    specialtyFilter: 'Gynecologist',
    doctorId: '6a83634e9a3050a3d62f9a26',
    hoursLabel: 'Mon – Sat, 9:00 AM – 7:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Prenatal Care',
        description: 'Regular checkups and monitoring throughout pregnancy.',
        longDescription:
            'Scheduled checkups, ultrasounds, and monitoring throughout your '
            'pregnancy to track your baby\'s development and catch any '
            'concerns early.',
      ),
      ClinicService(
        name: 'Vaccination',
        description: 'Complete immunization schedules for infants and children.',
        longDescription:
            'Age-appropriate immunization schedules for infants and children, '
            'tracked and reminded so no dose is ever missed.',
      ),
      ClinicService(
        name: 'Well-Baby Checkups',
        description: 'Growth and development monitoring.',
        longDescription:
            'Routine checkups that track your baby\'s growth, milestones, and '
            'nutrition — giving you an early heads-up on anything that needs '
            'attention.',
      ),
      ClinicService(
        name: 'Lactation Support',
        description: 'Breastfeeding guidance and consultation.',
        longDescription:
            'One-on-one guidance on breastfeeding technique, latch, and '
            'supply concerns from experienced lactation consultants.',
      ),
      ClinicService(
        name: 'Postnatal Care',
        description: 'Recovery and wellness support after delivery.',
        longDescription:
            'Physical recovery checkups and emotional wellness support for '
            'new mothers in the weeks and months after delivery.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Mahnoor I.',
        rating: 5,
        comment:
            'Followed my entire pregnancy here. Every appointment was '
            'reassuring and the doctor always had time for my questions.',
        dateLabel: 'June 2026',
      ),
      ClinicTestimonial(
        patientName: 'Sarah W.',
        rating: 5,
        comment:
            'The lactation support after delivery made such a difference. '
            'Very patient and knowledgeable team.',
        dateLabel: 'April 2026',
      ),
      ClinicTestimonial(
        patientName: 'Nida F.',
        rating: 4.5,
        comment:
            'Take my daughter here for all her vaccinations. Clean, '
            'organized, and they send reminders which I love.',
        dateLabel: 'February 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'How often should prenatal checkups happen?',
        answer:
            'Typically monthly in early pregnancy, increasing to biweekly and '
            'then weekly closer to delivery — your doctor will set a '
            'schedule based on your health.',
      ),
      ClinicFaq(
        question: 'Do you follow the standard immunization schedule?',
        answer:
            'Yes, we follow the recommended national immunization schedule '
            'and can track and remind you ahead of each due date.',
      ),
      ClinicFaq(
        question: 'Can I get lactation support without a prior appointment?',
        answer:
            'We recommend booking ahead so a lactation consultant is '
            'available, but urgent concerns are accommodated where possible.',
      ),
    ],
  ),
  Clinic(
    id: 'physio',
    name: 'iCare Physiotherapy & Rehabilitation Centre',
    tagline: 'Recovery, Movement & Pain Relief',
    description:
        'Personalized physiotherapy programs for injury recovery, pain '
        'management, and mobility.',
    location: 'Karachi',
    accentColor: Color(0xFF3B82F6),
    icon: Icons.accessibility_new_rounded,
    specialtyFilter: 'Physiotherapist',
    doctorId: '6a83634f9a3050a3d62f9a28',
    hoursLabel: 'Mon – Sat, 9:00 AM – 8:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Sports Injury Rehab',
        description: 'Recovery programs for athletic injuries.',
        longDescription:
            'Targeted rehab programs to safely restore strength and '
            'mobility after sports injuries, built around your specific '
            'sport and recovery timeline.',
      ),
      ClinicService(
        name: 'Post-Surgical Rehab',
        description: 'Structured recovery after orthopedic surgery.',
        longDescription:
            'Structured, staged recovery plans following orthopedic surgery '
            'to rebuild strength and range of motion safely.',
      ),
      ClinicService(
        name: 'Chronic Pain Management',
        description: 'Long-term pain relief and mobility plans.',
        longDescription:
            'Long-term management plans combining manual therapy and '
            'guided exercise to reduce chronic pain and improve daily '
            'function.',
      ),
      ClinicService(
        name: 'Manual Therapy',
        description: 'Hands-on techniques to relieve pain and stiffness.',
        longDescription:
            'Hands-on joint and soft-tissue techniques to relieve pain, '
            'reduce stiffness, and improve movement quality.',
      ),
      ClinicService(
        name: 'Neuro Rehabilitation',
        description: 'Recovery support for neurological conditions.',
        longDescription:
            'Specialized rehabilitation support for patients recovering '
            'from stroke or other neurological conditions, focused on '
            'regaining independence.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Owais N.',
        rating: 5,
        comment:
            'Tore a ligament playing football — the sports rehab program '
            'here got me back on the field in weeks, not months.',
        dateLabel: 'May 2026',
      ),
      ClinicTestimonial(
        patientName: 'Rabia H.',
        rating: 4.5,
        comment:
            'Chronic back pain that nothing else fixed. A few weeks of '
            'manual therapy and I finally have relief.',
        dateLabel: 'March 2026',
      ),
      ClinicTestimonial(
        patientName: 'Imran Q.',
        rating: 5,
        comment:
            'Post-surgery rehab was structured and the therapist tracked my '
            'progress every session. Highly recommend.',
        dateLabel: 'February 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'How many sessions will I need?',
        answer:
            'It depends on your condition — your physiotherapist will '
            'assess you first and outline an expected program length.',
      ),
      ClinicFaq(
        question: 'Do I need a doctor\'s referral to book?',
        answer:
            'No referral is required — you can book a physiotherapy '
            'appointment directly.',
      ),
      ClinicFaq(
        question: 'Is physiotherapy covered for post-surgery recovery?',
        answer:
            'Yes, post-surgical rehab is one of our core programs and is '
            'coordinated around your surgeon\'s recovery timeline.',
      ),
    ],
  ),
  Clinic(
    id: 'psychiatry',
    name: "iCare Psychiatry's & Mental Health Centre",
    tagline: 'Confidential, Compassionate Mental Health Care',
    description:
        'Licensed psychiatrists and counselors providing therapy and '
        'psychiatric care in a private, judgment-free setting.',
    location: 'Karachi',
    accentColor: Color(0xFF6366F1),
    icon: Icons.psychology_rounded,
    specialtyFilter: 'Psychiatrist',
    doctorId: '6a8363509a3050a3d62f9a2a',
    hoursLabel: 'Mon – Sat, 11:00 AM – 7:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Counseling & Therapy',
        description: 'One-on-one sessions for stress, anxiety, and more.',
        longDescription:
            'Confidential one-on-one sessions to work through stress, '
            'anxiety, grief, or life transitions, at a pace that suits you.',
      ),
      ClinicService(
        name: 'CBT (Cognitive Behavioral Therapy)',
        description: 'Structured therapy for lasting change.',
        longDescription:
            'A structured, evidence-based approach that helps identify and '
            'reshape unhelpful thought patterns for lasting change.',
      ),
      ClinicService(
        name: 'Medication Management',
        description: 'Psychiatric evaluation and prescription care.',
        longDescription:
            'Careful psychiatric evaluation and ongoing medication review to '
            'find the right treatment with the fewest side effects.',
      ),
      ClinicService(
        name: 'Family Therapy',
        description: 'Guided sessions to support family relationships.',
        longDescription:
            'Guided sessions that help families communicate better and work '
            'through conflict in a supportive, neutral setting.',
      ),
      ClinicService(
        name: 'Adolescent Counseling',
        description: 'Mental health support for teens.',
        longDescription:
            'A safe space for teens to talk through school stress, identity, '
            'and emotional challenges with a counselor trained in '
            'adolescent care.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Areeba J.',
        rating: 5,
        comment:
            'Finally found a therapist who I feel truly listens. The whole '
            'process from booking to session felt private and respectful.',
        dateLabel: 'June 2026',
      ),
      ClinicTestimonial(
        patientName: 'Danish K.',
        rating: 5,
        comment:
            'CBT sessions here genuinely changed how I handle anxiety at '
            'work. Grateful I gave it a try.',
        dateLabel: 'April 2026',
      ),
      ClinicTestimonial(
        patientName: 'Laila P.',
        rating: 4.5,
        comment:
            'Brought my teenager in for counseling — she opened up more '
            'than I expected. Kind, patient staff.',
        dateLabel: 'March 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'Is everything discussed confidential?',
        answer:
            'Yes — all sessions are strictly confidential, in line with '
            'standard clinical ethics and privacy practice.',
      ),
      ClinicFaq(
        question: 'Can I book therapy without a psychiatric diagnosis?',
        answer:
            'Absolutely — counseling and therapy are open to anyone dealing '
            'with stress, life changes, or wanting general support.',
      ),
      ClinicFaq(
        question: 'Do you offer online/video sessions?',
        answer:
            'Consultations can be conducted online through the app — ask '
            'your counselor about availability when booking.',
      ),
    ],
  ),
  Clinic(
    id: 'lifestyle_wellness',
    name: 'iCare Lifestyle and Wellness Centre',
    tagline: 'Live Healthier, Every Day',
    description:
        'Nutrition, fitness, and lifestyle guidance to help you build '
        'sustainable, healthy habits.',
    location: 'Karachi',
    accentColor: Color(0xFF16A34A),
    icon: Icons.spa_rounded,
    specialtyFilter: 'Nutritionist',
    doctorId: '6a83637418f9abf9de617493',
    hoursLabel: 'Mon – Sat, 9:00 AM – 6:00 PM',
    mapQuery: 'iCare Clinics, Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Karachi',
    address: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, '
        'Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
    services: [
      ClinicService(
        name: 'Nutrition Counseling',
        description: 'Personalized diet plans for your health goals.',
        longDescription:
            'A personalized diet plan built around your health goals, food '
            'preferences, and lifestyle — with regular check-ins to adjust '
            'as you progress.',
      ),
      ClinicService(
        name: 'Weight Management',
        description: 'Structured programs for sustainable weight loss.',
        longDescription:
            'A structured, sustainable program combining diet and habit '
            'changes — designed for long-term results, not quick fixes.',
      ),
      ClinicService(
        name: 'Diabetes Care',
        description: 'Lifestyle-based support for managing diabetes.',
        longDescription:
            'Lifestyle and nutrition-based support to help manage blood '
            'sugar levels alongside your existing medical care.',
      ),
      ClinicService(
        name: 'Fitness Planning',
        description: 'Custom exercise plans for all fitness levels.',
        longDescription:
            'Custom exercise plans built for your current fitness level and '
            'goals, whether starting from scratch or training for '
            'performance.',
      ),
      ClinicService(
        name: 'Wellness Checkups',
        description: 'Preventive health screening and guidance.',
        longDescription:
            'Preventive screening and lifestyle guidance to catch potential '
            'health concerns early and keep you on track.',
      ),
    ],
    journey: _defaultJourney,
    testimonials: [
      ClinicTestimonial(
        patientName: 'Kamran L.',
        rating: 5,
        comment:
            'Lost 8kg in 3 months following the nutrition plan here — '
            'practical advice, not a crash diet.',
        dateLabel: 'June 2026',
      ),
      ClinicTestimonial(
        patientName: 'Hina D.',
        rating: 4.5,
        comment:
            'The diabetes lifestyle program helped me get my sugar levels '
            'under control alongside my regular medication.',
        dateLabel: 'April 2026',
      ),
      ClinicTestimonial(
        patientName: 'Tariq B.',
        rating: 5,
        comment:
            'Booked a wellness checkup and got a clear, honest breakdown of '
            'where I stood. Booking and payment was smooth too.',
        dateLabel: 'March 2026',
      ),
    ],
    faqs: [
      ClinicFaq(
        question: 'Do I need a referral for nutrition counseling?',
        answer:
            'No, you can book directly — a nutritionist will build your '
            'plan around your goals and any existing conditions.',
      ),
      ClinicFaq(
        question: 'How long until I see results from a weight program?',
        answer:
            'Most patients see measurable progress within 4–6 weeks, with '
            'the program adjusted as needed at follow-up sessions.',
      ),
      ClinicFaq(
        question: 'Is this suitable if I already see a diabetes specialist?',
        answer:
            'Yes — our lifestyle support is designed to complement your '
            'existing medical care, not replace it.',
      ),
    ],
  ),
];
