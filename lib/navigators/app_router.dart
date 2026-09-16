import 'package:flutter/foundation.dart';
import 'package:icare/screens/doctors_list.dart' deferred as d_doctors_list;
import 'package:icare/screens/promotions_screen.dart' deferred as d_promotions;
import 'package:icare/screens/instructors_list_screen.dart' deferred as d_instructors_list;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/auth.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/email_otp_screen.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/screens/book_appointment.dart';
import 'package:icare/screens/reception_dashboard.dart'
    deferred as d_reception_dashboard;
import 'package:icare/screens/reception_records_screen.dart'
    deferred as d_reception_records_screen;
import 'package:icare/screens/admin_receptionist_management.dart'
    deferred as d_admin_receptionist_management;
import 'package:icare/screens/admin_clinic_management.dart'
    deferred as d_admin_clinic_management;
import 'package:icare/screens/clinic_admin_dashboard.dart'
    deferred as d_clinic_admin_dashboard;
import 'package:icare/screens/icare_clinics_list_screen.dart'
    deferred as d_icare_clinics_list_screen;
import 'package:icare/screens/public_home.dart';
import 'package:icare/screens/signup.dart';
import 'package:icare/screens/splash.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/screens/doctor_appointments.dart';
import 'package:icare/screens/doctor_dashboard.dart'
    deferred as d_doctor_dashboard;
import 'package:icare/screens/student_profile_setup.dart'
    deferred as d_student_profile_setup;
import 'package:icare/navigators/deferred_route.dart';
import 'package:icare/screens/admin_dashboard.dart' deferred as admin_dashboard;
import 'package:icare/screens/profile.dart' deferred as d_profile;
import 'package:icare/screens/work_with_us_signup.dart'
    deferred as d_work_with_us_signup;
import 'package:icare/screens/lms_public_catalog.dart';
import 'package:icare/screens/admin_verification_panel.dart'
    deferred as admin_verification;
import 'package:icare/screens/instructor_lms_dashboard.dart'
    deferred as i_lms_dash;
import 'package:icare/screens/instructor_lms_courses.dart'
    deferred as i_lms_courses;
import 'package:icare/screens/instructor_lms_create_course.dart'
    deferred as i_create_course;
import 'package:icare/screens/instructor_create_quiz_screen.dart'
    deferred as i_quiz;
import 'package:icare/screens/instructor_create_assignment_screen.dart'
    deferred as i_assign;
import 'package:icare/screens/instructor_grading_screen.dart'
    deferred as i_grading;
import 'package:icare/screens/instructor_schedule_session_screen.dart'
    deferred as i_session;
import 'package:icare/screens/instructor_student_progress_screen.dart'
    deferred as i_progress;
import 'package:icare/screens/instructor_course_content_screen.dart'
    deferred as i_content;
import 'package:icare/screens/instructor_course_analytics_screen.dart'
    deferred as i_analytics;
import 'package:icare/screens/instructor_course_stream_screen.dart'
    deferred as i_stream;
import 'package:icare/screens/instructor_feedback_screen.dart'
    deferred as i_feedback;
import 'package:icare/screens/certificate_verification_page.dart';
import 'package:icare/screens/otp_verification_screen.dart'
    deferred as d_otp_verification_screen;
import 'package:icare/screens/lms_public_course_detail.dart';
import 'package:icare/screens/privacy_policy.dart' deferred as d_privacy_policy;
import 'package:icare/screens/terms_and_conditions.dart'
    deferred as d_terms_and_conditions;
import 'package:icare/screens/refund_policy.dart' deferred as d_refund_policy;
import 'package:icare/screens/tasks.dart' deferred as d_tasks;
import 'package:icare/screens/bookings.dart' deferred as d_bookings;
import 'package:icare/screens/reminder_list.dart' deferred as d_reminder_list;
import 'package:icare/screens/help_and_support.dart'
    deferred as d_help_and_support;
import 'package:icare/screens/wallet.dart' deferred as d_wallet;
import 'package:icare/screens/courses.dart' deferred as d_courses;
import 'package:icare/screens/laboratory_dashboard.dart'
    deferred as d_laboratory_dashboard;
import 'package:icare/screens/lab_bookings_management.dart';
import 'package:icare/screens/lab_reports_screen.dart'
    deferred as d_lab_reports_screen;
import 'package:icare/screens/lab_tests_management.dart'
    deferred as d_lab_tests_management;
import 'package:icare/screens/payment_invoices.dart'
    deferred as d_payment_invoices;
import 'package:icare/screens/lab_analytics.dart' deferred as d_lab_analytics;
import 'package:icare/screens/settings.dart' deferred as d_settings;
import 'package:icare/screens/bookings_history.dart'
    deferred as d_bookings_history;
import 'package:icare/screens/patient_prescriptions.dart'
    deferred as d_patient_prescriptions;
import 'package:icare/screens/pharmacies.dart' deferred as d_pharmacies;
import 'package:icare/screens/patient_book_lab_flow.dart'
    deferred as d_patient_book_lab_flow;
import 'package:icare/screens/my_learning.dart' deferred as d_my_learning;
import 'package:icare/screens/health_journey_screen.dart'
    deferred as d_health_journey_screen;
import 'package:icare/screens/lifestyle_tracker_screen.dart'
    deferred as d_lifestyle_tracker_screen;
import 'package:icare/screens/emergency_contacts_screen.dart'
    deferred as d_emergency_contacts_screen;
import 'package:icare/screens/health_community.dart'
    deferred as d_health_community;
import 'package:icare/screens/gamification_screen.dart'
    deferred as d_gamification_screen;
import 'package:icare/screens/patient_records_list.dart'
    deferred as d_patient_records_list;
import 'package:icare/screens/doctor_schedule_calendar.dart'
    deferred as d_doctor_schedule_calendar;
import 'package:icare/screens/doctor_analytics.dart'
    deferred as d_doctor_analytics;
import 'package:icare/screens/doctor_availability.dart'
    deferred as d_doctor_availability;
import 'package:icare/screens/doctor_notifications.dart'
    deferred as d_doctor_notifications;
import 'package:icare/screens/pharmacist_dashboard.dart'
    deferred as d_pharmacist_dashboard;
import 'package:icare/screens/pharmacy_orders.dart'
    deferred as d_pharmacy_orders;
import 'package:icare/screens/pharmacy_inventory.dart'
    deferred as d_pharmacy_inventory;
import 'package:icare/screens/pharmacy_analytics.dart'
    deferred as d_pharmacy_analytics;
import 'package:icare/screens/instructor_dashboard.dart'
    deferred as d_instructor_dashboard;
