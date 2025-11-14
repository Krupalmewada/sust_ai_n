import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sust_ai_n/features/home/receipe/recipe_detail_page.dart';
import 'package:sust_ai_n/main.dart';
import '../../../services/inventory_service.dart';

class RecipesPage extends StatefulWidget {
  final List<String> inventoryItems;

  const RecipesPage({super.key, required this.inventoryItems});

  @override
  RecipesPageState createState() => RecipesPageState();
}

class RecipesPageState extends State<RecipesPage> with RouteAware {
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

  static const String _apiKey = '**';
  static const String _baseUrl = 'https://api.spoonacular.com';

  @override
  void initState() {
    super.initState();
    _fetchRecipes(widget.inventoryItems);
  }

  // 🔁 Subscribe to route changes (detect when coming back from ScanPage)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // 🔄 Automatically refresh recipes when returning from ScanPage
  @override
  void didPopNext() async {
    debugPrint("🔄 Returned from Scan Page – refreshing recipes...");
    final updatedItems = await InventoryService().fetchInventoryItems();
    _fetchRecipes(updatedItems);
  }

  // 🔍 Called externally (from ReceipeBasePage) to perform search
  void searchRecipes(String query) {
    if (query.isEmpty) {
      _fetchRecipes(widget.inventoryItems);
    } else {
      _fetchRecipes([query]);
    }
  }

  // ❌ Called externally (from ReceipeBasePage) to clear search
  void clearSearch() {
    _fetchRecipes(widget.inventoryItems);
  }

  // 🔁 Refresh when Firestore inventory changes
  void refreshWithNewInventory(List<String> updatedItems) {
    if (!mounted) return;
    debugPrint('♻️ Inventory updated: ${updatedItems.length} items');
    _fetchRecipes(updatedItems);
  }

  // 🍳 Fetch recipes based on ingredients
  Future<void> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final ingredientString = ingredients
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .join(',');

      const desiredCount = 5; // how many valid recipes to show
      final List<Map<String, dynamic>> validRecipes = [];
      int attempts = 0;

      while (validRecipes.length < desiredCount && attempts < 3) {
        attempts++;

        // 1️⃣ Find recipes by ingredients
        final findUri = Uri.https(
          'api.spoonacular.com',
          '/recipes/findByIngredients',
          {
            'ingredients': ingredientString,
            'number': '${desiredCount * 2}', // fetch extra for filtering
            'ranking': '2',
            'apiKey': _apiKey,
          },
        );

        final findRes = await http.get(findUri);
        if (findRes.statusCode != 200) {
          debugPrint('❌ findByIngredients failed: ${findRes.body}');
          break;
        }

        final List findData = json.decode(findRes.body);
        if (findData.isEmpty) {
          debugPrint('⚠️ No recipes found.');
          break;
        }

        // 2️⃣ Extract recipe IDs
        final ids = findData.map((r) => r['id'].toString()).toList();
        final idsParam = ids.join(',');

        // 3️⃣ Fetch detailed info (nutrition + images)
        final infoUri = Uri.https(
          'api.spoonacular.com',
          '/recipes/informationBulk',
          {
            'ids': idsParam,
            'includeNutrition': 'true',
            'apiKey': _apiKey,
          },
        );

        final infoRes = await http.get(infoUri);
        if (infoRes.statusCode != 200) {
          debugPrint('⚠️ Bulk info failed: ${infoRes.body}');
          break;
        }

        final List infoData = json.decode(infoRes.body);

        // 4️⃣ Filter and enrich valid recipes
        for (final recipe in infoData) {
          final imageUrl = recipe['image'] ?? '';
          if (imageUrl.isEmpty ||
              !imageUrl.startsWith('http') ||
              imageUrl.contains('404')) continue;

          final nutrients = (recipe['nutrition']?['nutrients'] as List?) ?? [];
          final calRow = nutrients.cast<Map>().firstWhere(
                (n) => n['name'] == 'Calories',
            orElse: () => {},
          );

          final calories = calRow.isNotEmpty
              ? '${calRow['amount'].round()} ${calRow['unit']}'
              : 'N/A';
          final servings = recipe['servings']?.toString() ?? 'N/A';

          validRecipes.add({
            'id': recipe['id'],
            'title': recipe['title'],
            'image': imageUrl,
            'calories': calories,
            'servings': servings,
          });

          if (validRecipes.length >= desiredCount) break;
        }
      }

      // 5️⃣ Update UI
      if (!mounted) return;
      setState(() => _recipes = validRecipes);

      debugPrint('✅ Loaded ${_recipes.length} valid recipes');
    } catch (e) {
      debugPrint('❌ Exception fetching recipes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _recipes.isEmpty
        ? const Center(child: Text("No recipes found"))
        : ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(
                    recipeId: recipe['id'],
                    title: recipe['title'],
                  ),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  recipe['image'] ?? '',
                  width: width * 0.18,
                  height: width * 0.18,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    width: width * 0.18,
                    height: width * 0.18,
                    alignment: Alignment.center,
                    child: const Icon(Icons.fastfood_rounded,
                        color: Colors.grey),
                  ),
                ),
              ),
              title: Text(
                recipe['title'] ?? 'Untitled',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                "🍽 ${recipe['servings'] ?? 'N/A'} servings  |  🔥 ${recipe['calories'] ?? 'N/A'} kcal",
                style:
                const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}
