import 'package:get/get.dart';
import '../controllers/broadcast_compose_controller.dart';
import '../controllers/broadcast_detail_controller.dart';
import '../controllers/broadcast_history_controller.dart';
import '../controllers/broadcast_inbox_controller.dart';

class BroadcastHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BroadcastHistoryController());
  }
}

class BroadcastComposeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BroadcastComposeController());
  }
}

class BroadcastDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BroadcastDetailController());
  }
}

class BroadcastInboxBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BroadcastInboxController());
  }
}
