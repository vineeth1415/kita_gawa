import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shift_report.dart';
import '../repositories/report_repository.dart';

class ReportsProvider extends ChangeNotifier {
  final ReportRepository _repository;
  StreamSubscription<List<ShiftReport>>? _sub;

  ReportsProvider({ReportRepository? repository})
    : _repository = repository ?? ReportRepository();

  List<ShiftReport> _reports = const [];
  List<ShiftReport> get reports => _reports;

  bool _loading = true;
  bool get loading => _loading;

  void start() {
    _sub ??= _repository.watchHistory().listen(
      (value) {
        _reports = value;
        _loading = false;
        notifyListeners();
      },
      onError: (Object _) {
        _loading = false;
        notifyListeners();
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _reports = const [];
    _loading = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
