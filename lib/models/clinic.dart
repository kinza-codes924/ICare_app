import 'package:flutter/material.dart';

/// A single service offered inside an iCare specialty clinic (e.g. "Laser
/// Hair Removal" under Derma & Skin Care).
class ClinicService {
  final String name;
  final String description;
  // Longer procedure detail shown on the clinic detail page. `description`
  // stays short for the list-screen teaser.
  final String longDescription;
  // Optional asset path for a real photo illustrating this specific
  // service (e.g. assets/clinic_photos/dental_implant.jpg). Null when no
  // photo is available yet for this service.
  final String? imagePath;

  const ClinicService({
    required this.name,
    required this.description,
    required this.longDescription,
    this.imagePath,
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

/// A patient testimonial. Either a real Google-review screenshot
/// (imagePath set — rendered as-is, no re-typed text) or, for a clinic
/// without a screenshot yet, the older text-only fields as a fallback.
class ClinicTestimonial {
  final String patientName;
  final double rating;
  final String comment;
  final String dateLabel;
  // Local asset path to a real review screenshot (assets/clinic_photos/
  // reviews/...). When set, the UI renders this image directly instead of
  // the text fields above.
  final String? imagePath;

  const ClinicTestimonial({
    required this.patientName,
    required this.rating,
    required this.comment,
    required this.dateLabel,
    this.imagePath,
  });
}

class ClinicFaq {
  final String question;
  final String answer;

  const ClinicFaq({required this.question, required this.answer});
}

/// "Care & Maintenance" tips banner shown on the detail page — a short
/// title, a few bullet-point tips, and an optional photo (e.g. "Proper
/// Brushing, Daily Flossing..." for Dental).
class ClinicCareTips {
  final String title;
  final List<String> tips;
  final String? imagePath;

  const ClinicCareTips({
    required this.title,
    required this.tips,
    this.imagePath,
  });
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
  // Free-text query for "Get Directions" (Google Maps search).
  final String mapQuery;
  // Full street address, shown in the "Visit Our Clinic" section. All
  // clinics currently share iCare's one registered location.
  final String address;
  // Optional real photo for the detail page hero (replaces the plain
  // gradient background when available). Null for clinics without a
  // photo yet — those keep the gradient-only header.
  final String? heroImage;
  // Optional real reception/treatment-room photos for the "Visit Our
  // Clinic" section. Empty for clinics without photos yet.
  final List<String> facilityPhotos;
  // Optional "Care & Maintenance" tips banner shown after the services
  // grid. Null for clinics without tips written yet.
  final ClinicCareTips? careTips;

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
    required this.address,
    this.heroImage,
    this.facilityPhotos = const [],
    this.careTips,
  });
}
