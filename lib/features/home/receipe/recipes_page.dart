import 'package:flutter/material.dart';

import '../../../widgets/bottom_nav_bar.dart';
import '../../../widgets/inventory_tab_selector.dart';


class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

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
          "Recipes",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
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
              "Recent",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: height * 0.015),

            // Category Tabs
            InventoryTabSelector(
              selectedIndex: 2, // Recipes selected
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.pushNamed(context, '/categories');
                } else if (index == 1) {
                  Navigator.pushNamed(context, '/inventoryList');
                }
              },
            ),



            SizedBox(height: height * 0.02),

            // 📋 Recipe list
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: const [
                  _RecipeItem(
                    image: "🍲",
                    title: "Stir-fry chicken",
                    subtitle: "Dinner / 20 mins",
                    bgColor: Color(0xFFFFF6E5),
                  ),
                  _RecipeItem(
                    image: "🍜",
                    title: "Ramen",
                    subtitle: "Lunch / 15 mins",
                    bgColor: Color(0xFFEDEBFF),
                  ),
                  _RecipeItem(
                    image: "🥗",
                    title: "Salmon salad",
                    subtitle: "Lunch / 15 mins",
                    bgColor: Color(0xFFFFEFE9),
                  ),
                  _RecipeItem(
                    image: "🍳",
                    title: "Tropical fruit salad",
                    subtitle: "Breakfast / 15 mins",
                    bgColor: Color(0xFFE8F6FF),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Common bottom nav bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Recipe tab
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/inventory');
          } else if (index == 1) {
            // Already on Recipes
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }
}

// ------------------ COMPONENT ------------------

class _RecipeItem extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final Color bgColor;

  const _RecipeItem({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(bottom: width * 0.04),
      child: Row(
        children: [
          Container(
            width: width * 0.16,
            height: width * 0.16,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(image, style: TextStyle(fontSize: width * 0.08)),
            ),
          ),
          SizedBox(width: width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black54, size: 18),
        ],
      ),
    );
  }
}
