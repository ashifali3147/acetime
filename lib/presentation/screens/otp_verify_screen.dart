import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../style/app_color.dart';
import '../../utils/utils.dart';
import '../navigation/route_names.dart';
import '../widget/loading_overlay.dart';

class OtpVerifyScreen extends StatelessWidget {
  const OtpVerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: LoadingOverlay(
        isLoading: viewModel.isLoginVerifyPageLoading,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Container(
              color: AppColors.backgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 100,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Enter Verification Code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headingColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please enter the OTP sent to your mobile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 5,
                      children: [
                        const Text(
                          'number',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.hintTextColor,
                          ),
                        ),
                        Text(
                          '+${viewModel.countryCode}-${viewModel.phoneNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headingColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () {
                        viewModel.changeNumber();
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.themeColor,
                        size: 24,
                      ),
                      // icon on the left
                      label: const Text(
                        'Change Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingColor,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.transparent,
                        // disables splash
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        // optional: remove padding
                        tapTargetSize: MaterialTapTargetSize
                            .shrinkWrap, // optional: compact hit area
                      ),
                    ),
                    const SizedBox(height: 40),
                    OtpTextField(
                      numberOfFields: 6,
                      borderColor: AppColors.themeColor,
                      //set to true to show as box or false to show as dash
                      showFieldAsBox: true,
                      //runs when a code is typed in
                      onCodeChanged: (String code) {
                        //handle validation or checks here
                        if (code.isEmpty) viewModel.otpCode = "";
                      },
                      //runs when every textfield is filled
                      onSubmit: (String verificationCode) {
                        viewModel.otpCode = verificationCode;
                      }, // end onSubmit
                    ),
                    const SizedBox(height: 50),
                    Utils.conditionalWidget(
                      condition: (viewModel.otpValidTime > 0),
                      trueWidget: Text.rich(
                        TextSpan(
                          text: 'Your code is valid for ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.hintTextColor,
                          ),
                          children: [
                            TextSpan(
                              text: Utils.formatTimeInMinSec(viewModel.otpValidTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800, // bold
                                color: AppColors.headingColor,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      falseWidget: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            "Not received code yet?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.hintTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              viewModel.resendOtp(context);
                            },
                            child: Text(
                              "Resend OTP",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    Opacity(
                      opacity: viewModel.isOtpValid ? 1 : .5,
                      child: ElevatedButton(
                        onPressed: () {
                          Utils.hideKeyboard(context);
                          if (!viewModel.isOtpValid) {
                            Utils.showSnackBar(
                              context,
                              message: "Please enter a valid OTP",
                            );
                            return;
                          }
                          viewModel.verifyOtp(
                            context,
                            otp: viewModel.otpCode,
                            onSuccess: () {
                              context.goNamed(RouteNames.userRegistration);
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
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // slightly rounded
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
