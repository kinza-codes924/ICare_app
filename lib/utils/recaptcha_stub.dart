/// Non-web platforms (mobile/desktop) have no grecaptcha.js loaded, so the
/// checkbox widget is never shown and verification is skipped — callers
/// must treat a null token as "recaptcha not applicable on this platform"
/// rather than a hard failure.
const String recaptchaContainerId = 'icare-recaptcha-container';
const String _recaptchaViewType = 'icare-recaptcha-view';

void registerRecaptchaView() {}

String get recaptchaViewType => _recaptchaViewType;

Future<String?> getRecaptchaResponse() async => null;

void resetRecaptcha() {}
