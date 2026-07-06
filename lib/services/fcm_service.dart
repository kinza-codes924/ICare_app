import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/connect_now_events.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background FCM message: ${message.messageId}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging get fcm => _fcm ??= FirebaseMessaging.instance;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'icare_high_importance',
    'ICare Notifications',
    description: 'Notifications for appointments, messages and updates',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    // Setup local notifications for foreground display
    await _setupLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    await getAndSaveToken();
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 Local notification tapped: ${details.payload}');
      },
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Tell FCM to show heads-up notifications on Android
    await fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground FCM: ${message.notification?.title} | type=${message.data['type']}');

    // Connect Now: trigger immediate dialog on doctor side — no polling delay
    if (message.data['type'] == 'connect_now_request') {
      debugPrint('🚨 [ConnectNow] FCM arrived → triggering immediate poll');
      ConnectNowEvents.trigger(Map<String, dynamic>.from(message.data));
      return; // Don't show a banner — the dialog will pop up from the listener
    }

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['type'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: type=${message.data['type']}');
    // Connect Now tap (app in background): trigger immediate poll
    if (message.data['type'] == 'connect_now_request') {
      debugPrint('🚨 [ConnectNow] Notification tapped → triggering immediate poll');
      ConnectNowEvents.trigger(Map<String, dynamic>.from(message.data));
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      return await fcm.getToken();
    } catch (e) {
      debugPrint('⚠️ Could not get FCM token: $e');
      return null;
    }
  }

  // Call this after login to send token to your backend
  Future<String?> getAndSaveToken() async {
    final token = await getToken();
    if (token != null) {
      debugPrint('📱 Sending FCM token to backend...');
      try {
        final apiService = ApiService();
        await apiService.post('/users/fcm-token', {'fcmToken': token});
        debugPrint('✅ FCM token saved to backend');
      } catch (e) {
        debugPrint('⚠️ Could not save FCM token to backend: $e');
      }
    }
    return token;
  }
}
