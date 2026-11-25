import 'package:get/get.dart';
import '../controllers/room_keys_controller.dart';

/// Room Keys list and room screens share one controller; a room opened on
/// its own creates it.
class RoomKeysBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RoomKeysController());
  }
}
