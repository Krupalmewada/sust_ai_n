// lib/services/notification_service.dart
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notificationsPlugin.initialize(settings);
  }

  Future<void> showFunFactNotification(String fact) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'peeley_channel',
      'Peeley Updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await notificationsPlugin.show(
      Random().nextInt(100),
      '🌱 Peeley Fun Fact',
      fact,
      details,
    );
  }
}