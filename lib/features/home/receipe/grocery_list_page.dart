import 'package:flutter/material.dart';
import '../../../services/grocery_service.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key});

  @override
  GroceryListPageState createState() => GroceryListPageState();
}

class GroceryListPageState extends State<GroceryListPage> {
  final GroceryService _service = GroceryService();
  String _query = '';

  void searchGrocery(String query) => setState(() => _query = query);
  void clearSearch() => setState(() => _query = '');

  // 🧩 Emoji mapping for categories
  final Map<String, String> categoryEmojis = {
    'Vegetables': '🥬',
    'Dairy': '🧈',
    'Proteins': '🍗',
    'Condiments': '🧂',
    'Snacks': '🍿',
    'Beverages': '🥤',
    'Fruits': '🍎',
    'Meat': '🥩',
    'Other': '🧺',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
        stream: _service.streamGroceryItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("🛒 Your grocery list is empty"));
          }

          // Filter categories and items based on search query
          final Map<String, List<Map<String, dynamic>>> data = {};
          snapshot.data!.forEach((category, items) {
            final filtered = _query.isEmpty
                ? items
                : items
                .where((item) => item['name']
                .toString()
                .toLowerCase()
                .contains(_query.toLowerCase()))
                .toList();
            if (filtered.isNotEmpty) data[category] = filtered;
          });

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: data.entries.map((entry) {
              final emoji = categoryEmojis[entry.key] ?? '🧺'; // 👈 auto pick
              return _ExpandableCategory(
                category: entry.key,
                emoji: emoji,
                items: entry.value,
                onDelete: (id) => _service.deleteItem(id),
              );
            }).toList(),
          );
        },
      ),

      // ✅ Floating Action Button (for adding new grocery item)
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nameController = TextEditingController();
          final qtyController = TextEditingController();
          String? selectedCategory; // 👈 start as null (no default)

          final List<String> categories = [
            'Vegetables',
            'Dairy',
            'Proteins',
            'Condiments',
            'Snacks',
            'Beverages',
            'Fruits',
            'Meat',
            'Other',
          ];

          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Add Grocery Item"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Item name"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: "Quantity"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: "Category",
                      hintText: "Select category",
                    ),
                    items: categories
                        .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    ))
                        .toList(),
                    onChanged: (v) => selectedCategory = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final qty = qtyController.text.trim().isEmpty
                        ? "1"
                        : qtyController.text.trim();

                    // ⚠️ Validate all fields
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Please enter item name')),
                      );
                      return;
                    }

                    if (selectedCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Please select a category')),
                      );
                      return;
                    }

                    await _service.addItem(name, qty, selectedCategory!);
                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------- Category Component ----------------

class _ExpandableCategory extends StatefulWidget {
  final String category;
  final String emoji;
  final List<Map<String, dynamic>> items;
  final Function(String id) onDelete;

  const _ExpandableCategory({
    required this.category,
    required this.emoji,
    required this.items,
    required this.onDelete,
  });

  @override
  State<_ExpandableCategory> createState() => _ExpandableCategoryState();
}

class _ExpandableCategoryState extends State<_ExpandableCategory> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                widget.category,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          children: widget.items.map((item) {
            return Padding(
              padding:
              const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radio_button_off,
                          size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 10),
                      Text(item['name'] ?? '',
                          style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(item['qty'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => widget.onDelete(item['id']),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
