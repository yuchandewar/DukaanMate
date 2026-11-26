import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:dukaan_mate/core/providers/settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysBillsStream = ref.watch(billRepositoryProvider).watchTodaysBills();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DukaanMate'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              ref.watch(storeNameProvider),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            
            // Today's Sales Hero Card
            StreamBuilder<List<Bill>>(
              stream: todaysBillsStream,
              builder: (context, snapshot) {
                double totalSales = 0.0;
                int billCount = 0;
                double cash = 0.0;
                double upi = 0.0;
                double credit = 0.0;

                if (snapshot.hasData) {
                  final bills = snapshot.data!;
                  billCount = bills.length;
                  for (var bill in bills) {
                    totalSales += bill.total;
                    if (bill.paymentMethod == 'Cash') cash += bill.amountPaid;
                    if (bill.paymentMethod == 'UPI') upi += bill.amountPaid;
                    if (bill.paymentMethod == 'Credit') credit += bill.amountPaid;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade700, Colors.green.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Today's Sales",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MoneyText(
                            amount: totalSales,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "$billCount Bills",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _QuickActionButton(
                          icon: Icons.receipt_long,
                          label: 'New Bill',
                          color: Colors.blue,
                          onTap: () => context.push('/new_bill'),
                        ),
                        _QuickActionButton(
                          icon: Icons.scale,
                          label: 'Weight',
                          color: Colors.orange,
                          onTap: () => context.push('/weight_calculator'),
                        ),
                        _QuickActionButton(
                          icon: Icons.calculate,
                          label: 'Calculator',
                          color: Colors.purple,
                          onTap: () => context.push('/smart_calculator'),
                        ),
                        _QuickActionButton(
                          icon: Icons.menu_book,
                          label: 'Khata',
                          color: Colors.brown,
                          onTap: () => context.push('/customers'),
                        ),
                        _QuickActionButton(
                          icon: Icons.inventory_2,
                          label: 'Products',
                          color: Colors.teal,
                          onTap: () => context.push('/products'),
                        ),
                        _QuickActionButton(
                          icon: Icons.bar_chart,
                          label: 'Sales',
                          color: Colors.red,
                          onTap: () => context.push('/reports'),
                        ),
                        _QuickActionButton(
                          icon: Icons.qr_code_2,
                          label: 'My QRs',
                          color: Colors.indigo,
                          onTap: () => context.push('/qrcodes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      "Today's Summary",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _SummaryRow('Cash', cash, Colors.green),
                            const Divider(),
                            _SummaryRow('UPI', upi, Colors.blue),
                            const Divider(),
                            _SummaryRow('Credit', credit, Colors.orange),
                            const Divider(),
                            const _SummaryRow('Expenses', 0.0, Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
            
            StreamBuilder<List<Product>>(
              stream: ref.watch(productRepositoryProvider).watchLowStockProducts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                final lowStockProducts = snapshot.data!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Low Stock ⚠️",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lowStockProducts.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final product = lowStockProducts[index];
                          return ListTile(
                            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text('${product.stockQuantity} ${product.unit}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 80), // Padding for FAB
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color dotColor;

  const _SummaryRow(this.label, this.amount, this.dotColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          MoneyText(
            amount: amount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
