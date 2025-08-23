import 'dart:io';

class Constant {
  static const int successResCheckValue = 1;

  static const String isUserLogin = "IS_USER_LOGIN";
  static const String fcmToken = "FCM_TOKEN";
  static const String jwtToken = "JWT_TOKEN";

  static final String platform = getPlatform();
  static final String deviceType = getPlatform().toUpperCase();

  static String getPlatform() {
    if (Platform.isAndroid) {
      return "android";
    } else if (Platform.isIOS) {
      return "iOS";
    } else {
      return "unknown";
    }
  }

  static const String somethingWentWrong = "Something went wrong!";
}
