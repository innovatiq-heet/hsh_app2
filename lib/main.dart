import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/constants/app_pages.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/network/global_bindings.dart';
import 'features/shared/widgets/network_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      builder: (context, child) => NetworkWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
