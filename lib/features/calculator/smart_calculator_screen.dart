import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';

class SmartCalculatorScreen extends StatefulWidget {
  const SmartCalculatorScreen({super.key});

  @override
  State<SmartCalculatorScreen> createState() => _SmartCalculatorScreenState();
}

class _SmartCalculatorScreenState extends State<SmartCalculatorScreen> {
  final List<_CalcLine> _lines = [_CalcLine()];

  double get _total {
    return _lines.fold(0.0, (sum, line) => sum + line.total);
  }

  void _addLine() {
    setState(() {
      _lines.add(_CalcLine());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Calculator'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                return _buildCalcLineRow(_lines[index], index);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          border: Border(top: BorderSide(color: Colors.purple.shade200)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.purple)),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: MoneyText(
                    amount: _total,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Colors.purple),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLine,
        backgroundColor: Colors.purple,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCalcLineRow(_CalcLine line, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.qtyController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Qty'),
              onChanged: (val) => setState(() {}),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('×', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: line.priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Price', prefixText: '₹'),
              onChanged: (val) => setState(() {}),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('=', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: MoneyText(
                  amount: line.total,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalcLine {
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  double get total {
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;
    return qty * price;
  }
}
