import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/firebase_error_mapper.dart';
import '../utils/utils.dart';

class AuthRepo {
  static String verId = "";
  static int? _resendToken;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Start phone number verification
  static void verifyPhoneNumber({
    required BuildContext context,
    required String number,
    VoidCallback? onCodeSent,
    VoidCallback? onAutoLogin,
    VoidCallback? onVerificationFailed,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: number,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) {
        final verificationId = credential.verificationId;
        final smsCode = credential.smsCode;

        // Auto verification can return a credential without an SMS code.
        if (verificationId != null && smsCode != null) {
          signInWithPhoneNumber(
            context: context,
            verificationId: verificationId,
            smsCode: smsCode,
            onSuccess: onAutoLogin,
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        Utils.showSnackBar(context, message: FirebaseErrorMapper.getMessage(e));
        onVerificationFailed?.call();
      },
      codeSent: (String verificationId, int? resendToken) {
        verId = verificationId;
        _resendToken = resendToken;
        onCodeSent?.call();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        verId = verificationId;
      },
    );
  }

  /// Resend OTP using the stored resendToken
  static void resendOtp({
    required BuildContext context,
    required String number,
    VoidCallback? onCodeSent,
    VoidCallback? onVerificationFailed,
  }) {
    verifyPhoneNumber(
      context: context,
      number: number,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
    );
  }

  /// Submit OTP manually
  static void submitOtp({
    required BuildContext context,
    required String otp,
    VoidCallback? onSuccess,
    VoidCallback? onFailure,
  }) {
    signInWithPhoneNumber(
      context: context,
      verificationId: verId,
      smsCode: otp,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  /// Sign in using verificationId and smsCode
  static Future<void> signInWithPhoneNumber({
    required BuildContext context,
    required String verificationId,
    required String smsCode,
    VoidCallback? onSuccess,
    VoidCallback? onFailure,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _firebaseAuth.signInWithCredential(credential);
      // Sign in
      // final userCredential = await _firebaseAuth.signInWithCredential(
      //   credential,
      // );
      //
      // // Get ID token
      // final token = await userCredential.user?.getIdToken();
      //TODO:: uncomment above code if you want jwt token from firebase
      onSuccess?.call();
      if (!context.mounted) return;
    } catch (e) {
      onFailure?.call();
      if (e is FirebaseAuthException) {
        Utils.showSnackBar(context, message: FirebaseErrorMapper.getMessage(e));
      }
    }
  }

  /// Sign out and go back to login
  static void logoutApp({VoidCallback? onLogout}) async {
    await _firebaseAuth.signOut();
    onLogout?.call();
  }

  static void resetEverything() {
    verId = "";
    _resendToken = null;
  }
}
