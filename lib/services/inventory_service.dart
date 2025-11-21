import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// InventoryService — combines Spoonacular metadata + USDA FoodKeeper shelf-life estimation.
class InventoryService {
  late final String _spoonacularKey;

  InventoryService() {
    _spoonacularKey = dotenv.env['SpoonacularapiKey'] ?? '';
  }


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Map<String, String>> _categoryCache = {};

  // ----------------------------------------------------------
  // 🧠 Get Shelf Life (FoodKeeper API + debug output)
  // ----------------------------------------------------------

  /// 🔹 Fetch shelf life for a product from the USDA FoodKeeper dataset (online only)
  /// 🔹 Fetch shelf life for a product from the USDA FoodKeeper dataset (v128 schema)
  /// 🔹 Fetch shelf life for a product from the USDA FoodKeeper dataset (v128 schema)
  Future<int?> getShelfLifeDays(String productName) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.fsis.usda.gov/shared/data/EN/foodkeeper.json'),
      );
      print('🌐 HTTP ${response.statusCode}, size: ${response.body.length} bytes');

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch FoodKeeper data');
      }

      final decoded = json.decode(response.body);

      // ✅ Navigate to "sheets" → sheet with name "Product"
      if (decoded is! Map || !decoded.containsKey('sheets')) {
        print('⚠️ Unexpected USDA JSON structure (no "sheets")');
        return null;
      }

      final sheets = decoded['sheets'] as List<dynamic>;
      final productSheet = sheets.firstWhere(
            (sheet) => (sheet['name'] ?? '').toString().toLowerCase() == 'product',
        orElse: () => {},
      );

      if (productSheet.isEmpty || productSheet['data'] == null) {
        print('⚠️ No "Product" sheet found in USDA data');
        return null;
      }

      final List<dynamic> data = productSheet['data'];
      final query = productName.toLowerCase().trim();

      // 🔍 Each entry is a list of maps like [{"Name":"Bacon"},{"Name_subtitle":...}]
      Map<String, dynamic>? rowMap;
      for (final row in data) {
        if (row is List) {
          final flat = {
            for (final cell in row)
              if (cell is Map && cell.isNotEmpty) cell.keys.first: cell.values.first
          };
          final name = (flat['Name'] ?? '').toString().toLowerCase();
          if (name.contains(query)) {
            rowMap = flat.cast<String, dynamic>();

            break;
          }
        }
      }

      if (rowMap == null) {
        print('⚠️ No matching product found for "$productName"');
        return null;
      }

      print('🔍 Matched entry for $productName: ${rowMap['Name']}');

      // 🧠 Extract numeric fields
      double? minValue;
      double? maxValue;
      String? metric;

      for (final prefix in [
        'DOP_Refrigerate',
        'Refrigerate',
        'DOP_Pantry',
        'Pantry',
        'DOP_Freeze',
        'Freeze'
      ]) {
        if (rowMap['${prefix}_Min'] != null &&
            rowMap['${prefix}_Metric'] != null) {
          minValue = (rowMap['${prefix}_Min'] as num).toDouble();
          maxValue = (rowMap['${prefix}_Max'] as num?)?.toDouble() ?? minValue;
          metric = rowMap['${prefix}_Metric']?.toString();
          print('🧩 Found $prefix → $minValue–$maxValue $metric');
          break;
        }
      }

      if (minValue == null || metric == null) {
        print('⚠️ No numeric shelf life info for "$productName"');
        return null;
      }

      final avg = (minValue + maxValue!) / 2;
      final days = _convertMetricToDays(avg, metric);

      print('📅 $productName lasts ≈ $days days ($avg $metric)');
      return days;
    } catch (e, st) {
      print('❌ Shelf life lookup failed for "$productName": $e');
      print(st);
      return null;
    }
  }

  int _convertMetricToDays(double value, String metric) {
    switch (metric.toLowerCase()) {
      case 'day':
      case 'days':
        return value.round();
      case 'week':
      case 'weeks':
        return (value * 7).round();
      case 'month':
      case 'months':
        return (value * 30).round();
      case 'year':
      case 'years':
        return (value * 365).round();
      default:
        return value.round();
    }
  }



  Future<void> likeRecipe(Map<String, dynamic> recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Path for liked recipe
    final path = "users/$uid/recipe/liked/${recipe['id']}";
    print("📌 Writing liked recipe to -> $path");

    final data = {
      'id': recipe['id'],
      'title': recipe['title'],
      'image': recipe['image'],
      'servings': recipe['servings'],
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('recipe')
          .doc('liked')       // parent doc
          .collection('items') // subcollection
          .doc(recipe['id'].toString())
          .set(data);

      print("❤️ SUCCESS: Liked recipe saved → ${recipe['id']}");
    } catch (e) {
      print("❌ FIRESTORE WRITE FAILED → $e");
    }
  }


  Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    final data = {
      'id': recipe['id'],
      'title': recipe['title'],
      'image': recipe['image'],
      'servings': recipe['servings'],
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('recipe')
          .doc('saved')
          .collection('items')
          .doc(recipe['id'].toString())
          .set(data);

      print("📌 SUCCESS: Saved recipe → ${recipe['id']}");
    } catch (e) {
      print("❌ FIRESTORE WRITE FAILED → $e");
    }
  }






  Future<List<Map<String, dynamic>>> fetchLikedRecipes() async {
    final uid = _auth.currentUser!.uid;

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('liked')
        .collection('items')
        .orderBy('timestamp', descending: true)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSavedRecipes() async {
    final uid = _auth.currentUser!.uid;

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('saved')
        .collection('items')
        .orderBy('timestamp', descending: true)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  Future<bool> isRecipeLiked(int id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('liked')
        .collection('items')
        .doc(id.toString())
        .get();

    return snap.exists;
  }

  Future<bool> isRecipeSaved(int id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('saved')
        .collection('items')
        .doc(id.toString())
        .get();

    return snap.exists;
  }
  Future<void> unlikeRecipe(int id) async {
    final uid = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('liked')
        .collection('items')
        .doc(id.toString())
        .delete();
  }

  Future<void> unsaveRecipe(int id) async {
    final uid = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipe')
        .doc('saved')
        .collection('items')
        .doc(id.toString())
        .delete();
  }



  /// 🔸 Convert human-readable durations like "3-5 days" or "2 weeks" to integer days
  int? _parseShelfLifeToDays(String shelfLife) {
    if (shelfLife.isEmpty || shelfLife.toLowerCase().contains('varies')) return null;

    final regex = RegExp(
      r'(\d+)(?:\s*(?:-|–|to)\s*(\d+))?\s*(day|week|month|year)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(shelfLife);
    if (match == null) return null;

    final minValue = int.parse(match.group(1)!);
    final maxValue = match.group(2) != null ? int.parse(match.group(2)!) : minValue;
    final avg = (minValue + maxValue) / 2;
    final unit = match.group(3)!.toLowerCase();

    switch (unit) {
      case 'day':
      case 'days':
        return avg.round();
      case 'week':
      case 'weeks':
        return (avg * 7).round();
      case 'month':
      case 'months':
        return (avg * 30).round();
      case 'year':
      case 'years':
        return (avg * 365).round();
      default:
        return null;
    }
  }

  /// 🔹 Default multi-storage expiry options (for notification and reminders)
  Map<String, int> _getDefaultShelfLifeOptions() {
    return {
      'pantry': 7,          // 1 week
      'refrigerator': 20,   // 3 weeks
      'freezer': 90,        // 3 months
    };
  }

  // ----------------------------------------------------------
// ----------------------------------------------------------
// 🔹 Add Single Item
  Future<void> addItem({
    required String name,
    required num qty,
    required String unit,
    String sourceType = 'Manual',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final lowerName = name.toLowerCase().trim();

    // 🍽 Get Spoonacular category + aisle
    final catData = await _getCategoryAndAisle(lowerName);
    final aisle = catData['aisle'] ?? 'General';
    final category = catData['category'] ?? 'General';

    // 🧠 Get estimated shelf life (FoodKeeper)
    final shelfLifeDays = await getShelfLifeDays(lowerName) ?? 7;

    // 📅 Date added (local)
    final dateAdded = DateTime.now();

    // ⏳ **expiry = dateAdded + shelf-life days**
    final expiryDate = dateAdded.add(Duration(days: shelfLifeDays));

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .doc();

    await ref.set({
      'name': lowerName,
      'qty': qty,
      'unit': unit,
      'category': category,
      'aisle': aisle,
      'approxExpiryDays': shelfLifeDays,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'sourceType': sourceType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint(
        '✅ Added $lowerName → $category | Shelf: $shelfLifeDays days | Expiry: ${expiryDate.toLocal()}');
  }


// ----------------------------------------------------------
// 🔹 Add Multiple Items (Batch Add)
// ----------------------------------------------------------
  Future<void> addItems(List<Map<String, dynamic>> items) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final batch = _firestore.batch();
    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory');

    for (final item in items) {
      final name = (item['name'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty) continue;

      // 🍽 Category + Aisle
      final catData = await _getCategoryAndAisle(name);
      final aisle = catData['aisle'] ?? 'General';
      final category = catData['category'] ?? 'General';

      // 🧠 Shelf life (FoodKeeper)
      final shelfLifeDays = await getShelfLifeDays(name) ?? 7;

      // 📅 Date added
      final dateAdded = DateTime.now();

      // ⏳ **expiry = dateAdded + shelfLifeDays**
      final expiry = dateAdded.add(Duration(days: shelfLifeDays));

      batch.set(ref.doc(), {
        'name': name,
        'qty': item['qty'] ?? 1,
        'unit': item['unit'] ?? 'pcs',
        'category': category,
        'aisle': aisle,
        'approxExpiryDays': shelfLifeDays,
        'dateAdded': Timestamp.fromDate(dateAdded),
        'expiryDate': Timestamp.fromDate(expiry),
        'sourceType': item['sourceType'] ?? 'Scan',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Batch added ${items.length} items using auto shelf-life expiry.');
  }

  Future<List<String>> getMissingIngredients(List<String> ingredients) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .get();

    final inventoryNames = snap.docs
        .map((d) => d['name'].toString().toLowerCase())
        .toList();

    final missing = <String>[];

    for (final ing in ingredients) {
      if (!inventoryNames.contains(ing.toLowerCase())) {
        missing.add(ing);
      }
    }

    return missing;
  }
  Future<Map<String, List<String>>> getIngredientStatus(List<String> ingredients) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {"have": [], "missing": []};

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .get();

    final inventoryNames = snap.docs
        .map((d) => d['name'].toString().toLowerCase())
        .toList();

    final have = <String>[];
    final missing = <String>[];

    for (final ing in ingredients) {
      final normalized = ing.toLowerCase().trim();

      if (inventoryNames.contains(normalized)) {
        have.add(ing);
      } else {
        missing.add(ing);
      }
    }

    return {"have": have, "missing": missing};
  }

  Future<void> addToGroceryList(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .add({
      'name': name,
      'qty': 1,
      'addedAt': DateTime.now(),
    });
  }





  // ----------------------------------------------------------
  // 🔹 Get Category + Aisle from Spoonacular
  // ----------------------------------------------------------
  Future<Map<String, String>> _getCategoryAndAisle(String name) async {
    final lower = name.toLowerCase().trim();
    if (_categoryCache.containsKey(lower)) return _categoryCache[lower]!;

    try {
      final searchUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/search',
        {'query': lower, 'number': '1', 'apiKey': _spoonacularKey},
      );
      final searchRes = await http.get(searchUri);
      if (searchRes.statusCode != 200) {
        return {'category': 'General', 'aisle': 'General'};
      }

      final searchData = json.decode(searchRes.body);
      if (searchData['results'] == null || searchData['results'].isEmpty) {
        return {'category': 'General', 'aisle': 'General'};
      }

      final id = searchData['results'][0]['id'].toString();
      final infoUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/$id/information',
        {'amount': '1', 'apiKey': _spoonacularKey},
      );
      final infoRes = await http.get(infoUri);
      if (infoRes.statusCode != 200) {
        return {'category': 'General', 'aisle': 'General'};
      }

      final infoData = json.decode(infoRes.body);
      final rawAisle = (infoData['aisle'] ?? '').toString().trim();
      final aisle =
      rawAisle.isNotEmpty ? _capitalize(rawAisle.split('/').last) : 'General';

      String category = 'General';
      if (infoData['categoryPath'] != null &&
          infoData['categoryPath'] is List &&
          (infoData['categoryPath'] as List).isNotEmpty) {
        category =
            _capitalize((infoData['categoryPath'] as List).last.toString());
      }

      final result = {'category': category, 'aisle': aisle};
      _categoryCache[lower] = result;
      return result;
    } catch (e) {
      debugPrint('❌ Spoonacular lookup failed for "$name": $e');
      return {'category': 'General', 'aisle': 'General'};
    }
  }

  String _capitalize(String v) => v.isEmpty
      ? v
      : v
      .split(' ')
      .map((w) => w.isNotEmpty
      ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
      : '')
      .join(' ');

  // ----------------------------------------------------------
  // 🔹 Ingredient Image via Spoonacular
  // ----------------------------------------------------------
  Future<String?> fetchIngredientImage(String name) async {
    try {
      final cleaned = name.toLowerCase().trim();
      final searchUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/search',
        {'query': cleaned, 'number': '5', 'apiKey': _spoonacularKey},
      );

      final res = await http.get(searchUri);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      if (data['results'] == null || data['results'].isEmpty) return null;

      final result = (data['results'] as List)[0];
      if (result['image'] != null) {
        return 'https://spoonacular.com/cdn/ingredients_250x250/${result['image']}';
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to fetch ingredient image for $name: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // 🔹 Firestore Helpers
  // ----------------------------------------------------------
  Stream<List<Map<String, dynamic>>> getItems() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList());
  }

  Future<List<String>> fetchInventoryItems() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .get();
    return snapshot.docs
        .map((d) => (d.data()['name'] ?? '').toString().trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toList();
  }
}
