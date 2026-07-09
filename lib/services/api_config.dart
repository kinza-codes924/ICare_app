class ApiConfig {
  // Production backend URL - Vercel (latest fixes)
  static const String baseUrl = 'https://icare-backend-inky.vercel.app/api';

  // Virtual Hospital VPS backend (old):
  // static const String baseUrl = 'https://api.icare-virtual-hospital.com/api';

  // For local development (web/Chrome):
  // static const String baseUrl = 'http://localhost:5000/api';

  // For local development (Android emulator):
  // static const String baseUrl = 'http://10.0.2.2:5000/api';

  // For local development (physical device - use your computer's IP):
  // static const String baseUrl = 'http://192.168.1.XXX:5000/api';

  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String doctorsEndpoint = '/doctors';
  static const String patientsEndpoint = '/paitents';
  static const String pharmacyEndpoint = '/pharmacy';
  static const String appointmentsEndpoint = '/appointments';

  // Auth endpoints
  static const String register = '$authEndpoint/register';
  static const String login = '$authEndpoint/login';
  static const String forgetPassword = '$authEndpoint/forget_password';
  static const String checkOTP = '$authEndpoint/checkOTP';
  static const String resetPassword = '$authEndpoint/reset_password';
  static const String verifyEmail = '$authEndpoint/verify-email';
  static const String resendVerification = '$authEndpoint/resend-verification';
}
