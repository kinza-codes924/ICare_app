/// Working out who the viewer is in a consultation.
///
/// This lives on its own, away from the screen, for one reason: it is the
/// piece that broke. The caller's name used to come straight out of
/// GoRouter's `extra`, which is only populated when another screen pushed the
/// route. Reaching /consultation/<id> by URL — or simply reloading the page
/// mid-call — left it empty, and the person on the other end was rung by
/// "Unknown".
///
/// A pure function can be tested without building a screen, mounting a
/// router or signing anyone in, so the rule it enforces is checked on every
/// run instead of being re-discovered during a live consultation.
library;

/// The viewer's own display name, from the best source available.
///
/// Tried in order: what the screen was given, then the consultation record
/// (which names both sides regardless of how the screen was opened), then a
/// plain role word. Never returns an empty string — an empty name is what
/// reached the other party as "Unknown".
String resolveMyName({
  required bool isDoctor,
  String? passedInName,
  String? nameFromRecord,
}) {
  final passed = passedInName?.trim();
  if (passed != null && passed.isNotEmpty) return passed;

  final record = nameFromRecord?.trim();
  if (record != null && record.isNotEmpty) return record;

  return isDoctor ? 'Doctor' : 'Patient';
}

/// How the caller announces themselves on the ring signal.
///
/// Doctors ring with their title so the patient sees who is calling. The
/// title is added only when it is not already there, so a name stored as
/// "Dr. Kamran" does not go out as "Dr. Dr. Kamran".
String resolveCallerDisplayName({
  required bool isDoctor,
  required String myName,
}) {
  final name = myName.trim();
  if (!isDoctor) return name;
  if (name.toLowerCase().startsWith('dr.') ||
      name.toLowerCase().startsWith('dr ')) {
    return name;
  }
  return 'Dr. $name';
}
