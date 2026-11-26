import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/shared/widgets/money_text.dart';
import 'package:dukaan_mate/shared/widgets/app_button.dart';
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:share_plus/share_plus.dart';
import 'package:dukaan_mate/core/providers/settings_provider.dart';
import 'package:dukaan_mate/core/providers/qr_codes_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dukaan_mate/features/billing/pdf_service.dart';

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  // Temporary state for the UI mockup
  final List<Map<String, dynamic>> _items = [];

  double _discount = 0.0;
  double _gstPercentage = 0.0;
  double _paidAmount = 0.0;
  String _paymentMethod = 'Cash';
  int? _selectedCustomerId;

  double get _subtotal {
    return _items.fold(0, (sum, item) => sum + (item['qty'] * item['price']));
  }

  double get _gstAmount => (_subtotal - _discount) * (_gstPercentage / 100);
  double get _total => _subtotal - _discount + _gstAmount;
  double get _change => _paidAmount > 0 ? _paidAmount - _total : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('New Bill'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          _buildCustomerSelector(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchAndFavorites(),
            _buildBillItemsList(shrinkWrap: true),
            _buildTotalsSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildCustomerSelector() {
    final customersStream = ref.watch(customerRepositoryProvider).watchAllCustomers();
    
    return StreamBuilder<List<Customer>>(
      stream: customersStream,
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];
        if (customers.isEmpty) {
          return IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push('/customers'),
            tooltip: 'Add Customer',
          );
        }
        
        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedCustomerId != null && customers.any((c) => c.id == _selectedCustomerId) 
                  ? _selectedCustomerId 
                  : null,
              hint: Text('Select Customer', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              icon: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
              onChanged: (int? val) {
                setState(() {
                  _selectedCustomerId = val;
                  if (val != null) {
                    _paymentMethod = 'Credit';
                    _paidAmount = 0.0;
                  }
                });
              },
              items: customers.map((c) {
                return DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFavorites() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<Product>(
            displayStringForOption: (Product option) => option.name,
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Product>.empty();
              }
              final repo = ref.read(productRepositoryProvider);
              return await repo.searchProducts(textEditingValue.text);
            },
            onSelected: (Product product) {
              _promptForQuantityAndAdd(product);
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search product...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () {},
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.green, size: 32),
                    tooltip: 'Add Custom Item',
                    onPressed: _showAddCustomItemDialog,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Favorites',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildFavoritesStream(),
        ],
      ),
    );
  }

  Widget _buildFavoritesStream() {
    final favoritesStream = ref.watch(productRepositoryProvider).watchFavoriteProducts();

    return StreamBuilder<List<Product>>(
      stream: favoritesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No favorites added. Star products in the Products screen.', style: TextStyle(fontSize: 12));
        }

        final favorites = snapshot.data!;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: favorites.map((p) => _buildFavoriteChip(p)).toList(),
          ),
        );
      }
    );
  }

  Widget _buildFavoriteChip(Product product) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Column(
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('₹${product.sellingPrice}/${product.unit}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green.withOpacity(0.1),
        side: BorderSide(color: Colors.green.withOpacity(0.3)),
        onPressed: () {
          _promptForQuantityAndAdd(product);
        },
      ),
    );
  }

  Widget _buildBillItemsList({bool shrinkWrap = false}) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        final total = item['qty'] * item['price'];
        return ListTile(
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${item['qty']} ${item['unit']} × ₹${item['price']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyText(amount: total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _items.removeAt(index);
                  });
                },
              )
            ],
          ),
          onTap: () {
            _showEditDialog('Quantity (${item['unit']})', item['qty'], (val) {
              setState(() {
                _items[index]['qty'] = val;
              });
            });
          },
        );
      },
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _subtotal),
          _buildTotalRow('Discount', _discount, isEditable: true),
          _buildTotalRow('GST ($_gstPercentage%)', _gstAmount, isEditable: true, isGst: true),
          const Divider(),
          _buildTotalRow('TOTAL', _total, isLarge: true),
          const SizedBox(height: 16),
          _buildPaymentSection(),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isLarge = false, bool isEditable = false, bool isGst = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isLarge ? 20 : 16,
                  fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isEditable)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: InkWell(
                    onTap: () {
                      if (isGst) {
                        _showEditDialog('GST Percentage', _gstPercentage, (val) {
                          setState(() => _gstPercentage = val);
                        }, isPercentage: true);
                      } else {
                        _showEditDialog('Discount', _discount, (val) {
                          setState(() => _discount = val);
                        });
                      }
                    },
                    child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                  ),
                ),
            ],
          ),
          MoneyText(
            amount: amount,
            style: TextStyle(
              fontSize: isLarge ? 24 : 16,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.w500,
              color: isLarge ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Paid By:', style: TextStyle(fontWeight: FontWeight.bold)),
              ChoiceChip(
                label: const Text('Cash'),
                selected: _paymentMethod == 'Cash',
                onSelected: (val) {
                  setState(() {
                    _paymentMethod = 'Cash';
                    _paidAmount = _total;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('UPI'),
                selected: _paymentMethod == 'UPI',
                onSelected: (val) {
                  setState(() {
                    _paymentMethod = 'UPI';
                    _paidAmount = _total;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Credit'),
                selected: _paymentMethod == 'Credit',
                onSelected: (val) {
                  if (_selectedCustomerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer first')));
                    return;
                  }
                  setState(() {
                    _paymentMethod = 'Credit';
                    _paidAmount = 0.0; // Credit usually implies unpaid
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paid Amount', style: TextStyle(fontSize: 16)),
              GestureDetector(
                onTap: () {
                  _showEditDialog('Paid Amount', _paidAmount, (val) {
                    setState(() => _paidAmount = val);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text(
                        _paidAmount.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              )
            ],
          ),
          if (_change > 0) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CHANGE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                MoneyText(
                  amount: _change,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.orange),
                ),
              ],
            )
          ],
          if (_paymentMethod == 'UPI' && ref.watch(qrCodesProvider).isNotEmpty) ...[
            const Divider(),
            const Text('Scan to Pay Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.shade100, width: 2),
              ),
              child: Builder(
                builder: (context) {
                  final qr = ref.watch(qrCodesProvider).first;
                  final connector = qr.upiData.contains('?') ? '&' : '?';
                  final dynamicUpi = '${qr.upiData}${connector}am=${_total.toStringAsFixed(2)}';
                  
                  return QrImageView(
                    data: dynamicUpi,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    embeddedImage: const AssetImage('assets/images/logo.jpg'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
                  );
                }
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 8,
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'RECEIPT',
                icon: Icons.receipt,
                isSecondary: true,
                onPressed: () {
                  _showReceiptOptions(context);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () async {
                  if (_items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items in bill.')));
                    return;
                  }

                  final billRepo = ref.read(billRepositoryProvider);
                  final generatedBillNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
                  
                  final newBill = BillsCompanion.insert(
                    billNumber: generatedBillNumber,
                    subtotal: _subtotal,
                    discount: drift.Value(_discount),
                    gstAmount: drift.Value(_gstAmount),
                    total: _total,
                    amountPaid: drift.Value(_paidAmount),
                    paymentMethod: drift.Value(_paymentMethod),
                    customerId: drift.Value(_selectedCustomerId),
                  );

                  final newItems = _items.map((item) {
                    return BillItemsCompanion.insert(
                      billId: 0, // Assigned inside the transaction
                      productId: drift.Value(item['id'] as int?),
                      productName: item['name'],
                      quantity: item['qty'],
                      unit: item['unit'],
                      price: item['price'],
                      total: item['qty'] * item['price'],
                    );
                  }).toList();

                  await billRepo.saveCompleteBill(bill: newBill, items: newItems);

                  if (context.mounted) {
                    _showPostSaveDialog(generatedBillNumber);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('SAVE BILL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showEditDialog(String title, double currentValue, ValueChanged<double> onSaved, {bool isPercentage = false}) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: isPercentage ? null : '₹ ', suffixText: isPercentage ? '%' : null),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => context.pop(), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text) ?? 0.0;
                onSaved(val);
                context.pop();
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
  void _promptForQuantityAndAdd(Product product) {
    final controller = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quantity for ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: product.unit),
            autofocus: true,
            onSubmitted: (val) {
              final qty = double.tryParse(val) ?? 1.0;
              setState(() {
                _items.add({
                  'id': product.id,
                  'name': product.name,
                  'qty': qty,
                  'unit': product.unit,
                  'price': product.sellingPrice,
                });
              });
              context.pop();
            },
          ),
          actions: [
            TextButton(onPressed: () => context.pop(), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(controller.text) ?? 1.0;
                setState(() {
                  _items.add({
                    'id': product.id,
                    'name': product.name,
                    'qty': qty,
                    'unit': product.unit,
                    'price': product.sellingPrice,
                  });
                });
                context.pop();
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCustomItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    String selectedUnit = 'pcs';
    final units = ['pcs', 'kg', 'g', 'L', 'ml', 'box', 'dozen', 'm'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price', prefixText: '₹'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => context.pop(), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                    final price = double.tryParse(priceCtrl.text) ?? 0.0;
                    setState(() {
                      _items.add({
                        'id': null,
                        'name': nameCtrl.text.trim(),
                        'qty': qty,
                        'unit': selectedUnit,
                        'price': price,
                      });
                    });
                    context.pop();
                  },
                  child: const Text('ADD'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showReceiptOptions(BuildContext context) {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items in bill to generate receipt.')));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Receipt Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.blue),
                title: const Text('Share Simple Text Receipt'),
                onTap: () {
                  context.pop();
                  _shareReceiptText();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Share Professional PDF'),
                subtitle: const Text('With logo and store details'),
                onTap: () {
                  context.pop();
                  _generateAndSharePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.purple),
                title: const Text('Print Receipt (Bluetooth)'),
                onTap: () {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect Bluetooth printer in Settings to print directly.')));
                  // Or they can print via the Share sheet using Android's built-in Print service.
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  void _shareReceiptText() {
    final storeName = ref.read(storeNameProvider);
    final buffer = StringBuffer();
    buffer.writeln('=== $storeName ===');
    buffer.writeln('Receipt');
    buffer.writeln('--------------------------------');
    for (var item in _items) {
      buffer.writeln('${item['name']} - ${item['qty']}${item['unit']} x ${item['price']} = ₹${item['qty']*item['price']}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Subtotal: ₹$_subtotal');
    if (_discount > 0) buffer.writeln('Discount: -₹$_discount');
    if (_gstAmount > 0) buffer.writeln('GST ($_gstPercentage%): ₹$_gstAmount');
    buffer.writeln('TOTAL: ₹$_total');
    buffer.writeln('--------------------------------');
    buffer.writeln('Thank you for visiting!');
    
    Share.share(buffer.toString(), subject: 'Receipt from $storeName');
  }

  void _generateAndSharePdf([String? billNumber]) {
    final storeName = ref.read(storeNameProvider);
    final storeAddress = ref.read(storeAddressProvider);
    final storePhone = ref.read(storePhoneProvider);
    final storeGstn = ref.read(storeGstnProvider);

    PdfService.shareReceipt(
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeGstn: storeGstn,
      items: _items,
      subtotal: _subtotal,
      discount: _discount,
      gstPercentage: _gstPercentage,
      gstAmount: _gstAmount,
      total: _total,
      paidAmount: _paidAmount,
      paymentMethod: _paymentMethod,
      billNumber: billNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _showPostSaveDialog(String billNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 16),
              Text('Bill Saved!', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
          content: const Text('Would you like to share a receipt for this bill?', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _generateAndSharePdf(billNumber);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Share Professional PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _shareReceiptText();
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Simple Text'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    // Start next bill
                    setState(() {
                      _items.clear();
                      _selectedCustomerId = null;
                      _paidAmount = 0.0;
                      _discount = 0.0;
                      _paymentMethod = 'Cash';
                    });
                    Navigator.pop(context); // Close dialog
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('New Bill'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    context.pop(); // Go back to dashboard
                  },
                  child: const Text('Back to Home', style: TextStyle(color: Colors.grey)),
                ),
              ],
            )
          ],
        );
      },
    );
  }
}
