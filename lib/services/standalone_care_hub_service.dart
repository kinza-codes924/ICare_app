
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/appointment_detail.dart';
import '../utils/role_ui.dart';
import '../utils/shared_pref.dart';

class StandaloneCareHubService {
  StandaloneCareHubService._internal();
  static final StandaloneCareHubService _instance = StandaloneCareHubService._internal();
  factory StandaloneCareHubService() => _instance;

  static const String _dbKey = 'standalone_care_hub_db';
  static const String _activeTokenKey = 'standalone_active_token';

  final Uuid _uuid = const Uuid();
  final SharedPref _sharedPref = SharedPref();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _loadDb() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_dbKey);
    if (raw == null || raw.isEmpty) {
      final seeded = _seedDb();
      await prefs.setString(_dbKey, jsonEncode(seeded));
      return seeded;
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveDb(Map<String, dynamic> db) async {
    final prefs = await _prefs();
    await prefs.setString(_dbKey, jsonEncode(db));
  }

  Future<void> ensureSeeded() async {
    await _loadDb();
  }

  List<Map<String, dynamic>> _listOfMaps(Map<String, dynamic> db, String key) {
    final list = (db[key] as List?) ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Map<String, dynamic>? _findById(List<Map<String, dynamic>> items, String id) {
    for (final item in items) {
      if (item['_id'] == id) return item;
    }
    return null;
  }

  String _standaloneTokenForUser(String userId) => 'standalone-token-$userId';

  Future<void> _setActiveToken(String token) async {
    final prefs = await _prefs();
    await prefs.setString(_activeTokenKey, token);
  }

  Future<String?> _getActiveToken() async {
    final prefs = await _prefs();
    return prefs.getString(_activeTokenKey);
  }

  String? _userIdFromToken(String? token) {
    if (token == null) return null;
    if (token.startsWith('standalone-token-')) {
      return token.replaceFirst('standalone-token-', '');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getStoredUserMap() async {
    final storedUser = await _sharedPref.getUserData();
    if (storedUser == null) return null;
    return storedUser.toJson();
  }

  Future<Map<String, dynamic>?> _resolveCurrentUser({String? token}) async {
    final db = await _loadDb();
    final users = _listOfMaps(db, 'users');
    final providedToken = token ?? await _sharedPref.getToken() ?? await _getActiveToken();
    final standaloneUserId = _userIdFromToken(providedToken);
    if (standaloneUserId != null) {
      final found = _findById(users, standaloneUserId);
      if (found != null) return found;
    }

    final storedUser = await _getStoredUserMap();
    if (storedUser != null && (storedUser['_id']?.toString().isNotEmpty ?? false)) {
      final existing = _findById(users, storedUser['_id'].toString());
      if (existing != null) return existing;
      await _ensureExternalUserExists(storedUser);
      final refreshed = await _loadDb();
      return _findById(_listOfMaps(refreshed, 'users'), storedUser['_id'].toString());
    }
    return null;
  }

  Future<void> _ensureExternalUserExists(Map<String, dynamic> user) async {
    final db = await _loadDb();
    final users = _listOfMaps(db, 'users');
    if (_findById(users, user['_id']?.toString() ?? '') != null) {
      return;
    }

    final normalizedRole = normalizeRoleName(user['role']?.toString() ?? 'Patient');
    final newUser = {
      '_id': user['_id']?.toString() ?? _uuid.v4(),
      'name': user['name']?.toString() ?? 'User',
      'email': user['email']?.toString() ?? 'user@icare.demo',
      'phoneNumber': user['phoneNumber']?.toString() ?? '03000000000',
      'role': normalizedRole,
      'profilePicture': user['profilePicture'],
      'password': 'Pass@123',
      'createdAt': user['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    };

    users.add(newUser);
    db['users'] = users;

    if (normalizedRole == 'Doctor') {
      final doctors = _listOfMaps(db, 'doctors');
      doctors.add({
        '_id': 'doctor-profile-${newUser['_id']}',
        'user': _publicUser(newUser),
        'specialization': 'General Medicine',
        'consultationType': ['Video', 'Clinic'],
        'languages': ['English', 'Urdu'],
        'degrees': ['MBBS'],
        'experience': '5 years',
        'licenseNumber': 'PMDC-${newUser['_id']}',
        'clinicName': 'iCare Virtual Clinic',
        'clinicAddress': 'Pakistan',
        'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
        'availableTime': {'start': '09:00', 'end': '17:00'},
        'isApproved': false,
        'ratings': [4.6, 4.8],
        'reviews': ['Professional consultation', 'Very helpful'],
      });
      db['doctors'] = doctors;
    }

    await _saveDb(db);
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> user) {
    return {
      '_id': user['_id'],
      'name': user['name'],
      'email': user['email'],
      'phoneNumber': user['phoneNumber'],
      'role': normalizeRoleName(user['role']?.toString()),
      'profilePicture': user['profilePicture'],
      'createdAt': user['createdAt'],
    };
  }

  Future<void> _appendAuditEvent(Map<String, dynamic> db, {
    required String category,
    required String action,
    String severity = 'info',
    String? entityId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? actor,
  }) async {
    final events = _auditEvents(db);
    final resolvedActor = actor ?? await _resolveCurrentUser();
    events.insert(0, {
      '_id': _uuid.v4(),
      'category': category,
      'action': action,
      'severity': severity,
      'entityId': entityId,
      'actor': resolvedActor != null ? _publicUser(resolvedActor) : {'name': 'System', 'role': 'System'},
      'metadata': metadata ?? <String, dynamic>{},
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (events.length > 250) {
      events.removeRange(250, events.length);
    }
    db['auditEvents'] = events;
  }

  String _suggestReferralSpecialty(String diagnosis) {
    final value = diagnosis.toLowerCase();
    if (value.contains('heart') || value.contains('cardio') || value.contains('hypertension')) return 'Cardiology';
    if (value.contains('skin') || value.contains('derma')) return 'Dermatology';
    if (value.contains('preg') || value.contains('prenatal') || value.contains('gyne')) return 'Gynecology';
    if (value.contains('bone') || value.contains('joint') || value.contains('ortho')) return 'Orthopedics';
    if (value.contains('brain') || value.contains('neuro') || value.contains('stroke')) return 'Neurology';
    if (value.contains('lung') || value.contains('asthma') || value.contains('breath')) return 'Pulmonology';
    if (value.contains('sugar') || value.contains('diabetes') || value.contains('thyroid')) return 'Endocrinology';
    return 'General Medicine';
  }

  String _priorityForDiagnosis(String diagnosis) {
    final value = diagnosis.toLowerCase();
    if (value.contains('acute') || value.contains('urgent') || value.contains('critical')) return 'urgent';
    if (value.contains('hypertension') || value.contains('cardio') || value.contains('prenatal')) return 'high';
    return 'normal';
  }

  List<Map<String, dynamic>> _doctors(Map<String, dynamic> db) => _listOfMaps(db, 'doctors');
  List<Map<String, dynamic>> _labs(Map<String, dynamic> db) => _listOfMaps(db, 'labs');
  List<Map<String, dynamic>> _pharmacies(Map<String, dynamic> db) => _listOfMaps(db, 'pharmacies');
  List<Map<String, dynamic>> _appointments(Map<String, dynamic> db) => _listOfMaps(db, 'appointments');
  List<Map<String, dynamic>> _records(Map<String, dynamic> db) => _listOfMaps(db, 'medicalRecords');
  List<Map<String, dynamic>> _labBookings(Map<String, dynamic> db) => _listOfMaps(db, 'labBookings');
  List<Map<String, dynamic>> _orders(Map<String, dynamic> db) => _listOfMaps(db, 'pharmacyOrders');
  List<Map<String, dynamic>> _medicines(Map<String, dynamic> db) => _listOfMaps(db, 'medicines');
  List<Map<String, dynamic>> _courses(Map<String, dynamic> db) => _listOfMaps(db, 'courses');
  List<Map<String, dynamic>> _enrollments(Map<String, dynamic> db) => _listOfMaps(db, 'enrollments');
  List<Map<String, dynamic>> _referrals(Map<String, dynamic> db) => _listOfMaps(db, 'referrals');
  List<Map<String, dynamic>> _subscriptionPlans(Map<String, dynamic> db) => _listOfMaps(db, 'subscriptionPlans');
  List<Map<String, dynamic>> _patientSubscriptions(Map<String, dynamic> db) => _listOfMaps(db, 'patientSubscriptions');
  List<Map<String, dynamic>> _carePlans(Map<String, dynamic> db) => _listOfMaps(db, 'carePlans');
  List<Map<String, dynamic>> _auditEvents(Map<String, dynamic> db) => _listOfMaps(db, 'auditEvents');

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final db = await _loadDb();
    final users = _listOfMaps(db, 'users');

    Map<String, dynamic>? user;
    for (final candidate in users) {
      if ((candidate['email']?.toString().toLowerCase() ?? '') == email.toLowerCase() && (candidate['password']?.toString() ?? '') == password) {
        user = candidate;
        break;
      }
    }

    if (user == null) {
      return {
        'success': false,
        'message': 'Invalid email or password. Use one of the seeded demo accounts or create a patient/doctor account.',
      };
    }

    final token = _standaloneTokenForUser(user['_id'].toString());
    await _setActiveToken(token);
    await _appendAuditEvent(db,
      category: 'auth',
      action: 'User logged in',
      entityId: user['_id'].toString(),
      metadata: {'role': user['role']},
      severity: 'info',
      actor: user,
    );
    await _saveDb(db);
    return {
      'success': true,
      'data': {
        'token': token,
        'user': _publicUser(user),
      },
    };
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
  }) async {
    final db = await _loadDb();
    final users = _listOfMaps(db, 'users');

    for (final user in users) {
      if ((user['email']?.toString().toLowerCase() ?? '') == email.toLowerCase()) {
        return {'success': false, 'message': 'An account with this email already exists.'};
      }
    }

    final normalizedRole = normalizeRoleName(role);
    if (!(normalizedRole == 'Patient' || normalizedRole == 'Doctor')) {
      return {
        'success': false,
        'message': 'Only Patient and Doctor accounts can sign up publicly. Lab, Pharmacy and Instructor accounts are admin-managed.',
      };
    }

    final createdAt = DateTime.now().toIso8601String();
    final userId = _uuid.v4();
    final user = {
      '_id': userId,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber ?? '03000000000',
      'role': normalizedRole,
      'profilePicture': null,
      'password': password,
      'createdAt': createdAt,
    };

    users.add(user);
    db['users'] = users;

    if (normalizedRole == 'Doctor') {
      final doctors = _doctors(db);
      doctors.add({
        '_id': _uuid.v4(),
        'user': _publicUser(user),
        'specialization': 'General Medicine',
        'consultationType': ['Video Consultation'],
        'languages': ['English', 'Urdu'],
        'degrees': ['MBBS'],
        'experience': '0 years',
        'licenseNumber': 'PENDING-APPROVAL',
        'clinicName': 'Pending Approval',
        'clinicAddress': 'Pakistan',
        'availableDays': ['Monday', 'Tuesday', 'Wednesday'],
        'availableTime': {'start': '10:00', 'end': '16:00'},
        'isApproved': false,
        'ratings': <double>[],
        'reviews': <String>[],
      });
      db['doctors'] = doctors;
    }

    await _saveDb(db);
    final token = _standaloneTokenForUser(userId);
    await _setActiveToken(token);
    return {
      'success': true,
      'data': {
        'token': token,
        'user': _publicUser(user),
      },
    };
  }

  Future<Map<String, dynamic>> getUserProfile({String? token}) async {
    final user = await _resolveCurrentUser(token: token);
    if (user == null) {
      return {'success': false, 'message': 'No active standalone user found'};
    }
    return {'success': true, 'user': _publicUser(user)};
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String name,
    required String phoneNumber,
    String? profilePicture,
  }) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    if (currentUser == null) {
      return {'success': false, 'message': 'No active user'};
    }
    final users = _listOfMaps(db, 'users');
    for (final user in users) {
      if (user['_id'] == currentUser['_id']) {
        user['name'] = name;
        user['phoneNumber'] = phoneNumber;
        user['profilePicture'] = profilePicture;
      }
    }
    db['users'] = users;
    _syncNestedUserReferences(db, currentUser['_id'].toString(), {
      'name': name,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
    });
    await _saveDb(db);
    final updatedUser = _findById(_listOfMaps(db, 'users'), currentUser['_id'].toString())!;
    return {'success': true, 'user': _publicUser(updatedUser)};
  }

  void _syncNestedUserReferences(Map<String, dynamic> db, String userId, Map<String, dynamic> updates) {
    final collections = ['doctors', 'labs', 'pharmacies', 'appointments', 'medicalRecords', 'labBookings', 'pharmacyOrders', 'referrals', 'subscriptionPlans', 'patientSubscriptions', 'carePlans', 'auditEvents'];
    for (final collectionKey in collections) {
      final collection = _listOfMaps(db, collectionKey);
      for (final item in collection) {
        if (item['user'] is Map && item['user']['_id'] == userId) {
          (item['user'] as Map<String, dynamic>).addAll(updates);
          item['user']['role'] = normalizeRoleName(item['user']['role']?.toString());
        }
        if (item['doctor'] is Map && item['doctor']['_id'] == userId) {
          (item['doctor'] as Map<String, dynamic>).addAll(updates);
        }
        if (item['patient'] is Map && item['patient']['_id'] == userId) {
          (item['patient'] as Map<String, dynamic>).addAll(updates);
        }
      }
      db[collectionKey] = collection;
    }
  }

  Future<List<dynamic>> getAllDoctors() async {
    final db = await _loadDb();
    return _doctors(db);
  }

  Future<Map<String, dynamic>> getDoctorById(String doctorId) async {
    final db = await _loadDb();
    final doctor = _findById(_doctors(db), doctorId);
    if (doctor == null) throw Exception('Doctor not found');
    return doctor;
  }

  Future<Map<String, dynamic>> updateDoctorProfile(Map<String, dynamic> data) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final doctors = _doctors(db);
    for (final doctor in doctors) {
      final user = Map<String, dynamic>.from(doctor['user'] as Map);
      if (user['_id'] == currentUser?['_id']) {
        doctor.addAll(data);
      }
    }
    db['doctors'] = doctors;
    await _saveDb(db);
    return {'success': true, 'message': 'Doctor profile updated'};
  }

  Future<Map<String, dynamic>> addDoctorReview({required String doctorId, required double rating, String? review}) async {
    final db = await _loadDb();
    final doctors = _doctors(db);
    for (final doctor in doctors) {
      if (doctor['_id'] == doctorId) {
        final ratings = List<dynamic>.from(doctor['ratings'] as List? ?? []);
        ratings.add(rating);
        doctor['ratings'] = ratings;
        if (review != null && review.isNotEmpty) {
          final reviews = List<dynamic>.from(doctor['reviews'] as List? ?? []);
          reviews.add(review);
          doctor['reviews'] = reviews;
        }
      }
    }
    db['doctors'] = doctors;
    await _saveDb(db);
    return {'success': true, 'doctor': _findById(doctors, doctorId)};
  }

  Future<Map<String, dynamic>> filterDoctors({String? specialization, String? consultationType, String? language, double? minRating}) async {
    final doctors = List<Map<String, dynamic>>.from(await getAllDoctors());
    final filtered = doctors.where((doctor) {
      final ratings = List<dynamic>.from(doctor['ratings'] as List? ?? []);
      final avg = ratings.isEmpty ? 0.0 : ratings.map((e) => (e as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
      final specializationsMatch = specialization == null || (doctor['specialization']?.toString().toLowerCase().contains(specialization.toLowerCase()) ?? false);
      final consultationMatch = consultationType == null || List<dynamic>.from(doctor['consultationType'] as List? ?? []).map((e) => e.toString().toLowerCase()).contains(consultationType.toLowerCase());
      final languageMatch = language == null || List<dynamic>.from(doctor['languages'] as List? ?? []).map((e) => e.toString().toLowerCase()).contains(language.toLowerCase());
      final ratingMatch = minRating == null || avg >= minRating;
      return specializationsMatch && consultationMatch && languageMatch && ratingMatch;
    }).toList();
    return {'success': true, 'doctors': filtered};
  }

  Future<Map<String, dynamic>> updateAvailability({required List<String> availableDays, required Map<String, String> availableTime, List<String>? unavailableDates}) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final doctors = _doctors(db);
    for (final doctor in doctors) {
      final user = Map<String, dynamic>.from(doctor['user'] as Map);
      if (user['_id'] == currentUser?['_id']) {
        doctor['availableDays'] = availableDays;
        doctor['availableTime'] = availableTime;
        if (unavailableDates != null) doctor['unavailableDates'] = unavailableDates;
      }
    }
    db['doctors'] = doctors;
    await _saveDb(db);
    return {'success': true, 'message': 'Availability updated'};
  }

  Future<Map<String, dynamic>> getAvailability() async {
    final currentUser = await _resolveCurrentUser();
    final doctors = await getAllDoctors();
    for (final doctor in doctors) {
      final user = Map<String, dynamic>.from(doctor['user'] as Map);
      if (user['_id'] == currentUser?['_id']) {
        return {'success': true, 'availability': {'availableDays': doctor['availableDays'], 'availableTime': doctor['availableTime']}};
      }
    }
    return {'success': false, 'message': 'Availability not found'};
  }

  Future<Map<String, dynamic>> bookAppointment({required String doctorId, required DateTime date, required String timeSlot, String? reason}) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final doctor = _findById(_doctors(db), doctorId);
    if (currentUser == null || doctor == null) {
      return {'success': false, 'message': 'Unable to create appointment'};
    }
    final appointmentJson = {
      '_id': _uuid.v4(),
      'doctor': Map<String, dynamic>.from(doctor['user'] as Map),
      'patient': _publicUser(currentUser),
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
      'reason': reason,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final appointments = _appointments(db);
    appointments.add(appointmentJson);
    db['appointments'] = appointments;
    await _saveDb(db);
    return {
      'success': true,
      'message': 'Appointment booked successfully',
      'appointment': Appointment.fromJson(appointmentJson),
    };
  }

  Future<Map<String, dynamic>> getMyAppointmentsDetailed() async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    if (currentUser == null) {
      return {'success': false, 'message': 'No active user', 'appointments': <AppointmentDetail>[]};
    }
    final role = normalizeRoleName(currentUser['role']?.toString());
    final appointments = _appointments(db).where((appointment) {
      if (role == 'Doctor') {
        return appointment['doctor'] is Map && appointment['doctor']['_id'] == currentUser['_id'];
      }
      return appointment['patient'] is Map && appointment['patient']['_id'] == currentUser['_id'];
    }).toList();
    appointments.sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return {
      'success': true,
      'appointments': appointments.map((e) => AppointmentDetail.fromJson(e)).toList(),
      'count': appointments.length,
    };
  }

  Future<Map<String, dynamic>> updateAppointmentStatus({required String appointmentId, required String status}) async {
    final db = await _loadDb();
    final appointments = _appointments(db);
    for (final appointment in appointments) {
      if (appointment['_id'] == appointmentId) {
        appointment['status'] = status;
        appointment['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    db['appointments'] = appointments;
    await _appendAuditEvent(db,
      category: 'appointment',
      action: 'Appointment status changed to $status',
      entityId: appointmentId,
      metadata: {'status': status},
      severity: status == 'cancelled' ? 'medium' : 'info',
    );
    await _saveDb(db);
    return {'success': true, 'message': 'Status updated successfully'};
  }

  Future<Map<String, dynamic>> createMedicalRecord(Map<String, dynamic> data) async {
    final db = await _loadDb();
    final currentDoctor = await _resolveCurrentUser();
    final patientId = data['patientId']?.toString() ?? '';
    final patient = _findById(_listOfMaps(db, 'users'), patientId);
    if (currentDoctor == null || patient == null) {
      return {'success': false, 'message': 'Unable to create medical record'};
    }

    final prescription = List<Map<String, dynamic>>.from((data['prescription'] as List? ?? []).map((e) {
      final item = Map<String, dynamic>.from(e as Map);
      return {
        'name': item['medicineName'] ?? item['name'] ?? 'Medicine',
        'dosage': item['dosage'] ?? '',
        'frequency': item['frequency'] ?? '',
        'duration': item['duration'] ?? '',
        'instructions': item['instructions'] ?? '',
      };
    }));

    final diagnosis = data['diagnosis']?.toString() ?? 'General Consultation';
    final notes = data['notes']?.toString() ?? '';
    final symptoms = data['symptoms']?.toString() ?? '';
    final followUpDate = data['followUpDate']?.toString();
    final labTests = List<String>.from((data['labTests'] as List? ?? []).map((e) => e.toString()));

    final recommendedPrograms = _matchProgramsForDiagnosis(db, diagnosis);

    final record = {
      '_id': _uuid.v4(),
      'patient': _publicUser(patient),
      'doctor': _publicUser(currentDoctor),
      'appointmentId': data['appointmentId'],
      'diagnosis': diagnosis,
      'symptoms': symptoms,
      'notes': notes,
      'vitalSigns': data['vitalSigns'] ?? {},
      'prescription': prescription,
      'labTests': labTests,
      'assignedPrograms': recommendedPrograms,
      'followUpDate': followUpDate,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final records = _records(db);
    records.add(record);
    db['medicalRecords'] = records;

    if (prescription.isNotEmpty) {
      final pharmacies = _pharmacies(db);
      final targetPharmacy = pharmacies.isNotEmpty ? pharmacies.first : null;
      if (targetPharmacy != null) {
        final items = prescription.map((item) => {
          'productName': item['name'],
          'quantity': 1,
          'price': 650,
        }).toList();
        final totalAmount = items.fold<double>(0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));
        final orders = _orders(db);
        orders.add({
          '_id': _uuid.v4(),
          'orderNumber': 'RX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'pharmacyId': targetPharmacy['_id'],
          'patient': _publicUser(patient),
          'doctor': _publicUser(currentDoctor),
          'items': items,
          'recordId': record['_id'],
          'status': 'pending',
          'totalAmount': totalAmount,
          'deliveryOption': 'delivery',
          'address': 'Patient delivery address',
          'createdAt': DateTime.now().toIso8601String(),
        });
        db['pharmacyOrders'] = orders;
      }
    }

    if (labTests.isNotEmpty) {
      final labs = _labs(db);
      final targetLab = labs.isNotEmpty ? labs.first : null;
      if (targetLab != null) {
        final bookings = _labBookings(db);
        for (final test in labTests) {
          bookings.add({
            '_id': _uuid.v4(),
            'labId': targetLab['_id'],
            'labName': targetLab['labName'] ?? targetLab['name'] ?? 'Laboratory',
            'patient': _publicUser(patient),
            'doctor': _publicUser(currentDoctor),
            'testType': test,
            'date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            'status': 'pending',
            'price': 1800,
            'doctorInstructions': notes,
            'diagnosisNote': diagnosis,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
        db['labBookings'] = bookings;
      }
    }

    if (recommendedPrograms.isNotEmpty) {
      final enrollments = _enrollments(db);
      for (final course in recommendedPrograms) {
        final alreadyAssigned = enrollments.any((enrollment) => enrollment['userId'] == patient['_id'] && enrollment['courseId'] == course['_id']);
        if (!alreadyAssigned) {
          enrollments.add({
            '_id': _uuid.v4(),
            'userId': patient['_id'],
            'courseId': course['_id'],
            'course': course,
            'status': 'active',
            'progress': {'completedVideos': 0, 'totalVideos': course['totalUnits'] ?? 8, 'percent': 0},
            'assignedByDoctor': _publicUser(currentDoctor),
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }
      db['enrollments'] = enrollments;
    }

    final carePlans = _carePlans(db);
    carePlans.add({
      '_id': _uuid.v4(),
      'patientId': patient['_id'],
      'recordId': record['_id'],
      'doctor': _publicUser(currentDoctor),
      'title': '${diagnosis.split(' ').take(4).join(' ')} Care Plan',
      'status': 'active',
      'priority': _priorityForDiagnosis(diagnosis),
      'programs': recommendedPrograms.map((e) => {'_id': e['_id'], 'title': e['title'] ?? e['name']}).toList(),
      'followUpDate': followUpDate,
      'medicationCount': prescription.length,
      'labCount': labTests.length,
      'createdAt': DateTime.now().toIso8601String(),
    });
    db['carePlans'] = carePlans;

    final shouldRefer = (data['referToSpecialist'] == true) || (data['referralSpecialty']?.toString().isNotEmpty ?? false) || diagnosis.toLowerCase().contains('cardio') || diagnosis.toLowerCase().contains('hypertension');
    if (shouldRefer) {
      final doctors = _doctors(db);
      final specialty = data['referralSpecialty']?.toString() ?? _suggestReferralSpecialty(diagnosis);
      Map<String, dynamic>? targetDoctor;
      for (final doctor in doctors) {
        if ((doctor['specialization']?.toString() ?? '').toLowerCase().contains(specialty.toLowerCase()) && doctor['user'] is Map && doctor['user']['_id'] != currentDoctor['_id']) {
          targetDoctor = Map<String, dynamic>.from(doctor);
          break;
        }
      }
      if (targetDoctor != null) {
        final referrals = _referrals(db);
        referrals.add({
          '_id': _uuid.v4(),
          'patient': _publicUser(patient),
          'sourceDoctor': _publicUser(currentDoctor),
          'targetDoctor': targetDoctor['user'],
          'specialty': specialty,
          'reason': data['referralReason']?.toString() ?? diagnosis,
          'notes': notes,
          'priority': _priorityForDiagnosis(diagnosis),
          'status': 'pending',
          'recordId': record['_id'],
          'createdAt': DateTime.now().toIso8601String(),
        });
        db['referrals'] = referrals;
      }
    }

    await _appendAuditEvent(db,
      category: 'clinical',
      action: 'Medical record created',
      entityId: record['_id'],
      metadata: {
        'patientId': patient['_id'],
        'diagnosis': diagnosis,
        'prescriptions': prescription.length,
        'labTests': labTests.length,
        'programs': recommendedPrograms.length,
      },
      severity: 'high',
      actor: currentDoctor,
    );

    await _saveDb(db);
    return {'success': true, 'record': record};
  }

  List<Map<String, dynamic>> _matchProgramsForDiagnosis(Map<String, dynamic> db, String diagnosis) {
    final normalized = diagnosis.toLowerCase();
    final courses = _courses(db).where((course) => course['audience'] == 'patient').toList();
    final matches = courses.where((course) {
      final tags = List<dynamic>.from(course['diagnosisTags'] as List? ?? []);
      return tags.any((tag) => normalized.contains(tag.toString().toLowerCase()));
    }).toList();
    if (matches.isNotEmpty) return matches.take(2).toList();
    return courses.take(1).toList();
  }

  Future<Map<String, dynamic>> getPatientRecords(String patientId) async {
    final records = (await _loadDb())['medicalRecords'] as List? ?? [];
    final filtered = records.where((record) => record['patient'] is Map && record['patient']['_id'] == patientId).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    filtered.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return {'success': true, 'records': filtered};
  }

  Future<Map<String, dynamic>> getDoctorRecords() async {
    final currentUser = await _resolveCurrentUser();
    final records = _records(await _loadDb()).where((record) => record['doctor'] is Map && record['doctor']['_id'] == currentUser?['_id']).toList();
    return {'success': true, 'records': records};
  }

  Future<Map<String, dynamic>> getRecordById(String recordId) async {
    final db = await _loadDb();
    final record = _findById(_records(db), recordId);
    if (record == null) return {'success': false, 'message': 'Record not found'};
    return {'success': true, 'record': record};
  }

  Future<Map<String, dynamic>> updateMedicalRecord(String recordId, Map<String, dynamic> data) async {
    final db = await _loadDb();
    final records = _records(db);
    for (final record in records) {
      if (record['_id'] == recordId) {
        record.addAll(data);
        record['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    db['medicalRecords'] = records;
    await _saveDb(db);
    return {'success': true, 'record': _findById(records, recordId)};
  }

  Future<List<dynamic>> getAllLaboratories() async {
    final db = await _loadDb();
    return _labs(db);
  }

  Future<Map<String, dynamic>> getLabById(String labId) async {
    final db = await _loadDb();
    final lab = _findById(_labs(db), labId);
    if (lab == null) throw Exception('Laboratory not found');
    return lab;
  }

  Future<Map<String, dynamic>> getLabProfile() async {
    final currentUser = await _resolveCurrentUser();
    final labs = await getAllLaboratories();
    for (final lab in labs) {
      if (lab['user'] is Map && lab['user']['_id'] == currentUser?['_id']) return Map<String, dynamic>.from(lab as Map);
    }
    return Map<String, dynamic>.from((labs.isNotEmpty ? labs.first : <String, dynamic>{}) as Map);
  }

  Future<Map<String, dynamic>> updateLabProfile(Map<String, dynamic> data) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final labs = _labs(db);
    for (final lab in labs) {
      if (lab['user'] is Map && lab['user']['_id'] == currentUser?['_id']) {
        lab.addAll(data);
      }
    }
    db['labs'] = labs;
    await _saveDb(db);
    return _findById(labs, (await getLabProfile())['_id']?.toString() ?? '') ?? (labs.isNotEmpty ? labs.first : {});
  }

  Future<Map<String, dynamic>> createLabBooking(String labId, Map<String, dynamic> data) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final lab = _findById(_labs(db), labId);
    if (currentUser == null || lab == null) throw Exception('Unable to create lab booking');
    final booking = {
      '_id': _uuid.v4(),
      'labId': labId,
      'labName': lab['labName'] ?? lab['name'] ?? 'Laboratory',
      'patient': _publicUser(currentUser),
      'doctor': data['doctor'] ?? _publicUser(currentUser),
      'testType': data['testType'] ?? data['name'] ?? 'Lab Test',
      'date': data['date'] ?? DateTime.now().toIso8601String(),
      'status': 'pending',
      'price': data['price'] ?? 1800,
      'doctorInstructions': data['doctorInstructions'],
      'diagnosisNote': data['diagnosisNote'],
      'createdAt': DateTime.now().toIso8601String(),
    };
    final bookings = _labBookings(db);
    bookings.add(booking);
    db['labBookings'] = bookings;
    await _saveDb(db);
    return booking;
  }

  Future<List<dynamic>> getLabBookings(String labId, {String? status}) async {
    final db = await _loadDb();
    var bookings = _labBookings(db).where((booking) => booking['labId'] == labId).toList();
    if (status != null) {
      bookings = bookings.where((booking) => booking['status'] == status).toList();
    }
    bookings.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return bookings;
  }

  Future<List<dynamic>> getMyLabBookings() async {
    final currentUser = await _resolveCurrentUser();
    final db = await _loadDb();
    return _labBookings(db).where((booking) => booking['patient'] is Map && booking['patient']['_id'] == currentUser?['_id']).toList();
  }

  Future<Map<String, dynamic>> updateLabBooking(String bookingId, Map<String, dynamic> data) async {
    final db = await _loadDb();
    final bookings = _labBookings(db);
    for (final booking in bookings) {
      if (booking['_id'] == bookingId) {
        booking.addAll(data);
        booking['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    db['labBookings'] = bookings;
    await _appendAuditEvent(db,
      category: 'laboratory',
      action: 'Lab request updated',
      entityId: bookingId,
      metadata: data,
      severity: (data['status']?.toString() ?? '').contains('completed') ? 'info' : 'medium',
    );
    await _saveDb(db);
    return _findById(bookings, bookingId) ?? {};
  }

  Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    final db = await _loadDb();
    final booking = _findById(_labBookings(db), bookingId);
    if (booking == null) throw Exception('Booking not found');
    return booking;
  }

  Future<Map<String, dynamic>> getLabDashboardStats(String labId) async {
    final bookings = await getLabBookings(labId);
    final totalBookings = bookings.length;
    final pendingBookings = bookings.where((b) => b['status'] == 'pending').length;
    final completedBookings = bookings.where((b) => b['status'] == 'completed').length;
    final todayBookings = bookings.where((b) {
      final date = DateTime.tryParse(b['date']?.toString() ?? '');
      if (date == null) return false;
      final now = DateTime.now();
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).length;
    return {
      'totalBookings': totalBookings,
      'pendingBookings': pendingBookings,
      'completedBookings': completedBookings,
      'todayBookings': todayBookings,
      'recentActivity': bookings.take(5).toList(),
    };
  }

  Future<String> uploadLabReport(String bookingId, String fileName) async {
    final reportUrl = 'standalone://reports/$fileName';
    await updateLabBooking(bookingId, {'status': 'completed', 'reportUrl': reportUrl});
    return reportUrl;
  }

  Future<List<dynamic>> getAllPharmacies() async {
    final db = await _loadDb();
    return _pharmacies(db);
  }

  Future<Map<String, dynamic>> getPharmacyProfile() async {
    final currentUser = await _resolveCurrentUser();
    final pharmacies = await getAllPharmacies();
    for (final pharmacy in pharmacies) {
      if (pharmacy['user'] is Map && pharmacy['user']['_id'] == currentUser?['_id']) return Map<String, dynamic>.from(pharmacy as Map);
    }
    return Map<String, dynamic>.from((pharmacies.isNotEmpty ? pharmacies.first : <String, dynamic>{}) as Map);
  }

  Future<Map<String, dynamic>> updatePharmacyProfile(Map<String, dynamic> data) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final pharmacies = _pharmacies(db);
    for (final pharmacy in pharmacies) {
      if (pharmacy['user'] is Map && pharmacy['user']['_id'] == currentUser?['_id']) {
        pharmacy.addAll(data);
      }
    }
    db['pharmacies'] = pharmacies;
    await _saveDb(db);
    return _findById(pharmacies, (await getPharmacyProfile())['_id']?.toString() ?? '') ?? (pharmacies.isNotEmpty ? pharmacies.first : {});
  }

  Future<Map<String, dynamic>> getPharmacyStats() async {
    final pharmacy = await getPharmacyProfile();
    final orders = await getPharmacyOrders();
    final medicines = await getMedicines();
    final totalOrders = orders.length;
    final pendingOrders = orders.where((o) => o['status'] == 'pending').length;
    final completedOrders = orders.where((o) => o['status'] == 'completed').length;
    final totalProducts = medicines.length;
    final lowStock = medicines.where((m) => ((m['quantity'] ?? 0) as num).toInt() < 30).length;
    final revenue = orders.where((o) => o['status'] == 'completed').fold<double>(0.0, (sum, o) => sum + ((o['totalAmount'] as num?)?.toDouble() ?? 0.0));
    return {
      'pharmacyId': pharmacy['_id'],
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'completedOrders': completedOrders,
      'totalProducts': totalProducts,
      'lowStock': lowStock,
      'revenue': revenue.toInt(),
    };
  }

  Future<List<dynamic>> getMedicines({String? category, String? search}) async {
    final db = await _loadDb();
    final pharmacy = await getPharmacyProfile();
    var medicines = _medicines(db).where((medicine) => medicine['pharmacyId'] == pharmacy['_id']).toList();
    if (category != null && category != 'All') {
      medicines = medicines.where((medicine) => medicine['category'] == category).toList();
    }
    if (search != null && search.isNotEmpty) {
      medicines = medicines.where((medicine) => (medicine['productName']?.toString().toLowerCase().contains(search.toLowerCase()) ?? false)).toList();
    }
    return medicines;
  }

  Future<Map<String, dynamic>> createMedicine(Map<String, dynamic> data) async {
    final db = await _loadDb();
    final pharmacy = await getPharmacyProfile();
    final medicine = {
      '_id': _uuid.v4(),
      'pharmacyId': pharmacy['_id'],
      'productName': data['productName'] ?? data['name'] ?? 'Medicine',
      'category': data['category'] ?? 'General',
      'quantity': data['quantity'] ?? data['stock'] ?? 0,
      'price': data['price'] ?? 0,
      'description': data['description'] ?? '',
      'expiry': data['expiry'] ?? DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      'lowStockThreshold': data['lowStockThreshold'] ?? 20,
    };
    final medicines = _medicines(db);
    medicines.add(medicine);
    db['medicines'] = medicines;
    await _saveDb(db);
    return medicine;
  }

  Future<Map<String, dynamic>> updateMedicine(String id, Map<String, dynamic> data) async {
    final db = await _loadDb();
    final medicines = _medicines(db);
    for (final medicine in medicines) {
      if (medicine['_id'] == id) {
        medicine.addAll(data);
      }
    }
    db['medicines'] = medicines;
    await _saveDb(db);
    return _findById(medicines, id) ?? {};
  }

  Future<void> deleteMedicine(String id) async {
    final db = await _loadDb();
    final medicines = _medicines(db).where((medicine) => medicine['_id'] != id).toList();
    db['medicines'] = medicines;
    await _saveDb(db);
  }

  Future<List<dynamic>> getPharmacyOrders({String? status}) async {
    final db = await _loadDb();
    final pharmacy = await getPharmacyProfile();
    var orders = _orders(db).where((order) => order['pharmacyId'] == pharmacy['_id']).toList();
    if (status != null && status != 'all') {
      orders = orders.where((order) => order['status'] == status).toList();
    }
    orders.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return orders;
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final db = await _loadDb();
    final order = _findById(_orders(db), orderId);
    if (order == null) throw Exception('Order not found');
    return order;
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    final db = await _loadDb();
    final orders = _orders(db);
    for (final order in orders) {
      if (order['_id'] == orderId) {
        order['status'] = status;
        order['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    db['pharmacyOrders'] = orders;
    await _appendAuditEvent(db,
      category: 'pharmacy',
      action: 'Prescription order moved to $status',
      entityId: orderId,
      metadata: {'status': status},
      severity: status == 'rejected' ? 'medium' : 'info',
    );
    await _saveDb(db);
    return _findById(orders, orderId) ?? {};
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final medicines = await getMedicines();
    final orders = await getPharmacyOrders();
    final totalRevenue = orders.where((o) => o['status'] == 'completed').fold<double>(0.0, (sum, order) => sum + ((order['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final topSelling = medicines.take(3).map((medicine) => {
      'name': medicine['productName'],
      'sales': 18,
      'revenue': ((medicine['price'] as num?)?.toDouble() ?? 0) * 18,
    }).toList();
    return {
      'totalRevenue': totalRevenue.toInt(),
      'totalOrders': orders.length,
      'averageOrderValue': orders.isEmpty ? 0 : totalRevenue / orders.length,
      'topSellingProducts': topSelling,
    };
  }

  Future<Map<String, dynamic>> createOrderFromCart({required String pharmacyId, required String deliveryOption, String? address}) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final pharmacy = _findById(_pharmacies(db), pharmacyId);
    if (currentUser == null || pharmacy == null) throw Exception('Unable to create order');
    final pharmacyMedicines = _medicines(db).where((medicine) => medicine['pharmacyId'] == pharmacyId).take(2).toList();
    final items = pharmacyMedicines.map((medicine) => {
      'productName': medicine['productName'],
      'quantity': 1,
      'price': medicine['price'],
    }).toList();
    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));
    final order = {
      '_id': _uuid.v4(),
      'orderNumber': 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'pharmacyId': pharmacyId,
      'patient': _publicUser(currentUser),
      'doctor': null,
      'items': items,
      'status': 'pending',
      'totalAmount': totalAmount,
      'deliveryOption': deliveryOption,
      'address': address ?? 'Home delivery',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final orders = _orders(db);
    orders.add(order);
    db['pharmacyOrders'] = orders;
    await _saveDb(db);
    return order;
  }

  Future<List<dynamic>> getMyOrders({String? status}) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    var orders = _orders(db).where((order) => order['patient'] is Map && order['patient']['_id'] == currentUser?['_id']).toList();
    if (status != null && status.isNotEmpty) {
      orders = orders.where((order) => order['status'] == status).toList();
    }
    return orders;
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) async {
    final db = await _loadDb();
    final orders = _orders(db);
    for (final order in orders) {
      if (order['_id'] == orderId) {
        order['status'] = 'cancelled';
        order['cancelReason'] = reason;
      }
    }
    db['pharmacyOrders'] = orders;
    await _saveDb(db);
    return _findById(orders, orderId) ?? {};
  }

  Future<List<dynamic>> listPublicCourses() async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final role = normalizeRoleName(currentUser?['role']?.toString() ?? 'Patient');
    final audience = (role == 'Doctor' || role == 'Instructor') ? 'doctor' : 'patient';
    return _courses(db).where((course) => course['audience'] == audience).toList();
  }

  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    final db = await _loadDb();
    final course = _findById(_courses(db), courseId);
    if (course == null) throw Exception('Course not found');
    return course;
  }

  Future<Map<String, dynamic>> buyCourse(String courseId) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final course = _findById(_courses(db), courseId);
    if (currentUser == null || course == null) throw Exception('Unable to enroll');
    final enrollments = _enrollments(db);
    final existing = enrollments.where((e) => e['userId'] == currentUser['_id'] && e['courseId'] == courseId);
    if (existing.isEmpty) {
      enrollments.add({
        '_id': _uuid.v4(),
        'userId': currentUser['_id'],
        'courseId': courseId,
        'course': course,
        'status': 'active',
        'progress': {'completedVideos': 0, 'totalVideos': course['totalUnits'] ?? 8, 'percent': 0},
        'createdAt': DateTime.now().toIso8601String(),
      });
      db['enrollments'] = enrollments;
      await _saveDb(db);
    }
    return {'success': true, 'course': course};
  }

  Future<List<dynamic>> myPurchases() async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    return _enrollments(db).where((enrollment) => enrollment['userId'] == currentUser?['_id']).toList();
  }

  Future<Map<String, dynamic>> updateProgress(String enrollmentId, Map<String, dynamic> data) async {
    final db = await _loadDb();
    final enrollments = _enrollments(db);
    for (final enrollment in enrollments) {
      if (enrollment['_id'] == enrollmentId) {
        final current = Map<String, dynamic>.from(enrollment['progress'] as Map? ?? {});
        current.addAll(data);
        enrollment['progress'] = current;
        final percent = (current['percent'] as num?)?.toInt() ?? 0;
        if (percent >= 100) enrollment['status'] = 'completed';
      }
    }
    db['enrollments'] = enrollments;
    await _saveDb(db);
    return {'success': true};
  }

  Future<List<dynamic>> myCertificates() async {
    final enrollments = await myPurchases();
    return enrollments.where((enrollment) => (enrollment['status']?.toString() ?? '') == 'completed').map((enrollment) {
      final course = Map<String, dynamic>.from(enrollment['course'] as Map? ?? {});
      return {
        'course': {
          'name': course['title'] ?? course['name'],
          'totalUnits': course['totalUnits'] ?? 8,
        },
        'completedUnits': course['totalUnits'] ?? 8,
      };
    }).toList();
  }


  Future<List<dynamic>> getReferrals({String? status}) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final role = normalizeRoleName(currentUser?['role']?.toString());
    var referrals = _referrals(db);
    if (isPatientRole(role)) {
      referrals = referrals.where((item) => item['patient'] is Map && item['patient']['_id'] == currentUser?['_id']).toList();
    } else if (isDoctorRole(role)) {
      referrals = referrals.where((item) => (item['sourceDoctor'] is Map && item['sourceDoctor']['_id'] == currentUser?['_id']) || (item['targetDoctor'] is Map && item['targetDoctor']['_id'] == currentUser?['_id'])).toList();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      referrals = referrals.where((item) => (item['status']?.toString() ?? '') == status).toList();
    }
    referrals.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return referrals;
  }

  Future<Map<String, dynamic>> createReferral({
    required String patientId,
    required String specialty,
    required String reason,
    String priority = 'normal',
    String? targetDoctorId,
    String? notes,
  }) async {
    final db = await _loadDb();
    final actor = await _resolveCurrentUser();
    final users = _listOfMaps(db, 'users');
    final doctors = _doctors(db);
    final patient = _findById(users, patientId);
    Map<String, dynamic>? targetDoctor;
    if (targetDoctorId != null && targetDoctorId.isNotEmpty) {
      targetDoctor = doctors.firstWhere((d) => d['user'] is Map && d['user']['_id'] == targetDoctorId, orElse: () => <String, dynamic>{});
      if (targetDoctor.isEmpty) targetDoctor = null;
    }
    targetDoctor ??= doctors.firstWhere((d) => (d['specialization']?.toString() ?? '').toLowerCase().contains(specialty.toLowerCase()), orElse: () => doctors.isNotEmpty ? doctors.first : <String, dynamic>{});
    if (patient == null || actor == null || targetDoctor.isEmpty) {
      return {'success': false, 'message': 'Unable to create referral at the moment'};
    }
    final referral = {
      '_id': _uuid.v4(),
      'patient': _publicUser(patient),
      'sourceDoctor': _publicUser(actor),
      'targetDoctor': targetDoctor['user'],
      'specialty': specialty,
      'reason': reason,
      'notes': notes ?? '',
      'priority': priority,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final referrals = _referrals(db);
    referrals.insert(0, referral);
    db['referrals'] = referrals;
    await _appendAuditEvent(db,
      category: 'referral',
      action: 'Referral created for $specialty',
      entityId: referral['_id'].toString(),
      metadata: {'patientId': patientId, 'specialty': specialty, 'priority': priority},
      severity: priority == 'urgent' ? 'high' : 'medium',
      actor: actor,
    );
    await _saveDb(db);
    return {'success': true, 'referral': referral};
  }

  Future<Map<String, dynamic>> updateReferralStatus(String referralId, String status) async {
    final db = await _loadDb();
    final referrals = _referrals(db);
    for (final referral in referrals) {
      if (referral['_id'] == referralId) {
        referral['status'] = status;
        referral['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    db['referrals'] = referrals;
    await _appendAuditEvent(db,
      category: 'referral',
      action: 'Referral moved to $status',
      entityId: referralId,
      metadata: {'status': status},
      severity: status == 'accepted' ? 'info' : 'medium',
    );
    await _saveDb(db);
    return {'success': true};
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final db = await _loadDb();
    return _subscriptionPlans(db);
  }

  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final subscriptions = _patientSubscriptions(db);
    final matches = subscriptions.where((s) => s['patientId'] == currentUser?['_id']).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return matches.first;
  }

  Future<Map<String, dynamic>> subscribeCurrentPatient(String planId) async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    final plan = _findById(_subscriptionPlans(db), planId);
    if (currentUser == null || plan == null) {
      return {'success': false, 'message': 'Subscription plan not found'};
    }
    final subscriptions = _patientSubscriptions(db);
    subscriptions.removeWhere((s) => s['patientId'] == currentUser['_id'] && (s['status']?.toString() ?? '') == 'active');
    final active = {
      '_id': _uuid.v4(),
      'patientId': currentUser['_id'],
      'plan': plan,
      'status': 'active',
      'renewalDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    subscriptions.insert(0, active);
    db['patientSubscriptions'] = subscriptions;
    await _appendAuditEvent(db,
      category: 'subscription',
      action: 'Patient subscribed to ${plan['name']}',
      entityId: active['_id'].toString(),
      metadata: {'planId': planId},
      severity: 'info',
      actor: currentUser,
    );
    await _saveDb(db);
    return {'success': true, 'subscription': active};
  }

  Future<List<dynamic>> getCarePlansForCurrentUser() async {
    final db = await _loadDb();
    final currentUser = await _resolveCurrentUser();
    var carePlans = _carePlans(db);
    if (isPatientRole(currentUser?['role']?.toString())) {
      carePlans = carePlans.where((item) => item['patientId'] == currentUser?['_id']).toList();
    }
    carePlans.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return carePlans;
  }

  Future<Map<String, dynamic>> getAuditDashboard() async {
    final db = await _loadDb();
    final events = _auditEvents(db);
    final today = DateTime.now();
    final todayEvents = events.where((event) {
      final dt = DateTime.tryParse(event['createdAt']?.toString() ?? '');
      if (dt == null) return false;
      return dt.year == today.year && dt.month == today.month && dt.day == today.day;
    }).toList();
    final mediumOrHigher = events.where((event) => ['medium', 'high'].contains((event['severity']?.toString() ?? '').toLowerCase())).length;
    final openReferrals = _referrals(db).where((ref) => (ref['status']?.toString() ?? '') == 'pending').length;
    return {
      'totalEvents': events.length,
      'todayEvents': todayEvents.length,
      'mediumOrHigher': mediumOrHigher,
      'openReferrals': openReferrals,
      'recentEvents': events.take(20).toList(),
    };
  }

  Future<Map<String, dynamic>> getAdminOverview() async {
    final db = await _loadDb();
    return {
      'users': _listOfMaps(db, 'users').length,
      'patients': _listOfMaps(db, 'users').where((u) => normalizeRoleName(u['role']?.toString()) == 'Patient').length,
      'doctors': _listOfMaps(db, 'users').where((u) => normalizeRoleName(u['role']?.toString()) == 'Doctor').length,
      'labs': _labs(db).length,
      'pharmacies': _pharmacies(db).length,
      'activeSubscriptions': _patientSubscriptions(db).where((s) => (s['status']?.toString() ?? '') == 'active').length,
      'pendingReferrals': _referrals(db).where((r) => (r['status']?.toString() ?? '') == 'pending').length,
      'recentAudits': _auditEvents(db).take(12).toList(),
    };
  }

  Future<Map<String, dynamic>> getSecurityOverview() async {
    final db = await _loadDb();
    final events = _auditEvents(db);
    final loginEvents = events.where((e) => (e['category']?.toString() ?? '') == 'auth').length;
    final riskEvents = events.where((e) => ['medium', 'high'].contains((e['severity']?.toString() ?? '').toLowerCase())).toList();
    return {
      'loginEvents': loginEvents,
      'riskEvents': riskEvents.length,
      'riskFeed': riskEvents.take(15).toList(),
      'securityUsers': _listOfMaps(db, 'users').where((u) => normalizeRoleName(u['role']?.toString()) == 'Security').length,
    };
  }

  Map<String, dynamic> _seedDb() {
    final now = DateTime.now();
    final cityMap = ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Peshawar', 'Quetta', 'Faisalabad', 'Multan', 'Sialkot', 'Hyderabad'];
    final specializations = ['General Medicine', 'Cardiology', 'Dermatology', 'Gynecology', 'Pediatrics', 'Neurology', 'Orthopedics', 'Endocrinology', 'Psychiatry', 'Pulmonology'];
    final users = <Map<String, dynamic>>[];
    final doctors = <Map<String, dynamic>>[];
    final labs = <Map<String, dynamic>>[];
    final pharmacies = <Map<String, dynamic>>[];
    final courses = <Map<String, dynamic>>[];
    final medicines = <Map<String, dynamic>>[];
    final enrollments = <Map<String, dynamic>>[];
    final appointments = <Map<String, dynamic>>[];
    final records = <Map<String, dynamic>>[];
    final labBookings = <Map<String, dynamic>>[];
    final orders = <Map<String, dynamic>>[];
    final referrals = <Map<String, dynamic>>[];
    final subscriptionPlans = <Map<String, dynamic>>[];
    final patientSubscriptions = <Map<String, dynamic>>[];
    final carePlans = <Map<String, dynamic>>[];
    final auditEvents = <Map<String, dynamic>>[];

    for (var i = 0; i < 10; i++) {
      final patient = {
        '_id': 'patient-${i + 1}',
        'name': 'Patient ${i + 1}',
        'email': 'patient${i + 1}@icare.demo',
        'phoneNumber': '0300${(1111111 + i).toString()}',
        'role': 'Patient',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 30 - i)).toIso8601String(),
        'region': cityMap[i],
      };
      users.add(patient);
    }

    for (var i = 0; i < 10; i++) {
      final doctorUser = {
        '_id': 'doctor-${i + 1}',
        'name': 'Dr. ${['Ahsan', 'Fatima', 'Ali', 'Mariam', 'Hamza', 'Ayesha', 'Usman', 'Zara', 'Bilal', 'Noor'][i]}',
        'email': 'doctor${i + 1}@icare.demo',
        'phoneNumber': '0311${(1111111 + i).toString()}',
        'role': 'Doctor',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 45 - i)).toIso8601String(),
      };
      users.add(doctorUser);
      doctors.add({
        '_id': 'doctor-profile-${i + 1}',
        'user': _publicUser(doctorUser),
        'specialization': specializations[i],
        'consultationType': i < 5 ? ['Video Consultation', 'Clinic Visit'] : ['Video Consultation'],
        'languages': ['English', 'Urdu'],
        'degrees': ['MBBS', if (i >= 5) 'FCPS'],
        'experience': '${4 + i} years',
        'licenseNumber': 'PMDC-${1000 + i}',
        'clinicName': 'iCare ${specializations[i]} Clinic',
        'clinicAddress': cityMap[i],
        'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        'availableTime': {'start': '09:00', 'end': '17:00'},
        'isApproved': true,
        'ratings': [4.3 + (i * 0.05), 4.6],
        'reviews': ['Great consultation', 'Professional and clear'],
      });
    }

    for (var i = 0; i < 10; i++) {
      final labUser = {
        '_id': 'lab-user-${i + 1}',
        'name': 'Lab Partner ${i + 1}',
        'email': 'lab${i + 1}@icare.demo',
        'phoneNumber': '0321${(1111111 + i).toString()}',
        'role': 'Laboratory',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 20 - i)).toIso8601String(),
      };
      users.add(labUser);
      labs.add({
        '_id': 'lab-${i + 1}',
        'user': _publicUser(labUser),
        'labName': 'iCare Diagnostics ${cityMap[i]}',
        'name': 'iCare Diagnostics ${cityMap[i]}',
        'title': 'ISO Certified Diagnostics Partner',
        'location': cityMap[i],
        'address': '${cityMap[i]}, Pakistan',
        'licenseNumber': 'LAB-${2000 + i}',
        'contactNumber': labUser['phoneNumber'],
        'isVerified': true,
      });
    }

    for (var i = 0; i < 10; i++) {
      final pharmacyUser = {
        '_id': 'pharmacy-user-${i + 1}',
        'name': 'Pharmacy Partner ${i + 1}',
        'email': 'pharmacy${i + 1}@icare.demo',
        'phoneNumber': '0331${(1111111 + i).toString()}',
        'role': 'Pharmacy',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 22 - i)).toIso8601String(),
      };
      users.add(pharmacyUser);
      pharmacies.add({
        '_id': 'pharmacy-${i + 1}',
        'user': _publicUser(pharmacyUser),
        'pharmacyName': 'iCare Pharmacy ${cityMap[i]}',
        'name': 'iCare Pharmacy ${cityMap[i]}',
        'location': cityMap[i],
        'address': '${cityMap[i]}, Pakistan',
        'licenseNumber': 'PH-${3000 + i}',
        'contactNumber': pharmacyUser['phoneNumber'],
        'isVerified': true,
      });
      // Common Pakistani medicines
      final medicinesList = [
        {'name': 'Panadol', 'category': 'Pain Relief', 'price': 5, 'company': 'GSK'},
        {'name': 'Panadol Extra', 'category': 'Pain Relief', 'price': 8, 'company': 'GSK'},
        {'name': 'Brufen', 'category': 'Pain Relief', 'price': 10, 'company': 'Abbott'},
        {'name': 'Disprin', 'category': 'Pain Relief', 'price': 3, 'company': 'Reckitt'},
        {'name': 'Ponstan', 'category': 'Pain Relief', 'price': 12, 'company': 'Pfizer'},
        {'name': 'Calpol Syrup', 'category': 'Pain Relief', 'price': 120, 'company': 'GSK'},
        {'name': 'Augmentin', 'category': 'Antibiotics', 'price': 250, 'company': 'GSK'},
        {'name': 'Amoxil', 'category': 'Antibiotics', 'price': 150, 'company': 'GSK'},
        {'name': 'Flagyl', 'category': 'Antibiotics', 'price': 180, 'company': 'Sanofi'},
        {'name': 'Ciproxin', 'category': 'Antibiotics', 'price': 200, 'company': 'Bayer'},
        {'name': 'Avil', 'category': 'Allergy', 'price': 80, 'company': 'Sanofi'},
        {'name': 'Cetrizine', 'category': 'Allergy', 'price': 50, 'company': 'Generic'},
        {'name': 'Telfast', 'category': 'Allergy', 'price': 120, 'company': 'Sanofi'},
        {'name': 'Multivitamin', 'category': 'Vitamins', 'price': 200, 'company': 'Generic'},
        {'name': 'Vitamin D3', 'category': 'Vitamins', 'price': 150, 'company': 'Generic'},
        {'name': 'Calcium Tablets', 'category': 'Vitamins', 'price': 180, 'company': 'Generic'},
        {'name': 'Gaviscon', 'category': 'Digestive', 'price': 250, 'company': 'Reckitt'},
        {'name': 'Motilium', 'category': 'Digestive', 'price': 180, 'company': 'Janssen'},
        {'name': 'Risek', 'category': 'Digestive', 'price': 220, 'company': 'Getz'},
        {'name': 'Dettol Antiseptic', 'category': 'First Aid', 'price': 300, 'company': 'Reckitt'},
      ];

      for (var m = 0; m < medicinesList.length; m++) {
        final med = medicinesList[m];
        medicines.add({
          '_id': 'medicine-${i + 1}-$m',
          'pharmacyId': 'pharmacy-${i + 1}',
          'productName': med['name'],
          'category': med['category'],
          'companyName': med['company'],
          'quantity': 50 + (i * 10) + (m * 2),
          'price': med['price'],
          'description': 'High quality ${med['name']} from ${med['company']}',
          'expiry': now.add(Duration(days: 180 + (m * 30))).toIso8601String(),
          'lowStockThreshold': 25,
        });
      }
    }

    for (var i = 0; i < 10; i++) {
      final instructorUser = {
        '_id': 'instructor-${i + 1}',
        'name': 'Instructor ${i + 1}',
        'email': 'instructor${i + 1}@icare.demo',
        'phoneNumber': '0341${(1111111 + i).toString()}',
        'role': 'Instructor',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 18 - i)).toIso8601String(),
      };
      final studentUser = {
        '_id': 'student-${i + 1}',
        'name': 'Student ${i + 1}',
        'email': 'student${i + 1}@icare.demo',
        'phoneNumber': '0351${(1111111 + i).toString()}',
        'role': 'Student',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(Duration(days: 15 - i)).toIso8601String(),
      };
      users.add(instructorUser);
      users.add(studentUser);
    }

    users.addAll([
      {
        '_id': 'admin-1',
        'name': 'Admin One',
        'email': 'admin@icare.demo',
        'phoneNumber': '03610000001',
        'role': 'Admin',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(const Duration(days: 10)).toIso8601String(),
      },
      {
        '_id': 'super-admin-1',
        'name': 'Super Admin',
        'email': 'superadmin@icare.demo',
        'phoneNumber': '03610000002',
        'role': 'Super Admin',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(const Duration(days: 12)).toIso8601String(),
      },
      {
        '_id': 'security-1',
        'name': 'Security Officer',
        'email': 'security@icare.demo',
        'phoneNumber': '03610000003',
        'role': 'Security',
        'profilePicture': null,
        'password': 'Pass@123',
        'createdAt': now.subtract(const Duration(days: 8)).toIso8601String(),
      },
    ]);

    final patientPrograms = [
      ['Diabetes Management Program', 'diabetes'],
      ['Weight Loss Plan', 'weight'],
      ['Prenatal Care Journey', 'prenatal'],
      ['Hypertension Control Program', 'hypertension'],
      ['Post Surgery Rehabilitation', 'surgery'],
      ['Asthma Lifestyle Program', 'asthma'],
      ['Mental Wellness Routine', 'anxiety'],
      ['Heart Healthy Living', 'cardiac'],
      ['Nutrition Basics for Families', 'nutrition'],
      ['Women Wellness Program', 'women'],
    ];

    final doctorCourses = [
      'Clinical Documentation Standards',
      'SOAP Notes Best Practices',
      'Digital Prescribing Workflow',
      'Virtual Consultation Excellence',
      'Referral Pathway Management',
      'Clinical Audit Fundamentals',
      'Patient Safety & QA Monitoring',
      'Chronic Care Program Design',
      'Evidence-Based Telehealth',
      'Revenue & Usage Analytics for Clinics',
    ];

    for (var i = 0; i < patientPrograms.length; i++) {
      courses.add({
        '_id': 'patient-course-${i + 1}',
        'title': patientPrograms[i][0],
        'name': patientPrograms[i][0],
        'description': 'Condition-linked care plan for ${patientPrograms[i][1]} management.',
        'price': 0,
        'category': 'Health Program',
        'tag': 'Care Plan',
        'audience': 'patient',
        'diagnosisTags': [patientPrograms[i][1]],
        'image': 'assets/images/course1.png',
        'instructor': {'name': 'Instructor ${i + 1}'},
        'totalUnits': 8,
      });
      courses.add({
        '_id': 'doctor-course-${i + 1}',
        'title': doctorCourses[i],
        'name': doctorCourses[i],
        'description': 'Professional training module for doctors on ${doctorCourses[i].toLowerCase()}.',
        'price': 0,
        'category': 'Professional Training',
        'tag': 'Certification',
        'audience': 'doctor',
        'diagnosisTags': <String>[],
        'image': 'assets/images/course2.jpg',
        'instructor': {'name': 'Instructor ${i + 1}'},
        'totalUnits': 10,
      });
    }

    for (var i = 0; i < 5; i++) {
      final patientCourse = courses.firstWhere((course) => course['_id'] == 'patient-course-${i + 1}');
      enrollments.add({
        '_id': 'enrollment-patient-${i + 1}',
        'userId': 'patient-${i + 1}',
        'courseId': patientCourse['_id'],
        'course': patientCourse,
        'status': i < 2 ? 'completed' : 'active',
        'progress': {'completedVideos': i < 2 ? 8 : 4, 'totalVideos': 8, 'percent': i < 2 ? 100 : 50},
        'createdAt': now.subtract(Duration(days: 6 + i)).toIso8601String(),
      });
      final doctorCourse = courses.firstWhere((course) => course['_id'] == 'doctor-course-${i + 1}');
      enrollments.add({
        '_id': 'enrollment-doctor-${i + 1}',
        'userId': 'doctor-${i + 1}',
        'courseId': doctorCourse['_id'],
        'course': doctorCourse,
        'status': i < 1 ? 'completed' : 'active',
        'progress': {'completedVideos': i < 1 ? 10 : 6, 'totalVideos': 10, 'percent': i < 1 ? 100 : 60},
        'createdAt': now.subtract(Duration(days: 4 + i)).toIso8601String(),
      });
    }

    appointments.addAll([
      {
        '_id': 'appointment-1',
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'date': now.add(const Duration(days: 1)).toIso8601String(),
        'timeSlot': '10:00 AM',
        'reason': 'Diabetes follow-up',
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        '_id': 'appointment-2',
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-2')),
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'date': now.add(const Duration(days: 5)).toIso8601String(),
        'timeSlot': '02:00 PM',
        'reason': 'Skin rash review',
        'status': 'pending',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        '_id': 'appointment-3',
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-2')),
        'date': now.subtract(const Duration(days: 3)).toIso8601String(),
        'timeSlot': '11:30 AM',
        'reason': 'Prenatal consultation',
        'status': 'completed',
        'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ]);

    final record1 = {
      '_id': 'record-1',
      'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
      'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
      'appointmentId': 'appointment-1',
      'diagnosis': 'Type 2 diabetes and hypertension',
      'symptoms': 'Fatigue and elevated sugar levels',
      'notes': 'Continue lifestyle monitoring and review after 2 weeks',
      'vitalSigns': {'bloodPressure': '140/90', 'temperature': '98.6', 'heartRate': 78, 'weight': 78.0, 'height': 170.0},
      'prescription': [
        {'name': 'Metformin', 'dosage': '500mg', 'frequency': 'Twice daily', 'duration': '30 days', 'instructions': 'Take after meals'},
        {'name': 'Amlodipine', 'dosage': '5mg', 'frequency': 'Once daily', 'duration': '30 days', 'instructions': 'Take in the morning'},
      ],
      'labTests': ['HbA1c', 'Lipid Profile'],
      'assignedPrograms': [courses.firstWhere((c) => c['_id'] == 'patient-course-1'), courses.firstWhere((c) => c['_id'] == 'patient-course-4')],
      'followUpDate': now.add(const Duration(days: 14)).toIso8601String(),
      'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      'updatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
    };
    records.add(record1);

    final record2 = {
      '_id': 'record-2',
      'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-2')),
      'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
      'appointmentId': 'appointment-3',
      'diagnosis': 'Prenatal care follow-up',
      'symptoms': 'Routine trimester check',
      'notes': 'Continue vitamins and education program',
      'vitalSigns': {'bloodPressure': '118/78', 'temperature': '98.0', 'heartRate': 75, 'weight': 64.0, 'height': 162.0},
      'prescription': [
        {'name': 'Prenatal Vitamins', 'dosage': '1 tablet', 'frequency': 'Daily', 'duration': '60 days', 'instructions': 'Take after breakfast'},
      ],
      'labTests': ['CBC'],
      'assignedPrograms': [courses.firstWhere((c) => c['_id'] == 'patient-course-3')],
      'followUpDate': now.add(const Duration(days: 21)).toIso8601String(),
      'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      'updatedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
    };
    records.add(record2);

    labBookings.addAll([
      {
        '_id': 'lab-booking-1',
        'labId': 'lab-1',
        'labName': 'iCare Diagnostics Karachi',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'testType': 'HbA1c',
        'date': now.add(const Duration(days: 1)).toIso8601String(),
        'status': 'pending',
        'price': 1800,
        'doctorInstructions': 'Fasting not required',
        'diagnosisNote': 'Diabetes monitoring',
        'createdAt': now.subtract(const Duration(hours: 20)).toIso8601String(),
      },
      {
        '_id': 'lab-booking-2',
        'labId': 'lab-1',
        'labName': 'iCare Diagnostics Karachi',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'testType': 'Lipid Profile',
        'date': now.add(const Duration(days: 2)).toIso8601String(),
        'status': 'confirmed',
        'price': 2200,
        'doctorInstructions': '8 hour fast required',
        'diagnosisNote': 'Cardio-metabolic risk',
        'createdAt': now.subtract(const Duration(hours: 18)).toIso8601String(),
      },
      {
        '_id': 'lab-booking-3',
        'labId': 'lab-2',
        'labName': 'iCare Diagnostics Lahore',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-2')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
        'testType': 'CBC',
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'status': 'completed',
        'price': 1200,
        'reportUrl': 'standalone://reports/cbc-patient-2.pdf',
        'doctorInstructions': 'Routine prenatal lab',
        'diagnosisNote': 'Prenatal assessment',
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
    ]);

    orders.addAll([
      {
        '_id': 'order-1',
        'orderNumber': 'RX-1001',
        'pharmacyId': 'pharmacy-1',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'items': [
          {'productName': 'Metformin', 'quantity': 1, 'price': 600},
          {'productName': 'Amlodipine', 'quantity': 1, 'price': 450},
        ],
        'status': 'pending',
        'totalAmount': 1050,
        'deliveryOption': 'delivery',
        'address': 'Karachi, Pakistan',
        'createdAt': now.subtract(const Duration(hours: 12)).toIso8601String(),
      },
      {
        '_id': 'order-2',
        'orderNumber': 'RX-1002',
        'pharmacyId': 'pharmacy-1',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-3')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-2')),
        'items': [
          {'productName': 'Paracetamol', 'quantity': 2, 'price': 250},
        ],
        'status': 'completed',
        'totalAmount': 500,
        'deliveryOption': 'pickup',
        'address': 'Lahore, Pakistan',
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        '_id': 'order-3',
        'orderNumber': 'RX-1003',
        'pharmacyId': 'pharmacy-2',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-2')),
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
        'items': [
          {'productName': 'Prenatal Vitamins', 'quantity': 1, 'price': 900},
        ],
        'status': 'preparing',
        'totalAmount': 900,
        'deliveryOption': 'delivery',
        'address': 'Islamabad, Pakistan',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ]);


    subscriptionPlans.addAll([
      {
        '_id': 'plan-basic',
        'name': 'Basic Preventive Care',
        'price': 2999,
        'interval': 'monthly',
        'features': ['1 doctor consultation', '2 lab discounts', '1 preventive program'],
        'tier': 'basic',
      },
      {
        '_id': 'plan-chronic',
        'name': 'Chronic Care Plus',
        'price': 7999,
        'interval': 'monthly',
        'features': ['Dedicated care plan', 'Monthly follow-up', 'Lab & pharmacy coordination'],
        'tier': 'premium',
      },
      {
        '_id': 'plan-family',
        'name': 'Family Preventive Package',
        'price': 11999,
        'interval': 'monthly',
        'features': ['Up to 4 dependents', 'Wellness reminders', 'Annual screening support'],
        'tier': 'family',
      },
    ]);

    patientSubscriptions.add({
      '_id': 'subscription-1',
      'patientId': 'patient-1',
      'plan': subscriptionPlans[1],
      'status': 'active',
      'renewalDate': now.add(const Duration(days: 30)).toIso8601String(),
      'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
    });

    referrals.addAll([
      {
        '_id': 'referral-1',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'sourceDoctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'targetDoctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-2')),
        'specialty': 'Cardiology',
        'reason': 'Hypertension risk assessment',
        'notes': 'Please review ongoing BP trend and medication tolerance.',
        'priority': 'high',
        'status': 'pending',
        'createdAt': now.subtract(const Duration(hours: 16)).toIso8601String(),
      },
      {
        '_id': 'referral-2',
        'patient': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-2')),
        'sourceDoctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
        'targetDoctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-4')),
        'specialty': 'Gynecology',
        'reason': 'Prenatal specialist review',
        'notes': 'Second trimester specialist follow-up.',
        'priority': 'normal',
        'status': 'accepted',
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
    ]);

    carePlans.addAll([
      {
        '_id': 'care-plan-1',
        'patientId': 'patient-1',
        'recordId': 'record-1',
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'title': 'Diabetes + Hypertension Care Plan',
        'status': 'active',
        'priority': 'high',
        'programs': [{'title': 'Diabetes Management Program'}, {'title': 'Hypertension Control Program'}],
        'followUpDate': now.add(const Duration(days: 14)).toIso8601String(),
        'medicationCount': 2,
        'labCount': 2,
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        '_id': 'care-plan-2',
        'patientId': 'patient-2',
        'recordId': 'record-2',
        'doctor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-3')),
        'title': 'Prenatal Monitoring Plan',
        'status': 'active',
        'priority': 'normal',
        'programs': [{'title': 'Prenatal Care Journey'}],
        'followUpDate': now.add(const Duration(days: 21)).toIso8601String(),
        'medicationCount': 1,
        'labCount': 1,
        'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ]);

    auditEvents.addAll([
      {
        '_id': 'audit-1',
        'category': 'clinical',
        'action': 'Medical record created',
        'severity': 'high',
        'entityId': 'record-1',
        'actor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'metadata': {'diagnosis': 'Type 2 diabetes and hypertension'},
        'createdAt': now.subtract(const Duration(hours: 18)).toIso8601String(),
      },
      {
        '_id': 'audit-2',
        'category': 'referral',
        'action': 'Referral created for Cardiology',
        'severity': 'medium',
        'entityId': 'referral-1',
        'actor': _publicUser(users.firstWhere((u) => u['_id'] == 'doctor-1')),
        'metadata': {'priority': 'high'},
        'createdAt': now.subtract(const Duration(hours: 16)).toIso8601String(),
      },
      {
        '_id': 'audit-3',
        'category': 'subscription',
        'action': 'Patient subscribed to Chronic Care Plus',
        'severity': 'info',
        'entityId': 'subscription-1',
        'actor': _publicUser(users.firstWhere((u) => u['_id'] == 'patient-1')),
        'metadata': {'planId': 'plan-chronic'},
        'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        '_id': 'audit-4',
        'category': 'security',
        'action': 'Admin reviewed access configuration',
        'severity': 'medium',
        'entityId': 'security-1',
        'actor': _publicUser(users.firstWhere((u) => u['_id'] == 'security-1')),
        'metadata': {'module': 'Access Controls'},
        'createdAt': now.subtract(const Duration(hours: 8)).toIso8601String(),
      },
    ]);

    return {
      'users': users,
      'doctors': doctors,
      'labs': labs,
      'pharmacies': pharmacies,
      'courses': courses,
      'medicines': medicines,
      'enrollments': enrollments,
      'appointments': appointments,
      'medicalRecords': records,
      'labBookings': labBookings,
      'pharmacyOrders': orders,
      'referrals': referrals,
      'subscriptionPlans': subscriptionPlans,
      'patientSubscriptions': patientSubscriptions,
      'carePlans': carePlans,
      'auditEvents': auditEvents,
    };
  }
}
