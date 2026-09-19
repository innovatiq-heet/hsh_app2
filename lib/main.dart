import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'constants/app_pages.dart';
import 'constants/app_routes.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'network/global_bindings.dart';

void main() {
  runApp(const HshApp());
}

class HshApp extends StatelessWidget {
  const HshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: Routes.splash,
      initialBinding: GlobalBindings(),
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