import 'package:icare/screens/instructor_courses_management.dart'
    deferred as d_instructor_courses_management;
import 'package:icare/screens/instructor_learners_screen.dart'
    deferred as d_instructor_learners_screen;
import 'package:icare/screens/instructor_precautions_management.dart'
    deferred as d_instructor_precautions_management;
import 'package:icare/screens/instructor_analytics.dart'
    deferred as d_instructor_analytics;
import 'package:icare/screens/instructor_profile_setup.dart'
    deferred as d_instructor_profile_setup;
import 'package:icare/screens/student_dashboard.dart'
    deferred as d_student_dashboard;
import 'package:icare/screens/student_lms_dashboard.dart'
    deferred as d_student_lms_dashboard;
import 'package:icare/screens/certificates_screen.dart'
    deferred as d_certificates_screen;
import 'package:icare/screens/assessments_screen.dart'
    deferred as d_assessments_screen;
import 'package:icare/screens/admin_lms_payments_screen.dart'
    deferred as d_admin_lms_payments_screen;
import 'package:icare/screens/admin_payments_screen.dart'
    deferred as d_admin_payments_screen;
import 'package:icare/screens/payment_success_screen.dart'
    deferred as d_payment_success_screen;
import 'package:icare/screens/about_us.dart' deferred as d_about_us;
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/screens/doctor_revenue_analytics_screen.dart'
    deferred as d_doctor_revenue_analytics_screen;
import 'package:icare/screens/patient_profile.dart'
    deferred as d_patient_profile;
import 'package:icare/screens/profile_edit.dart' deferred as d_profile_edit;
import 'package:icare/screens/patient_home_dashboard.dart'
    deferred as d_patient_home_dashboard;
import 'package:icare/screens/patient_medical_records.dart'
    deferred as d_patient_medical_records;
import 'package:icare/screens/patient_lab_orders.dart'
    deferred as d_patient_lab_orders;
import 'package:icare/screens/patient_addresses_screen.dart'
    deferred as d_patient_addresses_screen;
import 'package:icare/screens/pharmacy_home.dart' deferred as d_pharmacy_home;
import 'package:icare/screens/pharmacy_management.dart'
    deferred as d_pharmacy_management;
import 'package:icare/screens/pharmacy_profile_setup.dart'
    deferred as d_pharmacy_profile_setup;
import 'package:icare/screens/pharmacy_filter.dart'
    deferred as d_pharmacy_filter;
import 'package:icare/screens/product_details.dart'
    deferred as d_product_details;
import 'package:icare/screens/my_orders.dart' deferred as d_my_orders;
import 'package:icare/screens/active_orders.dart' deferred as d_active_orders;
import 'package:icare/screens/lab_profile_setup.dart'
    deferred as d_lab_profile_setup;
import 'package:icare/screens/laboratories.dart' deferred as d_laboratories;
import 'package:icare/screens/lab_appointment.dart'
    deferred as d_lab_appointment;
import 'package:icare/screens/lab_filters.dart' deferred as d_lab_filters;
import 'package:icare/screens/lab_supplies_management.dart'
    deferred as d_lab_supplies_management;
import 'package:icare/screens/lab_settings_screen.dart'
    deferred as d_lab_settings_screen;
import 'package:icare/screens/lab_tests_directory_screen.dart'
    deferred as d_lab_tests_directory_screen;
import 'package:icare/screens/instructor_lms_screen.dart'
    deferred as d_instructor_lms_screen;
import 'package:icare/screens/instructor_assigned_learners.dart'
    deferred as d_instructor_assigned_learners;
import 'package:icare/screens/instructor_earnings_screen.dart'
    deferred as d_instructor_earnings_screen;
import 'package:icare/screens/instructor_voucher_screen.dart'
    deferred as d_instructor_voucher_screen;
import 'package:icare/screens/instructor_qa_center_screen.dart'
    deferred as d_instructor_qa_center_screen;
import 'package:icare/screens/resource_library_screen.dart'
    deferred as d_resource_library_screen;
import 'package:icare/screens/community_forum_screen.dart'
    deferred as d_community_forum_screen;
import 'package:icare/screens/admin_panel_screen.dart'
    deferred as d_admin_panel_screen;
import 'package:icare/screens/demo_users_screen.dart'
    deferred as d_demo_users_screen;
import 'package:icare/screens/security_audit_log_screen.dart'
    deferred as d_security_audit_log_screen;
import 'package:icare/screens/clinical_audit_dashboard_screen.dart'
    deferred as d_clinical_audit_dashboard_screen;
import 'package:icare/screens/clinical_audit_screen.dart'
    deferred as d_clinical_audit_screen;
import 'package:icare/screens/security_settings_screen.dart'
    deferred as d_security_settings_screen;
import 'package:icare/screens/login_activity_screen.dart'
    deferred as d_login_activity_screen;
import 'package:icare/screens/credential_vault_screen.dart'
    deferred as d_credential_vault_screen;
import 'package:icare/screens/change_password.dart'
    deferred as d_change_password;
import 'package:icare/screens/forget_password.dart'
    deferred as d_forget_password;
import 'package:icare/screens/select_user_type.dart'
    deferred as d_select_user_type;
import 'package:icare/screens/chat_list_screen.dart'
    deferred as d_chat_list_screen;
import 'package:icare/screens/notification_settings.dart'
    deferred as d_notification_settings;
import 'package:icare/screens/manage_dependents_screen.dart'
    deferred as d_manage_dependents_screen;
import 'package:icare/screens/star_click_game.dart'
    deferred as d_star_click_game;
import 'package:icare/screens/walkthrough.dart' deferred as d_walkthrough;
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/guest_session_join_screen.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/app_keys.dart';

/// Loads auth from SharedPrefs once on app start and populates authProvider.
final authInitProvider = FutureProvider<void>((ref) async {
  try {
    final token = await SharedPref().getToken();
    if (token != null && token.isNotEmpty) {
      await ref.read(authProvider.notifier).setUserToken(token);
      final userRole = await SharedPref().getUserRole();
      if (userRole != null) {
        await ref.read(authProvider.notifier).setUserRole(userRole);
      }
      final userData = await SharedPref().getUserData();
      if (userData != null) {
        await ref.read(authProvider.notifier).setUser(userData);
      }
    }
  } catch (_) {}
});

/// Notifies go_router when auth or init state changes so redirect reruns.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<void>>(authInitProvider, (_, _) => notifyListeners());
    ref.listen<Auth>(authProvider, (_, _) => notifyListeners());
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

