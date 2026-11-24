import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _store = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Defaults to the system theme until the user picks light or dark.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _store.read(key: 'theme_mode');
      if (v == 'dark') state = ThemeMode.dark;
      if (v == 'light') state = ThemeMode.light;
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    try {
      await _store.write(key: 'theme_mode', value: m == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
