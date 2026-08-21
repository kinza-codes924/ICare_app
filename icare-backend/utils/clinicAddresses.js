// Master address list for iCare's standalone clinics — mirrors the address
// field in lib/data/icare_clinics_data.dart (Flutter, public website).
// Every standalone clinic (Dental, Derma, Mother & Child, Physio,
// Psychiatry, Lifestyle & Wellness) currently shares this one physical
// location; keyed by clinicId so a future clinic in a different city
// (Lahore, Ghotki, etc.) is a one-line addition here, not a code change.
const CLINIC_ADDRESSES = {
  dental: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
  derma: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
  mother_child: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
  physio: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
  psychiatry: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
  lifestyle_wellness: 'Mezzanine Floor, Mall Square, Zamzama Boulevard, DHA Phase 5, Clifton, Zamzama Commercial Area, Defence V, Karachi, 75600',
};

// Resolves the address line to print on an invoice/prescription for a given
// doctor: prefers their standalone clinic's address (by clinicId), falls
// back to a free-text clinic_address on their own DoctorProfile (set by an
// independent doctor who isn't part of one of the named clinics), and
// finally null if neither is set (caller should just omit the line).
function resolveClinicAddress(doctorProfile) {
  if (!doctorProfile) return null;
  if (doctorProfile.clinicId && CLINIC_ADDRESSES[doctorProfile.clinicId]) {
    return CLINIC_ADDRESSES[doctorProfile.clinicId];
  }
  if (doctorProfile.clinic_address) return doctorProfile.clinic_address;
  return null;
}

module.exports = { CLINIC_ADDRESSES, resolveClinicAddress };
