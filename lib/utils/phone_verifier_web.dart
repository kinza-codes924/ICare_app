// Web stub — phone OTP via SMS is not used on web.
// Web users have isPhoneVerified=true set by the backend at registration.
class PhoneVerifierImpl {
  Future<String> sendOtp(String phoneNumber) async {
    throw UnsupportedError('Phone OTP is not supported on web.');
  }

  Future<void> confirmOtp(String verificationId, String smsCode) async {
    throw UnsupportedError('Phone OTP is not supported on web.');
  }
}
