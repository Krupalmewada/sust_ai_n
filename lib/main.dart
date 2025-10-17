import 'package:flutter/material.dart';
import 'package:sust_ai_n/features/onboarding/peeley_service.dart';
import 'package:sust_ai_n/features/onboarding/peeley_models.dart';
import 'features/onboarding/peeley_chat_screen.dart';
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
        '/': (context) => const LoginScreen(),
        '/name': (context) => PeleyChatScreen(
          inventory: [
            FoodItem(
              name: 'Milk',
              expiryDate: DateTime.now().add(Duration(days: 3)),
              category: 'dairy',
              quantity: 1,
            ),
            FoodItem(
              name: 'Banana',
              expiryDate: DateTime.now().add(Duration(days: 2)),
              category: 'fruits',
              quantity: 4,
            ),
            FoodItem(
              name: 'Chicken',
              expiryDate: DateTime.now().add(Duration(days: 1)),
              category: 'proteins',
              quantity: 500,
            ),
            FoodItem(
              name: 'Lettuce',
              expiryDate: DateTime.now().add(Duration(days: 5)),
              category: 'vegetables',
              quantity: 1,
            ),
            FoodItem(
              name: 'Rice',
              expiryDate: DateTime.now().add(Duration(days: 180)),
              category: 'pantry',
              quantity: 1000,
            ),
          ],
        ),
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
    );
  }
}
