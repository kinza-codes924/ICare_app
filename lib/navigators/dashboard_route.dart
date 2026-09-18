/// Maps a role name to its dashboard route.
///
/// Used after a role switch to navigate straight to the new role's home
/// instead of going through '/dashboard' and relying on that route's own
/// redirect to re-read the just-updated authProvider role. Keep this in
/// sync with the '/dashboard' redirect in app_router.dart.
String dashboardRouteFor(String role) {
  return switch (role) {
    'Doctor' => '/doctor/dashboard',
    'Patient' => '/patient/home',
    'Student' => '/student/dashboard',
    'Instructor' => '/instructor/dashboard',
    'Laboratory' => '/lab/dashboard',
    'Pharmacy' => '/pharmacy/dashboard',
    'Receptionist' => '/reception/dashboard',
    'Admin' => '/admin/dashboard',
    _ => '/patient/home',
  };
}
