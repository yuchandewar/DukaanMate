import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dukaan_mate/core/providers/qr_codes_provider.dart';

class QRCodesScreen extends ConsumerWidget {
  const QRCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrCodes = ref.watch(qrCodesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payment QRs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add new QR',
            onPressed: () => _showAddQRDialog(context, ref),
          ),
        ],
      ),
      body: qrCodes.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: qrCodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final qr = qrCodes[index];
                return _buildQRCard(context, ref, qr);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'No Payment QRs Saved',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your UPI ID to generate dynamic payment QRs for your customers.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddQRDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add UPI ID'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCard(BuildContext context, WidgetRef ref, QRCode qr) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showFullScreenQR(context, qr),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Hero(
                tag: 'qr_${qr.id}',
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: qr.upiData,
                    version: QrVersions.auto,
                    size: 80,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    embeddedImage: const AssetImage('assets/images/logo.jpg'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(20, 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qr.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Tap to set amount and view', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  ref.read(qrCodesProvider.notifier).removeQRCode(qr.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code deleted')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddQRDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final upiController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add UPI ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (e.g. Google Pay, Shop QR)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID (e.g. shop@okicici)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final upi = upiController.text.trim();
                if (name.isNotEmpty && upi.isNotEmpty) {
                  // Basic UPI Intent
                  final upiData = 'upi://pay?pa=$upi&pn=${Uri.encodeComponent(name)}&cu=INR';
                  ref.read(qrCodesProvider.notifier).addQRCode(name, upiData);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added!')));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      }
    );
  }

  void _showFullScreenQR(BuildContext context, QRCode qr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DynamicQRScreen(qr: qr),
      ),
    );
  }
}

class _DynamicQRScreen extends StatefulWidget {
  final QRCode qr;
  const _DynamicQRScreen({required this.qr});

  @override
  State<_DynamicQRScreen> createState() => _DynamicQRScreenState();
}

class _DynamicQRScreenState extends State<_DynamicQRScreen> {
  String _amount = "";
  final TextEditingController _amountController = TextEditingController();

  String get _dynamicUpiData {
    if (_amount.isEmpty || double.tryParse(_amount) == null) {
      return widget.qr.upiData;
    }
    // Append amount to UPI string
    final connector = widget.qr.upiData.contains('?') ? '&' : '?';
    return '${widget.qr.upiData}${connector}am=$_amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.qr.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  hintText: 'Enter Amount (Optional)',
                  hintStyle: const TextStyle(fontSize: 20, color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _amount = val;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text('Enter an amount to generate a specific payment QR', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              Hero(
                tag: 'qr_${widget.qr.id}',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: QrImageView(
                    data: _dynamicUpiData,
                    version: QrVersions.auto,
                    size: 300,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    embeddedImage: const AssetImage('assets/images/logo.jpg'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(60, 60),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _amount.isNotEmpty ? 'Scan to pay ₹$_amount' : 'Scan to pay any amount',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
