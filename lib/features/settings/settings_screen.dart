import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_mate/features/backup/backup_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukaan_mate/core/database/database_provider.dart';
import 'package:dukaan_mate/core/providers/settings_provider.dart';
import 'package:dukaan_mate/core/providers/qr_codes_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const _SectionTitle('General Info'),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Store Name'),
            subtitle: Text(ref.watch(storeNameProvider)),
            onTap: () {
              _showEditStoreNameDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Store Address'),
            subtitle: Text(ref.watch(storeAddressProvider).isEmpty ? 'Tap to add address' : ref.watch(storeAddressProvider)),
            onTap: () {
              _showEditStoreAddressDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Store Phone'),
            subtitle: Text(ref.watch(storePhoneProvider).isEmpty ? 'Tap to add phone number' : ref.watch(storePhoneProvider)),
            onTap: () {
              _showEditStorePhoneDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('GSTIN Number'),
            subtitle: Text(ref.watch(storeGstnProvider).isEmpty ? 'Tap to add GSTIN' : ref.watch(storeGstnProvider)),
            onTap: () {
              _showEditStoreGstnDialog(context, ref);
            },
          ),
          const Divider(),
          const _SectionTitle('Data & Backup'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Backup'),
            subtitle: const Text('Save your shop data securely'),
            onTap: () async {
              try {
                final db = ref.read(databaseProvider);
                await BackupService().exportBackup(db);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup exported successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import Backup'),
            subtitle: const Text('Restore data from a previous backup'),
            onTap: () async {
              try {
                final db = ref.read(databaseProvider);
                final success = await BackupService().importBackup(db);
                
                if (success) {
                  // Seamlessly reload the database across the entire app
                  ref.invalidate(databaseProvider);
                  
                  // Invalidate settings providers so they read the newly imported data
                  ref.invalidate(storeNameProvider);
                  ref.invalidate(storeAddressProvider);
                  ref.invalidate(storePhoneProvider);
                  ref.invalidate(storeGstnProvider);
                  ref.invalidate(themeModeProvider);
                  ref.invalidate(qrCodesProvider);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup imported successfully!')));
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              }
            },
          ),
          const _SectionTitle('App Preferences'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: ref.watch(themeModeProvider),
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).toggleTheme(val);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () async {
              final url = Uri.parse('https://sites.google.com/view/dukaanmate-privacy');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Privacy Policy.')));
                }
              }
            },
          ),
          const Divider(),
          const _SectionTitle('Payment Options'),
          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: const Text('My Payment QRs'),
            subtitle: const Text('Save your shop\'s UPI/Payment QR codes'),
            onTap: () {
              context.push('/qrcodes');
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

void _showEditStoreNameDialog(BuildContext context, WidgetRef ref) {
  final currentName = ref.read(storeNameProvider);
  final controller = TextEditingController(text: currentName);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit Store Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Store Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(storeNameProvider.notifier).setStoreName(controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      );
    },
  );
}

void _showEditStoreAddressDialog(BuildContext context, WidgetRef ref) {
  final currentAddress = ref.read(storeAddressProvider);
  final controller = TextEditingController(text: currentAddress);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit Store Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Full Address',
            hintText: 'E.g. Shop No 42, Main Market',
          ),
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(storeAddressProvider.notifier).setStoreAddress(controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      );
    },
  );
}

void _showEditStorePhoneDialog(BuildContext context, WidgetRef ref) {
  final currentPhone = ref.read(storePhoneProvider);
  final controller = TextEditingController(text: currentPhone);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit Store Phone'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'E.g. +91 9876543210',
          ),
          autofocus: true,
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(storePhoneProvider.notifier).setStorePhone(controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      );
    },
  );
}

void _showEditStoreGstnDialog(BuildContext context, WidgetRef ref) {
  final currentGstn = ref.read(storeGstnProvider);
  final controller = TextEditingController(text: currentGstn);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit GSTIN Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'GSTIN',
            hintText: 'E.g. 22AAAAA0000A1Z5',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(storeGstnProvider.notifier).setStoreGstn(controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      );
    },
  );
}
