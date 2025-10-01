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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load .env file once at the start
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // This print statement is helpful for debugging missing .env files
    print("Error loading .env file: $e");
  }

  // Initialize OneSignal
  // Note: Using the null-check operator (!) because the value is expected to be present
  OneSignal.initialize(dotenv.env['ONE_SIGNAL_API_KEY']!);
  OneSignal.Notifications.requestPermission(true);

  // Initialize Gemini
  Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: initialScreen,
    );
  }
}
