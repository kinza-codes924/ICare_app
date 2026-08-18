import 'package:flutter/material.dart';

/// A single service offered inside an iCare specialty clinic (e.g. "Laser
/// Hair Removal" under Derma & Skin Care).
class ClinicService {
  final String name;
  final String description;
  // Longer procedure detail shown on the clinic detail page. `description`
  // stays short for the list-screen teaser.
  final String longDescription;

  const ClinicService({
    required this.name,
    required this.description,
    required this.longDescription,
  });
}

/// One step in a clinic's patient journey (Consultation -> Diagnosis ->
/// Treatment -> Follow-up), rendered as a timeline on the detail page.
class JourneyStep {
  final String title;
  final String description;
  final IconData icon;

  const JourneyStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// A placeholder-but-realistic patient testimonial — text only, no photos,
/// per the client's explicit instruction. A starting point the client can
/// replace with real reviews later.
class ClinicTestimonial {
  final String patientName;
  final double rating;
  final String comment;
  final String dateLabel;

  const ClinicTestimonial({
    required this.patientName,
    required this.rating,
    required this.comment,
    required this.dateLabel,
  });
}

class ClinicFaq {
  final String question;
  final String answer;

  const ClinicFaq({required this.question, required this.answer});
}

/// One of iCare's branded specialty clinics (Dental, Derma, etc). Data-driven
/// on purpose — the client has already named 5 more clinics he wants added
/// later (Gynaecology, Physiotherapy, General Physician, Digital X-ray,
/// Psychiatry), so a new clinic should only ever require adding one entry to
/// icare_clinics_data.dart, never a new screen.
class Clinic {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String location;
  final Color accentColor;
  final IconData icon;
  // Matches DoctorProfile.specialization (free-text on the backend, no
  // enum — see icare-backend/models/DoctorProfile.js) so "Book Appointment"
  // can filter DoctorsList to real doctors in this specialty.
  final String specialtyFilter;
  final List<ClinicService> services;
  // Mongo _id of this clinic's designated doctor account (renamed to the
  // clinic's branded name, e.g. "iCare Derma & Skin Care"). When set,
  // booking goes straight to that one account instead of a specialty
  // search list. Nullable so a clinic works via the specialtyFilter
  // fallback before its dedicated account is wired up.
  final String? doctorId;
  final List<JourneyStep> journey;
  final List<ClinicTestimonial> testimonials;
  final List<ClinicFaq> faqs;
  final String hoursLabel;
  // Free-text query for "Get Directions" (Google Maps search) — not a fixed
  // lat/lng, since clinics don't have a single fixed street address yet.
  final String mapQuery;

  const Clinic({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.location,
    required this.accentColor,
    required this.icon,
    required this.specialtyFilter,
    required this.services,
    this.doctorId,
    required this.journey,
    required this.testimonials,
    required this.faqs,
    required this.hoursLabel,
    required this.mapQuery,
  });
}
