import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final String _spoonacularKey;

  GroceryService() {
    _spoonacularKey = dotenv.env['SpoonacularapiKey'] ?? '';
  }


  // ---------------------------------------------------------------
  // CATEGORY LOGIC (Same as Inventory)
  // ---------------------------------------------------------------
  Future<String> determineCategory(String name) async {
    try {
      final searchUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/search',
        {'query': name, 'number': '1', 'apiKey': _spoonacularKey},
      );

      final searchRes = await http.get(searchUri);
      if (searchRes.statusCode != 200) return "Other";

      final searchData = json.decode(searchRes.body);
      if (searchData['results'] == null || searchData['results'].isEmpty) {
        return "Other";
      }

      final id = searchData['results'][0]['id'].toString();

      final infoUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/$id/information',
        {'amount': '1', 'apiKey': _spoonacularKey},
      );

      final infoRes = await http.get(infoUri);
      if (infoRes.statusCode != 200) return "Other";

      final infoData = json.decode(infoRes.body);

      final aisle = (infoData['aisle'] ?? "").toString();
      final categoryPath = infoData['categoryPath'];

      String category = "Other";

      if (categoryPath is List && categoryPath.isNotEmpty) {
        category = categoryPath.last.toString();
      } else if (aisle.isNotEmpty) {
        category = aisle;
      }

      return _capitalize(category);
    } catch (_) {
      return "Other";
    }
  }

  String _capitalize(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  // ---------------------------------------------------------------
  // ADD grocery item with auto–category
  // ---------------------------------------------------------------
  Future<void> addCategorizedItem(String name, String qty) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    final cleanName = name.trim().toLowerCase();

    // 🔍 Check if item already exists
    final existing = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .where('nameLower', isEqualTo: cleanName)
        .limit(1)
        .get();

    // ❗ If exists → silently do nothing
    if (existing.docs.isNotEmpty) return;

    // 🟢 Determine category using Spoonacular
    final category = await determineCategory(name);

    // 🟢 Add new item
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .add({
      'name': name,
      'nameLower': cleanName, // used for duplicate check
      'qty': qty,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }



  // ---------------------------------------------------------------
  // DELETE grocery item
  // ---------------------------------------------------------------
  Future<void> deleteItem(String docId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .doc(docId)
        .delete();
  }

  // ---------------------------------------------------------------
  // STREAM grouped grocery items by category
  // ---------------------------------------------------------------
  Stream<Map<String, List<Map<String, dynamic>>>> streamGroceryItems() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = (data['category'] ?? 'Other') as String;

        grouped.putIfAbsent(category, () => []);
        grouped[category]!.add({
          'id': doc.id,
          'name': data['name'],
          'qty': data['qty'],
        });
      }

      return grouped;
    });
  }
}
