import 'package:acetime/presentation/widget/app_logo.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../style/app_color.dart';
import '../../utils/utils.dart';
import '../navigation/route_names.dart';
import '../widget/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final viewModel = Provider.of<AuthProvider>(context, listen: false);
      viewModel.initFCMToken();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: LoadingOverlay(
        isLoading: viewModel.isLoginPageLoading,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE71F83), // Purple-ish
                Color(0x4C940DE7), // Light Blue with opacity
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AppLogo(color: Colors.white,),
                ),
              ),
              //Text Enter Fields
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Verify Phone Number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'We will send you a one-time code to verify your phone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.hintTextColor,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Expanded(
                            child: Text(
                              'Contact Number *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showCountryCode(context, viewModel);
                              },
                              child: Text(
                                "+${viewModel.countryCode}",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 16,
                              thickness: 1,
                              color: Color(0xFFDCDCDC),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: viewModel.phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'Enter 10 digit phone number',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF999999),
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: viewModel.isTermsAndConditionChecked,
                            onChanged: (value) {
                              viewModel.isTermsAndConditionChecked = value!;
                            },
                            activeColor: AppColors.themeColor,
                          ),
                          Expanded(
                            child: RichText(
                              textAlign: TextAlign.start,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black, // fallback color
                                  fontFamily: 'NunitoSans-Regular',
                                ),
                                children: [
                                  const TextSpan(text: 'I agree with '),
                                  TextSpan(
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        openWebView(
                                          context,
                                          "",
                                          'Terms & Conditions',
                                        );
                                      },
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: Color(0xFF2B29AF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        openWebView(
                                          context,
                                          "",
                                          'Privacy Policy',
                                        );
                                      },
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Color(0xFF2B29AF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: viewModel.isTermsAndConditionChecked ? 1 : .5,
                        child: ElevatedButton(
                          onPressed: () {
                            Utils.hideKeyboard(context);
                            if (viewModel.phoneController.text.isEmpty) {
                              Utils.showSnackBar(
                                context,
                                message: "Please enter phone number",
                              );
                              return;
                            }
                            if (!viewModel.isTermsAndConditionChecked) {
                              Utils.showSnackBar(
                                context,
                                message: "Please accept Terms & Conditions",
                              );
                              return;
                            }
                            viewModel.phoneNumber =
                                viewModel.phoneController.text;
                            viewModel.sendOtp(
                              context,
                              onSuccess: () {
                                Future.microtask(() {
                                  if (context.mounted) {
                                    context.pushNamed(RouteNames.otp);
                                  }
                                });
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
            ],
          ),
        ),
      ),
    );
  }

  void showCountryCode(BuildContext context, AuthProvider viewModel) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      // optional. Shows phone code before the country name.
      favorite: <String>['IN'],
      onSelect: (Country country) {
        viewModel.countryCode = country.phoneCode;
      },
    );
  }

  void openWebView(BuildContext context, String url, String title) {
    context.push(
      Uri(
        path: '/web-preview',
        queryParameters: {'url': url, 'title': title},
      ).toString(),
    );
  }
}
