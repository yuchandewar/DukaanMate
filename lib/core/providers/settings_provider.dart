import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class StoreNameNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('store_name') ?? 'MY SHOP';
  }

  void setStoreName(String newName) {
    if (newName.trim().isNotEmpty) {
      ref.read(sharedPreferencesProvider).setString('store_name', newName.trim());
      state = newName.trim();
    }
  }
}

final storeNameProvider = NotifierProvider<StoreNameNotifier, String>(() {
  return StoreNameNotifier();
});

class StoreAddressNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('store_address') ?? '';
  }

  void setStoreAddress(String address) {
    ref.read(sharedPreferencesProvider).setString('store_address', address.trim());
    state = address.trim();
  }
}

final storeAddressProvider = NotifierProvider<StoreAddressNotifier, String>(() {
  return StoreAddressNotifier();
});

class StorePhoneNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('store_phone') ?? '';
  }

  void setStorePhone(String phone) {
    ref.read(sharedPreferencesProvider).setString('store_phone', phone.trim());
    state = phone.trim();
  }
}

final storePhoneProvider = NotifierProvider<StorePhoneNotifier, String>(() {
  return StorePhoneNotifier();
});

class StoreGstnNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('store_gstn') ?? '';
  }

  void setStoreGstn(String gstn) {
    ref.read(sharedPreferencesProvider).setString('store_gstn', gstn.trim().toUpperCase());
    state = gstn.trim().toUpperCase();
  }
}

final storeGstnProvider = NotifierProvider<StoreGstnNotifier, String>(() {
  return StoreGstnNotifier();
});

class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('dark_mode') ?? false;
  }

  void toggleTheme(bool isDark) {
    ref.read(sharedPreferencesProvider).setBool('dark_mode', isDark);
    state = isDark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(() {
  return ThemeModeNotifier();
});
