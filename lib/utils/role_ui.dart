import 'package:flutter/material.dart';

enum AppRoleKind { patient, doctor, laboratory, pharmacy, instructor, student, admin, superAdmin, security, unknown }

String normalizeRoleName(String? role) {
  final value = (role ?? '').trim().toLowerCase();
  switch (value) {
    case 'patient':
      return 'Patient';
    case 'doctor':
      return 'Doctor';
    case 'lab':
    case 'laboratory':
    case 'lab technician':
    case 'lab_technician':
      return 'Laboratory';
    case 'pharmacy':
    case 'pharmacist':
      return 'Pharmacy';
    case 'instructor':
      return 'Instructor';
    case 'student':
      return 'Student';
    case 'admin':
      return 'Admin';
    case 'super admin':
    case 'super_admin':
    case 'superadmin':
      return 'Super Admin';
    case 'security':
    case 'security admin':
    case 'security_admin':
      return 'Security';
    default:
      return role?.trim() ?? '';
  }
}

AppRoleKind roleKind(String? role) {
  switch (normalizeRoleName(role)) {
    case 'Patient':
      return AppRoleKind.patient;
    case 'Doctor':
      return AppRoleKind.doctor;
    case 'Laboratory':
      return AppRoleKind.laboratory;
    case 'Pharmacy':
      return AppRoleKind.pharmacy;
    case 'Instructor':
      return AppRoleKind.instructor;
    case 'Student':
      return AppRoleKind.student;
    case 'Admin':
      return AppRoleKind.admin;
    case 'Super Admin':
      return AppRoleKind.superAdmin;
    case 'Security':
      return AppRoleKind.security;
    default:
      return AppRoleKind.unknown;
  }
}

bool roleMatches(String? role, String target) => normalizeRoleName(role) == normalizeRoleName(target);
bool isPatientRole(String? role) => roleKind(role) == AppRoleKind.patient;
bool isDoctorRole(String? role) => roleKind(role) == AppRoleKind.doctor;
bool isLabRole(String? role) => roleKind(role) == AppRoleKind.laboratory;
bool isPharmacyRole(String? role) => roleKind(role) == AppRoleKind.pharmacy;
bool isInstructorRole(String? role) => roleKind(role) == AppRoleKind.instructor;
bool isStudentRole(String? role) => roleKind(role) == AppRoleKind.student;
bool isAdminRole(String? role) => roleKind(role) == AppRoleKind.admin;
bool isSuperAdminRole(String? role) => roleKind(role) == AppRoleKind.superAdmin;
bool isSecurityRole(String? role) => roleKind(role) == AppRoleKind.security;
bool isBackofficeRole(String? role) => isAdminRole(role) || isSuperAdminRole(role) || isSecurityRole(role);
bool isPatientEducationRole(String? role) => isPatientRole(role) || isStudentRole(role);

String roleDisplayLabel(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.laboratory:
      return 'Lab Partner';
    case AppRoleKind.pharmacy:
      return 'Pharmacy Partner';
    case AppRoleKind.instructor:
      return 'Instructor';
    case AppRoleKind.student:
      return 'Learner';
    case AppRoleKind.doctor:
      return 'Doctor';
    case AppRoleKind.patient:
      return 'Patient';
    case AppRoleKind.admin:
      return 'Admin';
    case AppRoleKind.superAdmin:
      return 'Super Admin';
    case AppRoleKind.security:
      return 'Security';
    default:
      return normalizeRoleName(role);
  }
}

String rolePortalLabel(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.laboratory:
      return 'LAB OPERATIONS';
    case AppRoleKind.pharmacy:
      return 'PHARMACY PARTNER';
    case AppRoleKind.instructor:
      return 'CARE PROGRAMS';
    case AppRoleKind.student:
      return 'HEALTH JOURNEY';
    case AppRoleKind.doctor:
      return 'CLINICAL DASHBOARD';
    case AppRoleKind.patient:
      return 'PATIENT PORTAL';
    case AppRoleKind.admin:
      return 'ADMIN COMMAND';
    case AppRoleKind.superAdmin:
      return 'SUPER ADMIN';
    case AppRoleKind.security:
      return 'SECURITY CONSOLE';
    default:
      return 'ICARE PORTAL';
  }
}

String coursesLabelForRole(String? role) => isPatientEducationRole(role) ? 'Health Programs' : 'Courses';
String myLearningLabelForRole(String? role) => isPatientEducationRole(role) ? 'My Health Journey' : 'My Learning';
String assignedProgramsLabelForRole(String? role) => isPatientEducationRole(role) ? 'Assigned Programs' : 'My Courses';
String searchHintForRole(String? role) => isPatientEducationRole(role) ? 'Search health programs...' : 'Search courses...';
String tabLabelForRole(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.pharmacy:
      return 'Orders';
    case AppRoleKind.laboratory:
      return 'Requests';
    case AppRoleKind.instructor:
    case AppRoleKind.student:
      return 'Learning';
    case AppRoleKind.admin:
    case AppRoleKind.superAdmin:
      return 'Audit';
    case AppRoleKind.security:
      return 'Security';
    default:
      return 'Appointments';
  }
}

IconData tabIconForRole(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.pharmacy:
      return Icons.receipt_long_rounded;
    case AppRoleKind.laboratory:
      return Icons.assignment_rounded;
    case AppRoleKind.instructor:
    case AppRoleKind.student:
      return Icons.school_rounded;
    case AppRoleKind.admin:
    case AppRoleKind.superAdmin:
      return Icons.fact_check_rounded;
    case AppRoleKind.security:
      return Icons.security_rounded;
    default:
      return Icons.calendar_month_rounded;
  }
}

String quickActionPrimaryLabel(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.doctor:
      return 'Patient Records';
    case AppRoleKind.laboratory:
      return 'Incoming Requests';
    case AppRoleKind.pharmacy:
      return 'Incoming Orders';
    case AppRoleKind.instructor:
      return 'Manage Courses';
    case AppRoleKind.student:
      return 'Assigned Programs';
    case AppRoleKind.admin:
    case AppRoleKind.superAdmin:
      return 'Admin Overview';
    case AppRoleKind.security:
      return 'Security Alerts';
    default:
      return 'Book Appointment';
  }
}

String quickActionSecondaryLabel(String? role) {
  switch (roleKind(role)) {
    case AppRoleKind.doctor:
      return 'Open Schedule';
    case AppRoleKind.laboratory:
      return 'Records';
    case AppRoleKind.pharmacy:
      return 'Inventory';
    case AppRoleKind.instructor:
      return 'Create Course';
    case AppRoleKind.student:
      return 'My Health Journey';
    case AppRoleKind.admin:
    case AppRoleKind.superAdmin:
      return 'Clinical Audit';
    case AppRoleKind.security:
      return 'Access Controls';
    default:
      return 'View Lab Reports';
  }
}
