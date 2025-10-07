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
import 'careTaker/caretaker_bottom_nav.dart';
import 'admin/admin_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final oneSignalAppId = "73673a14-2de9-44c4-a9c5-dd531da39b59"; 
     OneSignal.initialize(oneSignalAppId);
     OneSignal.Notifications.requestPermission(true);

  final geminiApiKey = "AIzaSyAZ9H-7y_aWH38HSCrOBbshkLmdLTLGvS4";
    Gemini.init(apiKey: geminiApiKey);

  final prefs = await SharedPreferences.getInstance();
  final user = FirebaseAuth.instance.currentUser;
  Widget initialScreen = const WelcomePage();

  if (user != null) {
    try {
      await OneSignal.login(user.uid);
    } catch (e) {
      debugPrint('OneSignal login failed in main: $e');
    }
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: initialScreen,
    );
  }
}