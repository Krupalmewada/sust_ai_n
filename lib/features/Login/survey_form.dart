import 'package:flutter/material.dart';

class SurveyForm extends StatefulWidget {
  const SurveyForm({super.key});

  @override
  State<SurveyForm> createState() => _SurveyForm();
}

class _SurveyForm extends State<SurveyForm> {
  final _ageGroupController = TextEditingController();
  final _familyCountController = TextEditingController();
  final _spendingController = TextEditingController();

  final FocusNode _ageFocus = FocusNode();
  final FocusNode _familyFocus = FocusNode();
  final FocusNode _spendingFocus = FocusNode();

  String? _shoppingFrequency;

  final List<String> dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Keto',
    'Lactose Intolerant',
    'Pescatarian',
  ];
  final List<String> cuisineOptions = [
    'Italian',
    'Indian',
    'Chinese',
    'Mexican',
    'Fast Food',
    'Japanese',
  ];

  List<String> selectedDietary = [];
  List<String> selectedCuisines = [];

  // Error messages
  String? _ageError;
  String? _familyError;
  String? _dietError;
  String? _cuisineError;
  String? _spendingError;
  String? _frequencyError;

  @override
  void initState() {
    super.initState();

    // Validate on focus lost
    _ageFocus.addListener(() {
      if (!_ageFocus.hasFocus) {
        setState(() {
          _ageError = _ageGroupController.text.trim().isEmpty
              ? "Please enter age group."
              : null;
        });
      }
    });

    _familyFocus.addListener(() {
      if (!_familyFocus.hasFocus) {
        setState(() {
          _familyError = _familyCountController.text.trim().isEmpty
              ? "Please enter family count."
              : null;
        });
      }
    });

    _spendingFocus.addListener(() {
      if (!_spendingFocus.hasFocus) {
        setState(() {
          _spendingError = _spendingController.text.trim().isEmpty
              ? "Please enter weekly spending."
              : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _ageGroupController.dispose();
    _familyCountController.dispose();
    _spendingController.dispose();
    _ageFocus.dispose();
    _familyFocus.dispose();
    _spendingFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const errorColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Personalization",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Age group
                    _buildLabel("Age group of household members"),
                    TextField(
                      controller: _ageGroupController,
                      focusNode: _ageFocus,
                      decoration: _inputDecoration("e.g. 2 adults, 2 kids"),
                    ),
                    if (_ageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _ageError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Family count
                    _buildLabel("Number of family members"),
                    TextField(
                      controller: _familyCountController,
                      focusNode: _familyFocus,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("Enter number"),
                    ),
                    if (_familyError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _familyError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Dietary restrictions
                    _buildLabelWithAdd(
                      "Dietary restrictions",
                          () => _showAddDialog(
                        title: "Add Dietary Restriction",
                        onAdd: (value) =>
                            setState(() => dietaryOptions.add(value)),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: dietaryOptions.map((option) {
                        final selected = selectedDietary.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: selected,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(10),
                          selectedColor: Colors.green,
                          checkmarkColor: Colors.white,
                          onSelected: (value) {
                            setState(() {
                              value
                                  ? selectedDietary.add(option)
                                  : selectedDietary.remove(option);
                              _dietError = selectedDietary.isEmpty
                                  ? "Please select at least one dietary restriction."
                                  : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_dietError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _dietError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Preferred cuisines
                    _buildLabelWithAdd(
                      "Preferred cuisines",
                          () => _showAddDialog(
                        title: "Add Preferred Cuisine",
                        onAdd: (value) =>
                            setState(() => cuisineOptions.add(value)),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: cuisineOptions.map((option) {
                        final selected = selectedCuisines.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: selected,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(10),
                          selectedColor: Colors.green,
                          checkmarkColor: Colors.white,
                          onSelected: (value) {
                            setState(() {
                              value
                                  ? selectedCuisines.add(option)
                                  : selectedCuisines.remove(option);
                              _cuisineError = selectedCuisines.isEmpty
                                  ? "Please select at least one cuisine."
                                  : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_cuisineError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _cuisineError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Weekly grocery spending
                    _buildLabel("Weekly grocery spending (\$)"),
                    TextField(
                      controller: _spendingController,
                      focusNode: _spendingFocus,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("e.g. 150"),
                    ),
                    if (_spendingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _spendingError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Grocery frequency
                    _buildLabel("How regularly do you get groceries?"),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration("Select frequency"),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      value: _shoppingFrequency,
                      items:
                      [
                        'Every day',
                        '2-3 times a week',
                        'Once a week',
                        'Bi-weekly',
                        'Monthly',
                      ]
                          .map(
                            (freq) => DropdownMenuItem(
                          value: freq,
                          child: Text(freq),
                        ),
                      )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _shoppingFrequency = value;
                        _frequencyError =
                        (_shoppingFrequency == null ||
                            _shoppingFrequency!.isEmpty)
                            ? "Please select shopping frequency."
                            : null;
                      }),
                    ),
                    if (_frequencyError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _frequencyError!,
                          style: const TextStyle(color: errorColor),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Submit button fixed at bottom
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleSubmit,
                child: const Text(
                  "Submit",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    setState(() {
      // Reset errors
      _ageError = _familyError = _dietError = _cuisineError = _spendingError =
          _frequencyError = null;
      bool hasError = false;

      if (_ageGroupController.text.trim().isEmpty) {
        _ageError = "Please enter age group.";
        hasError = true;
      }
      if (_familyCountController.text.trim().isEmpty) {
        _familyError = "Please enter family count.";
        hasError = true;
      }
      if (selectedDietary.isEmpty) {
        _dietError = "Please select at least one dietary restriction.";
        hasError = true;
      }
      if (selectedCuisines.isEmpty) {
        _cuisineError = "Please select at least one cuisine.";
        hasError = true;
      }
      if (_spendingController.text.trim().isEmpty) {
        _spendingError = "Please enter weekly spending.";
        hasError = true;
      }
      if (_shoppingFrequency == null || _shoppingFrequency!.isEmpty) {
        _frequencyError = "Please select shopping frequency.";
        hasError = true;
      }

      if (!hasError) {
        final List<Map<String, String>> responses = [
          {'Age group': _ageGroupController.text},
          {'Family members': _familyCountController.text},
          {'Dietary restrictions': selectedDietary.join(', ')},
          {'Preferred cuisines': selectedCuisines.join(', ')},
          {'Weekly spending': '\$${_spendingController.text}'},
          {'Shopping frequency': _shoppingFrequency ?? ''},
        ];

        print(responses);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Responses submitted successfully!')),
        );
      }
    });
  }

  Text _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  );

  Widget _buildLabelWithAdd(String text, VoidCallback onAdd) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add, color: Colors.green),
        onPressed: onAdd,
      ),
    ],
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  void _showAddDialog({
    required String title,
    required Function(String) onAdd,
  }) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: "Enter value",
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green, width: 2),
            ),
          ),
          cursorColor: Colors.green,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.green)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAdd(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}