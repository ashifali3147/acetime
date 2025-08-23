import 'dart:async';

import 'package:acetime/presentation/widget/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../utils/storage_helper.dart';
import '../navigation/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () => context.goNamed(getMainScreen()));
  }

  String getMainScreen() {
    return StorageHelper().getLoginStatus()
        ? RouteNames.home
        : RouteNames.login;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Animate(
          effects: [ShimmerEffect(duration: 3.seconds)],
          onPlay: (controller) => controller.repeat(),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: AppLogo(),
          ),
        ),
      ),
    );
  }
}
