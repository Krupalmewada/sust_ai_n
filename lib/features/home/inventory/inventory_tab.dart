import 'package:flutter/material.dart';

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      body: const Center(
        child: Text(
          "Inventory Page Running",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      
    );
  }
}
