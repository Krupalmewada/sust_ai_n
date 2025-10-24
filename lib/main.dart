import 'package:flutter/material.dart';
import 'package:sust_ai_n/features/ocr_scan/presentation/pages/scan_page.dart';
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
        '/recipes': (context) => const RecipesPage(inventoryItems: []),
        '/categories': (context) => const CategoriesPage(),
        '/scan' :(context)=> const ScanPage(),
      },
    );
  }
}
