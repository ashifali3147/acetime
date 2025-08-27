import 'package:acetime/utils/storage_helper.dart';
import 'package:flutter/material.dart';

class Utils {
  Utils._privateConstructor();

  static final Utils _instance = Utils._privateConstructor();

  factory Utils() {
    return _instance;
  }

  static void showSnackBar(
    BuildContext context, {
    required String message,
    String? actionText,
    Function? actionCallBack,
  }) {
    if (!context.mounted) return;
    final snackBar = SnackBar(
      content: Text(message),
      action: actionText != null
          ? SnackBarAction(
              label: actionText,
              onPressed: () {
                actionCallBack?.call();
              },
            )
          : null,
    );

    // Find the ScaffoldMessenger in the widget tree
    // and use it to show a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static Widget conditionalWidget({
    required bool condition,
    required Widget trueWidget,
    required Widget falseWidget,
  }) {
    if (condition) {
      return trueWidget;
    } else {
      return falseWidget;
    }
  }

  static String formatTimeInMinSec(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes > 0 && seconds > 0) {
      return '$minutes min $seconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }

  static String getSenderName() {
    return StorageHelper().getUserName().isNotEmpty
        ? StorageHelper().getUserName()
        : "Someone";
  }
}
