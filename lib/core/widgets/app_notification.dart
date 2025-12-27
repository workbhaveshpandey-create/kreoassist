import 'package:flutter/material.dart';

/// Premium styled notifications for the app
class AppNotification {
  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: config.iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  config.icon,
                  color: config.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.title,
                      style: TextStyle(
                        color: config.titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction?.call();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: config.iconColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        backgroundColor: config.bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: config.borderColor, width: 1),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void success(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(context,
        message: message,
        type: NotificationType.success,
        actionLabel: actionLabel,
        onAction: onAction);
  }

  static void error(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(context,
        message: message,
        type: NotificationType.error,
        actionLabel: actionLabel,
        onAction: onAction);
  }

  static void warning(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(context,
        message: message,
        type: NotificationType.warning,
        actionLabel: actionLabel,
        onAction: onAction);
  }

  static void info(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(context,
        message: message,
        type: NotificationType.info,
        actionLabel: actionLabel,
        onAction: onAction);
  }

  static _NotificationConfig _getConfig(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return _NotificationConfig(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF4ADE80),
          iconBgColor: const Color(0xFF4ADE80).withOpacity(0.15),
          bgColor: const Color(0xFF1A2F23),
          borderColor: const Color(0xFF4ADE80).withOpacity(0.3),
          title: 'Success',
          titleColor: const Color(0xFF4ADE80),
        );
      case NotificationType.error:
        return _NotificationConfig(
          icon: Icons.error_rounded,
          iconColor: const Color(0xFFF87171),
          iconBgColor: const Color(0xFFF87171).withOpacity(0.15),
          bgColor: const Color(0xFF2F1A1A),
          borderColor: const Color(0xFFF87171).withOpacity(0.3),
          title: 'Error',
          titleColor: const Color(0xFFF87171),
        );
      case NotificationType.warning:
        return _NotificationConfig(
          icon: Icons.warning_rounded,
          iconColor: const Color(0xFFFBBF24),
          iconBgColor: const Color(0xFFFBBF24).withOpacity(0.15),
          bgColor: const Color(0xFF2F2A1A),
          borderColor: const Color(0xFFFBBF24).withOpacity(0.3),
          title: 'Warning',
          titleColor: const Color(0xFFFBBF24),
        );
      case NotificationType.info:
        return _NotificationConfig(
          icon: Icons.info_rounded,
          iconColor: const Color(0xFF60A5FA),
          iconBgColor: const Color(0xFF60A5FA).withOpacity(0.15),
          bgColor: const Color(0xFF1A2330),
          borderColor: const Color(0xFF60A5FA).withOpacity(0.3),
          title: 'Info',
          titleColor: const Color(0xFF60A5FA),
        );
    }
  }
}

enum NotificationType { success, error, warning, info }

class _NotificationConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final Color titleColor;

  _NotificationConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.titleColor,
  });
}
