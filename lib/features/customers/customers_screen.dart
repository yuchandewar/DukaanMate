import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerRepo = ref.watch(customerRepositoryProvider);
    final customersStream = customerRepo.watchAllCustomers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers (Khata)'),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: customersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final customers = snapshot.data ?? [];
          
          if (customers.isEmpty) {
            return const Center(
              child: Text('No customers added yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: customers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: customer.photoPath != null && customer.photoPath!.length > 100 
                    ? MemoryImage(base64Decode(customer.photoPath!)) 
                    : (customer.photoPath != null ? FileImage(File(customer.photoPath!)) as ImageProvider : null),
                  child: customer.photoPath == null ? Text(customer.name.substring(0, 1).toUpperCase()) : null,
                ),
                title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(customer.phone ?? 'No phone'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Due Amount', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    MoneyText(
                      amount: customer.creditBalance,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: customer.creditBalance > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  context.push('/customers/${customer.id}');
                },
                onLongPress: () {
                  if (customer.creditBalance > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot delete ${customer.name} because they have pending dues of ₹${customer.creditBalance.toStringAsFixed(2)}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Customer?'),
                        content: Text('Are you sure you want to permanently delete ${customer.name}? This will remove all their details.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () async {
                              await customerRepo.deleteCustomer(customer.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('DELETE'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context, customerRepo),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, CustomerRepository repo) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final altPhoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Customer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          setDialogState(() {
                            selectedImage = File(image.path);
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: selectedImage != null ? FileImage(selectedImage!) : null,
                        child: selectedImage == null ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey) : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to add photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Customer Name'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: altPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Alternate Phone (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Address (Optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    
                    String? photoBase64;
                    if (selectedImage != null) {
                      final bytes = await selectedImage!.readAsBytes();
                      photoBase64 = base64Encode(bytes);
                    }

                    final newCustomer = CustomersCompanion(
                      name: drift.Value(nameCtrl.text),
                      phone: drift.Value(phoneCtrl.text.isEmpty ? null : phoneCtrl.text),
                      alternatePhone: drift.Value(altPhoneCtrl.text.isEmpty ? null : altPhoneCtrl.text),
                      address: drift.Value(addressCtrl.text.isEmpty ? null : addressCtrl.text),
                      photoPath: drift.Value(photoBase64),
                    );
                    
                    await repo.addCustomer(newCustomer);
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
  void _showEditDueDialog(BuildContext context, CustomerRepository repo, Customer customer) {
    final dueCtrl = TextEditingController(text: customer.creditBalance.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Due for ${customer.name}'),
          content: TextField(
            controller: dueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Due Amount', prefixText: '₹'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final newDue = double.tryParse(dueCtrl.text) ?? 0.0;
                repo.updateCustomer(customer.copyWith(
                  creditBalance: newDue,
                  updatedAt: DateTime.now(),
                ));
                Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
}
