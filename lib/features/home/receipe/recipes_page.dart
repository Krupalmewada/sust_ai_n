import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecipesPage extends StatefulWidget {
  final List<String> inventoryItems;

  const RecipesPage({super.key, required this.inventoryItems});

  @override
  RecipesPageState createState() => RecipesPageState();
}

class RecipesPageState extends State<RecipesPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

  static const String _apiKey = '80c1041e2fb84b6389d2ba69fa7c1f3f';
  static const String _baseUrl = 'https://api.spoonacular.com';

  @override
  void initState() {
    super.initState();
    _fetchRecipes(widget.inventoryItems);
  }

  // ✅ FIXED — only one _fetchRecipes() definition
  Future<void> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // 1️⃣ Find recipes by ingredients
      final ingredientString = ingredients
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .join(',');

      final findUri = Uri.https(
        'api.spoonacular.com',
        '/recipes/findByIngredients',
        {
          'ingredients': ingredientString,
          'number': '5',
          'ranking': '2',
          'apiKey': _apiKey,
        },
      );

      final findRes = await http.get(findUri);

      if (findRes.statusCode != 200) {
        debugPrint('❌ findByIngredients failed: ${findRes.body}');
        setState(() => _isLoading = false);
        return;
      }

      final List findData = json.decode(findRes.body);
      if (findData.isEmpty) {
        debugPrint('⚠️ No recipes found.');
        setState(() => _recipes = []);
        return;
      }

      // 2️⃣ Extract recipe IDs
      final ids = findData.map((r) => r['id'].toString()).toList();
      final idsParam = ids.join(',');

      // 3️⃣ Fetch details (servings + calories)
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
        setState(() {
          _recipes = findData.map((e) => e as Map<String, dynamic>).toList();
        });
        return;
      }

      final List infoData = json.decode(infoRes.body);

      // 4️⃣ Merge & extract nutrition info
      final enriched = infoData.map((recipe) {
        final nutrients = (recipe['nutrition']?['nutrients'] as List?) ?? [];
        final calRow = nutrients.cast<Map>().firstWhere(
              (n) => n['name'] == 'Calories',
          orElse: () => {},
        );

        final calories = calRow.isNotEmpty
            ? '${calRow['amount'].round()} ${calRow['unit']}'
            : 'N/A';
        final servings = recipe['servings']?.toString() ?? 'N/A';

        return {
          'id': recipe['id'],
          'title': recipe['title'],
          'image': recipe['image'],
          'calories': calories,
          'servings': servings,
        };
      }).toList();

      // 5️⃣ Update UI
      setState(() {
        _recipes = enriched.cast<Map<String, dynamic>>();
      });

      debugPrint('✅ Loaded ${_recipes.length} recipes with nutrition');
    } catch (e) {
      debugPrint('❌ Exception fetching recipes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔍 From ReceipeBasePage
  void searchRecipes(String query) {
    if (query.isEmpty) {
      _fetchRecipes(widget.inventoryItems);
      return;
    }
    _fetchRecipes([query]);
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
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                recipe['image'] ?? '',
                width: width * 0.18,
                fit: BoxFit.cover,
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
        );
      },
    );
  }
}
