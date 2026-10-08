import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../constants/app_routes.dart';
import '../network/repository/authentication/auth_repository.dart';
import '../storage/session_store.dart';

/// Top-level background message handler for FCM.
///
/// Must be annotated with `@pragma('vm:entry-point')` so the Flutter engine
/// can invoke it when a message arrives while the app is in the background or killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase already initialized or config not present
  }
  developer.log(
    'Handling background push message: ${message.messageId}',
    name: 'PushNotification',
  );
}

/// App-wide Push Notification Service using Firebase Cloud Messaging (FCM)
/// and [FlutterLocalNotificationsPlugin] for foreground notification display.
class PushNotificationService extends GetxService {
  static PushNotificationService get to => Get.find<PushNotificationService>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Reactive state containing the current device FCM token.
  final RxnString fcmToken = RxnString();

  /// Whether Firebase and notification listeners have initialized successfully.
  final RxBool isInitialized = false.obs;

  /// High importance notification channel for Android.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'hsh_high_importance_channel',
    'Hostel Notifications',
    description:
        'High importance notifications for hostel alerts, curfew breaches, and announcements.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Initializes Firebase, requests notification permissions, sets up local
  /// notification channels, and registers FCM token listeners.
  ///
  /// Wrapped in safe error handling so that if `google-services.json` or Firebase
  /// options are not yet placed by the developer, the app will continue to run
  /// normally and gracefully activate once credentials are provided.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      developer.log(
        'PushNotificationService: Firebase.initializeApp() skipped or failed: $e. '
        'Add android/app/google-services.json to activate live push notifications.',
        name: 'PushNotification',
      );
      return;
    }

    try {
      await _initLocalNotifications();
      await _requestPermissions();
      await _setupForegroundPresentation();
      _setupMessageListeners();
      await _retrieveAndSyncToken();

      isInitialized.value = true;
      developer.log(
        'PushNotificationService initialized successfully.',
        name: 'PushNotification',
      );
    } catch (e) {
      developer.log(
        'PushNotificationService setup warning: $e',
        name: 'PushNotification',
      );
    }
  }

  /// Configures local notification channels and plugin settings for Android and iOS.
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.createNotificationChannel(_channel);
    }
  }

  /// Requests user permission to display alerts, badges, and play sounds.
  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    developer.log(
      'Notification authorization status: ${settings.authorizationStatus}',
      name: 'PushNotification',
    );
  }

  /// Sets foreground notification presentation options for iOS.
  Future<void> _setupForegroundPresentation() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Sets up message listeners for foreground, background, and cold start clicks.
  void _setupMessageListeners() {
    // 1. App killed/background: top-level handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Foreground: display heads-up banner via flutter_local_notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 3. User taps notification while app is running in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

    // 4. App launched from terminated state by tapping notification
    FirebaseMessaging.instance.getInitialMessage().then((initialMessage) {
      if (initialMessage != null) {
        _handleNotificationOpenedApp(initialMessage);
      }
    });

    // 5. Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      fcmToken.value = newToken;
      developer.log('FCM Token refreshed: $newToken', name: 'PushNotification');
      syncTokenWithBackend(newToken);
    });
  }

  /// Displays an in-app heads-up notification when a message arrives in foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    developer.log(
      'Foreground push received: ${message.notification?.title}',
      name: 'PushNotification',
    );

    final notification = message.notification;
    if (notification == null) return;

    final android = message.notification?.android;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Hostel Alert',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handles notification tap when opened from system tray.
  void _handleNotificationOpenedApp(RemoteMessage message) {
    developer.log(
      'Notification opened with payload: ${message.data}',
      name: 'PushNotification',
    );
    _navigateFromPayload(message.data);
  }

  /// Callback when a local notification heads-up banner is tapped.
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          _navigateFromPayload(decoded);
        }
      } catch (e) {
        developer.log('Error parsing notification payload: $e',
            name: 'PushNotification');
      }
    }
  }

  /// Dispatches navigation based on notification payload data.
  void _navigateFromPayload(Map<String, dynamic> data) {
    final targetRoute = data['route'] ?? data['screen'];
    if (targetRoute is String && targetRoute.isNotEmpty) {
      Get.toNamed(targetRoute, arguments: data);
      return;
    }

    final type = data['type']?.toString().toLowerCase();
    switch (type) {
      case 'attendance':
      case 'attendance_alert':
        Get.toNamed(Routes.attendanceHistory);
        break;
      case 'complaint':
      case 'complaint_update':
        final complaintId = data['complaint_id'] ?? data['id'];
        if (complaintId != null) {
          Get.toNamed(Routes.complaintDetail, arguments: complaintId);
        } else {
          Get.toNamed(Routes.studentHome);
        }
        break;
      case 'leave':
      case 'leave_status':
        Get.toNamed(Routes.leave);
        break;
      case 'geofence':
      case 'breach':
      case 'curfew':
        Get.toNamed(Routes.studentHome);
        break;
      case 'screentime':
      case 'screen_time':
        Get.toNamed(Routes.studentScreenTime);
        break;
      default:
        break;
    }
  }

  /// Retrieves current device token and synchronizes it with the backend.
  Future<void> _retrieveAndSyncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        fcmToken.value = token;
        developer.log('Current FCM Token: $token', name: 'PushNotification');
        await syncTokenWithBackend(token);
      }
    } catch (e) {
      developer.log('Failed to retrieve FCM token: $e',
          name: 'PushNotification');
    }
  }

  /// Sends the FCM token to the backend `/auth/fcm-token` endpoint if the user
  /// is currently logged in.
  Future<void> syncTokenWithBackend([String? tokenToSync]) async {
    final token = tokenToSync ?? fcmToken.value;
    if (token == null || token.isEmpty) return;

    if (!Get.isRegistered<SessionStore>()) return;
    final session = Get.find<SessionStore>();
    final authToken = session.currentToken ?? await session.token;
    if (authToken == null || authToken.isEmpty) {
      developer.log(
        'User not logged in; skipping FCM token sync to backend.',
        name: 'PushNotification',
      );
      return;
    }

    if (!Get.isRegistered<AuthRepository>()) return;
    try {
      await Get.find<AuthRepository>().updateFcmToken(token);
      developer.log(
        'FCM token successfully registered on backend.',
        name: 'PushNotification',
      );
    } catch (e) {
      developer.log(
        'Could not register FCM token on backend: $e',
        name: 'PushNotification',
      );
    }
  }
}
