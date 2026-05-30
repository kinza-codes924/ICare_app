import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

// ── Replace this with your real Web Client ID from Google Cloud Console ──────
// Steps: console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0
// Authorized origins: https://icare-app-ten.vercel.app  and  http://localhost
const String _kGoogleClientId =
    '1076307742101-avj49igc93qipdcnqbqsk3u14gdcb2oh.apps.googleusercontent.com';

const String _kCalendarScope = 'https://www.googleapis.com/auth/calendar';

class GoogleCalendarService {
  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _kGoogleClientId : null,
    scopes: [_kCalendarScope],
  );

  bool get isSignedIn => _googleSignIn.currentUser != null;
  String? get userEmail => _googleSignIn.currentUser?.email;

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      debugPrint('GoogleCalendarService signIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<String?> _accessToken() async {
    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<bool> addEvent({
    required String title,
    required String description,
    required DateTime scheduledFor,
  }) async {
    try {
      final token = await _accessToken();
      if (token == null) return false;

      final endTime = scheduledFor.add(const Duration(minutes: 30));
      final event = {
        'summary': title,
        'description': description.isNotEmpty ? description : 'iCare Reminder',
        'start': {
          'dateTime': scheduledFor.toIso8601String(),
          'timeZone': 'Asia/Karachi',
        },
        'end': {
          'dateTime': endTime.toIso8601String(),
          'timeZone': 'Asia/Karachi',
        },
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 15},
            {'method': 'email', 'minutes': 30},
          ],
        },
        'source': {
          'title': 'iCare App',
          'url': 'https://icare-app-ten.vercel.app',
        },
      };

      final dio = Dio();
      await dio.post(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        data: event,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'application/json',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('GoogleCalendarService addEvent error: $e');
      return false;
    }
  }

  Future<Map<String, int>> syncReminders(
      List<Map<String, dynamic>> reminders) async {
    int success = 0, failed = 0;
    for (final r in reminders) {
      try {
        final scheduledStr = r['scheduledFor'] as String?;
        if (scheduledStr == null || scheduledStr.isEmpty) {
          failed++;
          continue;
        }
        final dt = DateTime.parse(scheduledStr);
        final ok = await addEvent(
          title: r['title'] as String? ?? 'iCare Reminder',
          description: r['instructions'] as String? ?? '',
          scheduledFor: dt,
        );
        if (ok) success++; else failed++;
      } catch (_) {
        failed++;
      }
    }
    return {'success': success, 'failed': failed};
  }
}
