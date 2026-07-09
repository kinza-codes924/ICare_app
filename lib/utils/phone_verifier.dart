// Conditional export: web uses RecaptchaVerifier, mobile uses verifyPhoneNumber.
export 'phone_verifier_stub.dart'
    if (dart.library.html) 'phone_verifier_web.dart';
