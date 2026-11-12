import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_user.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';
import '../utils/business_date.dart';

/// Tracks the working day the store has selected.
///
/// The date is not the device's clock: a store user picks it once in the
/// morning and every device follows the shared `settings/workingDay`
/// pointer, so two store phones always file under the same date. The pointer
/// is set when a day is started and cleared when it is closed, so this
/// provider only ever sees "no day selected" or "this day is open".
///
/// The device clock still matters for one thing — warning when the working
/// day is not today (someone forgot to close yesterday). A timer fires at the
/// next local midnight so that hint appears on a device left awake on a dock
/// rather than waiting for a resume that may never come.
class WorkingDayProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ShiftRepository _repository;
  StreamSubscription<String?>? _pointerSub;
  StreamSubscription<Shift?>? _shiftSub;
  Timer? _midnightTimer;

  WorkingDayProvider({ShiftRepository? repository})
    : _repository = repository ?? ShiftRepository();

  String? _businessDate;

  /// The selected working day, or null when none has been started.
  String? get businessDate => _businessDate;

  Shift? _shift;
  Shift? get shift => _shift;

  bool _loading = true;
  bool get loading => _loading;

  bool get isDayOpen => _businessDate != null && (_shift?.isOpen ?? false);
  bool get noDaySelected => !_loading && _businessDate == null;

  /// True when the working day is behind the device's calendar — the usual
  /// sign that yesterday was never closed.
  bool get isStale =>
      _businessDate != null && _businessDate != todayBusinessDate();

  /// The shift id to stamp on a movement; null when no day is open, in which
  /// case the entry screens refuse to save.
  String? get openShiftId => isDayOpen ? _businessDate : null;

  void start() {
    if (_pointerSub != null) return;
    WidgetsBinding.instance.addObserver(this);
    _loading = true;
    _pointerSub = _repository.watchWorkingDay().listen(
      _onWorkingDay,
      onError: (Object _) {
        _loading = false;
        notifyListeners();
      },
    );
    _scheduleMidnightRollover();
  }

  void _onWorkingDay(String? date) {
    if (date == _businessDate && _shiftSub != null) return;
    _businessDate = date;
    _shift = null;
    _shiftSub?.cancel();
    _shiftSub = null;

    if (date == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    _shiftSub = _repository
        .watchShiftFor(date)
        .listen(
          (value) {
            _shift = value;
            _loading = false;
            notifyListeners();
          },
          onError: (Object _) {
            _loading = false;
            notifyListeners();
          },
        );
  }

  /// Re-notifies at local midnight so [isStale] flips without user action.
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // A few seconds' grace, so the timer never fires a hair early.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 2);
    _midnightTimer = Timer(delay, () {
      notifyListeners();
      _scheduleMidnightRollover();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Timers do not fire reliably while the process is suspended, so a
    // resume re-arms the timer and refreshes the stale-day hint.
    _scheduleMidnightRollover();
    notifyListeners();
  }

  void stop() {
    _pointerSub?.cancel();
    _pointerSub = null;
    _shiftSub?.cancel();
    _shiftSub = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _businessDate = null;
    _shift = null;
    _loading = true;
  }

  /// Starts [businessDate] as the working day. The stream updates every
  /// device, including this one, but the local state is set eagerly so the
  /// screen does not flicker back to "select a date" while the snapshot is
  /// in flight.
  Future<Shift> openDay(AppUser user, String businessDate) async {
    final shift = await _repository.openDay(
      businessDate: businessDate,
      user: user,
    );
    _businessDate = businessDate;
    _shift = shift;
    _loading = false;
    notifyListeners();
    return shift;
  }

  @override
  void dispose() {
    _pointerSub?.cancel();
    _shiftSub?.cancel();
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
