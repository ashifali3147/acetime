import 'package:acetime/presentation/navigation/route_names.dart';
import 'package:acetime/presentation/widget/loading_overlay.dart';
import 'package:acetime/style/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../service/firestore_service.dart';
import '../../utils/storage_helper.dart';
import '../../utils/utils.dart';
import '../widget/app_logo.dart';

class UserRegistration extends StatefulWidget {
  const UserRegistration({super.key});

  @override
  State<UserRegistration> createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final inputDecoration = InputDecoration(
    labelStyle: TextStyle(color: AppColors.hintTextColor),
    border: OutlineInputBorder(),
  );
  final fullNameController = TextEditingController();
  var isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(
          child: Column(
            children: [
              Animate(
                effects: [ShimmerEffect(duration: 3.seconds)],
                onPlay: (controller) => controller.repeat(),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: AppLogo(),
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: fullNameController,
                decoration: inputDecoration.copyWith(labelText: 'Name *'),
              ),
              SizedBox(height: 50),
              ElevatedButton(
                onPressed: () async {
                  Utils.hideKeyboard(context);
                  if (fullNameController.text.trim().isEmpty) {
                    Utils.showSnackBar(
                      context,
                      message: "Please enter your name",
                    );
                    return;
                  }
                  setState(() {
                    isLoading = true;
                  });
                  final fcmToken = StorageHelper().getFCMToken();
                  await FirestoreService().getOrCreateUser(
                    fcmToken: fcmToken,
                    userName: fullNameController.text.trim(),
                    onSuccess: () {
                      setState(() {
                        isLoading = false;
                      });
                      StorageHelper().setLoginStatus(true);
                      context.goNamed(RouteNames.home);
                    },
                    onError: (message) {
                      setState(() {
                        isLoading = false;
                      });
                      Utils.showSnackBar(context, message: message);
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.themeColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // slightly rounded
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadUserData() async {
    final userData = await FirestoreService().getCurrentUserData();
    if (userData != null && userData['userName'] != null) {
      fullNameController.text = userData['userName'];
    }
  }
}
