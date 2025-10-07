import 'package:flutter/material.dart';
import 'features/onboarding/login_screen.dart';
import 'features/onboarding/name_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SustAIn',
      initialRoute: '/',
      routes: {
        '/':(context) => const LoginScreen(),
        '/name':(context) => const NameScreen()
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // home: const InventoryTab(),
    );
  }
}
