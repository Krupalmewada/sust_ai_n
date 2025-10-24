import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  static final String? _apiKey = dotenv.env['SpoonacularapiKey'];

  /// Fetch recipes from ingredients list
  static Future<List<Map<String, dynamic>>> getRecipesFromIngredients(
      List<String> ingredients) async {
    final ingredientString = ingredients.join(',');
    final url =
        '$_baseUrl/recipes/findByIngredients?ingredients=$ingredientString&number=10&apiKey=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((recipe) => {
        'id': recipe['id'],
        'title': recipe['title'],
        'image': recipe['image'],
        'usedIngredientCount': recipe['usedIngredientCount'],
        'missedIngredientCount': recipe['missedIngredientCount'],
      }).toList();
    } else {
      print('❌ Response Code: ${response.statusCode}');
      print('❌ Response Body: ${response.body}');
      throw Exception('Failed to fetch recipes');
    }
  }
  static Future<Map<String, dynamic>> getRecipeDetails(int recipeId) async {
    final url =
        '$_baseUrl/recipes/$recipeId/information?includeNutrition=true&apiKey=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Extract servings
      final servings = data['servings'] ?? 'N/A';

      // Extract calories from nutrition
      String calories = 'N/A';
      if (data['nutrition'] != null && data['nutrition']['nutrients'] != null) {
        final nutrients = data['nutrition']['nutrients'] as List;
        final calorieItem = nutrients.firstWhere(
              (n) => n['name'] == 'Calories', // ✅ Correct key
          orElse: () => {'amount': 0, 'unit': 'kcal'},
        );
        calories = calorieItem['amount'].toStringAsFixed(0);
      }

      return {
        'servings': servings,
        'calories': calories,
      };
    } else {
      throw Exception('Failed to fetch recipe details: ${response.statusCode}');
    }
  }


}

