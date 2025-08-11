import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/connection_screen.dart';
import 'services/donation_service.dart'; // Import the service

// The entry point for the entire application.
void main() {
  runApp(
    // Wrap your app with a MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DonationService()..initialize()),
      ],
      child: const RadioCommanderApp(),
    ),
  );
}

class RadioCommanderApp extends StatelessWidget {
  const RadioCommanderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Benshi Commander',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        // Use CardThemeData for Material 3
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      // The app always starts at the ConnectionScreen.
      home: const ConnectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}