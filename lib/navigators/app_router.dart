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
import 'package:icare/screens/certificate_verification_page.dart';
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
const _publicPaths = ['/home', '/login', '/signup', '/work-with-us', '/splash', '/lms/catalog', '/verify'];

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

      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final path = state.matchedLocation;
      final isPublic = _publicPaths.contains(path);

      // Not logged in trying to access protected route → home.
      if (!isLoggedIn && !isPublic) return '/home';

      // Logged in trying to visit public route → dashboard.
      // /lms/catalog is accessible to both logged-in and logged-out users.
      if (isLoggedIn && isPublic && path != '/splash' && path != '/lms/catalog') return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/home', builder: (_, _) => const PublicHome()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/work-with-us', builder: (_, _) => const WorkWithUsSignup()),
      GoRoute(path: '/dashboard', builder: (_, _) => const TabsScreen()),
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
        path: '/verify',
        builder: (_, state) {
          final code = state.uri.queryParameters['code'];
          return CertificateVerificationPage(initialCode: code);
        },
      ),
      GoRoute(path: '/admin/verifications', builder: (_, _) => const AdminVerificationPanel()),
      
      // Instructor LMS Routes
      GoRoute(path: '/instructor/lms', builder: (_, _) => const InstructorLmsDashboard()),
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
