/// Demo Users for iCare Virtual Hospital
///
/// These credentials can be used to test different roles in the system.
/// All demo accounts use the password: Pass@123
///
/// IMPORTANT: These are for DEMO/TESTING purposes only.
/// In production, users should create their own accounts.
library;

class DemoUsers {
  static const String demoPassword = 'Pass@123';

  // Patient Demo Accounts
  static const List<Map<String, String>> patients = [
    {
      'name': 'Sarah Ahmed',
      'email': 'sarah.patient@icare.demo',
      'phone': '+923001234501',
      'role': 'Patient',
    },
    {
      'name': 'Ali Hassan',
      'email': 'ali.patient@icare.demo',
      'phone': '+923001234502',
      'role': 'Patient',
    },
    {
      'name': 'Fatima Khan',
      'email': 'fatima.patient@icare.demo',
      'phone': '+923001234503',
      'role': 'Patient',
    },
    {
      'name': 'Ahmed Raza',
      'email': 'ahmed.patient@icare.demo',
      'phone': '+923001234504',
      'role': 'Patient',
    },
    {
      'name': 'Ayesha Malik',
      'email': 'ayesha.patient@icare.demo',
      'phone': '+923001234505',
      'role': 'Patient',
    },
    {
      'name': 'Usman Ali',
      'email': 'usman.patient@icare.demo',
      'phone': '+923001234506',
      'role': 'Patient',
    },
    {
      'name': 'Zainab Hussain',
      'email': 'zainab.patient@icare.demo',
      'phone': '+923001234507',
      'role': 'Patient',
    },
    {
      'name': 'Bilal Sheikh',
      'email': 'bilal.patient@icare.demo',
      'phone': '+923001234508',
      'role': 'Patient',
    },
    {
      'name': 'Hira Siddiqui',
      'email': 'hira.patient@icare.demo',
      'phone': '+923001234509',
      'role': 'Patient',
    },
    {
      'name': 'Kamran Iqbal',
      'email': 'kamran.patient@icare.demo',
      'phone': '+923001234510',
      'role': 'Patient',
    },
  ];

  // Doctor Demo Accounts
  static const List<Map<String, String>> doctors = [
    {
      'name': 'Dr. Hassan Mahmood',
      'email': 'hassan.doctor@icare.demo',
      'phone': '+923001234601',
      'role': 'Doctor',
      'specialty': 'General Practitioner',
    },
    {
      'name': 'Dr. Sana Tariq',
      'email': 'sana.doctor@icare.demo',
      'phone': '+923001234602',
      'role': 'Doctor',
      'specialty': 'Cardiologist',
    },
    {
      'name': 'Dr. Imran Yousaf',
      'email': 'imran.doctor@icare.demo',
      'phone': '+923001234603',
      'role': 'Doctor',
      'specialty': 'Dermatologist',
    },
    {
      'name': 'Dr. Nadia Akhtar',
      'email': 'nadia.doctor@icare.demo',
      'phone': '+923001234604',
      'role': 'Doctor',
      'specialty': 'Pediatrician',
    },
    {
      'name': 'Dr. Faisal Aziz',
      'email': 'faisal.doctor@icare.demo',
      'phone': '+923001234605',
      'role': 'Doctor',
      'specialty': 'Orthopedic Surgeon',
    },
    {
      'name': 'Dr. Rabia Nasir',
      'email': 'rabia.doctor@icare.demo',
      'phone': '+923001234606',
      'role': 'Doctor',
      'specialty': 'Gynecologist',
    },
    {
      'name': 'Dr. Tariq Jamil',
      'email': 'tariq.doctor@icare.demo',
      'phone': '+923001234607',
      'role': 'Doctor',
      'specialty': 'Neurologist',
    },
    {
      'name': 'Dr. Mehwish Aslam',
      'email': 'mehwish.doctor@icare.demo',
      'phone': '+923001234608',
      'role': 'Doctor',
      'specialty': 'Psychiatrist',
    },
    {
      'name': 'Dr. Shahid Rana',
      'email': 'shahid.doctor@icare.demo',
      'phone': '+923001234609',
      'role': 'Doctor',
      'specialty': 'ENT Specialist',
    },
    {
      'name': 'Dr. Amna Riaz',
      'email': 'amna.doctor@icare.demo',
      'phone': '+923001234610',
      'role': 'Doctor',
      'specialty': 'Endocrinologist',
    },
  ];

