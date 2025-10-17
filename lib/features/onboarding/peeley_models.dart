// lib/models/peeley_models.dart
import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class FoodItem {
  final String name;
  final DateTime expiryDate;
  final String category;
  final int quantity;

  FoodItem({
    required this.name,
    required this.expiryDate,
    required this.category,
    required this.quantity,
  });

  int daysUntilExpiry() {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  String getStatus() {
    int days = daysUntilExpiry();
    if (days < 0) return 'Expired';
    if (days <= 2) return 'Expiring Soon';
    if (days <= 7) return 'Use Soon';
    return 'Good';
  }

  Color getStatusColor() {
    String status = getStatus();
    if (status == 'Expired') return Colors.red;
    if (status == 'Expiring Soon') return Colors.orange;
    if (status == 'Use Soon') return Colors.amber;
    return Colors.green;
  }
}

class Recipe {
  final String name;
  final List<String> ingredients;
  final int prepTime;
  final String difficulty;
  final String instructions;

  Recipe({
    required this.name,
    required this.ingredients,
    required this.prepTime,
    required this.difficulty,
    required this.instructions,
  });
}

// Sample Food Inventory Data for Testing

List<FoodItem> sampleInventory = [
  FoodItem(
    name: 'Milk',
    expiryDate: DateTime.now().add(Duration(days: 3)),
    category: 'dairy',
    quantity: 1,
  ),
  FoodItem(
    name: 'Banana',
    expiryDate: DateTime.now().add(Duration(days: 2)),
    category: 'fruits',
    quantity: 4,
  ),
  FoodItem(
    name: 'Chicken',
    expiryDate: DateTime.now().add(Duration(days: 1)),
    category: 'proteins',
    quantity: 500,
  ),
  FoodItem(
    name: 'Lettuce',
    expiryDate: DateTime.now().add(Duration(days: 5)),
    category: 'vegetables',
    quantity: 1,
  ),
  FoodItem(
    name: 'Rice',
    expiryDate: DateTime.now().add(Duration(days: 180)),
    category: 'pantry',
    quantity: 1000,
  ),
];

// Usage:
// List<FoodItem> inventory = sampleInventory;
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => PeleyChatScreen(inventory: inventory),
// ));
