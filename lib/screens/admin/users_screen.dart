import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../repositories/user_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'user_form_screen.dart';

/// Admin-only staff roster.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = UserRepository();
    final currentUid = context.watch<SessionProvider>().user?.uid;

    return AppScaffold(
      title: 'Users',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const UserFormScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('New user'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? const <AppUser>[];
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              message: 'No users yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserRow(
                user: user,
                repository: repository,
                // An admin cannot lock themselves out of their own console,
                // which also means the roster can never reach zero admins.
                isSelf: user.uid == currentUid,
                actingUid: currentUid,
              );
            },
          );
        },
      ),
    );
  }
}

/// One roster row, with the switch that grants or removes every permission
/// the account has.
///
/// Stateful because the write is a round trip: the switch has to stay
/// disabled until Firestore confirms, or a double tap on a slow warehouse
/// network fires two conflicting updates.
class _UserRow extends StatefulWidget {
  final AppUser user;
  final UserRepository repository;
  final bool isSelf;
  final String? actingUid;

  const _UserRow({
    required this.user,
    required this.repository,
    required this.isSelf,
    required this.actingUid,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _busy = false;

  Future<void> _setActive(bool active) async {
    final user = widget.user;
    final actingUid = widget.actingUid;
    if (actingUid == null) return;

    // Deactivating takes effect on that person's device immediately, mid-task
    // if they are in the middle of one, so it is confirmed. Switching an
    // account back on takes nothing away and is not.
    if (!active && !await _confirmDeactivation(user)) return;

    setState(() => _busy = true);
    try {
      await widget.repository.setActive(
        uid: user.uid,
        active: active,
        actingUid: actingUid,
      );
      if (!mounted) return;
      _snack(
        active
            ? '${user.displayName} can sign in again'
            : '${user.displayName} has been deactivated',
        active ? AppColors.inward : AppColors.dispatch,
      );
    } catch (_) {
      // Without this the switch would spring back with no explanation — the
      // stream simply never reports the change it was told to make.
      if (!mounted) return;
      _snack(
        'Could not update ${user.displayName}. Check the connection and try again.',
        AppColors.dispatch,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDeactivation(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Deactivate ${user.displayName}?'),
        content: Text(
          'They lose access straight away, on whatever device they are '
          'holding — they do not have to sign out first.\n\n'
          'Everything ${user.displayName} has already recorded stays in the '
          'ledger and on every report. You can switch the account back on at '
          'any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dispatch),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _snack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _roleColor(user.role).withValues(alpha: 0.14),
        child: Icon(_roleIcon(user.role), color: _roleColor(user.role)),
      ),
      title: Row(
        children: [
          Flexible(child: Text(user.displayName)),
          if (widget.isSelf)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '(you)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B6B75),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${user.username} · ${user.role.label}'
        '${user.active ? '' : ' · deactivated${_deactivatedOn(user)}'}',
      ),
      trailing: _busy
          ? const SizedBox(
              width: AppSizes.minTapTarget,
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          : Switch(
              value: user.active,
              onChanged: widget.isSelf ? null : _setActive,
            ),
    );
  }

  static String _deactivatedOn(AppUser user) {
    final at = user.deactivatedAt;
    if (at == null) return '';
    final date =
        '${at.year}-${at.month.toString().padLeft(2, '0')}'
        '-${at.day.toString().padLeft(2, '0')}';
    return ' $date';
  }

  static IconData _roleIcon(UserRole role) => switch (role) {
    UserRole.admin => Icons.admin_panel_settings,
    UserRole.readOnly => Icons.visibility,
    UserRole.store => Icons.swap_vert,
    UserRole.auditor => Icons.fact_check,
  };

  static Color _roleColor(UserRole role) => switch (role) {
    UserRole.admin => AppColors.brandBlue,
    UserRole.readOnly => AppColors.brandCyan,
    UserRole.store => AppColors.inward,
    UserRole.auditor => AppColors.audit,
  };
}
