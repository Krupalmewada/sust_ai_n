import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔹 Import your existing BottomNavBar widget
import '../../../widgets/bottom_nav_bar.dart';

class UserInventoryPage extends StatefulWidget {
  const UserInventoryPage({super.key});

  @override
  State<UserInventoryPage> createState() => _UserInventoryPageState();
}

class _UserInventoryPageState extends State<UserInventoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  int _currentIndex = 2; // ✅ Inventory tab active

  Stream<Map<String, List<Map<String, dynamic>>>> _streamUserInventory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .snapshots()
        .map((snapshot) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // 🔹 Smarter category logic
        final rawCategory = (data['category'] ?? '').toString().trim().toLowerCase();
        final rawAisle = (data['aisle'] ?? '').toString().trim();

        // If category is 'general', 'misc', or empty, use aisle instead
        final category = (rawCategory.isEmpty ||
            rawCategory == 'general' ||
            rawCategory == 'misc' ||
            rawCategory == 'other')
            ? (rawAisle.isNotEmpty ? _capitalize(rawAisle) : 'Uncategorized')
            : _capitalize(rawCategory);

        grouped.putIfAbsent(category, () => []);
        grouped[category]!.add(data);
      }

      return grouped;
    });
  }

// 🔸 Helper function to capitalize category titles properly
  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ App bar WITHOUT back button
      appBar: AppBar(
        automaticallyImplyLeading: false, // 👈 disables default back arrow
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'User Inventory',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      // 🔹 Firestore stream
      body: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
        stream: _streamUserInventory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('🧺 No items in your inventory'),
            );
          }

          final inventory = snapshot.data!;
          final categories = inventory.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final items = inventory[category]!;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.grey.shade100,
                  title: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  children: items.map((item) {
                    return ListTile(
                      title: Text(item['name'] ?? 'Unnamed'),
                      subtitle: Text(
                        'Qty: ${item['qty']} ${item['unit'] ?? ''} • Exp: ${item['expiryDate'] ?? '-'}',
                      ),
                      leading: const Icon(Icons.inventory_2_outlined),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),

      // ✅ Bottom Navigation (main navigation control)
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            Navigator.pushNamed(context, '/inventory');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/recipes');
          } else if (index == 2) {
            // already on inventory
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }
}
