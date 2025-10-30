import 'package:flutter/material.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key});

  @override
  GroceryListPageState createState() => GroceryListPageState();
}

class GroceryListPageState extends State<GroceryListPage> {
  String _query = '';

  // Example static data (later connect with Firebase)
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Vegetables',
      'icon': '🥬',
      'items': [
        {'name': 'Bok Choy', 'qty': '2'},
        {'name': 'Onion', 'qty': '1'},
      ]
    },
    {
      'name': 'Dairy',
      'icon': '🧈',
      'items': [
        {'name': 'Unsalted butter', 'qty': '1'},
      ]
    },
    {
      'name': 'Proteins',
      'icon': '🥚',
      'items': [
        {'name': 'Chicken breasts', 'qty': '250g'},
        {'name': 'Eggs', 'qty': '1'},
      ]
    },
    {
      'name': 'Condiments',
      'icon': '🧂',
      'items': [
        {'name': 'Sesame oil', 'qty': '1 can'},
      ]
    },
  ];

  void filterFromParentSearch(String query) {
    setState(() => _query = query);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _query.isEmpty
        ? _categories
        : _categories
        .map((cat) => {
      'name': cat['name'],
      'icon': cat['icon'],
      'items': List<Map<String, String>>.from(cat['items'])
          .where((item) => item['name']!
          .toLowerCase()
          .contains(_query.toLowerCase()))
          .toList(),
    })
        .where((cat) => (cat['items'] as List).isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return _ExpandableCategory(
            category: category['name'],
            emoji: category['icon'],
            items: List<Map<String, String>>.from(category['items']),
          );
        },
      ),
    );
  }
}

// ---------------- Category Component ----------------

class _ExpandableCategory extends StatefulWidget {
  final String category;
  final String emoji;
  final List<Map<String, String>> items;

  const _ExpandableCategory({
    required this.category,
    required this.emoji,
    required this.items,
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
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                widget.category,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          children: widget.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radio_button_off,
                          size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 10),
                      Text(
                        item['name']!,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  Text(
                    item['qty']!,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
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
