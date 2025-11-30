import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../widgets/recipe_card.dart';
import '../../../services/inventory_service.dart';
import 'package:sust_ai_n/main.dart';

class RecipesPage extends StatefulWidget {
  final List<String> inventoryItems;

  const RecipesPage({super.key, required this.inventoryItems});

  @override
  RecipesPageState createState() => RecipesPageState();
}

class RecipesPageState extends State<RecipesPage> with RouteAware {
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

  final String _apiKey = dotenv.env['SpoonacularapiKey'] ?? '';

  @override
  void initState() {
    super.initState();
    _fetchRecipes(widget.inventoryItems);
  }

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

  @override
  void didPopNext() async {
    final updatedItems = await InventoryService().fetchInventoryItems();
    _fetchRecipes(updatedItems);
  }

  void searchRecipes(String query) {
    if (query.isEmpty) {
      _fetchRecipes(widget.inventoryItems);
    } else {
      _fetchRecipes([query]);
    }
  }

  void clearSearch() {
    _fetchRecipes(widget.inventoryItems);
  }

  void refreshWithNewInventory(List<String> updatedItems) {
    if (!mounted) return;
    _fetchRecipes(updatedItems);
  }

  Future<void> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final ingredientString = ingredients.join(',');
      const desiredCount = 15;

      final findRes = await http.get(
        Uri.https(
          'api.spoonacular.com',
          '/recipes/findByIngredients',
          {
            'ingredients': ingredientString,
            'number': '${desiredCount * 2}',
            'ranking': '2',
            'apiKey': _apiKey,
          },
        ),
      );

      if (findRes.statusCode != 200) return;

      final List findData = json.decode(findRes.body);

      final ids = findData.map((r) => r['id'].toString()).toList();
      final bulk = await http.get(
        Uri.https(
          'api.spoonacular.com',
          '/recipes/informationBulk',
          {
            'ids': ids.join(','),
            'includeNutrition': 'true',
            'includeIngredients': 'true',
            'apiKey': _apiKey,
          },
        ),
      );

      if (bulk.statusCode != 200) return;
      final List infoData = json.decode(bulk.body);

      final List<Map<String, dynamic>> filtered = [];

      for (final recipe in infoData) {
        if (filtered.length >= desiredCount) break;

        final url = recipe['image'] ?? '';
        if (!url.startsWith("http")) continue;

        final nutrients = recipe['nutrition']?['nutrients'] ?? [];
        final calRow = nutrients.firstWhere(
              (e) => e['name'] == 'Calories',
          orElse: () => null,
        );

        filtered.add({
          'id': recipe['id'],
          'title': recipe['title'],
          'image': url,
          'servings': recipe['servings'],
          'calories': calRow != null ? calRow['amount'] : null,
          'extendedIngredients': recipe['extendedIngredients'] ?? [],
        });
      }

      if (!mounted) return;
      setState(() => _recipes = filtered);

    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recipes.isEmpty) {
      return const Center(child: Text("No recipes found"));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];

        return RecipeCard(
          key: ValueKey(recipe['id']),
          recipe: recipe,

          // NEW CALLBACKS — REQUIRED
          onLikeChanged: (liked) {
            // do nothing, only FavoritesPage cares
          },

          onSaveChanged: (saved) {
            // do nothing, only SavedPage cares
          },
        );
      },
    );
  }
}
