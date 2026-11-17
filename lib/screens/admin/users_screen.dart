import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../repositories/user_repository.dart';
import '../../services/user_admin_service.dart';
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
      actions: [
        IconButton(
          icon: const Icon(Icons.lock_reset),
          tooltip: 'Reset user password',
          onPressed: () => _openResetDialog(context, actingAdminUid: currentUid),
        ),
      ],
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

  static Future<void> _openResetDialog(
    BuildContext context, {
    String? initialUsername,
    required String? actingAdminUid,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ResetPasswordDialog(
        initialUsername: initialUsername,
        actingAdminUid: actingAdminUid,
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialUsername != null
                ? 'Password for $initialUsername reset successfully.'
                : 'Password reset successfully.',
          ),
          backgroundColor: AppColors.inward,
        ),
      );
    }
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.lock_reset, color: AppColors.brandBlue),
            tooltip: widget.isSelf
                ? 'Use Account > Change Password to update your own password'
                : 'Reset ${user.displayName}\'s password',
            onPressed: widget.isSelf
                ? null
                : () => UsersScreen._openResetDialog(
                      context,
                      initialUsername: user.username,
                      actingAdminUid: widget.actingUid,
                    ),
          ),
          if (_busy)
            const SizedBox(
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
          else
            Switch(
              value: user.active,
              onChanged: widget.isSelf ? null : _setActive,
            ),
        ],
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

class ResetPasswordDialog extends StatefulWidget {
  final String? initialUsername;
  final String? actingAdminUid;

  const ResetPasswordDialog({
    super.key,
    this.initialUsername,
    required this.actingAdminUid,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialUsername ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final actingUid = widget.actingAdminUid;
    if (actingUid == null) {
      setState(() => _error = 'Admin session not found. Please log in again.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userAdmin = UserAdminService();
      await userAdmin.resetStaffPassword(
        username: _usernameController.text,
        newPassword: _passwordController.text,
        actingAdminUid: actingUid,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedUsername =
        widget.initialUsername != null && widget.initialUsername!.isNotEmpty;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: AppColors.brandBlue),
          SizedBox(width: 8),
          Flexible(child: Text('Reset Password')),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dispatch.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.dispatch.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.dispatch,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              TextFormField(
                controller: _usernameController,
                readOnly: lockedUsername,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: lockedUsername,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'At least 6 characters required';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Reset Password'),
        ),
      ],
    );
  }
}
