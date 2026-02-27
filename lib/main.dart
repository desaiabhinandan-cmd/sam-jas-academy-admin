import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:media_kit/media_kit.dart'; 
import 'package:screen_protector/screen_protector.dart';
import 'package:sam_jas_academy/onboarding_screen.dart';
import 'package:sam_jas_academy/dashboard_screen.dart'; 
import 'package:sam_jas_academy/cart_screen.dart'; 
import 'package:sam_jas_academy/course_list_screen.dart'; 
import 'firebase_options.dart';
import 'notification_service.dart';

// Global keys for navigation and routing context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Notification Service for push notifications
    await NotificationService.init();

    runApp(const SamJasAcademyApp());
  } catch (e) {
    debugPrint("CRITICAL STARTUP ERROR: $e");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Startup Failed: $e", textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
  }
}

class SamJasAcademyApp extends StatefulWidget {
  const SamJasAcademyApp({super.key});

  @override
  State<SamJasAcademyApp> createState() => _SamJasAcademyAppState();
}

class _SamJasAcademyAppState extends State<SamJasAcademyApp> {
  
  @override
  void initState() {
    super.initState();
    _initSecurity();
  }

  /// Prevents screenshots and screen recording across the entire app for DRM protection
  void _initSecurity() async {
    await ScreenProtector.preventScreenshotOn();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sam & Jas Academy',
      
      // Essential for background notification navigation
      navigatorKey: navigatorKey, 
      navigatorObservers: [routeObserver], 
      
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'TrajanPro',
        brightness: Brightness.light,
        // Using the academy's signature earthy/luxurious palette
        primaryColor: const Color(0xFF4A342B),
        scaffoldBackgroundColor: const Color(0xFFFFFDF1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFDF1),
          foregroundColor: Color(0xFF4A342B),
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A342B),
          primary: const Color(0xFF4A342B),
          secondary: const Color(0xFFD4A373), // Gold Accent
        ),
      ),
      
      // Routes used by the NotificationService and internal navigation
      routes: {
        '/dashboard': (context) => DashboardScreen(),
        '/cart': (context) => const CartScreen(),
        '/courses': (context) => CourseListScreen(categoryName: "All Courses"),
      },

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show a luxury-themed loader while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD4A373), // Academy Gold
                  strokeWidth: 2,
                ),
              ),
            );
          }

          // If a user session exists, go straight to Dashboard
          if (snapshot.hasData && snapshot.data != null) {
            return DashboardScreen();
          }

          // Otherwise, start with Onboarding
          return const OnboardingScreen();
        },
      ),
    );
  }
}