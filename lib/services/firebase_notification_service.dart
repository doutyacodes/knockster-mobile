import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ⬅ add

/// Background message handler - MUST be top-level function

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background message received: ${message.messageId}');

  // 🔥 REQUIRED for background isolate
  await Firebase.initializeApp();

  await FirebaseNotificationService._handleBackgroundMessage(message);
}


class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Callback for when notification is tapped
  Function(Map<String, dynamic>)? onNotificationTap;

  // Callback for auto-navigation (emergency alerts)
  Function(Map<String, dynamic>)? onAutoNavigate;

  static const String _baseUrl = 'https://knockster-safety.vercel.app/api/mobile-api';

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    print('🔥 Initializing Firebase Messaging...');

    // Request permission for iOS and Android 13+
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // For iOS critical alerts
    );

    print('📱 Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      String? token = await getDeviceToken();
      if (token != null) {
        print('🎟️ FCM Token: ${token.substring(0, 20)}...');
        await _saveTokenLocally(token);
      }

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from terminated state via notification');
        _handleNotificationTap(initialMessage);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _saveTokenLocally(newToken);
        // TODO: Send new token to backend
      });

      print('✅ Firebase Messaging initialized successfully');
    } else {
      print('❌ User declined notification permission');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Local notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            onNotificationTap?.call(data);
          } catch (e) {
            print('❌ Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create EMERGENCY notification channel (HIGH PRIORITY)
    const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
      'emergency_checkin_channel',
      'Emergency Check-ins',
      description: 'CRITICAL: Emergency safety check-in alerts that require immediate attention',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
    );

    // Create NORMAL notification channel
    const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
      'safety_checkin_channel',
      'Safety Check-ins',
      description: 'Notifications for safety check-in alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(emergencyChannel);
    await androidPlugin?.createNotificationChannel(normalChannel);

    print('✅ Notification channels created');
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    final type = message.data['type'];

    // Check if this is an emergency check-in alert
    if (type == 'checkin_alert' || type == 'snooze_reminder') {
      print('🚨 EMERGENCY ALERT DETECTED - Showing full-screen notification');
      await _showFullScreenNotification(message);

      // AUTO-NAVIGATE immediately in foreground
      print('🔥 AUTO-NAVIGATING to /checkin-alert (foreground)');
      onAutoNavigate?.call(message.data);
    } else {
      // Show normal notification for other types
      await _showLocalNotification(message);
    }
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📬 Handling background message: ${message.messageId}');
    print('📬 Data: ${message.data}');

    final type = message.data['type'];

    // For emergency alerts in background, the full-screen notification will be shown
    // Navigation will happen when user taps the notification or it opens automatically
    if (type == 'checkin_alert' || type == 'snooze_reminder') {
      print('🚨 Emergency alert in background - will show full-screen');

      // Create instance to show full-screen notification
      final service = FirebaseNotificationService();
      await service._showFullScreenNotification(message);
    }
  }

  /// Handle notification tap (when app is in background)
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.messageId}');
    print('Data: ${message.data}');

    // Extract check-in data and navigate to PIN entry
    if (message.data.isNotEmpty) {
      onNotificationTap?.call(message.data);
    }
  }

  /// Show FULL-SCREEN notification (emergency style, like incoming call)
  Future<void> _showFullScreenNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? 'Safety Check-in Required';
    final body = notification?.body ?? 'Please verify your safety status now';

    // Create full-screen notification with maximum priority
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_checkin_channel',
      'Emergency Check-ins',
      channelDescription: 'CRITICAL: Emergency safety check-in alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,

      // CRITICAL: Full-screen intent settings
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,

      // Make it show on lock screen
      visibility: NotificationVisibility.public,

      // Make it persistent
      ongoing: false,
      autoCancel: true,

      // Styling
      styleInformation: const BigTextStyleInformation(''),
      color: const Color.fromARGB(255, 255, 59, 48),

      // Actions
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'respond_now',
          'Respond Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      sound: 'alarm.aiff',
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformDetails,
      payload: jsonEncode(data),
    );

    print('✅ Full-screen notification shown');
  }

  /// Show local notification (for normal messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'safety_checkin_channel',
      'Safety Check-ins',
      channelDescription: 'Notifications for safety check-in alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: jsonEncode(data),
    );
  }

  /// Get device FCM token
  Future<String?> getDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Save token locally
  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Get saved token
  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Register device token with backend
  Future<bool> registerDeviceToken(int userId, String deviceType) async {
    try {
      String? token = await getDeviceToken();
      if (token == null) {
        print('❌ No FCM token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_token': token,
          'device_type': deviceType, // 'android' or 'ios'
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Device token registered successfully');
        return true;
      } else {
        print('❌ Failed to register device token: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error registering device token: $e');
      return false;
    }
  }

  /// Subscribe to topic (for admin alerts)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Delete token (for logout)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
