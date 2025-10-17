// lib/services/peeley_service.dart
import 'package:sust_ai_n/features/onboarding/peeley_models.dart';

class PeeleyService {
  static final PeeleyService _instance = PeeleyService._internal();

  factory PeeleyService() {
    return _instance;
  }

  PeeleyService._internal();

  final List<String> funFacts = [
    "Did you know? Carrots were originally purple, not orange!",
    "Honey never spoils! Archaeologists found 3000-year-old honey in Egyptian tombs still edible.",
    "Bananas are berries, but strawberries aren't!",
    "Potatoes can absorb odors. Keep them away from onions!",
    "Lemons kill bacteria 10x better than vinegar!",
    "Apples float because they're 25% air!",
    "Garlic loses its health benefits if you cook it for more than 30 minutes.",
    "Tomatoes continue to ripen after being picked!",
    "Onions have layers - peel them properly for best flavor!",
    "Avocados ripen faster in brown paper bags!",
    "Broccoli stems are edible and taste great roasted!",
    "Bell peppers have 3 bumps on the bottom (female) or 4 (male) - female peppers are sweeter!",
    "Olive oil should never be heated above 190°C!",
    "Dark chocolate has more antioxidants than milk chocolate!",
    "Ginger helps with digestion and nausea!",
  ];

  final Map<String, Map<String, String>> storageGuide = {
    'milk': {
      'storage': 'Refrigerator',
      'temp': '0-4°C',
      'tip': 'Keep in coldest part of fridge. Never near door where temps fluctuate.',
      'shelfLife': '5-7 days after opening'
    },
    'tomato': {
      'storage': 'Room Temperature',
      'temp': '18-25°C',
      'tip': 'Store away from sunlight. Never refrigerate unless fully ripe.',
      'shelfLife': '3-5 days'
    },
    'lettuce': {
      'storage': 'Refrigerator',
      'temp': '0-4°C',
      'tip': 'Store in airtight container with paper towel to absorb moisture.',
      'shelfLife': '7-14 days'
    },
    'broccoli': {
      'storage': 'Refrigerator',
      'temp': '0-4°C',
      'tip': 'Keep stems can be roasted separately. Store in breathable bag.',
      'shelfLife': '3-5 days'
    },
    'potato': {
      'storage': 'Cool, Dark Place',
      'temp': '7-10°C',
      'tip': 'Never store with onions. Keep in dark place to prevent sprouting.',
      'shelfLife': '2-3 weeks'
    },
    'banana': {
      'storage': 'Room Temperature or Fridge',
      'temp': '18-22°C',
      'tip': 'Ripen at room temp. Move to fridge to slow ripening. Wrap stems.',
      'shelfLife': '3-7 days'
    },
  };

  final Map<String, List<Recipe>> recipeDatabase = {
    'chicken': [
      Recipe(
        name: 'Lemon Herb Grilled Chicken',
        ingredients: ['chicken', 'lemon', 'garlic', 'herbs'],
        prepTime: 30,
        difficulty: 'Easy',
        instructions: 'Marinate chicken in lemon and herbs. Grill for 20 min.',
      ),
      Recipe(
        name: 'Chicken Stir-fry',
        ingredients: ['chicken', 'bell pepper', 'onion', 'garlic', 'soy sauce'],
        prepTime: 20,
        difficulty: 'Easy',
        instructions: 'Dice chicken. Stir-fry on high heat with veggies.',
      ),
    ],
    'tomato': [
      Recipe(
        name: 'Tomato Soup',
        ingredients: ['tomato', 'onion', 'garlic', 'cream'],
        prepTime: 25,
        difficulty: 'Easy',
        instructions: 'Simmer tomatoes with onions. Blend and add cream.',
      ),
      Recipe(
        name: 'Salsa',
        ingredients: ['tomato', 'onion', 'cilantro', 'lime'],
        prepTime: 10,
        difficulty: 'Very Easy',
        instructions: 'Dice tomato and onion. Mix with cilantro and lime juice.',
      ),
    ],
    'banana': [
      Recipe(
        name: 'Banana Smoothie',
        ingredients: ['banana', 'milk', 'yogurt'],
        prepTime: 5,
        difficulty: 'Very Easy',
        instructions: 'Blend banana with milk and yogurt. Serve cold.',
      ),
      Recipe(
        name: 'Banana Bread',
        ingredients: ['banana', 'flour', 'sugar', 'egg', 'butter'],
        prepTime: 45,
        difficulty: 'Medium',
        instructions: 'Mix ingredients. Bake at 180°C for 35 min.',
      ),
    ],
  };

