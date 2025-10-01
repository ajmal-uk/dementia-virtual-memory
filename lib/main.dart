// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'welcome_page.dart';
import 'user/user_bottom_nav.dart';
import 'careTaker/care_taker.dart';
import 'admin/admin_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Load the .env file once at the beginning
  await dotenv.load(fileName: ".env");
  
  // 2. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 3. Initialize OneSignal (using dotenv)
  final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID']; 
  if (oneSignalAppId != null) {
     OneSignal.initialize(oneSignalAppId);
     OneSignal.Notifications.requestPermission(true);
  } else {
     debugPrint("Error: ONESIGNAL_APP_ID missing in .env");
  }

  // 4. Initialize Gemini (using dotenv)
  
  final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
  if (geminiApiKey != null) {
    Gemini.init(apiKey: geminiApiKey);
  } else {
    debugPrint("Error: GEMINI_API_KEY missing in .env");
  }

  
  final prefs = await SharedPreferences.getInstance();
  final user = FirebaseAuth.instance.currentUser;
  Widget initialScreen = const WelcomePage();

  if (user != null) {
    final role = prefs.getString('lastRole') ?? 'user';
    if (role == 'user') {
      initialScreen = const UserBottomNav();
    } else if (role == 'caretaker') {
      initialScreen = const CareTaker();
    } else if (role == 'admin') {
      initialScreen = const AdminBottomNav();
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DVMA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent), // Changed seed color for consistency
      ),
      home: initialScreen,
    );
  }
}