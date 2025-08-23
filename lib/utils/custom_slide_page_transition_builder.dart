import 'package:flutter/material.dart';

class CustomSlidePageTransitionBuilder extends PageTransitionsBuilder {
  const CustomSlidePageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Skip transitions for initial route
    if (route.settings.name == '/') return child;

    const begin = Offset(1.0, 0.0); // from right
    const end = Offset.zero;
    final tween = Tween(
      begin: begin,
      end: end,
    ).chain(CurveTween(curve: Curves.easeInOut));

    return SlideTransition(position: animation.drive(tween), child: child);
  }
}