  String getRandomFunFact() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return funFacts[random % funFacts.length];
  }

  String getStorageTip(String foodItem) {
    String key = foodItem.toLowerCase();
    if (storageGuide.containsKey(key)) {
      var info = storageGuide[key]!;
      return 'Storage: ${info['storage']}\n'
          'Temperature: ${info['temp']}\n'
          'Pro Tip: ${info['tip']}\n'
          'Shelf Life: ${info['shelfLife']}';
    }
    return 'Storage info not available for $foodItem. Keep in cool, dry place.';
  }

  String getExpiryAdvice(List<FoodItem> inventory) {
    List<FoodItem> expiringItems =
        inventory.where((item) => item.daysUntilExpiry() <= 7).toList();

    if (expiringItems.isEmpty) {
      return '✅ All your items are good! No items expiring within 7 days.';
    }

    String advice = '⚠️ You have ${expiringItems.length} items expiring soon:\n\n';
    for (var item in expiringItems) {
      int days = item.daysUntilExpiry();
      String emoji = item.getStatus() == 'Expired'
          ? '🔴'
          : item.getStatus() == 'Expiring Soon'
              ? '🟠'
              : '🟡';
      advice += '$emoji ${item.name}: ${days > 0 ? 'expires in $days days' : 'EXPIRED'}\n';
    }
    return advice;
  }

  List<Recipe> getSuggestedRecipes(List<FoodItem> inventory) {
    List<Recipe> suggestions = [];
    for (var item in inventory) {
      String key = item.name.toLowerCase();
      if (recipeDatabase.containsKey(key)) {
        suggestions.addAll(recipeDatabase[key]!);
      }
    }
    return suggestions.isEmpty ? [] : suggestions;
  }

  String processPeeleyResponse(String userQuery, List<FoodItem> inventory) {
    String query = userQuery.toLowerCase();

    if (query.contains('expir') || query.contains('going bad')) {
      return getExpiryAdvice(inventory);
    }

    if (query.contains('store') || query.contains('keep fresh')) {
      for (var item in inventory) {
        if (query.contains(item.name.toLowerCase())) {
          return getStorageTip(item.name);
        }
      }
      return 'Please specify which food item you want storage tips for!';
    }

    if (query.contains('recipe') || query.contains('cook') || query.contains('what can i')) {
      var recipes = getSuggestedRecipes(inventory);
      if (recipes.isEmpty) {
        return 'Add more items to your inventory for recipe suggestions!';
      }
      String response = '🍳 Here are recipes you can make:\n\n';
      for (int i = 0; i < (recipes.length > 3 ? 3 : recipes.length); i++) {
        response +=
            '${i + 1}. ${recipes[i].name} (${recipes[i].prepTime} min - ${recipes[i].difficulty})\n';
      }
      return response;
    }

    if (query.contains('fact') || query.contains('fun') || query.contains('did you')) {
      return '💡 ${getRandomFunFact()}';
    }

    if (query.contains('tip') || query.contains('pro') || query.contains('how to')) {
      return '🌟 ${getRandomFunFact()}';
    }

    return 'I can help with:\n'
        '📋 Expiry dates - ask "What\'s expiring?"\n'
        '🍳 Recipes - ask "Suggest a recipe"\n'
        '❄️ Storage - ask "How to store [food]?"\n'
        '💡 Fun facts - ask "Tell me a fact"\n'
        '📊 Waste stats - ask "My waste stats"';
  }
}
