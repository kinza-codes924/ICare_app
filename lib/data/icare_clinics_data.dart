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
    heroImage: 'assets/clinic_photos/dental_implant.jpg',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Dental Implants',
        description: 'Permanent tooth replacement with titanium implants.',
        longDescription:
            'Titanium implants act as an artificial tooth root, topped with a '
            'natural-looking crown — a permanent, durable fix for missing '
            'teeth that protects your jawbone and bite alignment.',
        imagePath: 'assets/clinic_photos/dental_implant.jpg',
      ),
      ClinicService(
        name: 'Teeth Whitening',
        description: 'In-clinic and take-home whitening treatments.',
        longDescription:
            'Professional-grade bleaching that lifts years of staining from '
            'coffee, tea, or smoking — done safely under supervision, with a '
            'take-home kit option to maintain your results.',
        imagePath: 'https://images.unsplash.com/photo-1567516364473-233c4b6fcfbe?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Braces & Aligners',
        description: 'Traditional braces and clear aligner therapy.',
        longDescription:
            'Straighten misaligned teeth with metal braces or nearly-invisible '
            'clear aligners, tailored to your bite and lifestyle, with regular '
            'progress checkups throughout treatment.',
        imagePath: 'assets/clinic_photos/dental_braces.jpg',
      ),
      ClinicService(
        name: 'Root Canal Treatment',
        description: 'Pain relief and tooth preservation.',
        longDescription:
            'Removes infected pulp to relieve pain and save a tooth that '
            'would otherwise need extraction — completed comfortably under '
            'local anesthesia in one to two visits.',
        imagePath: 'https://images.unsplash.com/photo-1664530837411-0c2e8a3d4dca?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Cosmetic Dentistry',
        description: 'Veneers, bonding, and smile design.',
        longDescription:
            'Veneers, bonding, and full smile design to reshape, brighten, or '
            'close gaps in your teeth — a custom plan built around the smile '
            'you want.',
        imagePath: 'https://images.unsplash.com/photo-1663182234283-28941e7612da?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Patient Care & Maintenance',
      tips: [
        'Proper Brushing',
        'Daily Flossing',
        'Regular Checkups',
        'Post-Treatment Maintenance',
      ],
      imagePath: 'https://images.unsplash.com/photo-1606811971618-4486d14f3f99?w=1200&q=80&auto=format&fit=crop',
    ),
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
    heroImage: 'https://images.unsplash.com/photo-1761718210089-ba3bb5ccb54f?w=1200&q=80&auto=format&fit=crop',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Laser Hair Removal',
        description: 'Long-lasting hair reduction for all skin types.',
        longDescription:
            'Medical-grade laser technology targets hair follicles for '
            'long-lasting reduction, safe for all skin tones, with sessions '
            'spaced for optimal results.',
        imagePath: 'https://images.unsplash.com/photo-1700760933574-9f0f4ea9aa3b?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'PRP Therapy',
        description: 'Platelet-rich plasma treatment for skin and hair.',
        longDescription:
            'Your own platelet-rich plasma is used to stimulate collagen and '
            'hair follicle activity — a natural option for skin rejuvenation '
            'and hair thinning.',
        imagePath: 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'HydraFacial',
        description: 'Deep cleansing and hydrating facial treatment.',
        longDescription:
            'A multi-step facial that cleanses, exfoliates, and infuses the '
            'skin with hydrating serums for an instant, glowing refresh — no '
            'downtime required.',
        imagePath: 'https://images.unsplash.com/photo-1761718210089-ba3bb5ccb54f?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Acne Treatment',
        description: 'Customized plans for active acne and scarring.',
        longDescription:
            'Personalized treatment plans combining topical care, in-clinic '
            'procedures, and lifestyle guidance to control active breakouts '
            'and reduce scarring over time.',
        imagePath: 'https://images.unsplash.com/photo-1552693673-1bf958298935?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Botox & Fillers',
        description: 'Non-surgical anti-aging treatments.',
        longDescription:
            'Smooth fine lines and restore volume with precise, non-surgical '
            'injectable treatments — administered by trained dermatologists '
            'for a natural-looking result.',
        imagePath: 'https://images.unsplash.com/photo-1746708810803-722593e53772?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Skin Care & Maintenance',
      tips: [
        'Daily Sunscreen (SPF 30+)',
        'Gentle Cleansing Routine',
        'Stay Hydrated',
        'Follow-up Skin Checks',
      ],
      imagePath: 'https://images.unsplash.com/photo-1552693673-1bf958298935?w=800&q=80&auto=format&fit=crop',
    ),
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
    heroImage: 'https://images.unsplash.com/photo-1691139600923-8fba078704b0?w=1200&q=80&auto=format&fit=crop',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Prenatal Care',
        description: 'Regular checkups and monitoring throughout pregnancy.',
        longDescription:
            'Scheduled checkups, ultrasounds, and monitoring throughout your '
            'pregnancy to track your baby\'s development and catch any '
            'concerns early.',
        imagePath: 'https://images.unsplash.com/photo-1691139600923-8fba078704b0?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Vaccination',
        description: 'Complete immunization schedules for infants and children.',
        longDescription:
            'Age-appropriate immunization schedules for infants and children, '
            'tracked and reminded so no dose is ever missed.',
        imagePath: 'https://images.unsplash.com/photo-1594051182587-0bd78bba36e7?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Well-Baby Checkups',
        description: 'Growth and development monitoring.',
        longDescription:
            'Routine checkups that track your baby\'s growth, milestones, and '
            'nutrition — giving you an early heads-up on anything that needs '
            'attention.',
        imagePath: 'https://images.unsplash.com/photo-1632053002928-1919605ee6f7?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Lactation Support',
        description: 'Breastfeeding guidance and consultation.',
        longDescription:
            'One-on-one guidance on breastfeeding technique, latch, and '
            'supply concerns from experienced lactation consultants.',
        imagePath: 'https://images.unsplash.com/photo-1576758412641-3b89a82e1043?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Postnatal Care',
        description: 'Recovery and wellness support after delivery.',
        longDescription:
            'Physical recovery checkups and emotional wellness support for '
            'new mothers in the weeks and months after delivery.',
        imagePath: 'https://images.unsplash.com/photo-1759802147227-d9b32bd34996?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Mother & Baby Wellness',
      tips: [
        'Keep All Prenatal Appointments',
        'Track Vaccination Schedule',
        'Balanced Nutrition & Rest',
        'Reach Out for Postnatal Support',
      ],
      imagePath: 'https://images.unsplash.com/photo-1691139600923-8fba078704b0?w=800&q=80&auto=format&fit=crop',
    ),
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
    heroImage: 'https://images.unsplash.com/photo-1649751361457-01d3a696c7e6?w=1200&q=80&auto=format&fit=crop',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Sports Injury Rehab',
        description: 'Recovery programs for athletic injuries.',
        longDescription:
            'Targeted rehab programs to safely restore strength and '
            'mobility after sports injuries, built around your specific '
            'sport and recovery timeline.',
        imagePath: 'https://images.unsplash.com/photo-1649751361457-01d3a696c7e6?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Post-Surgical Rehab',
        description: 'Structured recovery after orthopedic surgery.',
        longDescription:
            'Structured, staged recovery plans following orthopedic surgery '
            'to rebuild strength and range of motion safely.',
        imagePath: 'https://images.unsplash.com/photo-1768507423533-b87b62769758?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Chronic Pain Management',
        description: 'Long-term pain relief and mobility plans.',
        longDescription:
            'Long-term management plans combining manual therapy and '
            'guided exercise to reduce chronic pain and improve daily '
            'function.',
        imagePath: 'https://images.unsplash.com/photo-1540205895360-4ad4cffb3aa8?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Manual Therapy',
        description: 'Hands-on techniques to relieve pain and stiffness.',
        longDescription:
            'Hands-on joint and soft-tissue techniques to relieve pain, '
            'reduce stiffness, and improve movement quality.',
        imagePath: 'https://images.unsplash.com/photo-1706353399656-210cca727a33?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Neuro Rehabilitation',
        description: 'Recovery support for neurological conditions.',
        longDescription:
            'Specialized rehabilitation support for patients recovering '
            'from stroke or other neurological conditions, focused on '
            'regaining independence.',
        imagePath: 'https://images.unsplash.com/photo-1753698280805-bd08176ca4a8?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Recovery & Movement Care',
      tips: [
        'Do Home Exercises as Prescribed',
        'Apply Ice/Heat as Advised',
        'Avoid Overexertion',
        'Track Progress at Follow-ups',
      ],
      imagePath: 'https://images.unsplash.com/photo-1649751361457-01d3a696c7e6?w=800&q=80&auto=format&fit=crop',
    ),
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
    heroImage: 'https://images.unsplash.com/photo-1714976694810-85add1a29c96?w=1200&q=80&auto=format&fit=crop',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Counseling & Therapy',
        description: 'One-on-one sessions for stress, anxiety, and more.',
        longDescription:
            'Confidential one-on-one sessions to work through stress, '
            'anxiety, grief, or life transitions, at a pace that suits you.',
        imagePath: 'https://images.unsplash.com/photo-1714976694810-85add1a29c96?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'CBT (Cognitive Behavioral Therapy)',
        description: 'Structured therapy for lasting change.',
        longDescription:
            'A structured, evidence-based approach that helps identify and '
            'reshape unhelpful thought patterns for lasting change.',
        imagePath: 'https://images.unsplash.com/photo-1714976694867-bc0e012fab70?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Medication Management',
        description: 'Psychiatric evaluation and prescription care.',
        longDescription:
            'Careful psychiatric evaluation and ongoing medication review to '
            'find the right treatment with the fewest side effects.',
        imagePath: 'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Family Therapy',
        description: 'Guided sessions to support family relationships.',
        longDescription:
            'Guided sessions that help families communicate better and work '
            'through conflict in a supportive, neutral setting.',
        imagePath: 'https://images.unsplash.com/photo-1604881991720-f91add269bed?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Adolescent Counseling',
        description: 'Mental health support for teens.',
        longDescription:
            'A safe space for teens to talk through school stress, identity, '
            'and emotional challenges with a counselor trained in '
            'adolescent care.',
        imagePath: 'https://images.unsplash.com/photo-1758273240331-745ccab011a2?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Mental Wellness Habits',
      tips: [
        'Attend Sessions Consistently',
        'Practice Daily Mindfulness',
        'Maintain a Regular Sleep Routine',
        'Stay Connected with Support Systems',
      ],
      imagePath: 'https://images.unsplash.com/photo-1714976694810-85add1a29c96?w=800&q=80&auto=format&fit=crop',
    ),
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
    heroImage: 'https://images.unsplash.com/photo-1644704170910-a0cdf183649b?w=1200&q=80&auto=format&fit=crop',
    facilityPhotos: [
      'assets/clinic_photos/dental_reception.jpg',
      'assets/clinic_photos/dental_room.jpg',
    ],
    services: [
      ClinicService(
        name: 'Nutrition Counseling',
        description: 'Personalized diet plans for your health goals.',
        longDescription:
            'A personalized diet plan built around your health goals, food '
            'preferences, and lifestyle — with regular check-ins to adjust '
            'as you progress.',
        imagePath: 'https://images.unsplash.com/photo-1644704170910-a0cdf183649b?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Weight Management',
        description: 'Structured programs for sustainable weight loss.',
        longDescription:
            'A structured, sustainable program combining diet and habit '
            'changes — designed for long-term results, not quick fixes.',
        imagePath: 'https://images.unsplash.com/photo-1522844990619-4951c40f7eda?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Diabetes Care',
        description: 'Lifestyle-based support for managing diabetes.',
        longDescription:
            'Lifestyle and nutrition-based support to help manage blood '
            'sugar levels alongside your existing medical care.',
        imagePath: 'https://images.unsplash.com/photo-1683727186226-910f31a9da45?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Fitness Planning',
        description: 'Custom exercise plans for all fitness levels.',
        longDescription:
            'Custom exercise plans built for your current fitness level and '
            'goals, whether starting from scratch or training for '
            'performance.',
        imagePath: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&q=80&auto=format&fit=crop',
      ),
      ClinicService(
        name: 'Wellness Checkups',
        description: 'Preventive health screening and guidance.',
        longDescription:
            'Preventive screening and lifestyle guidance to catch potential '
            'health concerns early and keep you on track.',
        imagePath: 'https://images.unsplash.com/photo-1666887360680-9dc27a1d2753?w=800&q=80&auto=format&fit=crop',
      ),
    ],
    careTips: ClinicCareTips(
      title: 'Healthy Living Habits',
      tips: [
        'Follow Your Nutrition Plan',
        'Stay Active Daily',
        'Monitor Health Metrics Regularly',
        'Keep Follow-up Checkups',
      ],
      imagePath: 'https://images.unsplash.com/photo-1644704170910-a0cdf183649b?w=800&q=80&auto=format&fit=crop',
    ),
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
