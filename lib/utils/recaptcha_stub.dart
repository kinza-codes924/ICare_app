/// Non-web platforms (mobile/desktop) have no grecaptcha.js loaded, so this
/// always returns null — callers must treat a null token as "recaptcha not
/// applicable on this platform" rather than a hard failure.
Future<String?> executeRecaptcha(String action) async => null;
