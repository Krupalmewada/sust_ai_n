import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../features/home/receipe/recipe_detail_page.dart';
import '../services/grocery_service.dart';

class RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;

  final void Function(bool liked)? onLikeChanged;
  final void Function(bool saved)? onSaveChanged;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onLikeChanged,
    this.onSaveChanged,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  final InventoryService _service = InventoryService();

  bool isLiked = false;
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final id = widget.recipe['id'];
    final liked = await _service.isRecipeLiked(id);
    final saved = await _service.isRecipeSaved(id);

    if (!mounted) return;

    setState(() {
      isLiked = liked;
      isSaved = saved;
    });
  }

  // ================================================================
  // POPUP: show BOTH "have" and "missing" ingredients in two lists
  // ================================================================
  void _showIngredientStatusDialog(
      BuildContext context,
      List<String> have,
      List<String> missing,
      ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Ingredient Check", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (have.isNotEmpty)
                  const Text("✔ You already have:",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                if (have.isNotEmpty)
                  ...have.map((i) => Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: Text("• $i", style: TextStyle(color: Colors.green)),
                  )),

                const SizedBox(height: 16),

                if (missing.isNotEmpty)
                  const Text("❌ Missing ingredients:",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                if (missing.isNotEmpty)
                  ...missing.map((i) => Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: Text("• $i", style: TextStyle(color: Colors.red)),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),

            // ADD TO LIST BUTTON
            if (missing.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  final groceryService = GroceryService();

                  for (final item in missing) {
                    await GroceryService().addCategorizedItem(item, "1");
                  }

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Missing ingredients added to grocery list!"),
                    ),
                  );
                },
                child: const Text("Add to List"),
              ),
          ],
        );
      },
    );
  }

  // ================================================================

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailPage(
              recipeId: r['id'],
              title: r['title'],
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- IMAGE + LIKE/SAVE ----------
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Image.network(
                    r['image'] ?? "",
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned(
                  right: 10,
                  top: 10,
                  child: Row(
                    children: [
                      // LIKE BUTTON
                      _circleButton(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        onTap: () async {
                          final id = r['id'];

                          if (isLiked) {
                            await _service.unlikeRecipe(id);
                          } else {
                            await _service.likeRecipe(r);
                          }

                          setState(() => isLiked = !isLiked);
                          widget.onLikeChanged?.call(isLiked);
                        },
                      ),

                      const SizedBox(width: 10),

                      // SAVE BUTTON
                      _circleButton(
                        icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.black87,
                        onTap: () async {
                          final id = r['id'];

                          if (isSaved) {
                            await _service.unsaveRecipe(id);
                            setState(() => isSaved = false);
                            widget.onSaveChanged?.call(false);
                            return;
                          }

                          // Save recipe
                          await _service.saveRecipe(r);
                          setState(() => isSaved = true);
                          widget.onSaveChanged?.call(true);

                          // Check ingredients
                          if (r['extendedIngredients'] != null) {
                            final ingredients = (r['extendedIngredients'] as List)
                                .map((e) => (e['name'] ?? '').toString())
                                .toList();

                            final status = await _service.getIngredientStatus(ingredients);
                            final have = status["have"] ?? [];
                            final missing = status["missing"] ?? [];

                            if (context.mounted) {
                              _showIngredientStatusDialog(context, have, missing);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ---------- TITLE + SERVINGS ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "🍽 ${r['servings']} servings",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: color,
        ),
      ),
    );
  }
}
