import 'package:acetime/presentation/navigation/route_names.dart';
import 'package:go_router/go_router.dart';

import '../../utils/navigator.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_verify_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/user_registration.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      name: RouteNames.otp,
      builder: (context, state) => const OtpVerifyScreen(),
    ),
    GoRoute(
      path: '/user-registration',
      name: RouteNames.userRegistration,
      builder: (context, state) => const UserRegistration(),
    ),
    GoRoute(
      path: '/home',
      name: RouteNames.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
