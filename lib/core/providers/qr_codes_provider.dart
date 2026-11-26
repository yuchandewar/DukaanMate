import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dukaan_mate/core/providers/settings_provider.dart';

class QRCode {
  final String id;
  final String name;
  final String upiData;
  
  QRCode({required this.id, required this.name, required this.upiData});
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'upiData': upiData};
  factory QRCode.fromJson(Map<String, dynamic> json) => QRCode(
    id: json['id'], 
    name: json['name'], 
    upiData: json['upiData'] ?? json['imagePath'] ?? '', // Handle legacy data
  );
}

class QRCodesNotifier extends Notifier<List<QRCode>> {
  @override
  List<QRCode> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final data = prefs.getStringList('payment_qrs') ?? [];
    return data.map((e) => QRCode.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addQRCode(String name, String upiData) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final newQr = QRCode(id: id, name: name, upiData: upiData);
    final newList = [...state, newQr];
    
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList('payment_qrs', newList.map((e) => jsonEncode(e.toJson())).toList());
    
    state = newList;
  }
  
  Future<void> removeQRCode(String id) async {
    final newList = state.where((e) => e.id != id).toList();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList('payment_qrs', newList.map((e) => jsonEncode(e.toJson())).toList());
    
    state = newList;
  }
}

final qrCodesProvider = NotifierProvider<QRCodesNotifier, List<QRCode>>(() {
  return QRCodesNotifier();
});
