import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:intl/intl.dart';
import 'package:dukaan_mate/core/providers/settings_provider.dart';
import 'package:dukaan_mate/features/billing/pdf_service.dart';
import 'package:drift/drift.dart' as drift;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedMonth = DateTime.now();
  int _currentTabIndex = 0; // 0 = Summary, 1 = Sales, 2 = Expenses
  
  Stream<List<Bill>>? _billsStream;
  Stream<List<Expense>>? _expensesStream;

  @override
  void initState() {
    super.initState();
    // We can't use ref.read in initState directly sometimes, but ConsumerState allows it safely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStreams();
    });
  }

  void _updateStreams() {
    setState(() {
      _billsStream = ref.read(billRepositoryProvider).watchMonthlyBills(_selectedMonth);
      _expensesStream = ref.read(expenseRepositoryProvider).watchMonthlyExpenses(_selectedMonth);
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _updateStreams();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _updateStreams();
  }

  void _showExpenseDialog(BuildContext context, ExpenseRepository repo, {Expense? existingExpense}) {
    final titleCtrl = TextEditingController(text: existingExpense?.title ?? '');
    final amountCtrl = TextEditingController(text: existingExpense?.amount.toString() ?? '');
    final categoryCtrl = TextEditingController(text: existingExpense?.category ?? 'General');
    final categories = ['General', 'Rent', 'Electricity', 'Tea/Snacks', 'Salary', 'Maintenance', 'Travel', 'Other'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingExpense == null ? 'Add Expense' : 'Edit Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Expense Title'),
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: categoryCtrl.text,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => categoryCtrl.text = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;
                    final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amt <= 0) return;

                    if (existingExpense == null) {
                      await repo.addExpense(ExpensesCompanion.insert(
                        title: titleCtrl.text,
                        amount: amt,
                        category: drift.Value(categoryCtrl.text),
                      ));
                    } else {
                      await repo.updateExpense(existingExpense.copyWith(
                        title: titleCtrl.text,
                        amount: amt,
                        category: categoryCtrl.text,
                      ));
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
                Text(
                  monthFormat.format(_selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: _currentTabIndex == 0
                ? _buildSummaryTab()
                : _currentTabIndex == 1
                    ? _buildSalesTab()
                    : _buildExpensesTab(),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => _showExpenseDialog(context, ref.read(expenseRepositoryProvider)),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          _buildTabItem('Summary', 0),
          _buildTabItem('Sales', 1),
          _buildTabItem('Expenses', 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_billsStream == null || _expensesStream == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<Bill>>(
      stream: _billsStream,
      builder: (context, billSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, expenseSnapshot) {
            if (billSnapshot.connectionState == ConnectionState.waiting || expenseSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final bills = billSnapshot.data ?? [];
            final expenses = expenseSnapshot.data ?? [];

            double totalSales = 0.0;
            double totalExpenses = 0.0;

            for (var b in bills) totalSales += b.total;
            for (var e in expenses) totalExpenses += e.amount;

            final netProfit = totalSales - totalExpenses;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(
                    context,
                    'Net Profit/Loss',
                    netProfit,
                    netProfit >= 0 ? Colors.green : Colors.red,
                    isLarge: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(context, 'Total Sales', totalSales, Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(context, 'Total Expenses', totalExpenses, Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSalesTab() {
    if (_billsStream == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<List<Bill>>(
      stream: _billsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final bills = snapshot.data ?? [];
        if (bills.isEmpty) return const Center(child: Text('No sales for this month.'));

        double cashSales = 0.0;
        double upiSales = 0.0;
        double creditSales = 0.0;

        for (var bill in bills) {
          if (bill.paymentMethod == 'Cash') cashSales += bill.amountPaid;
          if (bill.paymentMethod == 'UPI') upiSales += bill.amountPaid;
          if (bill.paymentMethod == 'Credit') creditSales += (bill.total - bill.amountPaid);
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSmallSummaryCard(context, 'Cash', cashSales, Colors.green.shade700)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSmallSummaryCard(context, 'UPI', upiSales, Colors.blue.shade700)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSmallSummaryCard(context, 'Credit', creditSales, Colors.orange.shade700)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTransactionItem(context, ref, bills[index]),
                childCount: bills.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpensesTab() {
    if (_expensesStream == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<List<Expense>>(
      stream: _expensesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) return const Center(child: Text('No expenses recorded for this month.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final e = expenses[index];
            final dateStr = DateFormat('MMM dd, HH:mm').format(e.date);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.money_off, color: Colors.orange),
                ),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${e.category} • $dateStr', style: const TextStyle(fontSize: 12)),
                trailing: MoneyText(amount: e.amount, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  // Edit option
                  _showExpenseDialog(context, ref.read(expenseRepositoryProvider), existingExpense: e);
                },
                onLongPress: () {
                  // Delete option
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Expense?'),
                      content: Text('Are you sure you want to delete "${e.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                        TextButton(
                          onPressed: () {
                            ref.read(expenseRepositoryProvider).deleteExpense(e.id);
                            Navigator.pop(context);
                          },
                          child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, double amount, Color color, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 24 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          MoneyText(amount: amount, style: TextStyle(fontSize: isLarge ? 36 : 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryCard(BuildContext context, String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MoneyText(amount: amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, WidgetRef ref, Bill bill) {
    final dateStr = DateFormat('MMM dd, HH:mm').format(bill.createdAt);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(Icons.receipt, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(amount: bill.total, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(bill.paymentMethod, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
        onTap: () => _reprintBill(context, ref, bill),
      ),
    );
  }

  Future<void> _reprintBill(BuildContext context, WidgetRef ref, Bill bill) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      final items = await ref.read(billRepositoryProvider).getBillItems(bill.id);

      final mappedItems = items.map((i) => {
        'name': i.productName,
        'qty': i.quantity,
        'unit': i.unit,
        'price': i.price,
      }).toList();

      final storeName = ref.read(storeNameProvider);
      final storeAddress = ref.read(storeAddressProvider);
      final storePhone = ref.read(storePhoneProvider);
      final storeGstn = ref.read(storeGstnProvider);

      await PdfService.shareReceipt(
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeGstn: storeGstn,
        items: mappedItems,
        subtotal: bill.subtotal,
        discount: bill.discount,
        gstPercentage: 0, 
        gstAmount: bill.gstAmount,
        total: bill.total,
        paidAmount: bill.amountPaid,
        paymentMethod: bill.paymentMethod,
        billNumber: bill.billNumber,
      );

      if (context.mounted) Navigator.pop(context); // Close loader AFTER sharing
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating receipt: $e')));
      }
    }
  }
}
