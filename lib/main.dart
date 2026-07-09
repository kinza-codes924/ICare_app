import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:icare/navigators/app_router.dart';
import 'package:icare/utils/theme.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:icare/firebase_options.dart';
import 'package:icare/services/fcm_service.dart';
import 'package:icare/widgets/incoming_call_listener.dart';
import 'package:icare/widgets/doctor_connect_now_listener.dart';
import 'package:icare/widgets/appointment_reminder_listener.dart';
import 'package:icare/widgets/reminder_banner_listener.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Catch every unhandled async error (FormatException from bad JSON, etc.)
  // so it never surfaces as "Uncaught (in promise)" in the browser console.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 Unhandled error: $error');
    return true; // mark as handled — suppresses browser-level uncaught promise
  };

  // Use path-based URLs (no # hash) so /home, /login etc. work directly.
  usePathUrlStrategy();

  // Web: Firebase initialized for Phone Auth (requires web appId in firebase_options.dart).
  // Mobile: uses google-services.json — no options argument needed.
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } else {
      await Firebase.initializeApp();
      // Do NOT await FCM init: on iOS it waits for an APNS token, which never
      // arrives until the Push Notifications capability is added — awaiting it
      // here blocks runApp() and leaves the app on a blank screen.
      unawaited(FcmService().init().catchError((Object e) {
        debugPrint('FCM init failed (non-fatal): $e');
      }));
    }
  } catch (e) {
    // Graceful fallback if firebase_options.dart still has placeholder appId.
    debugPrint('Firebase init warning: $e');
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ur')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ScallingConfig().init(context);
    final router = ref.watch(routerProvider);

    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'iCare Virtual Hospital',
          theme: AppTheme.mainTheme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            ScallingConfig().init(context);
            return FlutterSmartDialog.init()(
              context,
              IncomingCallListener(
                child: DoctorConnectNowListener(
                  child: ReminderBannerListener(
                  child: AppointmentReminderListener(
                    child: ResponsiveBreakpoints.builder(
                      child: child ?? const SizedBox(),
                      breakpoints: const [
                        Breakpoint(start: 0, end: 600, name: MOBILE),
                        Breakpoint(start: 600, end: 900, name: TABLET),
                        Breakpoint(start: 901, end: 1920, name: DESKTOP),
                        Breakpoint(start: 1921, end: double.infinity, name: '4K'),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
