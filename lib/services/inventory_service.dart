import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Add a single item to inventory
  Future<void> addItem({
    required String name,
    required num qty,
    required String unit,
    required String category,
    required DateTime expiryDate,
    String sourceType = 'Manual',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .doc();

    await ref.set({
      'name': name,
      'qty': qty,
      'unit': unit,
      'category': category,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'sourceType': sourceType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// 🔹 Add multiple items (e.g. from OCR scan)
  Future<void> addItems(List<Map<String, dynamic>> items) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final batch = _firestore.batch();
    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory');

    for (final item in items) {
      final doc = ref.doc();
      batch.set(doc, {
        'name': item['name'] ?? 'Unknown',
        'qty': item['qty'] ?? 1,
        'unit': item['unit'] ?? 'pcs',
        'category': item['category'] ?? 'Uncategorized',
        'expiryDate': item['expiryDate'] ?? Timestamp.now(),
        'sourceType': item['sourceType'] ?? 'Scan',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// 🔹 Get real-time inventory stream
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

  /// 🔹 Delete a specific item
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

  /// 🔹 Optional: Clear entire inventory
  Future<void> clearInventory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory');

    final snapshot = await ref.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
