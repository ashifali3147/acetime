import 'package:flutter/material.dart';
import '../style/app_color.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color backgroundColor;
  final Color loaderColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.backgroundColor = AppColors.transparentOverlayColor,
    this.loaderColor = AppColors.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              // Prevents taps
              absorbing: true,
              child: Container(
                color: backgroundColor,
                child: Center(
                  child: CircularProgressIndicator(color: loaderColor),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