  // Laboratory Demo Accounts (Admin-created)
  static const List<Map<String, String>> laboratories = [
    {
      'name': 'City Diagnostic Lab',
      'email': 'city.lab@icare.demo',
      'phone': '+923001234701',
      'role': 'Laboratory',
      'labName': 'City Diagnostic Center',
      'city': 'Lahore',
    },
    {
      'name': 'Metro Medical Lab',
      'email': 'metro.lab@icare.demo',
      'phone': '+923001234702',
      'role': 'Laboratory',
      'labName': 'Metro Medical Laboratory',
      'city': 'Karachi',
    },
    {
      'name': 'Prime Diagnostics',
      'email': 'prime.lab@icare.demo',
      'phone': '+923001234703',
      'role': 'Laboratory',
      'labName': 'Prime Diagnostic Services',
      'city': 'Islamabad',
    },
    {
      'name': 'Excel Lab Services',
      'email': 'excel.lab@icare.demo',
      'phone': '+923001234704',
      'role': 'Laboratory',
      'labName': 'Excel Laboratory',
      'city': 'Faisalabad',
    },
    {
      'name': 'Advance Diagnostics',
      'email': 'advance.lab@icare.demo',
      'phone': '+923001234705',
      'role': 'Laboratory',
      'labName': 'Advance Diagnostic Center',
      'city': 'Multan',
    },
    {
      'name': 'Health Plus Lab',
      'email': 'healthplus.lab@icare.demo',
      'phone': '+923001234706',
      'role': 'Laboratory',
      'labName': 'Health Plus Laboratory',
      'city': 'Rawalpindi',
    },
    {
      'name': 'Care Lab Network',
      'email': 'care.lab@icare.demo',
      'phone': '+923001234707',
      'role': 'Laboratory',
      'labName': 'Care Lab Network',
      'city': 'Peshawar',
    },
    {
      'name': 'Medix Diagnostics',
      'email': 'medix.lab@icare.demo',
      'phone': '+923001234708',
      'role': 'Laboratory',
      'labName': 'Medix Diagnostic Center',
      'city': 'Quetta',
    },
    {
      'name': 'Precision Lab',
      'email': 'precision.lab@icare.demo',
      'phone': '+923001234709',
      'role': 'Laboratory',
      'labName': 'Precision Laboratory Services',
      'city': 'Sialkot',
    },
    {
      'name': 'Wellness Diagnostics',
      'email': 'wellness.lab@icare.demo',
      'phone': '+923001234710',
      'role': 'Laboratory',
      'labName': 'Wellness Diagnostic Lab',
      'city': 'Gujranwala',
    },
  ];

  // Pharmacy Demo Accounts (Admin-created)
  static const List<Map<String, String>> pharmacies = [
    {
      'name': 'MediCare Pharmacy',
      'email': 'medicare.pharmacy@icare.demo',
      'phone': '+923001234801',
      'role': 'Pharmacy',
      'pharmacyName': 'MediCare Pharmacy',
      'city': 'Lahore',
    },
    {
      'name': 'HealthFirst Pharmacy',
      'email': 'healthfirst.pharmacy@icare.demo',
      'phone': '+923001234802',
      'role': 'Pharmacy',
      'pharmacyName': 'HealthFirst Pharmacy',
      'city': 'Karachi',
    },
    {
      'name': 'CureWell Pharmacy',
      'email': 'curewell.pharmacy@icare.demo',
      'phone': '+923001234803',
      'role': 'Pharmacy',
      'pharmacyName': 'CureWell Pharmacy',
      'city': 'Islamabad',
    },
    {
      'name': 'Wellness Pharmacy',
      'email': 'wellness.pharmacy@icare.demo',
      'phone': '+923001234804',
      'role': 'Pharmacy',
      'pharmacyName': 'Wellness Pharmacy',
      'city': 'Faisalabad',
    },
    {
      'name': 'Life Care Pharmacy',
      'email': 'lifecare.pharmacy@icare.demo',
      'phone': '+923001234805',
      'role': 'Pharmacy',
      'pharmacyName': 'Life Care Pharmacy',
      'city': 'Multan',
    },
    {
      'name': 'Metro Pharmacy',
      'email': 'metro.pharmacy@icare.demo',
      'phone': '+923001234806',
      'role': 'Pharmacy',
      'pharmacyName': 'Metro Pharmacy',
      'city': 'Rawalpindi',
    },
    {
      'name': 'Prime Pharmacy',
      'email': 'prime.pharmacy@icare.demo',
      'phone': '+923001234807',
      'role': 'Pharmacy',
      'pharmacyName': 'Prime Pharmacy',
      'city': 'Peshawar',
    },
    {
      'name': 'Care Plus Pharmacy',
      'email': 'careplus.pharmacy@icare.demo',
      'phone': '+923001234808',
      'role': 'Pharmacy',
      'pharmacyName': 'Care Plus Pharmacy',
      'city': 'Quetta',
    },
    {
      'name': 'Medix Pharmacy',
      'email': 'medix.pharmacy@icare.demo',
      'phone': '+923001234809',
      'role': 'Pharmacy',
      'pharmacyName': 'Medix Pharmacy',
      'city': 'Sialkot',
    },
    {
      'name': 'Health Hub Pharmacy',
      'email': 'healthhub.pharmacy@icare.demo',
      'phone': '+923001234810',
      'role': 'Pharmacy',
      'pharmacyName': 'Health Hub Pharmacy',
      'city': 'Gujranwala',
    },
  ];