/// Public paths that don't require authentication.
const _publicPaths = [
  '/home',
  '/login',
  '/signup',
  '/work-with-us',
  '/splash',
  '/lms/catalog',
  '/verify',
  '/lms/course',
  '/privacypolicy',
  '/terms',
  '/refund-policy',
  '/about-us',
  '/help',
  '/payment-success',
  '/payment-cancelled',
  '/select-user-type',
  '/forget-password',
  // Guest invite links for LMS live sessions. Whoever follows one has no
  // account by definition, so the token in the URL is the credential; the
  // server checks it and only ever issues a non-moderator seat.
  '/join',
];

final routerProvider = Provider<GoRouter>((ref) {
  // Trigger auth init as soon as router is created.
  ref.watch(authInitProvider);
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/home',
    observers: [FlutterSmartDialog.observer],
    refreshListenable: notifier,
    redirect: (context, state) {
      final authInit = ref.read(authInitProvider);

      // Still loading auth from SharedPrefs → show splash.
      if (authInit.isLoading) return '/splash';

      final auth = ref.read(authProvider);
      final isLoggedIn = auth.isLoggedIn;
      final user = auth.user;
      final path = state.matchedLocation;
      final isPublic = _publicPaths.any(
        (p) => path == p || path.startsWith('$p/'),
      );

      // Not logged in trying to access protected route → home.
      if (!isLoggedIn && !isPublic) return '/home';

      if (isLoggedIn && user != null) {
        // Mobile: both phone + email must be verified.
        // Web: backend sets isPhoneVerified=true at registration, so only email checked.
        final needsVerification =
            !user.isPhoneVerified || !user.isEmailVerified;

        // Email and phone have separate screens, so route to the one that
        // actually needs doing. Email is checked first: web signup verifies
        // by emailed code, and the backend refuses login until it's entered.
        if (!user.isEmailVerified && path != '/verify-email')
          return '/verify-email';
        if (!user.isPhoneVerified && path != '/verify-otp')
          return '/verify-otp';

        // Fully verified user landing on either OTP screen → dashboard.
        if (!needsVerification &&
            (path == '/verify-otp' || path == '/verify-email')) {
          return '/dashboard';
        }

        // Logged in visiting any other public route → dashboard.
        // /lms/catalog, /lms/course/*, /verify, and the legal pages remain
        // accessible to everyone regardless of login state.
        const alwaysAccessible = [
          '/lms/catalog',
          '/verify',
          '/privacypolicy',
          '/terms',
          '/refund-policy',
          '/about-us',
          '/help',
          '/payment-success',
          '/payment-cancelled',
          // A guest invite must open the session for whoever follows it. Being
          // merely "public" was not enough: a visitor who happens to be signed
          // in to any account was bounced to their own dashboard instead, and
          // the link appeared to do nothing.
          '/join',
        ];
        // Prefix match (not exact) — /payment-success/<pid> carries our own
        // payment id as a path segment and must stay reachable for logged-in
        // users too, otherwise they get bounced to /dashboard before the
        // screen even mounts.
        final isAlwaysAccessible = alwaysAccessible.any(
          (p) => path == p || path.startsWith('$p/'),
        );
        if (isPublic &&
            path != '/splash' &&
            !isAlwaysAccessible &&
            !path.startsWith('/lms/course')) {
          return '/dashboard';
        }

        // Role guard — a logged-in user who types (or is deep-linked to)
        // another role's module gets bounced to their own home via /dashboard.
        // Only the role-prefixed module areas are gated; shared routes
        // (/settings, /help, /community, /chat, etc.) are open to everyone.
        final role = auth.userRole;
        const rolePrefixes = {
          'Doctor': '/doctor/',
          'Patient': '/patient/',
          'Student': '/student/',
          'Instructor': '/instructor/',
          'Laboratory': '/lab/',
          'Pharmacy': '/pharmacy/',
          'Admin': '/admin/',
        };
        // Clinic admins are still role:'admin' at the auth level (scoped by
        // ClinicAdminProfile server-side, not by a distinct role string), so
        // gate this route the same way as the rest of /admin/*.
        if (path.startsWith('/clinic-admin/') && role != 'Admin') {
          return '/dashboard';
        }
        for (final entry in rolePrefixes.entries) {
          if (path.startsWith(entry.value) && role != entry.key) {
            debugPrint(
              '🚦 ROUTER BLOCK: path=$path role=$role needs=${entry.key} → /dashboard',
            );
            return '/dashboard';
          }
        }
      }

      debugPrint('🚦 ROUTER ALLOW: path=$path role=${auth.userRole}');
      return null;
    },
    routes: [
      // Bare "/" (e.g. payment-gateway redirects with ?tracker=... params)
      // must never 404 — send it home; logged-in users bounce to /dashboard.
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      // Safepay sends the checkout tab here after payment — a clear
      // confirmation instead of a one-second flash + dashboard redirect.
      // Our payment id travels as a PATH segment (/payment-success/<pid>),
      // not a query param — Safepay appends its own "?tracker=..." to this
      // URL blindly (without checking for an existing "?"), which mangles
      // a query-param pid into an unparsable "?pid=xxx?tracker=yyy" mess.
      GoRoute(
        path: '/payment-success/:pid',
        builder: (_, state) => DeferredScreen(
          loader: d_payment_success_screen.loadLibrary,
          builder: () => d_payment_success_screen.PaymentSuccessScreen(
            paymentId: state.pathParameters['pid'],
          ),
        ),
      ),
      GoRoute(
        path: '/payment-cancelled/:pid',
        builder: (_, state) => DeferredScreen(
          loader: d_payment_success_screen.loadLibrary,
          builder: () => d_payment_success_screen.PaymentSuccessScreen(
            cancelled: true,
            paymentId: state.pathParameters['pid'],
          ),
        ),
      ),
      // Fallback for any old links without the pid segment.
      GoRoute(
        path: '/payment-success',
        builder: (_, state) => DeferredScreen(
          loader: d_payment_success_screen.loadLibrary,
          builder: () => d_payment_success_screen.PaymentSuccessScreen(
            paymentId: state.uri.queryParameters['pid'],
          ),
        ),
      ),
      GoRoute(
        path: '/payment-cancelled',
        builder: (_, state) => DeferredScreen(
          loader: d_payment_success_screen.loadLibrary,
          builder: () => d_payment_success_screen.PaymentSuccessScreen(
            cancelled: true,
            paymentId: state.uri.queryParameters['pid'],
          ),
        ),
      ),
      // A real GoRoute for the live consultation — so the URL bar actually
      // reflects "you're in a consultation" (instead of staying frozen on
      // whatever screen navigated here via a raw Navigator.push), and so
      // the back button has a real router location to fall back to instead
      // of popping into an empty stack (blank/white screen).
      GoRoute(
        path: '/consultation/:consultationId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final pathId = state.pathParameters['consultationId'];
          // 'new' is a sentinel meaning no existing consultationId yet
          final consultationId = (pathId == 'new')
              ? (extra?['consultationId'] as String?)
              : pathId;
          // `extra` is only there when another screen pushed this route.
          // Reaching /consultation/<id> by URL, or simply reloading the page
          // mid-call, leaves it null — and the signed-in user was then handed
          // in as an empty id and an empty name, so the other side's phone
          // rang as "Unknown". Take both from the session, which is present
          // either way, and let `extra` only override it.
          final signedIn = ref.read(authProvider).user;
          final extraName = (extra?['currentUserName'] as String?)?.trim();
          final extraId = (extra?['currentUserId'] as String?)?.trim();
          return ConsultationChatScreenV2(
            consultationId: consultationId,
            appointment: extra?['appointment'] as AppointmentDetail?,
            isDoctor: extra?['isDoctor'] as bool? ?? false,
            currentUserId: (extraId != null && extraId.isNotEmpty)
                ? extraId
                : (signedIn?.id ?? ''),
            currentUserName: (extraName != null && extraName.isNotEmpty)
                ? extraName
                : (signedIn?.name ?? ''),
          );
        },
      ),
      // Guest joining a live session from an invite link.
      GoRoute(
        path: '/join/:inviteToken',
        builder: (_, state) => GuestSessionJoinScreen(
          inviteToken: state.pathParameters['inviteToken'] ?? '',
        ),
      ),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/home', builder: (_, _) => const PublicHome()),
      GoRoute(
        path: '/login',
        builder: (_, state) {
          final redirectDoctorId =
              state.uri.queryParameters['redirectDoctorId'];
          // Set when the sign-in was prompted from a clinic page, so the
          // booking it returns to is still priced as a clinic visit.
          final redirectClinicId =
              state.uri.queryParameters['redirectClinicId'];
          return LoginScreen(
            redirectDoctorId: redirectDoctorId,
            redirectClinicId: redirectClinicId,
          );
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (_, state) {
          final role = state.uri.queryParameters['role'] ?? 'Patient';
          final redirectDoctorId =
              state.uri.queryParameters['redirectDoctorId'];
          final redirectClinicId =
              state.uri.queryParameters['redirectClinicId'];
          return SignupScreen(
            role: role,
            redirectDoctorId: redirectDoctorId,
            redirectClinicId: redirectClinicId,
          );
        },
      ),
      GoRoute(
        path: '/book-appointment',
        builder: (_, state) {
          final doctorId = state.uri.queryParameters['doctorId'] ?? '';
          // Present when the booking was opened from a clinic page — that is
          // what makes it a clinic visit for pricing.
          final clinicId = state.uri.queryParameters['clinicId'];
          return BookAppointmentRouteLoader(
            doctorId: doctorId,
            clinicId: clinicId,
          );
        },
      ),
      GoRoute(
        path: '/work-with-us',
        builder: (_, _) => DeferredScreen(
          loader: d_work_with_us_signup.loadLibrary,
          builder: () => d_work_with_us_signup.WorkWithUsSignup(),
        ),
      ),
      GoRoute(
        path: '/select-user-type',
        builder: (_, _) => DeferredScreen(
          loader: d_select_user_type.loadLibrary,
          builder: () => d_select_user_type.SelectUserType(),
        ),
      ),
      GoRoute(
        path: '/forget-password',
        builder: (_, _) => DeferredScreen(
          loader: d_forget_password.loadLibrary,
          builder: () => d_forget_password.ForgetPassword(),
        ),
      ),
      // Legacy /dashboard — bookmarks & old links land here. Redirect to the
      // role's real home so it never shows a URL-less shared screen again.
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) {
          final role = ref.read(authProvider).userRole;
          final adminTab = state.uri.queryParameters['adminTab'];
          return switch (role) {
            'Doctor' => '/doctor/dashboard',
            'Patient' => '/patient/home',
            'Student' => '/student/dashboard',
            'Instructor' => '/instructor/dashboard',
            'Laboratory' => '/lab/dashboard',
            'Pharmacy' => '/pharmacy/dashboard',
            'Receptionist' => '/reception/dashboard',
            'Admin' =>
              adminTab != null
                  ? '/admin/dashboard?adminTab=$adminTab'
                  : '/admin/dashboard',
            _ => '/patient/home',
          };
        },
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (_, _) => DeferredScreen(
          loader: d_otp_verification_screen.loadLibrary,
          builder: () => d_otp_verification_screen.OtpVerificationScreen(),
        ),
      ),
      // Email verification lives on its own route so the router's redirect
      // can land on it directly. Pushing it from signup.dart alone did not
      // survive: setUserToken() runs first, the router then sees a logged-in
      // user and calls go(), which replaces the whole navigator stack.
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final email =
              (state.extra as Map<String, dynamic>?)?['email']?.toString() ??
              ref.read(authProvider).user?.email ??
              '';
          return EmailOtpScreen(
            email: email,
            onVerified: (verifiedToken) async {
              final notifier = ref.read(authProvider.notifier);
              if (verifiedToken.isNotEmpty) {
                await notifier.setUserToken(verifiedToken);
              }
              // Flip the local flag, otherwise the redirect above bounces
              // straight back here and the screen never lets go.
              final u = ref.read(authProvider).user;
              if (u != null) {
                await notifier.setUser(u.copyWith(isEmailVerified: true));
              }
              if (context.mounted) context.go('/dashboard');
            },
          );
        },
      ),
      GoRoute(
        path: '/lms/catalog',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LmsPublicCatalog(
            audienceFilter: extra?['audienceFilter'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/lms/course/:id',
        builder: (_, state) {
          final courseId = state.pathParameters['id']!;
          return LmsPublicCourseDetail(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final code = state.uri.queryParameters['code'];
          return CertificateVerificationPage(initialCode: code);
        },
      ),
      GoRoute(
        path: '/admin/verifications',
        builder: (_, _) => DeferredScreen(
          loader: admin_verification.loadLibrary,
          // Not const: a deferred class isn't available at compile time, so
          // its constructor can't be evaluated as a constant expression.
          builder: () => admin_verification.AdminVerificationPanel(),
        ),
      ),
      GoRoute(
        path: '/admin/receptionists',
        builder: (_, _) => DeferredScreen(
          loader: d_admin_receptionist_management.loadLibrary,
          builder: () =>
              d_admin_receptionist_management.AdminReceptionistManagement(),
        ),
      ),
      GoRoute(
        path: '/admin/clinics',
        builder: (_, _) => DeferredScreen(
          loader: d_admin_clinic_management.loadLibrary,
          builder: () => d_admin_clinic_management.AdminClinicManagement(),
        ),
      ),
      GoRoute(
        path: '/clinic-admin/dashboard',
        builder: (_, _) => DeferredScreen(
          loader: d_clinic_admin_dashboard.loadLibrary,
          builder: () => d_clinic_admin_dashboard.ClinicAdminDashboard(),
        ),
      ),
      GoRoute(
        path: '/admin/lms-payments',
        builder: (_, _) => DeferredScreen(
          loader: d_admin_lms_payments_screen.loadLibrary,
          builder: () => d_admin_lms_payments_screen.AdminLmsPaymentsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/payments',
        builder: (_, _) => DeferredScreen(
          loader: d_admin_payments_screen.loadLibrary,
          builder: () => d_admin_payments_screen.AdminPaymentsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/panel',
        builder: (_, _) => DeferredScreen(
          loader: d_admin_panel_screen.loadLibrary,
          builder: () => d_admin_panel_screen.AdminPanelScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/demo-users',
        builder: (_, _) => DeferredScreen(
          loader: d_demo_users_screen.loadLibrary,
          builder: () => d_demo_users_screen.DemoUsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/security-audit-log',
        builder: (_, _) => DeferredScreen(
          loader: d_security_audit_log_screen.loadLibrary,
          builder: () => d_security_audit_log_screen.SecurityAuditLogScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/clinical-audit-dashboard',
        builder: (_, _) => DeferredScreen(
          loader: d_clinical_audit_dashboard_screen.loadLibrary,
          builder: () =>
              d_clinical_audit_dashboard_screen.ClinicalAuditDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/clinical-audit',
        builder: (_, _) => DeferredScreen(
          loader: d_clinical_audit_screen.loadLibrary,
          builder: () => d_clinical_audit_screen.ClinicalAuditScreen(),
        ),
      ),

      // Shared / cross-role routes
      GoRoute(
        path: '/tasks',
        builder: (_, _) => DeferredScreen(
          loader: d_tasks.loadLibrary,
          builder: () => d_tasks.TaskScreen(),
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (_, _) => DeferredScreen(
          loader: d_bookings.loadLibrary,
          builder: () => d_bookings.BookingsScreen(),
        ),
      ),
      GoRoute(
        path: '/about-us',
        builder: (_, _) => DeferredScreen(
          loader: d_about_us.loadLibrary,
          builder: () => d_about_us.AboutUs(),
        ),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, _) => DeferredScreen(
          loader: d_wallet.loadLibrary,
          builder: () => d_wallet.WalletScreen(),
        ),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, _) => DeferredScreen(
          loader: d_courses.loadLibrary,
          builder: () => d_courses.Courses(),
        ),
      ),
      GoRoute(
        path: '/payment-invoices',
        builder: (_, _) => DeferredScreen(
          loader: d_payment_invoices.loadLibrary,
          builder: () => d_payment_invoices.PaymentInvoices(),
        ),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, _) => DeferredScreen(
          loader: d_change_password.loadLibrary,
          builder: () => d_change_password.ChangePassword(),
        ),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (_, _) => DeferredScreen(
          loader: d_notification_settings.loadLibrary,
          builder: () => d_notification_settings.NotificationSettings(),
        ),
      ),
      GoRoute(
        path: '/security-settings',
        builder: (_, _) => DeferredScreen(
          loader: d_security_settings_screen.loadLibrary,
          builder: () => d_security_settings_screen.SecuritySettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/login-activity',
        builder: (_, _) => DeferredScreen(
          loader: d_login_activity_screen.loadLibrary,
          builder: () => d_login_activity_screen.LoginActivityScreen(),
        ),
      ),
      GoRoute(
        path: '/credential-vault',
        builder: (_, _) => DeferredScreen(
          loader: d_credential_vault_screen.loadLibrary,
          builder: () => d_credential_vault_screen.CredentialVaultScreen(),
        ),
      ),
      GoRoute(
        path: '/manage-dependents',
        builder: (_, _) => DeferredScreen(
          loader: d_manage_dependents_screen.loadLibrary,
          builder: () => d_manage_dependents_screen.ManageDependentsScreen(),
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, _) => DeferredScreen(
          loader: d_chat_list_screen.loadLibrary,
          builder: () => d_chat_list_screen.ChatListScreen(),
        ),
      ),
      GoRoute(
        path: '/rewards/game',
        builder: (_, _) => DeferredScreen(
          loader: d_star_click_game.loadLibrary,
          builder: () => d_star_click_game.StarClickGame(),
        ),
      ),
      GoRoute(
        path: '/walkthrough',
        builder: (_, _) => DeferredScreen(
          loader: d_walkthrough.loadLibrary,
          builder: () => d_walkthrough.Walkthrough(),
        ),
      ),

      // ── Logged-in shell: sidebar/bottom-nav stays put, only the inner
      // screen changes with the URL (see TabsScreen). ──────────────────
      ShellRoute(
        builder: (context, state, child) {
          final adminTab = state.uri.queryParameters['adminTab'];
          return TabsScreen(initialAdminTab: adminTab, child: child);
        },
        routes: [
          // Shared sidebar targets (must stay inside the shell)
          // The three policy pages live here rather than at the top level so
          // they keep the sidebar and header, the way Settings does. Opening
          // one used to swap the whole screen for a bare full-width page.
          GoRoute(
            path: '/privacypolicy',
            builder: (_, _) => DeferredScreen(
              loader: d_privacy_policy.loadLibrary,
              builder: () => d_privacy_policy.PrivacyPolicy(),
            ),
          ),
          GoRoute(
            path: '/terms',
            builder: (_, _) => DeferredScreen(
              loader: d_terms_and_conditions.loadLibrary,
              builder: () => d_terms_and_conditions.TermsAndConditions(),
            ),
          ),
          GoRoute(
            path: '/refund-policy',
            builder: (_, _) => DeferredScreen(
              loader: d_refund_policy.loadLibrary,
              builder: () => d_refund_policy.RefundPolicy(),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => DeferredScreen(
              loader: d_settings.loadLibrary,
              builder: () => d_settings.SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/help',
            builder: (_, _) => DeferredScreen(
              loader: d_help_and_support.loadLibrary,
              builder: () => d_help_and_support.HelpAndSupport(),
            ),
          ),
          // Shared (unprefixed) so a Student can open it too — the existing
          // /patient/icare-clinics is gated by the role guard above and would
          // bounce any non-Patient straight to /dashboard.
          GoRoute(
            path: '/icare-clinics',
            builder: (_, _) => DeferredScreen(
              loader: d_icare_clinics_list_screen.loadLibrary,
              builder: () =>
                  d_icare_clinics_list_screen.ICareClinicsListScreen(),
            ),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, _) => DeferredScreen(
              loader: d_reminder_list.loadLibrary,
              builder: () => d_reminder_list.ReminderList(),
            ),
          ),
          GoRoute(
            path: '/community',
            builder: (_, _) => DeferredScreen(
              loader: d_health_community.loadLibrary,
              builder: () => d_health_community.HealthCommunityScreen(),
            ),
          ),
          GoRoute(
            path: '/rewards',
            builder: (_, _) => DeferredScreen(
              loader: d_gamification_screen.loadLibrary,
              builder: () => d_gamification_screen.GamificationScreen(),
            ),
          ),
          GoRoute(
            path: '/doctor/appointments',
            builder: (_, state) {
              final filter = state.uri.queryParameters['filter'] ?? 'all';
              return DoctorAppointmentsScreen(initialFilter: filter);
            },
          ),
          // Missing role-home / sidebar targets (added for URL routing)
          GoRoute(
            path: '/doctor/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_dashboard.loadLibrary,
              builder: () => d_doctor_dashboard.DoctorDashboard(),
            ),
          ),
          GoRoute(
            path: '/patient/lab-reports',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_reports_screen.loadLibrary,
              builder: () => d_lab_reports_screen.LabReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/lab/invoices',
            builder: (_, _) => DeferredScreen(
              loader: d_payment_invoices.loadLibrary,
              builder: () => d_payment_invoices.PaymentInvoices(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/invoices',
            builder: (_, _) => DeferredScreen(
              loader: d_payment_invoices.loadLibrary,
              builder: () =>
                  d_payment_invoices.PaymentInvoices(isPharmacy: true),
            ),
          ),
          GoRoute(
            path: '/student/courses',
            builder: (_, _) => DeferredScreen(
              loader: d_courses.loadLibrary,
              builder: () => d_courses.Courses(),
            ),
          ),
          GoRoute(
            path: '/student/browse',
            builder: (_, _) => DeferredScreen(
              loader: d_courses.loadLibrary,
              builder: () => d_courses.Courses(browse: true),
            ),
          ),
          GoRoute(
            path: '/student/profile',
            builder: (_, _) => DeferredScreen(
              loader: d_student_profile_setup.loadLibrary,
              builder: () => d_student_profile_setup.StudentProfileSetup(),
            ),
          ),
          // Reception (front-desk) routes
          GoRoute(
            path: '/reception/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_reception_dashboard.loadLibrary,
              builder: () => d_reception_dashboard.ReceptionDashboard(),
            ),
          ),
          GoRoute(
            path: '/reception/records',
            builder: (_, _) => DeferredScreen(
              loader: d_reception_records_screen.loadLibrary,
              builder: () =>
                  d_reception_records_screen.ReceptionRecordsScreen(),
            ),
          ),
          // Laboratory routes
          GoRoute(
            path: '/lab/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_laboratory_dashboard.loadLibrary,
              builder: () => d_laboratory_dashboard.LaboratoryDashboard(),
            ),
          ),
          GoRoute(
            path: '/lab/bookings',
            builder: (_, state) {
              final title = state.uri.queryParameters['title'];
              final filter = state.uri.queryParameters['filter'];
              return LabBookingsManagement(title: title, initialFilter: filter);
            },
          ),
          GoRoute(
            path: '/lab/reports',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_reports_screen.loadLibrary,
              builder: () => d_lab_reports_screen.LabReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/lab/tests',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_tests_management.loadLibrary,
              builder: () => d_lab_tests_management.LabTestsManagement(),
            ),
          ),
          GoRoute(
            path: '/lab/analytics',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_analytics.loadLibrary,
              builder: () => d_lab_analytics.LabAnalytics(),
            ),
          ),

          // Patient routes
          GoRoute(
            path: '/patient/bookings-history',
            builder: (_, _) => DeferredScreen(
              loader: d_bookings_history.loadLibrary,
              builder: () => d_bookings_history.BookingsHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/prescriptions',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_prescriptions.loadLibrary,
              builder: () => d_patient_prescriptions.PatientPrescriptions(),
            ),
          ),
          GoRoute(
            path: '/patient/pharmacies',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacies.loadLibrary,
              builder: () => d_pharmacies.PharmaciesScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/book-lab',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_book_lab_flow.loadLibrary,
              builder: () => d_patient_book_lab_flow.PatientBookLabFlow(),
            ),
          ),
          GoRoute(
            path: '/patient/icare-clinics',
            builder: (_, _) => DeferredScreen(
              loader: d_icare_clinics_list_screen.loadLibrary,
              builder: () =>
                  d_icare_clinics_list_screen.ICareClinicsListScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/my-learning',
            builder: (_, _) => DeferredScreen(
              loader: d_my_learning.loadLibrary,
              builder: () => d_my_learning.MyLearningScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/health-journey',
            builder: (_, _) => DeferredScreen(
              loader: d_health_journey_screen.loadLibrary,
              builder: () => d_health_journey_screen.HealthJourneyScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/health-tracker',
            builder: (_, _) => DeferredScreen(
              loader: d_lifestyle_tracker_screen.loadLibrary,
              builder: () =>
                  d_lifestyle_tracker_screen.LifestyleTrackerScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/emergency-contacts',
            builder: (_, _) => DeferredScreen(
              loader: d_emergency_contacts_screen.loadLibrary,
              builder: () =>
                  d_emergency_contacts_screen.EmergencyContactsScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/records',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_records_list.loadLibrary,
              builder: () => d_patient_records_list.PatientRecordsListScreen(),
            ),
          ),
          GoRoute(
            // The Profile tab opens the editable profile directly. It used to
            // land on a read-only view where editing was tucked behind a menu
            // in the top-right corner -- a tap on "Profile" that showed the
            // details but gave no obvious way to change them. The edit screen
            // carries every field the read-only one displayed.
            path: '/patient/profile',
            builder: (_, _) => DeferredScreen(
              loader: d_profile_edit.loadLibrary,
              builder: () => d_profile_edit.ProfileEditScreen(),
            ),
          ),
          GoRoute(
            // The read-only view is still reachable for anyone who wants it.
            path: '/patient/profile/view',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_profile.loadLibrary,
              builder: () => d_patient_profile.PatientProfile(),
            ),
          ),
          GoRoute(
            path: '/patient/home',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_home_dashboard.loadLibrary,
              builder: () => d_patient_home_dashboard.PatientHomeDashboard(),
            ),
          ),
          GoRoute(
            path: '/patient/medical-records',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_medical_records.loadLibrary,
              builder: () => d_patient_medical_records.PatientMedicalRecords(),
            ),
          ),
          GoRoute(
            path: '/patient/lab-orders',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_lab_orders.loadLibrary,
              builder: () => d_patient_lab_orders.PatientLabOrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/patient/addresses',
            builder: (_, _) => DeferredScreen(
              loader: d_patient_addresses_screen.loadLibrary,
              builder: () =>
                  d_patient_addresses_screen.PatientAddressesScreen(),
            ),
          ),
          GoRoute(
            path: '/community/forum',
            builder: (_, _) => DeferredScreen(
              loader: d_community_forum_screen.loadLibrary,
              builder: () => d_community_forum_screen.CommunityForumScreen(),
            ),
          ),

          // Doctor routes
          GoRoute(
            path: '/doctor/schedule',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_schedule_calendar.loadLibrary,
              builder: () =>
                  d_doctor_schedule_calendar.DoctorScheduleCalendar(),
            ),
          ),
          GoRoute(
            path: '/doctor/analytics',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_analytics.loadLibrary,
              builder: () => d_doctor_analytics.DoctorAnalytics(),
            ),
          ),
          GoRoute(
            path: '/doctor/availability',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_availability.loadLibrary,
              builder: () => d_doctor_availability.DoctorAvailability(),
            ),
          ),
          GoRoute(
            path: '/doctor/notifications',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_notifications.loadLibrary,
              builder: () => d_doctor_notifications.DoctorNotifications(),
            ),
          ),
          GoRoute(
            path: '/doctor/revenue',
            builder: (_, _) => DeferredScreen(
              loader: d_doctor_revenue_analytics_screen.loadLibrary,
              builder: () =>
                  d_doctor_revenue_analytics_screen.DoctorRevenueAnalyticsScreen(),
            ),
          ),

          // Pharmacy routes
          GoRoute(
            path: '/pharmacy/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacist_dashboard.loadLibrary,
              builder: () => d_pharmacist_dashboard.PharmacistDashboard(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/orders',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_orders.loadLibrary,
              builder: () => d_pharmacy_orders.PharmacyOrders(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/inventory',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_inventory.loadLibrary,
              builder: () => d_pharmacy_inventory.PharmacyInventory(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/analytics',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_analytics.loadLibrary,
              builder: () => d_pharmacy_analytics.PharmacyAnalytics(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/home',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_home.loadLibrary,
              builder: () => d_pharmacy_home.PharmacyHome(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/management',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_management.loadLibrary,
              builder: () => d_pharmacy_management.PharmacyManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/profile-setup',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_profile_setup.loadLibrary,
              builder: () => d_pharmacy_profile_setup.PharmacyProfileSetup(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/filter',
            builder: (_, _) => DeferredScreen(
              loader: d_pharmacy_filter.loadLibrary,
              builder: () => d_pharmacy_filter.PharmacyFilterScreen(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/product',
            builder: (_, _) => DeferredScreen(
              loader: d_product_details.loadLibrary,
              builder: () => d_product_details.ProductDetailsScreen(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/my-orders',
            builder: (_, _) => DeferredScreen(
              loader: d_my_orders.loadLibrary,
              builder: () => d_my_orders.MyOrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/pharmacy/active-orders',
            builder: (_, _) => DeferredScreen(
              loader: d_active_orders.loadLibrary,
              builder: () => d_active_orders.ActiveOrdersScreen(),
            ),
          ),

          // Lab routes (additional)
          GoRoute(
            path: '/lab/profile-setup',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_profile_setup.loadLibrary,
              builder: () => d_lab_profile_setup.LabProfileSetup(),
            ),
          ),
          GoRoute(
            path: '/lab/list',
            builder: (_, _) => DeferredScreen(
              loader: d_laboratories.loadLibrary,
              builder: () => d_laboratories.LaboratoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/lab/appointments',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_appointment.loadLibrary,
              builder: () => d_lab_appointment.LabAppointments(),
            ),
          ),
          GoRoute(
            path: '/lab/filters',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_filters.loadLibrary,
              builder: () => d_lab_filters.LabFilters(),
            ),
          ),
          GoRoute(
            path: '/lab/supplies',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_supplies_management.loadLibrary,
              builder: () => d_lab_supplies_management.LabSuppliesManagement(),
            ),
          ),
          GoRoute(
            path: '/lab/settings',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_settings_screen.loadLibrary,
              builder: () => d_lab_settings_screen.LabSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/lab/tests-directory',
            builder: (_, _) => DeferredScreen(
              loader: d_lab_tests_directory_screen.loadLibrary,
              builder: () =>
                  d_lab_tests_directory_screen.LabTestsDirectoryScreen(),
            ),
          ),

          // Instructor (non-LMS-content) routes
          GoRoute(
            path: '/instructor/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_dashboard.loadLibrary,
              builder: () => d_instructor_dashboard.InstructorDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/manage-courses',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_courses_management.loadLibrary,
              builder: () =>
                  d_instructor_courses_management.InstructorCoursesManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/learners',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_learners_screen.loadLibrary,
              builder: () =>
                  d_instructor_learners_screen.InstructorLearnersScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/precautions',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_precautions_management.loadLibrary,
              builder: () =>
                  d_instructor_precautions_management.InstructorPrecautionsManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/analytics',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_analytics.loadLibrary,
              builder: () => d_instructor_analytics.InstructorAnalytics(),
            ),
          ),
          GoRoute(
            path: '/instructor/profile-setup',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_profile_setup.loadLibrary,
              builder: () =>
                  d_instructor_profile_setup.InstructorProfileSetupScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/lms-home',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_lms_screen.loadLibrary,
              builder: () => d_instructor_lms_screen.InstructorLmsScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/assigned-learners',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_assigned_learners.loadLibrary,
              builder: () =>
                  d_instructor_assigned_learners.InstructorAssignedLearners(),
            ),
          ),
          GoRoute(
            path: '/instructor/earnings',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_earnings_screen.loadLibrary,
              builder: () =>
                  d_instructor_earnings_screen.InstructorEarningsScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/vouchers',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_voucher_screen.loadLibrary,
              builder: () =>
                  d_instructor_voucher_screen.InstructorVoucherScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/qa-center',
            builder: (_, _) => DeferredScreen(
              loader: d_instructor_qa_center_screen.loadLibrary,
              builder: () =>
                  d_instructor_qa_center_screen.InstructorQACenterScreen(),
            ),
          ),
          GoRoute(
            path: '/instructor/resources',
            builder: (_, _) => DeferredScreen(
              loader: d_resource_library_screen.loadLibrary,
              builder: () => d_resource_library_screen.ResourceLibraryScreen(),
            ),
          ),

          // Student routes
          GoRoute(
            path: '/student/dashboard',
            builder: (_, _) => DeferredScreen(
              loader: d_student_dashboard.loadLibrary,
              builder: () => d_student_dashboard.StudentDashboard(),
            ),
          ),
          GoRoute(
            path: '/student/classroom',
            builder: (_, _) => DeferredScreen(
              loader: d_student_lms_dashboard.loadLibrary,
              builder: () => d_student_lms_dashboard.StudentLmsDashboard(),
            ),
          ),
          GoRoute(
        // Telehealth entry point. /book-appointment needs a specific doctor and
        // errors out without one, which is what the sidebar link used to hit.
        path: '/doctors',
        builder: (_, _) => DeferredScreen(
          loader: d_doctors_list.loadLibrary,
          builder: () => d_doctors_list.DoctorsList(),
        ),
      ),
      GoRoute(
        path: '/promotions',
        builder: (_, _) => DeferredScreen(
          loader: d_promotions.loadLibrary,
          builder: () => d_promotions.PromotionsScreen(),
        ),
      ),
      GoRoute(
        path: '/student/instructors',
        builder: (_, _) => DeferredScreen(
          loader: d_instructors_list.loadLibrary,
          builder: () => d_instructors_list.InstructorsListScreen(),
        ),
      ),
      GoRoute(
            path: '/student/certificates',
            builder: (_, _) => DeferredScreen(
              loader: d_certificates_screen.loadLibrary,
              builder: () => d_certificates_screen.CertificatesScreen(),
            ),
          ),
          GoRoute(
            path: '/student/assessments',
            builder: (_, _) => DeferredScreen(
              loader: d_assessments_screen.loadLibrary,
              builder: () => d_assessments_screen.AssessmentsScreen(),
            ),
          ),

          // Admin
          GoRoute(
            path: '/admin/dashboard',
            builder: (_, state) => DeferredScreen(
              loader: admin_dashboard.loadLibrary,
              builder: () => admin_dashboard.AdminDashboard(
                initialTab: state.uri.queryParameters['adminTab'] ?? 'Pending',
              ),
            ),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (_, _) => DeferredScreen(
              loader: d_profile.loadLibrary,
              builder: () => d_profile.ProfileScreen(),
            ),
          ),
        ],
      ),
      // Instructor LMS Routes
      GoRoute(
        path: '/instructor/lms',
        builder: (_, _) => DeferredScreen(
          loader: i_lms_dash.loadLibrary,
          builder: () => i_lms_dash.InstructorLmsDashboard(),
        ),
      ),
      GoRoute(
        path: '/instructor/lms/feedback',
        builder: (_, _) => DeferredScreen(
          loader: i_feedback.loadLibrary,
          builder: () => i_feedback.InstructorFeedbackScreen(),
        ),
      ),
      GoRoute(
        path: '/instructor/lms/courses',
        builder: (_, _) => DeferredScreen(
          loader: i_lms_courses.loadLibrary,
          builder: () => i_lms_courses.InstructorLmsCoursesScreen(),
        ),
      ),
      GoRoute(
        path: '/instructor/lms/create-course',
        builder: (_, _) => DeferredScreen(
          loader: i_create_course.loadLibrary,
          builder: () => i_create_course.InstructorLmsCreateCourseScreen(),
        ),
      ),

      // Quiz routes
      GoRoute(
        path: '/instructor/lms/create-quiz',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return DeferredScreen(
            loader: i_quiz.loadLibrary,
            builder: () =>
                i_quiz.InstructorCreateQuizScreen(courseId: courseId),
          );
        },
      ),
      GoRoute(
        path: '/instructor/lms/edit-quiz/:id',
        builder: (context, state) {
          final quizId = state.pathParameters['id'];
          return DeferredScreen(
            loader: i_quiz.loadLibrary,
            builder: () => i_quiz.InstructorCreateQuizScreen(quizId: quizId),
          );
        },
      ),

      // Assignment routes
      GoRoute(
        path: '/instructor/lms/create-assignment',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return DeferredScreen(
            loader: i_assign.loadLibrary,
            builder: () =>
                i_assign.InstructorCreateAssignmentScreen(courseId: courseId),
          );
        },
      ),
      GoRoute(
        path: '/instructor/lms/assignment/:id/grade',
        builder: (context, state) {
          final assignmentId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Assignment';
          return DeferredScreen(
            loader: i_grading.loadLibrary,
            builder: () => i_grading.InstructorGradingScreen(
              assignmentId: assignmentId,
              assignmentTitle: title,
            ),
          );
        },
      ),

      // Live session routes
      GoRoute(
        path: '/instructor/lms/schedule-session',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return DeferredScreen(
            loader: i_session.loadLibrary,
            builder: () =>
                i_session.InstructorScheduleSessionScreen(courseId: courseId),
          );
        },
      ),

      // Student progress routes
      GoRoute(
        path: '/instructor/lms/course/:id/students',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return DeferredScreen(
            loader: i_progress.loadLibrary,
            builder: () => i_progress.InstructorStudentProgressScreen(
              courseId: courseId,
              courseTitle: title,
            ),
          );
        },
      ),

      // Content management routes
      GoRoute(
        path: '/instructor/lms/course/:id/content',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          return DeferredScreen(
            loader: i_content.loadLibrary,
            builder: () =>
                i_content.InstructorCourseContentScreen(courseId: courseId),
          );
        },
      ),

      // Analytics routes
      GoRoute(
        path: '/instructor/lms/course/:id/analytics',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return DeferredScreen(
            loader: i_analytics.loadLibrary,
            builder: () => i_analytics.InstructorCourseAnalyticsScreen(
              courseId: courseId,
              courseTitle: title,
            ),
          );
        },
      ),

      // Stream/Announcements routes
      GoRoute(
        path: '/instructor/lms/course/:id/stream',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return DeferredScreen(
            loader: i_stream.loadLibrary,
            builder: () => i_stream.InstructorCourseStreamScreen(
              courseId: courseId,
              courseTitle: title,
            ),
          );
        },
      ),

      // Course detail page
      GoRoute(
        path: '/instructor/lms/course/:id',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          // This will need the course data - for now redirect to content
          return DeferredScreen(
            loader: i_content.loadLibrary,
            builder: () =>
                i_content.InstructorCourseContentScreen(courseId: courseId),
          );
        },
      ),
    ],
  );
});
