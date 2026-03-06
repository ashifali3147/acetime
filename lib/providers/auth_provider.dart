import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../repo/auth_repo.dart';
import '../service/fcm_service.dart';
import '../utils/constant.dart';
import '../utils/storage_helper.dart';

class AuthProvider extends ChangeNotifier {
  var _countryCode = "91";

  get countryCode => _countryCode;

  set countryCode(value) {
    _countryCode = value;
    notifyListeners();
  }

  final TextEditingController phoneController = TextEditingController();

  var _phoneNumber = "";

  get phoneNumber => _phoneNumber;

  set phoneNumber(value) {
    _phoneNumber = value;
    notifyListeners();
  }

  String getFormattedPhoneNumber() => "+$countryCode $phoneNumber";

  var _isTermsAndConditionChecked = false;

  get isTermsAndConditionChecked => _isTermsAndConditionChecked;

  set isTermsAndConditionChecked(value) {
    _isTermsAndConditionChecked = value;
    notifyListeners();
  }

  var _otpValidTime = Constant.resendOtpTimeLimitInSec;

  get otpValidTime => _otpValidTime;

  set otpValidTime(value) {
    _otpValidTime = value;
    notifyListeners();
  }

  Timer? _timer;

  void startOtpTimer() {
    // Cancel any existing timer
    _timer?.cancel();

    otpValidTime = Constant.resendOtpTimeLimitInSec;
    otpCode = "";

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpValidTime > 0) {
        otpValidTime = _otpValidTime - 1;
      } else {
        _timer?.cancel();
      }
    });
  }

  void disposeTimer() {
    _timer?.cancel();
  }

  //====================[Login Page]========================
  bool _isLoginPageLoading = false;

  bool get isLoginPageLoading => _isLoginPageLoading;

  set isLoginPageLoading(bool value) {
    _isLoginPageLoading = value;
    notifyListeners();
  }

  void sendOtp(BuildContext context, {required VoidCallback? onSuccess}) {
    sendOtpThroughFirebase(context, callback: onSuccess);
  }

  void sendOtpThroughFirebase(
    BuildContext context, {
    required VoidCallback? callback,
  }) {
    isLoginPageLoading = true;
    AuthRepo.verifyPhoneNumber(
      context: context,
      number: getFormattedPhoneNumber(),
      onCodeSent: () {
        isLoginPageLoading = false;
        callback?.call();
        startOtpTimer();
      },
      onVerificationFailed: () {
        isLoginPageLoading = false;
      },
    );
  }

  //====================[Verify Page]========================

  get isLoginVerifyPageLoading => _isLoginVerifyPageLoading;

  set isLoginVerifyPageLoading(value) {
    _isLoginVerifyPageLoading = value;
    notifyListeners();
  }

  var _isLoginVerifyPageLoading = false;

  var _otpCode = "";

  get otpCode => _otpCode;

  set otpCode(value) {
    _otpCode = value;
    isOtpValid = _otpCode.length == 6;
    notifyListeners();
  }

  var _isOtpValid = false;

  get isOtpValid => _isOtpValid;

  set isOtpValid(value) {
    _isOtpValid = value;
    notifyListeners();
  }

  void verifyOtp(
    BuildContext context, {
    required String otp,
    required VoidCallback? onSuccess,
  }) {
    verifyOtpThroughFirebase(context, otp: otp, onSuccess: onSuccess);
  }

  void verifyOtpThroughFirebase(
    BuildContext context, {
    required String otp,
    required VoidCallback? onSuccess,
  }) {
    isLoginVerifyPageLoading = true;
    AuthRepo.submitOtp(
      context: context,
      otp: otp,
      onSuccess: () {
        isLoginVerifyPageLoading = false;
        onSuccess?.call();
      },
      onFailure: () {
        isLoginVerifyPageLoading = false;
      },
    );
  }

  void resendOtp(BuildContext context) {
    resendOtpThroughFirebase(context);
  }

  void resendOtpThroughFirebase(BuildContext context) {
    isLoginVerifyPageLoading = true;
    AuthRepo.resendOtp(
      context: context,
      number: getFormattedPhoneNumber(),
      onCodeSent: () {
        isLoginVerifyPageLoading = false;
        startOtpTimer();
      },
      onVerificationFailed: () {
        isLoginVerifyPageLoading = false;
      },
    );
  }

  void changeNumber() {
    phoneNumber = "";
    otpCode = "";
    AuthRepo.resetEverything();
  }

  Future<void> initFCMToken() async {
    final fcmToken = await FcmService().getFcmToken();
    if (fcmToken != null) {
      StorageHelper().setFCMToken(fcmToken);
    }
  }
}
