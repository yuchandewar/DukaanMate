import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:intl/intl.dart';
import 'package:dukaan_mate/core/providers/settings_provider.dart';
import 'package:dukaan_mate/features/billing/pdf_service.dart';
import 'dart:io';
import 'dart:convert';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  final int customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  void _showSettlePaymentDialog(Customer customer) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settle Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Khata Balance: ₹${customer.creditBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Received',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text) ?? 0.0;
                if (amount > 0) {
                  final billRepo = ref.read(billRepositoryProvider);
                  await billRepo.settleCustomerCredit(customer.id, amount);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Received ₹$amount successfully! Applied to oldest bills.')));
                  }
                }
              },
              child: const Text('SETTLE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerStream = ref.watch(customerRepositoryProvider).watchCustomerById(widget.customerId);
    final billsStream = ref.watch(billRepositoryProvider).watchBillsForCustomer(widget.customerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Khata'),
      ),
      body: StreamBuilder<Customer>(
        stream: customerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading customer'));
          }

          final customer = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: customer.photoPath != null && customer.photoPath!.length > 100 
                          ? MemoryImage(base64Decode(customer.photoPath!)) 
                          : (customer.photoPath != null ? FileImage(File(customer.photoPath!)) as ImageProvider : null),
                        child: customer.photoPath == null ? Text(
                          customer.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(customer.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (customer.phone?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(customer.phone!, style: const TextStyle(color: Colors.grey)),
                      ],
                      if (customer.address?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(customer.address!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      
                      // Khata Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: customer.creditBalance > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: customer.creditBalance > 0 ? Colors.orange.shade200 : Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              customer.creditBalance > 0 ? 'PENDING KHATA BALANCE' : 'NO PENDING DUES',
                              style: TextStyle(
                                color: customer.creditBalance > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            MoneyText(
                              amount: customer.creditBalance,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: customer.creditBalance > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                              ),
                            ),
                            if (customer.creditBalance > 0) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showSettlePaymentDialog(customer),
                                  icon: const Icon(Icons.payment),
                                  label: const Text('RECEIVE PAYMENT'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bills List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              
              StreamBuilder<List<Bill>>(
                stream: billsStream,
                builder: (context, billSnapshot) {
                  if (billSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                  }
                  
                  final bills = billSnapshot.data ?? [];
                  
                  if (bills.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey))),
                      ),
                    );
                  }
                  
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final bill = bills[index];
                        final dateStr = DateFormat('MMM dd, HH:mm').format(bill.createdAt);
                        final isCredit = bill.paymentMethod == 'Credit';
                        final unpaid = bill.total - bill.amountPaid;
                        
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: isCredit && unpaid > 0 ? Colors.orange.withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCredit && unpaid > 0 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              child: Icon(Icons.receipt, color: isCredit && unpaid > 0 ? Colors.orange : Colors.green),
                            ),
                            title: Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                MoneyText(amount: bill.total, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (unpaid > 0)
                                  Text('Pending: ₹${unpaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))
                                else
                                  Text(bill.paymentMethod, style: const TextStyle(fontSize: 10, color: Colors.green)),
                              ],
                            ),
                            onTap: () => _reprintBill(context, ref, bill),
                            onLongPress: unpaid > 0 ? () => _showSettleSpecificBillDialog(context, bill, unpaid) : null,
                          ),
                        );
                      },
                      childCount: bills.length,
                    ),
                  );
                },
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        }
      ),
    );
  }

  void _showSettleSpecificBillDialog(BuildContext context, Bill bill, double unpaidAmount) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pay ${bill.billNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unpaid Amount: ₹${unpaidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Received',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text) ?? 0.0;
                if (amount > 0) {
                  final billRepo = ref.read(billRepositoryProvider);
                  await billRepo.settleSpecificBill(bill.id, amount);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Received ₹$amount towards ${bill.billNumber} successfully!')));
                  }
                }
              },
              child: const Text('SETTLE'),
            ),
          ],
        );
      },
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
