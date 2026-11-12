import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/movement.dart';
import '../../providers/session_provider.dart';
import '../../providers/working_day_provider.dart';
import '../../repositories/movement_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/shift_repository.dart';
import '../../services/report_builder.dart';
import '../../utils/business_date.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/day_status_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_tile.dart';
import '../movement/movement_entry_screen.dart';
import '../reports/report_detail_screen.dart';

/// The store's one screen for the whole day.
///
/// Morning: pick the working date and start the day. During the day: record
/// inward and outward stock against that date. Evening: close the day, which
/// generates and seals the report for that date automatically. Both store
/// logins see the same state because the working day is shared in Firestore.
class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  final _reportRepository = ReportRepository();
  final _movementRepository = MovementRepository();
  bool _busy = false;

  Future<void> _selectAndStartDay() async {
    final today = parseBusinessDate(todayBusinessDate());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      // Back-filling a missed day is legitimate; working on a future date is
      // not, since its stock has not moved yet.
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
      helpText: 'Select the working date',
      confirmText: 'Start day',
    );
    if (picked == null || !mounted) return;

    final user = context.read<SessionProvider>().user!;
    final businessDate = businessDateOf(picked);

    setState(() => _busy = true);
    try {
      await context.read<WorkingDayProvider>().openDay(user, businessDate);
      _snack('Working day started', AppColors.inward);
    } on ShiftAlreadyOpenException {
      _snack('That day is already open', AppColors.dispatch);
    } on AnotherDayOpenException catch (e) {
      _snack(
        'Another day (${_pretty(e.openBusinessDate)}) is still open — '
        'close it first',
        AppColors.dispatch,
      );
    } on ShiftAlreadyClosedException {
      _snack(
        'That day was already closed and its report saved. '
        'It cannot be reopened.',
        AppColors.dispatch,
      );
    } catch (error) {
      _snack('Could not start the day: $error', AppColors.dispatch);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeDay() async {
    final day = context.read<WorkingDayProvider>();
    final user = context.read<SessionProvider>().user!;
    final businessDate = day.businessDate;
    if (businessDate == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Close ${_pretty(businessDate)}?'),
        content: const Text(
          'This saves the day\'s report and seals it permanently. '
          'The day cannot be reopened afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dispatch),
            child: const Text('Close & save report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final report = await _reportRepository.closeDayAndBuildReport(
        businessDate: businessDate,
        user: user,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(businessDate: report.businessDate),
        ),
      );
    } on ReportAlreadyExistsException {
      _snack('A report already exists for this day', AppColors.dispatch);
    } on NoOpenShiftException {
      _snack('There is no open day to close', AppColors.dispatch);
    } catch (error) {
      _snack('Could not close the day: $error', AppColors.dispatch);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEntry(MovementType type) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovementEntryScreen(type: type)));
  }

  String _pretty(String businessDate) =>
      DateFormat('EEE, d MMM').format(parseBusinessDate(businessDate));

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final day = context.watch<WorkingDayProvider>();
    final user = context.watch<SessionProvider>().user;

    return AppScaffold(
      title: 'Stock Entry',
      body: Column(
        children: [
          const DayStatusBanner(),
          Expanded(
            child: day.loading
                ? const Center(child: CircularProgressIndicator())
                : !day.isDayOpen
                ? _SelectDayCard(busy: _busy, onSelect: _selectAndStartDay)
                : _OpenDayBody(
                    businessDate: day.businessDate!,
                    userId: user?.uid,
                    busy: _busy,
                    movementRepository: _movementRepository,
                    onInward: () => _openEntry(MovementType.inward),
                    onOutward: () => _openEntry(MovementType.dispatch),
                    onClose: _closeDay,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Morning state: nothing can be recorded until a date is picked.
class _SelectDayCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onSelect;

  const _SelectDayCard({required this.busy, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.screenPadding,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 56,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select the working date',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick today\'s date once in the morning. Every inward and '
                  'outward entry from any store login is filed under it, and '
                  'closing the day saves its report automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF5B5B66)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: AppSizes.primaryButton,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onSelect,
                    icon: busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.event, size: 30),
                    label: const Text(
                      'Select date & start day',
                      style: TextStyle(fontSize: 21),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Working state: the two entry buttons, a running total, the operator's
/// own recent entries, and the close-day control at the bottom.
class _OpenDayBody extends StatelessWidget {
  final String businessDate;
  final String? userId;
  final bool busy;
  final MovementRepository movementRepository;
  final VoidCallback onInward;
  final VoidCallback onOutward;
  final VoidCallback onClose;

  const _OpenDayBody({
    required this.businessDate,
    required this.userId,
    required this.busy,
    required this.movementRepository,
    required this.onInward,
    required this.onOutward,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.screenPadding,
      children: [
        Row(
          children: [
            Expanded(
              child: _EntryButton(
                label: 'Inward',
                icon: Icons.south_west,
                color: AppColors.inward,
                onPressed: busy ? null : onInward,
              ),
            ),
            const SizedBox(width: AppSizes.primaryButtonSpacing),
            Expanded(
              child: _EntryButton(
                label: 'Outward',
                icon: Icons.north_east,
                color: AppColors.dispatch,
                onPressed: busy ? null : onOutward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _TodaySoFar(businessDate: businessDate, repository: movementRepository),
        const SizedBox(height: 24),
        const Text(
          'Your recent entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (userId != null)
          _RecentEntries(userId: userId!, repository: movementRepository),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.flag_circle_outlined,
                  size: 48,
                  color: AppColors.dispatch,
                ),
                const SizedBox(height: 10),
                const Text(
                  'End of day',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Closing saves the report for this date and seals it. '
                  'This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF5B5B66)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: busy ? null : onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dispatch,
                  ),
                  icon: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: const Text('Close day & save report'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _EntryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.primaryButton,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSizes.buttonIconSize),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

class _RecentEntries extends StatelessWidget {
  final String userId;
  final MovementRepository repository;

  const _RecentEntries({required this.userId, required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Movement>>(
      stream: repository.watchRecentForUser(userId, limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final movements = snapshot.data ?? const <Movement>[];
        if (movements.isEmpty) {
          return const EmptyState(
            icon: Icons.swap_vert,
            message: 'Nothing recorded yet today.',
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < movements.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                MovementTile(movement: movements[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A live preview of the figures the closing report will carry, so the
/// operator can sanity-check the day before sealing it.
class _TodaySoFar extends StatelessWidget {
  final String businessDate;
  final MovementRepository repository;

  const _TodaySoFar({required this.businessDate, required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Movement>>(
      stream: repository.watchForBusinessDate(businessDate),
      builder: (context, snapshot) {
        final movements = snapshot.data ?? const <Movement>[];
        final totals = ReportBuilder.buildTotals(movements: movements);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This day so far',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _Stat(
                      label: 'Inward',
                      value: '+${totals.inwardQty}',
                      color: AppColors.inward,
                    ),
                    _Stat(
                      label: 'Outward',
                      value: '-${totals.dispatchQty}',
                      color: AppColors.dispatch,
                    ),
                    _Stat(
                      label: 'Movements',
                      value: '${totals.movementCount}',
                      color: AppColors.brandBlue,
                    ),
                    _Stat(
                      label: 'Items',
                      value: '${totals.itemsTouched}',
                      color: AppColors.brandBlue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B75)),
          ),
        ],
      ),
    );
  }
}
