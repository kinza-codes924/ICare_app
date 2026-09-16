// Guards the rule that leaving a call must not end the consultation.
//
// The incident: a patient pressed Back during a live call and the session
// closed itself. The video screen had registered a `beforeunload` handler
// that marked the appointment 'completed' — written for the browser tab being
// closed, but beforeunload also fires on every reload and every navigation
// away. Both sides lost the Rejoin card while the call was still running.
//
// This reads the source rather than running the screen, because the danger is
// not a value at runtime: it is someone adding that handler back, for the same
// reasonable-sounding motive as last time. A screen test would not catch it
// until a browser was driven through a real call.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Strip // and /* */ comments so the explanation of the bug does not itself
/// look like the bug.
String _withoutComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

void main() {
  group('leaving a call does not end the consultation', () {
    late String videoCallSource;

    setUpAll(() {
      videoCallSource =
          _withoutComments(File('lib/screens/video_call_web.dart').readAsStringSync());
    });

    test('the video screen registers no beforeunload handler', () {
      expect(
        videoCallSource.contains('beforeunload'),
        isFalse,
        reason: 'beforeunload fires on reload and on navigating away, not only '
            'when the tab closes. A handler here ended live consultations when '
            'the user merely pressed Back. If a session genuinely needs '
            'settling, do it server-side when the next one starts.',
      );
    });

    test('completing an appointment only follows a confirmed End', () {
      // Marking 'completed' is allowed — but only where the user pressed End
      // and confirmed it. The fault was doing it from a browser event, with
      // nobody asking. So for each place that completes an appointment, look
      // back for the confirmation that should precede it.
      final completions = RegExp(
        r"status:\s*'completed'",
      ).allMatches(videoCallSource).toList();

      expect(completions, isNotEmpty,
          reason: 'The explicit End Consultation path should still exist.');

      for (final m in completions) {
        final before = videoCallSource.substring(0, m.start);
        final confirmed = before.contains('confirm != true') ||
            before.contains("Text('End Consultation')");
        expect(
          confirmed,
          isTrue,
          reason: 'An appointment is completed here without a confirmed End '
              'in front of it. Ending a consultation is something a person '
              'asks for; doing it from a lifecycle or browser event is what '
              'removed the Rejoin card mid-call.',
        );
      }
    });

    test('no browser lifecycle event ends a session', () {
      for (final event in ['beforeunload', 'unload', 'pagehide', 'visibilitychange']) {
        expect(
          videoCallSource.contains(event),
          isFalse,
          reason: 'A "$event" handler here would fire on reload and on '
              'navigating away, not only when the user is finished.',
        );
      }
    });

    test('the chat screen still offers leaving without ending', () {
      final chat = File('lib/screens/consultation_chat_screen_v2.dart')
          .readAsStringSync();
      expect(
        chat.contains('Leave (keep session)'),
        isTrue,
        reason: 'Stepping away and coming back is normal mid-consultation; '
            'the explicit choice is what stops anyone guessing on the user\'s '
            'behalf again.',
      );
    });
  });
}
