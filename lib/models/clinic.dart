import 'package:flutter/material.dart';

/// A single service offered inside an iCare specialty clinic (e.g. "Laser
/// Hair Removal" under Derma & Skin Care).
class ClinicService {
  final String name;
  final String description;

  const ClinicService({required this.name, required this.description});
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
  });
}
