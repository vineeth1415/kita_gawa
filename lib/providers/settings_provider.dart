import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Watches the single settings document, whose `auditEnabled` flag decides
/// whether the Auditor role has anything to do.
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository;
  StreamSubscription<AppSettings>? _sub;

  SettingsProvider({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository();

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;
  bool get auditEnabled => _settings.auditEnabled;

  bool _loaded = false;
  bool get loaded => _loaded;

  void start() {
    _sub ??= _repository.watch().listen((value) {
      _settings = value;
      _loaded = true;
      notifyListeners();
    }, onError: (_) {
      _loaded = true;
      notifyListeners();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _settings = const AppSettings();
    _loaded = false;
  }

  Future<void> setAuditEnabled(bool enabled, String updatedBy) {
    return _repository.setAuditEnabled(enabled: enabled, updatedBy: updatedBy);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
