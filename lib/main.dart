// FIREBASE DISABLED: see pubspec.yaml.
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'core/constants/app_pages.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/network/global_bindings.dart';
import 'features/shared/widgets/network_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use the native Android Photo Picker so gallery selection works without
  // broad storage permissions (READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE).
  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  // FIREBASE DISABLED: see pubspec.yaml.
  // try {
  //   await Firebase.initializeApp();
  // } catch (e) {
  //   debugPrint('Firebase initialization warning in main: $e');
  // }
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
