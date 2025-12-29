import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../features/emergency_dashboard/presentation/screens/mesh_chat_screen.dart';
import 'update_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track initialization status
  bool _isInitialized = false;
  Future<void>? _initFuture;

  NotificationService() {
    _initFuture = _init();
  }

  /// Ensure initialization is complete before showing notifications
  Future<void> _ensureInitialized() async {
    if (!_isInitialized && _initFuture != null) {
      await _initFuture;
    }
  }

  Future<void> _init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings with permission request
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        print("🔔 Notification Tapped: ${details.payload}");

        if (details.payload != null && details.payload!.startsWith('chat:')) {
          try {
            final parts = details.payload!.split(':');
            if (parts.length >= 3) {
              final peerId = parts[1];
              final peerName = parts[2];

              // Navigate to chat screen
              // Using a delay to ensure context is ready if app was terminated
              Future.delayed(const Duration(milliseconds: 200), () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => MeshChatScreen(
                      peerId: peerId,
                      peerName: peerName,
                    ),
                  ),
                );
              });
            }
          } catch (e) {
            print("Error navigating to chat: $e");
          }
        } else if (details.payload == 'update_check') {
          print("🚀 Update Notification Tapped");
          Future.delayed(const Duration(milliseconds: 500), () {
            if (navigatorKey.currentContext != null) {
              UpdateService.checkForUpdates(navigatorKey.currentContext!);
            }
          });
        }
      },
    );

    // Request Android 13+ notification permission
    final androidImpl =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      print(
          '🔔 Android notification permission: ${granted == true ? "granted" : "denied"}');
    }

    _isInitialized = true;
    print('🔔 NotificationService initialized');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Wait for initialization to complete
    await _ensureInitialized();

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'mesh_channel',
        'Mesh Network Alerts',
        channelDescription:
            'Notifications for Mesh network connections and SOS',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      print('🔔 Notification shown: $title');
    } catch (e) {
      print('❌ Notification error: $e');
    }
  }

  // --- Static Medical Notification Logic ---
  static Future<void> showMedicalNotification({
    required String name,
    required String bloodGroup,
    required String allergies,
    required String conditions,
  }) async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();

    // Ensure initialized (safe to call multiple times)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin
        .initialize(const InitializationSettings(android: androidSettings));

    final String bodyText =
        "Blood: $bloodGroup\nAllergies: ${allergies.isEmpty ? 'None' : allergies}\nConditions: ${conditions.isEmpty ? 'None' : conditions}";

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medical_id_channel',
      'Medical ID',
      channelDescription: 'Persistent notification for Medical ID',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true, // Cannot be swiped away
      autoCancel: false,
      visibility: NotificationVisibility.public, // Show on lock screen
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''), // Expandable
      color: Color(0xFFFF5252),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await plugin.show(
      911, // Fixed ID for Medical Profile
      "Medical ID: $name",
      bodyText,
      platformDetails,
    );
  }

  static Future<void> cancelMedicalNotification() async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    await plugin.cancel(911);
  }

  static Future<void> showUpdateNotification({
    required String version,
  }) async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();

    // Ensure initialized
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin
        .initialize(const InitializationSettings(android: androidSettings));

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'update_channel',
      'App Updates',
      channelDescription: 'Notifications for new app updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00C853),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await plugin.show(
      777,
      "New Update Available! 🚀",
      "KreoAssist v$version is ready to download.",
      platformDetails,
      payload: "update_check",
    );
  }
}
