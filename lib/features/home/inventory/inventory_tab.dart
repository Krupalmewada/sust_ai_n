import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../widgets/bottom_nav_bar.dart';

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size; // Get screen size
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.045,
            vertical: height * 0.015,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "Hi Krupal,\nHere’s what you have!",
                        style: TextStyle(
                          fontSize: width * 0.055,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF212121),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.shopping_cart_outlined, size: 26),
                    ),
                  ],
                ),
                SizedBox(height: height * 0.02),

                // SEARCH BAR
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: width * 0.04, vertical: height * 0.012),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: width * 0.02),
                      const Expanded(
                        child: Text(
                          "Ask my AI",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: height * 0.03),

                // INVENTORY SECTION
                const Text(
                  "Inventory",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: height * 0.01),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: const [
                    Text("Items  ",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    Text("Expense  ",
                        style: TextStyle(color: Colors.grey)),
                    Text("Budget", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                SizedBox(height: height * 0.02),

                // CHART + LIST
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: width * 0.08,
                            sections: [
                              PieChartSectionData(
                                  color: const Color(0xFF23C483),
                                  value: 5,
                                  title: ''),
                              PieChartSectionData(
                                  color: const Color(0xFFFF9F43),
                                  value: 10,
                                  title: ''),
                              PieChartSectionData(
                                  color: const Color(0xFF4FB8FF),
                                  value: 2,
                                  title: ''),
                              PieChartSectionData(
                                  color: const Color(0xFF8BC34A),
                                  value: 9,
                                  title: ''),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _CategoryTile(
                              color: Color(0xFF4FB8FF),
                              name: "Beverage",
                              count: 5),
                          _CategoryTile(
                              color: Color(0xFFFF6B6B), name: "Meat", count: 2),
                          _CategoryTile(
                              color: Color(0xFFFF9F43),
                              name: "Dairy",
                              count: 10),
                          _CategoryTile(
                              color: Color(0xFF23C483),
                              name: "Vegetables",
                              count: 9),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: height * 0.03),

                // LAST PURCHASED
                // ---------------- LAST PURCHASED -----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "Last Purchased",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.info_outline, color: Colors.grey),
                  ],
                ),
                SizedBox(height: height * 0.015),

                SizedBox(
                  height: width * 0.28, // 🔹 responsive height (scales by screen width)
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: const [
                      _SmallItemCard(
                        emoji: "🍌",
                        bgColor: Color(0xFFFFF6E5),
                        dotColor: Color(0xFFFF5A5F),
                      ),
                      _SmallItemCard(
                        emoji: "🍇",
                        bgColor: Color(0xFFEDEBFF),
                        dotColor: Color(0xFFFFC107),
                      ),
                      _SmallItemCard(
                        emoji: "🍎",
                        bgColor: Color(0xFFFFEFE9),
                        dotColor: Color(0xFFFFC107),
                      ),
                      _SmallItemCard(
                        emoji: "🍓",
                        bgColor: Color(0xFFE8F6FF),
                        dotColor: Color(0xFF23C483),
                      ),
                    ],
                  ),
                ),


                // FOR YOU
                // ---------------- FOR YOU ----------------
                const Text(
                  "For you",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: height * 0.008),

// Tabs row (just visual for now)
                Row(
                  children: const [
                    // _TabLabel(label: "For you", selected: true),
                    // SizedBox(width: 14),
                    _TabLabel(label: "Popular"),
                    SizedBox(width: 14),
                    _TabLabel(label: "Trending"),
                    SizedBox(width: 14),
                    _TabLabel(label: "Cuisine"),
                  ],
                ),
                SizedBox(height: height * 0.016),

                SizedBox(
                  // tie the list height to screen width so cards scale nicely
                  height: width * 0.70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: const [
                      _FoodCard(
                        title: "Stir-fry chicken",
                        // use one of these two: imageEmoji OR imageAsset
                        imageEmoji: "🍲",
                        // imageAsset: "assets/foods/stirfry.png",
                        bgColor: Color(0xFFFFF7EC),
                      ),
                      _FoodCard(
                        title: "Ramen",
                        imageEmoji: "🍜",
                        // imageAsset: "assets/foods/ramen.png",
                        bgColor: Color(0xFFF1EEFF),
                      ),
                      _FoodCard(
                        title: "Pasta",
                        imageEmoji: "🍝",
                        // imageAsset: "assets/foods/pasta.png",
                        bgColor: Color(0xFFFFF1F1),
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
      ),

      //Bottom nav bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0, // Highlight Home / InventoryTab as active
        onTap: (index) {
          if (index == 0) {
            // Already on InventoryTab
          } else if (index == 1) {
            Navigator.pushNamed(context, '/recipes');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/userinventory');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),




    );
  }
}

// ------------------- COMPONENTS ------------------


class _CategoryTile extends StatelessWidget {
  final Color color;
  final String name;
  final int count;

  const _CategoryTile(
      {required this.color, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;
  const _TabLabel({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: w * 0.045,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF222222) : Colors.black54,
          ),
        ),
        if (selected)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 3,
            width: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF23C483),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}

class _FoodCard extends StatelessWidget {
  final String title;
  final String? imageAsset;   // optional: real image asset
  final String? imageEmoji;   // optional: emoji fallback
  final Color bgColor;

  const _FoodCard({
    required this.title,
    this.imageAsset,
    this.imageEmoji,
    this.bgColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    // equal card sizing
    final cardWidth  = w * 0.58;
    final corner     = 22.0;
    final pad        = w * 0.05;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: w * 0.04),
      child: Stack(
        children: [
          // Card body
          Container(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + w * 0.09),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(corner),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Heart (top-right inside card)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.favorite_border,
                      color: const Color(0xFF23C483), size: w * 0.06),
                ),
                SizedBox(height: w * 0.02),

                // Circular image with subtle white ring
                Container(
                  width: cardWidth * 0.52,
                  height: cardWidth * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Center(
                      child: imageAsset != null
                          ? Image.asset(
                        imageAsset!,
                        width: cardWidth * 0.48,
                        height: cardWidth * 0.48,
                        fit: BoxFit.cover,
                      )
                          : Text(
                        imageEmoji ?? "🍽️",
                        style: TextStyle(fontSize: w * 0.16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: w * 0.04),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: w * 0.045,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),

          // Floating + button (bottom-right)
          Positioned(
            right: w * 0.04,
            bottom: w * 0.04,
            child: Container(
              width: w * 0.10,
              height: w * 0.10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: const Color(0xFF23C483), size: w * 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallItemCard extends StatelessWidget {
  final String emoji;
  final Color bgColor;
  final Color dotColor;

  const _SmallItemCard({
    required this.emoji,
    required this.bgColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // 🔹 Use a size relative to screen width (responsive)
    final double cardSize = width * 0.22; // square box size

    return Container(
      width: cardSize,
      margin: EdgeInsets.only(right: width * 0.04),
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: cardSize,
            width: cardSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: width * 0.1), // scales emoji too
              ),
            ),
          ),
          Positioned(
            bottom: width * 0.02,
            right: width * 0.02,
            child: CircleAvatar(
              radius: width * 0.02, // scales with screen
              backgroundColor: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}
