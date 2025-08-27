import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class StorageHelper {
  static final StorageHelper _instance = StorageHelper._internal();
  static SharedPreferences? _prefs;

  factory StorageHelper() => _instance;

  StorageHelper._internal();

  // Call this once in main() or app startup
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void saveStringData(String key, String value) {
    _prefs?.setString(key, value);
  }

  String? getStringData(String key) {
    return _prefs?.getString(key);
  }

  void saveIntData(String key, int value) {
    _prefs?.setInt(key, value);
  }

  int? getIntData(String key) {
    return _prefs?.getInt(key);
  }

  void saveBoolData(String key, bool value) {
    _prefs?.setBool(key, value);
  }

  bool? getBoolData(String key) {
    return _prefs?.getBool(key);
  }

  void clearAllData() {
    _prefs?.clear();
  }

  //=============================================================================

  void setLoginStatus(bool isLoggedIn) {
    saveBoolData(Constant.isUserLogin, isLoggedIn);
  }

  bool getLoginStatus() {
    return getBoolData(Constant.isUserLogin) ?? false;
  }

  void setFCMToken(String token) {
    saveStringData(Constant.fcmToken, token);
  }

  String getFCMToken() {
    return getStringData(Constant.fcmToken) ?? "";
  }

  void setJWTToken(String token) {
    saveStringData(Constant.jwtToken, token);
  }

  String getJWTToken() {
    return getStringData(Constant.jwtToken) ?? "";
  }

  void setUserName(String value) {
    saveStringData(Constant.userName, value);
  }

  String getUserName() {
    return getStringData(Constant.userName) ?? "";
  }
}
