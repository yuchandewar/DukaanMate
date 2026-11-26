import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:dukaan_mate/shared/widgets/app_button.dart';

class WeightCalculatorScreen extends StatefulWidget {
  const WeightCalculatorScreen({super.key});

  @override
  State<WeightCalculatorScreen> createState() => _WeightCalculatorScreenState();
}

class _WeightCalculatorScreenState extends State<WeightCalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String _selectedUnit = 'kg';

  final List<String> _units = ['kg', 'g', 'litre', 'ml', 'metre', 'piece', 'dozen'];

  double get _calculatedTotal {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    
    if (_selectedUnit == 'g') {
      return (weight / 1000) * rate;
    } else if (_selectedUnit == 'ml') {
      return (weight / 1000) * rate;
    }
    return weight * rate;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Calculator'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result Display
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  const Text('RESULT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 8),
                  MoneyText(
                    amount: _calculatedTotal,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Weight Input
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Weight / Quantity',
                      labelStyle: TextStyle(fontSize: 16),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _units.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedUnit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Rate Input
            TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Rate (Price per $_selectedUnit)',
                labelStyle: const TextStyle(fontSize: 16),
                prefixText: '₹ ',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 48),
            
            // Add to Bill Button
            AppButton(
              text: 'ADD TO BILL',
              icon: Icons.add_shopping_cart,
              onPressed: () {
                // Return result or add directly to bill state via Riverpod
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
