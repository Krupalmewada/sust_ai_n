import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/inventory_service.dart';
import '../../../widgets/bottom_nav_bar.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryService _inventoryService = InventoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String _apiKey;
  bool _isLoadingRecipes = false;

  Map<String, int> _categoryCounts = {};
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _lastPurchased = [];
  final Map<String, Color> _categoryColorMap = {};

  @override
  void initState() {
    super.initState();
    _listenToInventory();
    _fetchTopRecipes();
    _listenToLastPurchased();
    _apiKey = dotenv.env['SpoonacularapiKey'] ?? '';
  }

  /// 🔹 Listen to inventory for chart data
  void _listenToInventory() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .snapshots()
        .listen((snapshot) {
      final Map<String, int> categoryCounts = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawCategory = (data['category'] ?? '').toString().trim().toLowerCase();
        final rawAisle = (data['aisle'] ?? '').toString().trim().toLowerCase();

        final category = (rawCategory.isEmpty ||
            rawCategory == 'general' ||
            rawCategory == 'misc' ||
            rawCategory == 'other')
            ? (rawAisle.isNotEmpty ? _capitalize(rawAisle) : 'Uncategorized')
            : _capitalize(rawCategory);

        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      setState(() => _categoryCounts = categoryCounts);
    });
  }

  /// 🔹 Listen for last purchased items (realtime)
  void _listenToLastPurchased() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      setState(() => _lastPurchased = items);
    });
  }

  String _capitalize(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  /// 🎨 Unique color for each category
  Color _getColorForCategory(String category) {
    if (_categoryColorMap.containsKey(category)) return _categoryColorMap[category]!;
    final random = Random();
    Color color;
    do {
      color = Color.fromARGB(
        255,
        100 + random.nextInt(155),
        100 + random.nextInt(155),
        100 + random.nextInt(155),
      );
    } while (_categoryColorMap.values.contains(color));
    _categoryColorMap[category] = color;
    return color;
  }

  /// 🍳 Fetch recipes dynamically
  Future<void> _fetchTopRecipes() async {
    setState(() => _isLoadingRecipes = true);
    try {
      final ingredients = await _inventoryService.fetchInventoryItems();
      if (ingredients.isEmpty) {
        setState(() => _recipes = []);
        return;
      }

      final url = Uri.https(
        'api.spoonacular.com',
        '/recipes/findByIngredients',
        {
          'ingredients': ingredients.take(10).join(','),
          'number': '5',
          'ranking': '1',
          'ignorePantry': 'true',
          'apiKey': _apiKey,
        },
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final recipes = await Future.wait(data.map((r) async {
          final map = r as Map<String, dynamic>;
          try {
            final info = await http.get(Uri.https(
                'api.spoonacular.com',
                '/recipes/${map['id']}/information',
                {'apiKey': _apiKey}));
            if (info.statusCode == 200) {
              final infodata = json.decode(info.body);
              map['servings'] = infodata['servings'] ?? '-';
            }
          } catch (_) {
            map['servings'] = '-';
          }
          return map;
        }));
        setState(() => _recipes = recipes);
      }
    } catch (e) {
      debugPrint('Recipe fetch error: $e');
    } finally {
      setState(() => _isLoadingRecipes = false);
    }
  }

  String _getFallbackEmoji(String name) {
    name = name.toLowerCase();
    if (name.contains('apple')) return '🍎';
    if (name.contains('banana')) return '🍌';
    if (name.contains('bread')) return '🍞';
    if (name.contains('milk')) return '🥛';
    if (name.contains('chicken')) return '🍗';
    if (name.contains('tomato')) return '🍅';
    return '🛒';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(width * 0.045),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    onPressed: _fetchTopRecipes,
                    icon: const Icon(Icons.refresh, size: 26),
                  ),
                ],
              ),
              SizedBox(height: width * 0.05),

              // Search Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: width * 0.03),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: width * 0.02),
                    const Expanded(
                      child: Text("Ask my AI", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: width * 0.05),

              // Inventory Overview
              const Text("Inventory Overview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: width * 0.04),

              if (_categoryCounts.isEmpty)
                const Center(child: Text("🧺 No items in your inventory"))
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 1,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: width * 0.08,
                            sections: _categoryCounts.entries.map((e) {
                              final color = _getColorForCategory(e.key);
                              return PieChartSectionData(
                                color: color,
                                value: e.value.toDouble(),
                                title: '',
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.04),
                    Flexible(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _categoryCounts.entries
                            .map((e) => _CategoryTile(
                          color: _getColorForCategory(e.key),
                          name: e.key,
                          count: e.value,
                        ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: width * 0.08),

              // 🛒 LAST PURCHASED SECTION (fully flexible + overflow-proof)
              const Text(
                "Last Purchased 🛒",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: width * 0.04),

              if (_lastPurchased.isEmpty)
                const Text("No recent purchases found.")
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: width * 0.45, // taller to adapt wrapped text
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _lastPurchased.length,
                      padding: EdgeInsets.only(right: width * 0.03),
                      itemBuilder: (context, i) {
                        final item = _lastPurchased[i];
                        final name = item['name'] ?? 'Unnamed';
                        final qty = item['qty'] ?? '-';
                        final unit = item['unit'] ?? '';
                        final expiry = item['expiryDate']?.toDate()?.toString().split(' ').first ?? '-';

                        return Padding(
                          padding: EdgeInsets.only(left: width * 0.03),
                          child: IntrinsicWidth(
                            child: Container(
                              constraints: BoxConstraints(
                                minWidth: width * 0.26,
                                maxWidth: width * 0.55, // auto-width range
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.035,
                                vertical: width * 0.03,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                              ),
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 🧩 Emoji / Fallback icon
                                    FutureBuilder<String?>(
                                      future: _inventoryService.fetchIngredientImage(name),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            height: 40,
                                            width: 40,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          );
                                        }

                                        final imgUrl = snapshot.data;

                                        if (imgUrl != null) {
                                          // ✅ Show network image from Spoonacular
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              imgUrl,
                                              height: width * 0.12,
                                              width: width * 0.12,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Image.asset(
                                                'assets/images/diet.png',
                                                height: width * 0.12,
                                                width: width * 0.12,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          );
                                        } else {
                                          // ✅ Fallback to your local asset
                                          return Image.asset(
                                            'assets/images/diet.png',
                                            height: width * 0.12,
                                            width: width * 0.12,
                                            fit: BoxFit.contain,
                                          );
                                        }
                                      },
                                    ),

                                    SizedBox(height: width * 0.015),

                                    // 🧾 Item name
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: width * 0.034,
                                      ),
                                    ),
                                    SizedBox(height: width * 0.012),

                                    // 🔹 Quantity + unit
                                    Text(
                                      '$qty $unit',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: width * 0.028,
                                      ),
                                    ),

                                    // 🗓 Expiry
                                    Text(
                                      'Exp: $expiry',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: width * 0.026,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              SizedBox(height: width * 0.08),



              // Recipes
              const Text("For You 🍳",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: width * 0.04),

              _isLoadingRecipes
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
                  ? const Text("No recipe suggestions yet — add items 🧺",
                  style: TextStyle(color: Colors.grey))
                  : SizedBox(
                height: width * 0.70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recipes.length,
                  itemBuilder: (context, i) {
                    final recipe = _recipes[i];
                    final title = recipe['title'] ?? 'Untitled';
                    final image = recipe['image'] ?? '';
                    final servings = recipe['servings'] ?? '-';

                    return Container(
                      width: width * 0.58,
                      margin: EdgeInsets.only(right: width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              // ================= IMAGE =================
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: image.isNotEmpty
                                    ? Image.network(
                                    image,
                                    width: double.infinity,
                                    height: width * 0.35,
                                    fit: BoxFit.cover)
                                    : Container(
                                  height: width * 0.35,
                                  color: const Color(0xFFF4F4F4),
                                  child: Center(
                                    child: Text(_getFallbackEmoji(title),
                                        style: TextStyle(fontSize: width * 0.14)),
                                  ),
                                ),
                              ),

                              // ================= ICONS (LIKE + ADD) =================
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Row(
                                  children: [
                                    // ❤️ LIKE
                                    InkWell(
                                      onTap: () async {
                                        await _inventoryService.likeRecipe(recipe);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Recipe added to Liked ❤️"))
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white70,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.favorite_border, color: Colors.red),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // ➕ ADD
                                    InkWell(
                                      onTap: () async {
                                        await _inventoryService.saveRecipe(recipe);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Recipe saved 📌"))
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white70,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add, color: Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ================= TEXT =================
                          Padding(
                            padding: EdgeInsets.all(width * 0.03),
                            child: Column(
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: width * 0.04,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: width * 0.02),
                                Text(
                                  "Servings: $servings",
                                  style: TextStyle(color: Colors.grey, fontSize: width * 0.03),
                                ),
                              ],
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
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, '/recipes');
          else if (index == 2) Navigator.pushNamed(context, '/userinventory');
          else if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }
}

// ------------------- Category Tile -------------------
class _CategoryTile extends StatelessWidget {
  final Color color;
  final String name;
  final int count;
  const _CategoryTile({required this.color, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.008),
      child: Row(
        children: [
          CircleAvatar(radius: width * 0.015, backgroundColor: color),
          SizedBox(width: width * 0.025),
          Expanded(child: Text(name, style: TextStyle(fontSize: width * 0.035))),
          Text(count.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: width * 0.035)),
        ],
      ),
    );
  }
}
