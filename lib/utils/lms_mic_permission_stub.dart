// Non-web stub — returns false (no permission needed on native)
Future<bool> lmsRequestMicPermission(int maxRetries, int retryDelayMs) async {
  return true; // Non-web: assume permission is handled by native plugins
}