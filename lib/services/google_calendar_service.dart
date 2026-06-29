import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

// ── Replace this with your real Web Client ID from Google Cloud Console ──────
// Steps: console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0
// Authorized origins: https://icare-app-ten.vercel.app  and  http://localhost
const String _kGoogleClientId =
    '564788374793-1eptqsl65ohkvsquqhc4qnhlia592v2f.apps.googleusercontent.com';

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
      if (account == null) return false;
      // On web, GIS auth flow gives id_token only — explicitly request
      // the authorization code/token flow to get an accessToken for APIs
      if (kIsWeb) {
        final granted = await _googleSignIn.requestScopes([_kCalendarScope]);
        return granted;
      }
      return true;
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
      // On web, ensure Calendar scope is authorized (triggers token flow)
      if (kIsWeb) {
        final hasScope = await _googleSignIn.canAccessScopes([_kCalendarScope]);
        if (!hasScope) {
          final granted = await _googleSignIn.requestScopes([_kCalendarScope]);
          if (!granted) return null;
        }
      }
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
      // Use UTC ISO string — Google Calendar converts to user's local timezone
      final startStr = scheduledFor.toUtc().toIso8601String();
      final endStr = endTime.toUtc().toIso8601String();
      final event = {
        'summary': title,
        'description': description.isNotEmpty ? description : 'iCare Reminder',
        'start': {'dateTime': startStr},
        'end': {'dateTime': endStr},
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 15},
          ],
        },
      };

      final dio = Dio();
      final resp = await dio.post(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        data: event,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'application/json',
        ),
      );
      return resp.statusCode != null && resp.statusCode! < 300;
    } catch (e) {
      debugPrint('GoogleCalendarService addEvent error: $e');
      return false;
    }
  }

  Future<Map<String, int>> syncReminders(
      List<Map<String, dynamic>> reminders) async {
    int success = 0, failed = 0, skipped = 0;
    for (final r in reminders) {
      try {
        final scheduledStr = r['scheduledFor'] as String?;
        if (scheduledStr == null || scheduledStr.trim().isEmpty) {
          skipped++;
          continue;
        }
        DateTime dt;
        try {
          dt = DateTime.parse(scheduledStr);
        } catch (_) {
          skipped++;
          continue;
        }
        final ok = await addEvent(
          title: r['title'] as String? ?? 'iCare Reminder',
          description: r['instructions'] as String? ?? '',
          scheduledFor: dt,
        );
        if (ok) success++; else failed++;
        // Small delay to avoid Google Calendar API rate limiting
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (_) {
        failed++;
      }
    }
    return {'success': success, 'failed': failed, 'skipped': skipped};
  }
}
