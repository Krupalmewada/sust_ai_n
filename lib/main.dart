import 'package:flutter/material.dart';
import 'features/profile/profile_page.dart'; // NEW
// import 'features/home/inventory/inventory_tab.dart'; // keep for later if needed

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SustAIn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const ProfilePage(), // ← temporary home with summary + button
    );
  }
}
