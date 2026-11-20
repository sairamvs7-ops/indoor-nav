import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'providers/navigation_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Firebase settings are not committed. Copy firebase_config.example.json to
    // firebase_config.json, fill it in, and run:
    //   flutter run --dart-define-from-file=firebase_config.json
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL'),
      ),
    );
    print("Firebase Initialized Successfully!");

    // Test Connection to Firestore (as required by instructions)
    await testFirebaseConnection();
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => NavigationProvider(),
      child: const IndoorNavApp(),
    ),
  );
}

Future<void> testFirebaseConnection() async {
  try {
    final db = FirebaseDatabase.instance.ref();
    // Try to read a test path to check connection
    await db.child('test_connection').get();
    print("Firebase Realtime Database Connection: SUCCESS");
  } catch (error) {
    if (error.toString().contains('client is offline')) {
      print("Firebase Error: Client is offline. Check your configuration and internet connection.");
    } else if (error.toString().contains('permission_denied')) {
      print("Firebase Error: Permission Denied. Check your Database Rules.");
    } else {
      print("Firebase Connection Error: $error");
    }
  }
}

class IndoorNavApp extends StatelessWidget {
  const IndoorNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndoorNav Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Colors.green,
          surface: Color(0xFF0A0A0A),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
