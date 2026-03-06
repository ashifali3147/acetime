import 'package:firebase_auth/firebase_auth.dart';

class FirebaseErrorMapper {
  static String getMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please double-check and try again.';
      case 'session-expired':
        return 'The code has expired. Please request a new one.';
      case 'invalid-phone-number':
        return 'That phone number doesn’t look right. Please check it and try again.';
      case 'too-many-requests':
        return 'You’ve tried too many times. Please wait a bit before trying again.';
      case 'network-request-failed':
        return 'We couldn’t connect. Please check your internet connection.';
      case 'user-disabled':
        return 'Your account has been disabled. Please contact our support team for help.';
      case 'operation-not-allowed':
        return 'Phone sign-in isn’t available at the moment. Please contact support.';
      case 'captcha-check-failed':
        return 'We couldn’t verify you with Captcha. Please try again.';
      case 'app-not-authorized':
        return 'This app isn’t authorized to use the sign-in service.';
      case 'quota-exceeded':
        return 'We’ve sent too many codes today. Please try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
