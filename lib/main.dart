import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

// Import all screens
import 'screens/login_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/success_screen.dart';
import 'screens/home_screen.dart';
import 'screens/checkin_alert_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/alerts_list_screen.dart';
import 'screens/alert_detail_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Import services
import 'services/firebase_notification_service.dart';

void handleNotificationNavigation(Map<String, dynamic> data) {
  final type = data['type'];
  final checkinId =
      data['checkin_id']?.toString() ?? data['checkinId']?.toString();
  final label = data['label'] ?? 'Safety Check-in';
  final scheduledTime =
      data['scheduled_time'] ?? data['scheduledTime'] ?? 'Now';

  // Allow only Check-in & Snooze to auto-open
  if (type == 'checkin_alert' || type == 'snooze_reminder') {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      print("📌 Auto-navigation triggered → /checkin-alert");
      ctx.go(
        '/checkin-alert',
        extra: {
          'checkinId': int.tryParse(checkinId ?? '0') ?? 0,
          'label': label,
          'scheduledTime': scheduledTime,
        },
      );
    }
  }
}

// Global navigator key for accessing router from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  print('✅ Firebase initialized');

  // Initialize Firebase Messaging
  final notificationService = FirebaseNotificationService();
  await notificationService.initialize();

  // Set up notification tap handler (foreground + background)
  notificationService.onNotificationTap = (data) {
    print('📲 Notification tapped with data: $data');
    handleNotificationNavigation(data);
  };

  // Set up AUTO-NAVIGATION for emergency alerts (foreground)
  notificationService.onAutoNavigate = (data) {
    print('🚨 AUTO-NAVIGATION triggered with data: $data');
    handleNotificationNavigation(data);
  };

  // Auto-open when app is launched from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null && message.data.isNotEmpty) {
      print("🚀 Launched from terminated state with data: ${message.data}");
      handleNotificationNavigation(message.data);
    }
  });

  // Auto-open when notification is tapped while app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    if (message.data.isNotEmpty) {
      print("🔄 Background → Foreground navigation data: ${message.data}");
      handleNotificationNavigation(message.data);
    }
  });

  runApp(const KnocksterApp());
}

class KnocksterApp extends StatelessWidget {
  const KnocksterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
  title: 'Knockster',
  debugShowCheckedModeBanner: false,
  theme: _buildLightTheme(),
  darkTheme: _buildDarkTheme(),
  themeMode: ThemeMode.system,
  routerConfig: _router,
  scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
);

  } // 👈 THIS WAS MISSING

  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    navigatorKey: navigatorKey, // 🔥 HERE instead
    routes: [
      // Authentication
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // Onboarding Flow
      GoRoute(
        path: '/pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/success',
        builder: (context, state) => const SuccessScreen(),
      ),

      // User/Employee Routes
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/checkin-alert',
        builder: (context, state) {
          // Get parameters from extra
          final extra = state.extra as Map<String, dynamic>?;
          return CheckinAlertScreen(
            checkinId: extra?['checkinId'] ?? 1,
            label: extra?['label'] ?? 'Check-in',
            scheduledTime: extra?['scheduledTime'] ?? '09:00 AM',
          );
        },
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/alerts',
        builder: (context, state) => const AlertsListScreen(),
      ),
      GoRoute(
        path: '/admin/alert-detail/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id'] ?? '0');
          return AlertDetailScreen(alertId: id);
        },
      ),
    ],
  );

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    );
  }
}
