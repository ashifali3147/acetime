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
}
