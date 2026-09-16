// Guards the consultation identity rules.
//
// These exist because of a real incident: a patient rang the doctor and the
// doctor's phone showed "Unknown", with the call header reading "Consultation
// with Unknown". The name came from GoRouter's `extra`, which is empty when
// the screen is opened by URL or the page is reloaded mid-call.
//
// If someone later makes the name depend on `extra` again, or lets an empty
// name through, these tests fail instead of a live consultation failing.

import 'package:flutter_test/flutter_test.dart';
import 'package:icare/utils/consultation_identity.dart';

void main() {
  group('resolveMyName', () {
    test('uses the name the screen was given', () {
      expect(
        resolveMyName(isDoctor: false, passedInName: 'Wajahat'),
        'Wajahat',
      );
    });

    test('falls back to the consultation record when extra is missing', () {
      // This is the reload / opened-by-URL case that caused the incident.
      expect(
        resolveMyName(
          isDoctor: false,
          passedInName: null,
          nameFromRecord: 'Wajahat',
        ),
        'Wajahat',
      );
      expect(
        resolveMyName(
          isDoctor: false,
          passedInName: '',
          nameFromRecord: 'Wajahat',
        ),
        'Wajahat',
      );
    });

    test('treats a whitespace-only name as missing', () {
      expect(
        resolveMyName(
          isDoctor: true,
          passedInName: '   ',
          nameFromRecord: 'Kamran',
        ),
        'Kamran',
      );
    });

    test('never returns an empty name, whatever is missing', () {
      // An empty name is precisely what reached the other side as "Unknown",
      // so there must always be something to show.
      for (final isDoctor in [true, false]) {
        final name = resolveMyName(
          isDoctor: isDoctor,
          passedInName: null,
          nameFromRecord: null,
        );
        expect(name.trim(), isNotEmpty);
        expect(name.toLowerCase(), isNot(contains('unknown')));
      }
    });

    test('names the role when nothing else is known', () {
      expect(resolveMyName(isDoctor: true), 'Doctor');
      expect(resolveMyName(isDoctor: false), 'Patient');
    });

    test('trims surrounding whitespace', () {
      expect(
        resolveMyName(isDoctor: false, passedInName: '  Wajahat  '),
        'Wajahat',
      );
    });
  });

  group('resolveCallerDisplayName', () {
    test('a doctor rings with their title', () {
      expect(
        resolveCallerDisplayName(isDoctor: true, myName: 'Kamran'),
        'Dr. Kamran',
      );
    });

    test('a title already there is not doubled', () {
      expect(
        resolveCallerDisplayName(isDoctor: true, myName: 'Dr. Kamran'),
        'Dr. Kamran',
      );
      expect(
        resolveCallerDisplayName(isDoctor: true, myName: 'dr. Kamran'),
        'dr. Kamran',
      );
    });

    test('a patient rings under their own name', () {
      expect(
        resolveCallerDisplayName(isDoctor: false, myName: 'Wajahat'),
        'Wajahat',
      );
    });

    test('a doctor with no name still rings as a doctor, not as Unknown', () {
      final shown = resolveCallerDisplayName(
        isDoctor: true,
        myName: resolveMyName(isDoctor: true),
      );
      expect(shown, 'Dr. Doctor');
      expect(shown.toLowerCase(), isNot(contains('unknown')));
    });
  });
}
