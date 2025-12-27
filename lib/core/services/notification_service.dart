import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService() {
    _init();
  }

  Future<void> _init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings can be added here if needed
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // When notification is tapped, bring app to foreground (default)
        // We can parse 'details.payload' to navigate to specific chat if needed
        print("🔔 Notification Tapped: ${details.payload}");
        // TODO: Implement navigation via GlobalKey if needed
      },
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'mesh_channel',
      'Mesh Network Alerts',
      channelDescription: 'Notifications for Mesh network connections and SOS',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
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