  // Instructor Demo Accounts (Admin-created)
  static const List<Map<String, String>> instructors = [
    {
      'name': 'Prof. Khalid Mehmood',
      'email': 'khalid.instructor@icare.demo',
      'phone': '+923001234901',
      'role': 'Instructor',
      'specialty': 'Medical Education',
    },
    {
      'name': 'Dr. Saima Iqbal',
      'email': 'saima.instructor@icare.demo',
      'phone': '+923001234902',
      'role': 'Instructor',
      'specialty': 'Nursing Education',
    },
    {
      'name': 'Prof. Asad Malik',
      'email': 'asad.instructor@icare.demo',
      'phone': '+923001234903',
      'role': 'Instructor',
      'specialty': 'Health Sciences',
    },
    {
      'name': 'Dr. Hina Rashid',
      'email': 'hina.instructor@icare.demo',
      'phone': '+923001234904',
      'role': 'Instructor',
      'specialty': 'Public Health',
    },
    {
      'name': 'Prof. Naveed Ahmed',
      'email': 'naveed.instructor@icare.demo',
      'phone': '+923001234905',
      'role': 'Instructor',
      'specialty': 'Clinical Skills',
    },
  ];

  // Student Demo Accounts (Admin-created)
  static const List<Map<String, String>> students = [
    {
      'name': 'Hamza Akram',
      'email': 'hamza.student@icare.demo',
      'phone': '+923001235001',
      'role': 'Student',
      'program': 'MBBS',
    },
    {
      'name': 'Maryam Saleem',
      'email': 'maryam.student@icare.demo',
      'phone': '+923001235002',
      'role': 'Student',
      'program': 'Nursing',
    },
    {
      'name': 'Talha Usman',
      'email': 'talha.student@icare.demo',
      'phone': '+923001235003',
      'role': 'Student',
      'program': 'Pharmacy',
    },
    {
      'name': 'Aiman Zahid',
      'email': 'aiman.student@icare.demo',
      'phone': '+923001235004',
      'role': 'Student',
      'program': 'Medical Lab Technology',
    },
    {
      'name': 'Zubair Khan',
      'email': 'zubair.student@icare.demo',
      'phone': '+923001235005',
      'role': 'Student',
      'program': 'Public Health',
    },
  ];

  // Admin Demo Accounts
  static const List<Map<String, String>> admins = [
    {
      'name': 'Admin User',
      'email': 'admin@icare.demo',
      'phone': '+923001236001',
      'role': 'Admin',
    },
    {
      'name': 'Super Admin',
      'email': 'superadmin@icare.demo',
      'phone': '+923001236002',
      'role': 'Super Admin',
    },
  ];

  /// Get all demo users as a flat list
  static List<Map<String, String>> getAllUsers() {
    return [
      ...patients,
      ...doctors,
      ...laboratories,
      ...pharmacies,
      ...instructors,
      ...students,
      ...admins,
    ];
  }

  /// Get demo users by role
  static List<Map<String, String>> getUsersByRole(String role) {
    switch (role.toLowerCase()) {
      case 'patient':
        return patients;
      case 'doctor':
        return doctors;
      case 'laboratory':
        return laboratories;
      case 'pharmacy':
        return pharmacies;
      case 'instructor':
        return instructors;
      case 'student':
        return students;
      case 'admin':
      case 'super admin':
        return admins;
      default:
        return [];
    }
  }

  /// Format demo users for display
  static String formatUserCredentials(Map<String, String> user) {
    return '''
Name: ${user['name']}
Email: ${user['email']}
Password: $demoPassword
Role: ${user['role']}
${user['specialty'] != null ? 'Specialty: ${user['specialty']}' : ''}
${user['labName'] != null ? 'Lab: ${user['labName']}' : ''}
${user['pharmacyName'] != null ? 'Pharmacy: ${user['pharmacyName']}' : ''}
${user['city'] != null ? 'City: ${user['city']}' : ''}
${user['program'] != null ? 'Program: ${user['program']}' : ''}
''';
  }
}
