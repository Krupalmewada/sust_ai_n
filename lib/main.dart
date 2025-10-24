import 'package:flutter/material.dart';
import 'features/home/inventory/inventory_tab.dart';
import 'features/ocr_scan/presentation/pages/scan_page.dart';


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
      routes: {
        '/scan': (_) => const ScanPage(),            // <-- add this
      },
          home: const InventoryTab(),
    );
  }
}
