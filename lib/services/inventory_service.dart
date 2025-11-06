import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class InventoryService {
  static const String _apiKey = '**';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, Map<String, String>> _categoryCache = {};

  /// 🔹 Add a single item
  Future<void> addItem({
    required String name,
    required num qty,
    required String unit,
    required DateTime expiryDate,
    String sourceType = 'Manual',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    // Always lowercase before lookup
    final lowerName = name.toLowerCase().trim();
    final catData = await _getCategoryAndAisle(lowerName);

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .doc();

    await ref.set({
      'name': lowerName,
      'qty': qty,
      'unit': unit,
      'category': catData['category'],
      'aisle': catData['aisle'],
      'expiryDate': Timestamp.fromDate(expiryDate),
      'sourceType': sourceType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint(
        '✅ Added $lowerName → cat: ${catData['category']} | aisle: ${catData['aisle']}');
  }

  /// 🔹 Add multiple items (OCR / bulk)
  Future<void> addItems(List<Map<String, dynamic>> items) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final batch = _firestore.batch();
    final ref =
    _firestore.collection('users').doc(user.uid).collection('inventory');

    for (final item in items) {
      final rawName = (item['name'] ?? '').toString().trim();
      if (rawName.isEmpty) continue;

      final name = rawName.toLowerCase();
      final catData = await _getCategoryAndAisle(name);

      batch.set(ref.doc(), {
        'name': name,
        'qty': item['qty'] ?? 1,
        'unit': item['unit'] ?? 'pcs',
        'category': catData['category'],
        'aisle': catData['aisle'],
        'expiryDate': item['expiryDate'] ?? Timestamp.now(),
        'sourceType': item['sourceType'] ?? 'Scan',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '🧾 Queued: $name → cat: ${catData['category']} | aisle: ${catData['aisle']}');
    }

    await batch.commit();
    debugPrint('✅ Batch added ${items.length} items with categories + aisles.');
  }

  // 🧠 Fetch both category (categoryPath) and aisle from Spoonacular
  Future<Map<String, String>> _getCategoryAndAisle(String name) async {
    final lowerName = name.toLowerCase().trim();
    if (_categoryCache.containsKey(lowerName)) return _categoryCache[lowerName]!;

    try {
      // 1️⃣ Get ingredient ID
      final searchUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/search',
        {'query': lowerName, 'number': '1', 'apiKey': _apiKey},
      );
      final searchRes = await http.get(searchUri);
      if (searchRes.statusCode != 200) {
        debugPrint('⚠️ Search failed (${searchRes.statusCode}) for $lowerName');
        return {'category': 'general', 'aisle': 'general'};
      }

      final searchData = json.decode(searchRes.body);
      if (searchData['results'] == null || searchData['results'].isEmpty) {
        debugPrint('⚠️ No search results for "$lowerName"');
        return {'category': 'general', 'aisle': 'general'};
      }

      final id = searchData['results'][0]['id'].toString();

      // 2️⃣ Get detailed info (contains aisle & categoryPath)
      final infoUri = Uri.https(
        'api.spoonacular.com',
        '/food/ingredients/$id/information',
        {'amount': '1', 'apiKey': _apiKey},
      );
      final infoRes = await http.get(infoUri);
      if (infoRes.statusCode != 200) {
        debugPrint('⚠️ Info lookup failed (${infoRes.statusCode}) for $lowerName');
        return {'category': 'general', 'aisle': 'general'};
      }

      final infoData = json.decode(infoRes.body);

      // Extract aisle and categoryPath if available
      final aisle =
      (infoData['aisle'] ?? 'general').toString().trim().toLowerCase();
      String category = 'general';
      if (infoData['categoryPath'] != null &&
          infoData['categoryPath'] is List &&
          (infoData['categoryPath'] as List).isNotEmpty) {
        category = (infoData['categoryPath'] as List)
            .join(' > ')
            .toString()
            .trim()
            .toLowerCase();
      }

      debugPrint('🔍 $lowerName → category: $category | aisle: $aisle');

      final result = {'category': category, 'aisle': aisle};
      _categoryCache[lowerName] = result;
      return result;
    } catch (e) {
      debugPrint('❌ Spoonacular lookup failed for "$name": $e');
      return {'category': 'general', 'aisle': 'general'};
    }
  }

  // 🔹 Stream inventory
  Stream<List<Map<String, dynamic>>> getItems() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  // 🔹 Delete an item
  Future<void> deleteItem(String docId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .doc(docId)
        .delete();
  }

  // 🔹 Clear all items
  Future<void> clearInventory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    final ref =
    _firestore.collection('users').doc(user.uid).collection('inventory');
    final snapshot = await ref.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  /// 🔹 Fetch all inventory item names (for recipe refresh)
  Future<List<String>> fetchInventoryItems() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .get();

    // Return only item names as lowercase list
    final items = snapshot.docs
        .map((doc) => (doc.data()['name'] ?? '').toString().trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toList();

    debugPrint('📦 Loaded ${items.length} items from inventory.');
    return items;
  }

}
