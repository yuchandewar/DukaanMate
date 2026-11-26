import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:intl/intl.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsStream = ref.watch(billRepositoryProvider).watchAllBills();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          )
        ],
      ),
      body: StreamBuilder<List<Bill>>(
        stream: billsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final bills = snapshot.data ?? [];

          if (bills.isEmpty) {
            return const Center(
              child: Text('No bills created yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: bills.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final bill = bills[index];
              final dateStr = DateFormat('MMM dd, HH:mm').format(bill.createdAt);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.receipt, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dateStr),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      amount: bill.total,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      bill.paymentMethod,
                      style: TextStyle(
                        fontSize: 12,
                        color: bill.paymentMethod == 'UPI' ? Colors.purple : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  // View bill details
                },
              );
            },
          );
        },
      ),
    );
  }
}
