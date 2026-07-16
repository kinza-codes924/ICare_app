import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/auth.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/screens/public_home.dart';
import 'package:icare/screens/signup.dart';
import 'package:icare/screens/splash.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/screens/doctor_appointments.dart';
import 'package:icare/screens/work_with_us_signup.dart';
import 'package:icare/screens/lms_public_catalog.dart';
import 'package:icare/screens/admin_verification_panel.dart';
import 'package:icare/screens/instructor_lms_dashboard.dart';
import 'package:icare/screens/instructor_lms_courses.dart';
import 'package:icare/screens/instructor_lms_create_course.dart';
import 'package:icare/screens/instructor_create_quiz_screen.dart';
import 'package:icare/screens/instructor_create_assignment_screen.dart';
import 'package:icare/screens/instructor_grading_screen.dart';
import 'package:icare/screens/instructor_schedule_session_screen.dart';
import 'package:icare/screens/instructor_student_progress_screen.dart';
import 'package:icare/screens/instructor_course_content_screen.dart';
import 'package:icare/screens/instructor_course_analytics_screen.dart';
import 'package:icare/screens/instructor_course_stream_screen.dart';
import 'package:icare/screens/instructor_feedback_screen.dart';
import 'package:icare/screens/certificate_verification_page.dart';
import 'package:icare/screens/otp_verification_screen.dart';
import 'package:icare/screens/lms_public_course_detail.dart';
import 'package:icare/screens/privacy_policy.dart';
import 'package:icare/screens/terms_and_conditions.dart';
import 'package:icare/screens/refund_policy.dart';
import 'package:icare/screens/tasks.dart';
import 'package:icare/screens/bookings.dart';
import 'package:icare/screens/reminder_list.dart';
import 'package:icare/screens/help_and_support.dart';
import 'package:icare/screens/wallet.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/laboratory_dashboard.dart';
import 'package:icare/screens/lab_bookings_management.dart';
import 'package:icare/screens/lab_reports_screen.dart';
import 'package:icare/screens/lab_tests_management.dart';
import 'package:icare/screens/payment_invoices.dart';
import 'package:icare/screens/lab_analytics.dart';
import 'package:icare/screens/settings.dart';
import 'package:icare/screens/bookings_history.dart';
import 'package:icare/screens/patient_prescriptions.dart';
import 'package:icare/screens/pharmacies.dart';
import 'package:icare/screens/patient_book_lab_flow.dart';
import 'package:icare/screens/my_learning.dart';
import 'package:icare/screens/health_journey_screen.dart';
import 'package:icare/screens/lifestyle_tracker_screen.dart';
import 'package:icare/screens/emergency_contacts_screen.dart';
import 'package:icare/screens/health_community.dart';
import 'package:icare/screens/gamification_screen.dart';
import 'package:icare/screens/patient_records_list.dart';
import 'package:icare/screens/doctor_schedule_calendar.dart';
import 'package:icare/screens/doctor_analytics.dart';
import 'package:icare/screens/doctor_availability.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/pharmacist_dashboard.dart';
import 'package:icare/screens/pharmacy_orders.dart';
import 'package:icare/screens/pharmacy_inventory.dart';
import 'package:icare/screens/pharmacy_analytics.dart';
import 'package:icare/screens/instructor_dashboard.dart';
import 'package:icare/screens/instructor_courses_management.dart';
import 'package:icare/screens/instructor_learners_screen.dart';
import 'package:icare/screens/instructor_precautions_management.dart';
import 'package:icare/screens/instructor_analytics.dart';
import 'package:icare/screens/instructor_profile_setup.dart';
import 'package:icare/screens/student_dashboard.dart';
import 'package:icare/screens/student_lms_dashboard.dart';
import 'package:icare/screens/certificates_screen.dart';
import 'package:icare/screens/assessments_screen.dart';
import 'package:icare/screens/admin_lms_payments_screen.dart';
import 'package:icare/screens/admin_payments_screen.dart';
import 'package:icare/screens/payment_success_screen.dart';
import 'package:icare/screens/about_us.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/screens/doctor_revenue_analytics_screen.dart';
import 'package:icare/screens/patient_profile.dart';
import 'package:icare/screens/patient_home_dashboard.dart';
import 'package:icare/screens/patient_medical_records.dart';
import 'package:icare/screens/patient_lab_orders.dart';
import 'package:icare/screens/patient_addresses_screen.dart';
import 'package:icare/screens/pharmacy_home.dart';
import 'package:icare/screens/pharmacy_management.dart';
import 'package:icare/screens/pharmacy_profile_setup.dart';
import 'package:icare/screens/pharmacy_filter.dart';
import 'package:icare/screens/product_details.dart';
import 'package:icare/screens/my_orders.dart';
import 'package:icare/screens/active_orders.dart';
import 'package:icare/screens/lab_profile_setup.dart';
import 'package:icare/screens/laboratories.dart';
import 'package:icare/screens/lab_appointment.dart';
import 'package:icare/screens/lab_filters.dart';
import 'package:icare/screens/lab_supplies_management.dart';
import 'package:icare/screens/lab_settings_screen.dart';
import 'package:icare/screens/lab_tests_directory_screen.dart';
import 'package:icare/screens/instructor_lms_screen.dart';
import 'package:icare/screens/instructor_assigned_learners.dart';
import 'package:icare/screens/instructor_earnings_screen.dart';
import 'package:icare/screens/instructor_voucher_screen.dart';
import 'package:icare/screens/instructor_qa_center_screen.dart';
import 'package:icare/screens/resource_library_screen.dart';
import 'package:icare/screens/community_forum_screen.dart';
import 'package:icare/screens/admin_panel_screen.dart';
import 'package:icare/screens/demo_users_screen.dart';
import 'package:icare/screens/security_audit_log_screen.dart';
import 'package:icare/screens/clinical_audit_dashboard_screen.dart';
import 'package:icare/screens/clinical_audit_screen.dart';
import 'package:icare/screens/security_settings_screen.dart';
import 'package:icare/screens/login_activity_screen.dart';
import 'package:icare/screens/credential_vault_screen.dart';
import 'package:icare/screens/change_password.dart';
import 'package:icare/screens/forget_password.dart';
import 'package:icare/screens/select_user_type.dart';
import 'package:icare/screens/chat_list_screen.dart';
import 'package:icare/screens/notification_settings.dart';
import 'package:icare/screens/manage_dependents_screen.dart';
import 'package:icare/screens/star_click_game.dart';
import 'package:icare/screens/walkthrough.dart';
import 'package:icare/models/appointment_detail.dart';
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
const _publicPaths = ['/home', '/login', '/signup', '/work-with-us', '/splash', '/lms/catalog', '/verify', '/lms/course', '/privacypolicy', '/terms', '/refund-policy', '/about-us', '/help', '/payment-success', '/payment-cancelled', '/select-user-type', '/forget-password'];

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
      final isPublic = _publicPaths.any((p) => path == p || path.startsWith('$p/'));

      // Not logged in trying to access protected route → home.
      if (!isLoggedIn && !isPublic) return '/home';

      if (isLoggedIn && user != null) {
        // Mobile: both phone + email must be verified.
        // Web: backend sets isPhoneVerified=true at registration, so only email checked.
        final needsVerification =
            !user.isPhoneVerified || !user.isEmailVerified;

        // Unverified user → force to OTP screen (unless already there).
        if (needsVerification && path != '/verify-otp') return '/verify-otp';

        // Fully verified user landing on OTP screen → send to dashboard.
        if (!needsVerification && path == '/verify-otp') return '/dashboard';

        // Logged in visiting any other public route → dashboard.
        // /lms/catalog, /lms/course/*, /verify, and the legal pages remain
        // accessible to everyone regardless of login state.
        const alwaysAccessible = ['/lms/catalog', '/verify', '/privacypolicy', '/terms', '/refund-policy', '/about-us', '/help', '/payment-success', '/payment-cancelled'];
        // Prefix match (not exact) — /payment-success/<pid> carries our own
        // payment id as a path segment and must stay reachable for logged-in
        // users too, otherwise they get bounced to /dashboard before the
        // screen even mounts.
        final isAlwaysAccessible = alwaysAccessible.any((p) => path == p || path.startsWith('$p/'));
        if (isPublic && path != '/splash' && !isAlwaysAccessible &&
            !path.startsWith('/lms/course')) {
          return '/dashboard';
        }
      }

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
        builder: (_, state) => PaymentSuccessScreen(paymentId: state.pathParameters['pid']),
      ),
      GoRoute(
        path: '/payment-cancelled/:pid',
        builder: (_, state) => PaymentSuccessScreen(cancelled: true, paymentId: state.pathParameters['pid']),
      ),
      // Fallback for any old links without the pid segment.
      GoRoute(
        path: '/payment-success',
        builder: (_, state) => PaymentSuccessScreen(paymentId: state.uri.queryParameters['pid']),
      ),
      GoRoute(
        path: '/payment-cancelled',
        builder: (_, state) => PaymentSuccessScreen(cancelled: true, paymentId: state.uri.queryParameters['pid']),
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
          return ConsultationChatScreenV2(
            consultationId: state.pathParameters['consultationId'],
            appointment: extra?['appointment'] as AppointmentDetail?,
            isDoctor: extra?['isDoctor'] as bool? ?? false,
            currentUserId: extra?['currentUserId'] as String? ?? '',
            currentUserName: extra?['currentUserName'] as String? ?? '',
          );
        },
      ),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/home', builder: (_, _) => const PublicHome()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, state) {
          final role = state.uri.queryParameters['role'] ?? 'Patient';
          return SignupScreen(role: role);
        },
      ),
      GoRoute(path: '/work-with-us', builder: (_, _) => const WorkWithUsSignup()),
      GoRoute(path: '/select-user-type', builder: (_, _) => const SelectUserType()),
      GoRoute(path: '/forget-password', builder: (_, _) => const ForgetPassword()),
      GoRoute(path: '/privacypolicy', builder: (_, _) => const PrivacyPolicy()),
      GoRoute(path: '/terms', builder: (_, _) => const TermsAndConditions()),
      GoRoute(path: '/refund-policy', builder: (_, _) => const RefundPolicy()),
      GoRoute(
        path: '/dashboard',
        builder: (_, state) {
          final adminTab = state.uri.queryParameters['adminTab'];
          return TabsScreen(initialAdminTab: adminTab);
        },
      ),
      GoRoute(path: '/verify-otp', builder: (_, _) => const OtpVerificationScreen()),
      GoRoute(path: '/doctor/appointments', builder: (_, state) {
        final filter = state.uri.queryParameters['filter'] ?? 'all';
        return DoctorAppointmentsScreen(initialFilter: filter);
      }),
      GoRoute(
        path: '/lms/catalog',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LmsPublicCatalog(audienceFilter: extra?['audienceFilter'] as String?);
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
      GoRoute(path: '/admin/verifications', builder: (_, _) => const AdminVerificationPanel()),
      GoRoute(path: '/admin/lms-payments', builder: (_, _) => const AdminLmsPaymentsScreen()),
      GoRoute(path: '/admin/payments', builder: (_, _) => const AdminPaymentsScreen()),
      GoRoute(path: '/admin/panel', builder: (_, _) => const AdminPanelScreen()),
      GoRoute(path: '/admin/demo-users', builder: (_, _) => const DemoUsersScreen()),
      GoRoute(path: '/admin/security-audit-log', builder: (_, _) => const SecurityAuditLogScreen()),
      GoRoute(path: '/admin/clinical-audit-dashboard', builder: (_, _) => const ClinicalAuditDashboardScreen()),
      GoRoute(path: '/admin/clinical-audit', builder: (_, _) => const ClinicalAuditScreen()),

      // Shared / cross-role routes
      GoRoute(path: '/tasks', builder: (_, _) => const TaskScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen()),
      GoRoute(path: '/reminders', builder: (_, _) => const ReminderList()),
      GoRoute(path: '/help', builder: (_, _) => const HelpAndSupport()),
      GoRoute(path: '/about-us', builder: (_, _) => const AboutUs()),
      GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
      GoRoute(path: '/courses', builder: (_, _) => const Courses()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/payment-invoices', builder: (_, _) => const PaymentInvoices()),
      GoRoute(path: '/change-password', builder: (_, _) => const ChangePassword()),
      GoRoute(path: '/notification-settings', builder: (_, _) => const NotificationSettings()),
      GoRoute(path: '/security-settings', builder: (_, _) => const SecuritySettingsScreen()),
      GoRoute(path: '/login-activity', builder: (_, _) => const LoginActivityScreen()),
      GoRoute(path: '/credential-vault', builder: (_, _) => const CredentialVaultScreen()),
      GoRoute(path: '/manage-dependents', builder: (_, _) => const ManageDependentsScreen()),
      GoRoute(path: '/chat', builder: (_, _) => const ChatListScreen()),
      GoRoute(path: '/rewards/game', builder: (_, _) => const StarClickGame()),
      GoRoute(path: '/walkthrough', builder: (_, _) => const Walkthrough()),

      // Laboratory routes
      GoRoute(path: '/lab/dashboard', builder: (_, _) => const LaboratoryDashboard()),
      GoRoute(
        path: '/lab/bookings',
        builder: (_, state) {
          final title = state.uri.queryParameters['title'];
          final filter = state.uri.queryParameters['filter'];
          return LabBookingsManagement(title: title, initialFilter: filter);
        },
      ),
      GoRoute(path: '/lab/reports', builder: (_, _) => const LabReportsScreen()),
      GoRoute(path: '/lab/tests', builder: (_, _) => const LabTestsManagement()),
      GoRoute(path: '/lab/analytics', builder: (_, _) => const LabAnalytics()),

      // Patient routes
      GoRoute(path: '/patient/bookings-history', builder: (_, _) => const BookingsHistoryScreen()),
      GoRoute(path: '/patient/prescriptions', builder: (_, _) => const PatientPrescriptions()),
      GoRoute(path: '/patient/pharmacies', builder: (_, _) => const PharmaciesScreen()),
      GoRoute(path: '/patient/book-lab', builder: (_, _) => const PatientBookLabFlow()),
      GoRoute(path: '/patient/my-learning', builder: (_, _) => const MyLearningScreen()),
      GoRoute(path: '/patient/health-journey', builder: (_, _) => const HealthJourneyScreen()),
      GoRoute(path: '/patient/health-tracker', builder: (_, _) => const LifestyleTrackerScreen()),
      GoRoute(path: '/patient/emergency-contacts', builder: (_, _) => const EmergencyContactsScreen()),
      GoRoute(path: '/patient/records', builder: (_, _) => const PatientRecordsListScreen()),
      GoRoute(path: '/patient/profile', builder: (_, _) => const PatientProfile()),
      GoRoute(path: '/patient/home', builder: (_, _) => const PatientHomeDashboard()),
      GoRoute(path: '/patient/medical-records', builder: (_, _) => const PatientMedicalRecords()),
      GoRoute(path: '/patient/lab-orders', builder: (_, _) => const PatientLabOrdersScreen()),
      GoRoute(path: '/patient/addresses', builder: (_, _) => const PatientAddressesScreen()),
      GoRoute(path: '/community', builder: (_, _) => const HealthCommunityScreen()),
      GoRoute(path: '/community/forum', builder: (_, _) => const CommunityForumScreen()),
      GoRoute(path: '/rewards', builder: (_, _) => const GamificationScreen()),

      // Doctor routes
      GoRoute(path: '/doctor/schedule', builder: (_, _) => const DoctorScheduleCalendar()),
      GoRoute(path: '/doctor/analytics', builder: (_, _) => const DoctorAnalytics()),
      GoRoute(path: '/doctor/availability', builder: (_, _) => const DoctorAvailability()),
      GoRoute(path: '/doctor/notifications', builder: (_, _) => const DoctorNotifications()),
      GoRoute(path: '/doctor/revenue', builder: (_, _) => const DoctorRevenueAnalyticsScreen()),

      // Pharmacy routes
      GoRoute(path: '/pharmacy/dashboard', builder: (_, _) => const PharmacistDashboard()),
      GoRoute(path: '/pharmacy/orders', builder: (_, _) => const PharmacyOrders()),
      GoRoute(path: '/pharmacy/inventory', builder: (_, _) => const PharmacyInventory()),
      GoRoute(path: '/pharmacy/analytics', builder: (_, _) => const PharmacyAnalytics()),
      GoRoute(path: '/pharmacy/home', builder: (_, _) => const PharmacyHome()),
      GoRoute(path: '/pharmacy/management', builder: (_, _) => const PharmacyManagementScreen()),
      GoRoute(path: '/pharmacy/profile-setup', builder: (_, _) => const PharmacyProfileSetup()),
      GoRoute(path: '/pharmacy/filter', builder: (_, _) => const PharmacyFilterScreen()),
      GoRoute(path: '/pharmacy/product', builder: (_, _) => const ProductDetailsScreen()),
      GoRoute(path: '/pharmacy/my-orders', builder: (_, _) => const MyOrdersScreen()),
      GoRoute(path: '/pharmacy/active-orders', builder: (_, _) => const ActiveOrdersScreen()),

      // Lab routes (additional)
      GoRoute(path: '/lab/profile-setup', builder: (_, _) => const LabProfileSetup()),
      GoRoute(path: '/lab/list', builder: (_, _) => const LaboratoriesScreen()),
      GoRoute(path: '/lab/appointments', builder: (_, _) => const LabAppointments()),
      GoRoute(path: '/lab/filters', builder: (_, _) => const LabFilters()),
      GoRoute(path: '/lab/supplies', builder: (_, _) => const LabSuppliesManagement()),
      GoRoute(path: '/lab/settings', builder: (_, _) => const LabSettingsScreen()),
      GoRoute(path: '/lab/tests-directory', builder: (_, _) => const LabTestsDirectoryScreen()),

      // Instructor (non-LMS-content) routes
      GoRoute(path: '/instructor/dashboard', builder: (_, _) => InstructorDashboardScreen()),
      GoRoute(path: '/instructor/manage-courses', builder: (_, _) => InstructorCoursesManagementScreen()),
      GoRoute(path: '/instructor/learners', builder: (_, _) => InstructorLearnersScreen()),
      GoRoute(path: '/instructor/precautions', builder: (_, _) => InstructorPrecautionsManagementScreen()),
      GoRoute(path: '/instructor/analytics', builder: (_, _) => InstructorAnalytics()),
      GoRoute(path: '/instructor/profile-setup', builder: (_, _) => InstructorProfileSetupScreen()),
      GoRoute(path: '/instructor/lms-home', builder: (_, _) => const InstructorLmsScreen()),
      GoRoute(path: '/instructor/assigned-learners', builder: (_, _) => const InstructorAssignedLearners()),
      GoRoute(path: '/instructor/earnings', builder: (_, _) => const InstructorEarningsScreen()),
      GoRoute(path: '/instructor/vouchers', builder: (_, _) => const InstructorVoucherScreen()),
      GoRoute(path: '/instructor/qa-center', builder: (_, _) => const InstructorQACenterScreen()),
      GoRoute(path: '/instructor/resources', builder: (_, _) => const ResourceLibraryScreen()),

      // Student routes
      GoRoute(path: '/student/dashboard', builder: (_, _) => const StudentDashboard()),
      GoRoute(path: '/student/classroom', builder: (_, _) => const StudentLmsDashboard()),
      GoRoute(path: '/student/certificates', builder: (_, _) => const CertificatesScreen()),
      GoRoute(path: '/student/assessments', builder: (_, _) => const AssessmentsScreen()),

      // Instructor LMS Routes
      GoRoute(path: '/instructor/lms', builder: (_, _) => const InstructorLmsDashboard()),
      GoRoute(path: '/instructor/lms/feedback', builder: (_, _) => const InstructorFeedbackScreen()),
      GoRoute(path: '/instructor/lms/courses', builder: (_, _) => const InstructorLmsCoursesScreen()),
      GoRoute(path: '/instructor/lms/create-course', builder: (_, _) => const InstructorLmsCreateCourseScreen()),
      
      // Quiz routes
      GoRoute(
        path: '/instructor/lms/create-quiz',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return InstructorCreateQuizScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/instructor/lms/edit-quiz/:id',
        builder: (context, state) {
          final quizId = state.pathParameters['id'];
          return InstructorCreateQuizScreen(quizId: quizId);
        },
      ),
      
      // Assignment routes
      GoRoute(
        path: '/instructor/lms/create-assignment',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return InstructorCreateAssignmentScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/instructor/lms/assignment/:id/grade',
        builder: (context, state) {
          final assignmentId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Assignment';
          return InstructorGradingScreen(
            assignmentId: assignmentId,
            assignmentTitle: title,
          );
        },
      ),
      
      // Live session routes
      GoRoute(
        path: '/instructor/lms/schedule-session',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return InstructorScheduleSessionScreen(courseId: courseId);
        },
      ),
      
      // Student progress routes
      GoRoute(
        path: '/instructor/lms/course/:id/students',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return InstructorStudentProgressScreen(
            courseId: courseId,
            courseTitle: title,
          );
        },
      ),
      
      // Content management routes
      GoRoute(
        path: '/instructor/lms/course/:id/content',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          return InstructorCourseContentScreen(courseId: courseId);
        },
      ),
      
      // Analytics routes
      GoRoute(
        path: '/instructor/lms/course/:id/analytics',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return InstructorCourseAnalyticsScreen(
            courseId: courseId,
            courseTitle: title,
          );
        },
      ),
      
      // Stream/Announcements routes
      GoRoute(
        path: '/instructor/lms/course/:id/stream',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Course';
          return InstructorCourseStreamScreen(
            courseId: courseId,
            courseTitle: title,
          );
        },
      ),
      
      // Course detail page
      GoRoute(
        path: '/instructor/lms/course/:id',
        builder: (context, state) {
          final courseId = state.pathParameters['id']!;
          // This will need the course data - for now redirect to content
          return InstructorCourseContentScreen(courseId: courseId);
        },
      ),
    ],
  );
});
