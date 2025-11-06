import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🧾 Add a grocery item
  Future<void> addItem(String name, String qty, String category) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('groceryList')
        .add({
      'name': name,
      'qty': qty,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// 📦 Delete a grocery item
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

  /// 🔁 Stream grocery items grouped by category
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
