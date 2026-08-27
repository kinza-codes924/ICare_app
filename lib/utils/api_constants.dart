class ApiConstants {
  // Served from our own server now, not Vercel. Same origin as the web app,
  // so browser requests skip CORS entirely. The old Vercel deployment stays
  // up for already-installed mobile builds that still point at it.
  static const String baseUrl = 'https://icare.com.co/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';

  // Headers
  static Map<String, String> getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
