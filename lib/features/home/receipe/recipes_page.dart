import 'package:flutter/material.dart';
import '../../../services/spoonacular_service.dart'; // 👈 use your existing service
import '../../../widgets/bottom_nav_bar.dart';
import '../../../widgets/inventory_tab_selector.dart';

class RecipesPage extends StatefulWidget {
  final List<String> inventoryItems;

  const RecipesPage({super.key, required this.inventoryItems});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    _fetchRecipes(widget.inventoryItems);
  }

  Future<void> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final recipes =
      await SpoonacularService.getRecipesFromIngredients(ingredients);

      // Fetch portion + calorie info for each recipe
      final detailedRecipes = await Future.wait(
        recipes.map((r) async {
          try {
            final details = await SpoonacularService.getRecipeDetails(r['id']);
            return {
              ...r,
              'servings': details['servings'],
              'calories': details['calories'],
            };
          } catch (e) {
            print('⚠️ Skipping details for ${r['title']}: $e');
            return {
              ...r,
              'servings': 'N/A',
              'calories': 'N/A',
            };
          }
        }),
      );

      setState(() {
        _recipes = detailedRecipes;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch recipes')),
      );
    }
  }



  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    final ingredients = [...widget.inventoryItems];
    if (query.isNotEmpty) {
      ingredients.add(query);
    }
    await _fetchRecipes(ingredients);
  }

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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Add ingredient to refine search",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    onPressed: _onSearch,
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.03),

            const Text(
              "Suggested Recipes",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: height * 0.015),

            InventoryTabSelector(
              selectedIndex: 2,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.pushNamed(context, '/categories');
                } else if (index == 1) {
                  Navigator.pushNamed(context, '/inventoryList');
                }
              },
            ),

            SizedBox(height: height * 0.02),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
                  ? const Center(child: Text("No recipes found"))
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  final recipe = _recipes[index];
                  return _RecipeItem(
                    imageUrl: recipe['image'],
                    title: recipe['title'],
                    subtitle:
                    "${recipe['servings'] ?? 'N/A'} servings • ${recipe['calories'] ?? 'N/A'} kcal",
                    bgColor: const Color(0xFFF5F5F5),
                  );
                },
              ),
            ),
          ],
        ),
      ),

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
}

// ------------------ COMPONENT ------------------

class _RecipeItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final Color bgColor;

  const _RecipeItem({
    required this.imageUrl,
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
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
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
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.black54, size: 18),
        ],
      ),
    );
  }
}
