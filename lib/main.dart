import 'package:acetime/presentation/navigation/app_router.dart';
import 'package:acetime/providers/auth_provider.dart';
import 'package:acetime/style/app_color.dart';
import 'package:acetime/utils/custom_slide_page_transition_builder.dart';
import 'package:acetime/utils/storage_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageHelper.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await Constant.initConstants();
  // FcmService().listenForTokenRefresh();
  // Utils.initializeTimeZone();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
