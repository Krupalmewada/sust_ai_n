import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Import all feature screens
import 'features/Login/user_login.dart';
import 'features/home/inventory/inventory_tab.dart';
import 'features/home/receipe/receipe_base_page.dart';
import 'features/home/receipe/recipes_page.dart';
import 'features/home/receipe/categories_page.dart';
import 'features/home/receipe/grocery_list_page.dart';
import 'features/ocr_scan/presentation/pages/scan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
        scaffoldBackgroundColor: Colors.white,
      ),

      // ✅ Inject RouteObserver globally
      navigatorObservers: [routeObserver],

      // ✅ Listen to FirebaseAuth state to decide start page
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data != null) {
            // User is logged in
            return const InventoryTab();
          } else {
            // User is not logged in
            return const UserLogin();
          }
        },
      ),

      // Named routes
      routes: {
        '/login': (context) => const UserLogin(),
        '/inventory': (context) => const InventoryTab(),
        '/scan': (context) => const ScanPage(),
        '/recipes': (context) => const ReceipeBasePage(),
        '/recipesPage': (context) => const RecipesPage(inventoryItems: []),
        '/categories': (context) => const CategoriesPage(),
        '/groceryList': (context) => const GroceryListPage(),
      },
    );
  }
}
