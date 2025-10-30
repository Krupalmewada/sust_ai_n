import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecipesPage extends StatefulWidget {
  final List<String> inventoryItems;

  const RecipesPage({super.key, required this.inventoryItems});

  @override
  RecipesPageState createState() => RecipesPageState(); // ✅ no underscore
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

  Future<void> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final ingredientString = ingredients.join(',');
      final url =
          '$_baseUrl/recipes/findByIngredients?ingredients=$ingredientString&number=10&ranking=2&apiKey=$_apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _recipes = data.map((e) => e as Map<String, dynamic>).toList();
        });
      } else {
        debugPrint('❌ Error fetching recipes: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔎 Called from ReceipeBasePage
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
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              "${recipe['usedIngredientCount']} used • ${recipe['missedIngredientCount']} missing",
              style:
              const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}
