import 'package:flutter/material.dart';
import 'features/home/inventory/inventory_tab.dart';
import 'features/home/receipe/categories_page.dart';
import 'features/home/receipe/recipes_page.dart';

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
      initialRoute: '/inventory',
      routes: {
        '/inventory': (context) => const InventoryTab(),
        '/recipes': (context) => const RecipesPage(),
        '/categories': (context) => const CategoriesPage(),
      },
    );
  }
}
