// Builds the booking screen from the real record that crashes it.
//
// A patient tapping Book Appointment for Dr Samiullah Mahar got "Null check
// operator used on a null value" and a blank screen. The record is unusual in
// several ways at once — no nested user object, a zero fee, empty weeklySlots,
// and an availableTime written with an en dash ("10:00 AM – 10:00 PM") rather
// than a hyphen — so this pins the exact shape rather than a tidied-up one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/screens/book_appointment.dart';

/// The doctor exactly as /api/doctors/<id> returns them.
Map<String, dynamic> get _liveDoctorJson => {
      'id': '6a931e4c1d5c7d71827bf4a3',
      '_id': '6a931e4c1d5c7d71827bf4a3',
      'name': 'Dr Samiullah Mahar',
      'email': '',
      'phoneNumber': '',
      'role': 'doctor',
      'profilePicture': null,
      'specialization': 'DENTAL SURGEON & AESTHETIC PHYSICIAN',
      'experience': 2,
      'licenseNumber': '941410-02-D',
      'consultationFee': 0,
      'availableDays': ['Mon', 'Tue', 'Wed', 'Thu', 'Sat', 'Fri'],
      // En dash, not a hyphen — this is what the record actually holds.
      'availableTime': '10:00 AM – 10:00 PM',
      'weeklySlots': <String, dynamic>{},
      'slotDuration': 15,
      'rating': 0,
      'totalReviews': 0,
      'clinicName': null,
      'clinicAddress': null,
      'clinicId': null,
      // No nested 'user' object at all.
    };

void main() {
  testWidgets('the booking screen builds for a doctor with no nested user',
      (tester) async {
    final doctor = Doctor.fromJson(_liveDoctorJson);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: BookAppointmentScreen(doctor: doctor)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Tapping Book Appointment for this doctor showed "Null check '
            'operator used on a null value" instead of the booking form.');
  });

  test('an en dash in availableTime still yields a usable range', () {
    final doctor = Doctor.fromJson(_liveDoctorJson);
    // Whatever the separator, the parsed start must not come back as the
    // whole string — that is what left the screen with no slots to offer.
    final start = doctor.availableTime?.start ?? '';
    expect(start.contains('–'), isFalse,
        reason: 'The en dash was not treated as a separator, so "start" still '
            'holds the entire "10:00 AM – 10:00 PM" string.');
  });
}
