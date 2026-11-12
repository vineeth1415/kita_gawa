import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/session_provider.dart';
import '../screens/account/change_password_screen.dart';
import '../utils/constants.dart';

enum _AccountAction { changePassword, signOut }

/// Standard page chrome: the screen title, who is signed in and in what role,
/// and an account menu.
///
/// Showing the role in the app bar is deliberate — these devices are shared,
/// and stock entries are attributed to whoever is logged in. Making the
/// current identity impossible to miss reduces movements filed under the
/// wrong person.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 20)),
            if (user != null)
              Text(
                '${user.displayName} · ${user.role.label}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B6B75),
                ),
              ),
          ],
        ),
        actions: [
          ...actions,
          // Every role reaches its own password through this menu — it is the
          // one chrome shared by all of them.
          PopupMenuButton<_AccountAction>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onSelected: (action) => switch (action) {
              _AccountAction.changePassword => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              ),
              _AccountAction.signOut => _confirmSignOut(context),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _AccountAction.changePassword,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_reset),
                  title: Text('Change password'),
                ),
              ),
              PopupMenuItem(
                value: _AccountAction.signOut,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: AppColors.dispatch),
                  title: Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your username and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dispatch),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SessionProvider>().signOut();
    }
  }
}
