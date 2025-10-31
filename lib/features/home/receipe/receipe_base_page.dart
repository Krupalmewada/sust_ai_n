import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../widgets/bottom_nav_bar.dart';
import '../../../widgets/inventory_tab_selector.dart';
import 'categories_page.dart';
import 'grocery_list_page.dart';
import 'recipes_page.dart';

class ReceipeBasePage extends StatefulWidget {
  const ReceipeBasePage({super.key});

  @override
  State<ReceipeBasePage> createState() => _ReceipeBasePageState();
}

class _ReceipeBasePageState extends State<ReceipeBasePage> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  List<String> _inventoryItems = [];
  bool _isLoadingInventory = true;

  @override
  void initState() {
    super.initState();
    _fetchInventoryItems();
  }

  /// 🔹 Fetch inventory items from Firestore
  Future<void> _fetchInventoryItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory');

      final snapshot = await ref.get();

      final items = snapshot.docs
          .map((doc) => doc['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      setState(() {
        _inventoryItems = items;
        _isLoadingInventory = false;
      });

      debugPrint('🧾 Loaded inventory items: $_inventoryItems');
    } catch (e) {
      debugPrint('❌ Failed to fetch inventory: $e');
      setState(() => _isLoadingInventory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,

      // ---------- App Bar ----------
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectedTabIndex == 0
              ? "Recipes"
              : _selectedTabIndex == 1
              ? "My Grocery List"
              : "My Categories",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      // ---------- Body ----------
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: width * 0.05),
        child: _isLoadingInventory
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Shared Search Bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.04,
                vertical: height * 0.012,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: width * 0.02),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // Send search input dynamically to recipes page only
                        if (_selectedTabIndex == 0) {
                          recipesPageKey.currentState
                              ?.searchRecipes(value.trim());
                        }
                      },
                      decoration: InputDecoration(
                        hintText: _selectedTabIndex == 0
                            ? "Search recipes"
                            : _selectedTabIndex == 1
                            ? "Search grocery list"
                            : "Search categories",
                        border: InputBorder.none,
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.03),

            // 📋 Section Heading
            Text(
              _selectedTabIndex == 0
                  ? "Suggested Recipes"
                  : _selectedTabIndex == 1
                  ? "Your Grocery List"
                  : "Your Categories",
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: height * 0.015),

            // 🔘 Tab Selector
            InventoryTabSelector(
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
            ),

            SizedBox(height: height * 0.02),

            // 🧩 Dynamic Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentView(),
              ),
            ),
          ],
        ),
      ),

      // ---------- Bottom Navigation ----------
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/inventory');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }

  // ---------- Tab Switcher ----------
  Widget _buildCurrentView() {
    switch (_selectedTabIndex) {
      case 0:
        return RecipesPage(
          key: recipesPageKey,
          inventoryItems: _inventoryItems,
        );
      case 1:
        return const GroceryListPage();
      case 2:
      default:
        return const CategoriesPage();
    }
  }
}

// Global key to access RecipesPage state
final GlobalKey<RecipesPageState> recipesPageKey = GlobalKey<RecipesPageState>();

