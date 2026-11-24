import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _store = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// null = follow device (Arabic by default).
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _store.read(key: 'locale');
      if (v == 'ar' || v == 'en') state = Locale(v!);
    } catch (_) {}
  }

  Future<void> set(String code) async {
    state = Locale(code);
    try {
      await _store.write(key: 'locale', value: code);
    } catch (_) {}
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());
