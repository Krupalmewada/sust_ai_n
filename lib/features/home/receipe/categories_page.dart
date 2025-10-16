import 'package:flutter/material.dart';

import '../../../widgets/bottom_nav_bar.dart';
import '../../../widgets/inventory_tab_selector.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final List<Map<String, dynamic>> categories = [
      {"name": "Fruits", "color": 0xFFFFEAEA, "emoji": "🍊"},
      {"name": "Dairy", "color": 0xFFE6F0FF, "emoji": "🥛"},
      {"name": "Vegetables", "color": 0xFFEFEAFF, "emoji": "🥦"},
      {"name": "Carbs", "color": 0xFFFFF6E5, "emoji": "🍞"},
      {"name": "Meat", "color": 0xFFE8F6FF, "emoji": "🥩"},
      {"name": "Oils", "color": 0xFFFFFBEA, "emoji": "🫒"},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Inventory",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: width * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Search bar
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
                  const Expanded(
                    child: Text(
                      "Search for items",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.03),

            const Text(
              "Overall",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: height * 0.015),

            // Tabs row (Categories highlighted)
            InventoryTabSelector(
              selectedIndex: 0, // Categories selected
              onTabSelected: (index) {
                if (index == 1) {
                  Navigator.pushNamed(context, '/inventoryList');
                } else if (index == 2) {
                  Navigator.pushNamed(context, '/recipes');
                }
              },
            ),

            SizedBox(height: height * 0.02),

            // Grid of categories
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: width * 0.05,
                  crossAxisSpacing: width * 0.05,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Color(cat["color"]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat["emoji"],
                          style: TextStyle(fontSize: width * 0.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat["name"],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Recipes section
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/inventory');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/recipes');
          }
        },
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.black : Colors.grey,
          ),
        ),
        if (selected)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 3,
            width: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF23C483),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}
