import 'package:flutter/material.dart';
import 'package:icare/models/clinic.dart';

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
    services: [
      ClinicService(name: 'Dental Implants', description: 'Permanent tooth replacement with titanium implants.'),
      ClinicService(name: 'Teeth Whitening', description: 'In-clinic and take-home whitening treatments.'),
      ClinicService(name: 'Braces & Aligners', description: 'Traditional braces and clear aligner therapy.'),
      ClinicService(name: 'Root Canal Treatment', description: 'Pain relief and tooth preservation.'),
      ClinicService(name: 'Cosmetic Dentistry', description: 'Veneers, bonding, and smile design.'),
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
    accentColor: Color(0xFF0D9488),
    icon: Icons.face_retouching_natural_rounded,
    specialtyFilter: 'Dermatologist',
    services: [
      ClinicService(name: 'Laser Hair Removal', description: 'Long-lasting hair reduction for all skin types.'),
      ClinicService(name: 'PRP Therapy', description: 'Platelet-rich plasma treatment for skin and hair.'),
      ClinicService(name: 'HydraFacial', description: 'Deep cleansing and hydrating facial treatment.'),
      ClinicService(name: 'Acne Treatment', description: 'Customized plans for active acne and scarring.'),
      ClinicService(name: 'Botox & Fillers', description: 'Non-surgical anti-aging treatments.'),
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
    accentColor: Color(0xFF0D9488),
    icon: Icons.family_restroom_rounded,
    specialtyFilter: 'Gynecologist',
    services: [
      ClinicService(name: 'Prenatal Care', description: 'Regular checkups and monitoring throughout pregnancy.'),
      ClinicService(name: 'Vaccination', description: 'Complete immunization schedules for infants and children.'),
      ClinicService(name: 'Well-Baby Checkups', description: 'Growth and development monitoring.'),
      ClinicService(name: 'Lactation Support', description: 'Breastfeeding guidance and consultation.'),
      ClinicService(name: 'Postnatal Care', description: 'Recovery and wellness support after delivery.'),
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
    accentColor: Color(0xFF0D9488),
    icon: Icons.accessibility_new_rounded,
    specialtyFilter: 'Physiotherapist',
    services: [
      ClinicService(name: 'Sports Injury Rehab', description: 'Recovery programs for athletic injuries.'),
      ClinicService(name: 'Post-Surgical Rehab', description: 'Structured recovery after orthopedic surgery.'),
      ClinicService(name: 'Chronic Pain Management', description: 'Long-term pain relief and mobility plans.'),
      ClinicService(name: 'Manual Therapy', description: 'Hands-on techniques to relieve pain and stiffness.'),
      ClinicService(name: 'Neuro Rehabilitation', description: 'Recovery support for neurological conditions.'),
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
    accentColor: Color(0xFF0D9488),
    icon: Icons.psychology_rounded,
    specialtyFilter: 'Psychiatrist',
    services: [
      ClinicService(name: 'Counseling & Therapy', description: 'One-on-one sessions for stress, anxiety, and more.'),
      ClinicService(name: 'CBT (Cognitive Behavioral Therapy)', description: 'Structured therapy for lasting change.'),
      ClinicService(name: 'Medication Management', description: 'Psychiatric evaluation and prescription care.'),
      ClinicService(name: 'Family Therapy', description: 'Guided sessions to support family relationships.'),
      ClinicService(name: 'Adolescent Counseling', description: 'Mental health support for teens.'),
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
    accentColor: Color(0xFF0D9488),
    icon: Icons.spa_rounded,
    specialtyFilter: 'Nutritionist',
    services: [
      ClinicService(name: 'Nutrition Counseling', description: 'Personalized diet plans for your health goals.'),
      ClinicService(name: 'Weight Management', description: 'Structured programs for sustainable weight loss.'),
      ClinicService(name: 'Diabetes Care', description: 'Lifestyle-based support for managing diabetes.'),
      ClinicService(name: 'Fitness Planning', description: 'Custom exercise plans for all fitness levels.'),
      ClinicService(name: 'Wellness Checkups', description: 'Preventive health screening and guidance.'),
    ],
  ),
];
