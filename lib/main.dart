import 'package:acetime/presentation/navigation/app_router.dart';
import 'package:acetime/providers/auth_provider.dart';
import 'package:acetime/providers/chat_provider.dart';
import 'package:acetime/providers/contacts_sync_provider.dart';
import 'package:acetime/service/fcm_service.dart';
import 'package:acetime/service/notification_service.dart';
import 'package:acetime/style/app_color.dart';
import 'package:acetime/utils/custom_slide_page_transition_builder.dart';
import 'package:acetime/utils/storage_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initializeForBackgroundMessages();
  await NotificationService().handleBackgroundMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await StorageHelper.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // await Constant.initConstants();
  FcmService().listenForTokenRefresh();
  await NotificationService().initialize();
  // Utils.initializeTimeZone();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactSyncProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      title: 'AceTime',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.themeColor),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomSlidePageTransitionBuilder(),
            TargetPlatform.iOS: CustomSlidePageTransitionBuilder(),
          },
        ),
      ),
    );
  }
}
