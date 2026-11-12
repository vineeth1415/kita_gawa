import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../admin/settings_screen.dart';
import '../admin/users_screen.dart';
import '../audit/audit_sessions_screen.dart';
import '../items/items_screen.dart';
import '../reports/reports_screen.dart';
import '../stock/stock_screen.dart';
import '../store/store_home_screen.dart';
import '../transactions/transactions_screen.dart';

/// One destination in the bottom navigation bar.
class _Tab {
  final String label;
  final IconData icon;
  final Widget screen;

  const _Tab({required this.label, required this.icon, required this.screen});
}

/// Routes each role to its own set of screens.
///
/// Roles get different tabs rather than a shared screen with disabled
/// buttons: a read-only user never sees an entry control they are not allowed to
/// use. The security rules enforce the same boundaries server side, so this
/// is a usability decision, not the access control itself.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Tab> _tabsFor(UserRole role, {required bool auditEnabled}) {
    switch (role) {
      case UserRole.store:
        return const [
          _Tab(
            label: 'Entry',
            icon: Icons.swap_vert,
            screen: StoreHomeScreen(),
          ),
          _Tab(label: 'Stock', icon: Icons.inventory_2, screen: StockScreen()),
          _Tab(
            label: 'Reports',
            icon: Icons.receipt_long,
            screen: ReportsScreen(),
          ),
        ];

      case UserRole.readOnly:
        // Management / audit: current stock, the live ledger, sealed reports.
        return const [
          _Tab(label: 'Stock', icon: Icons.inventory_2, screen: StockScreen()),
          _Tab(
            label: 'Transactions',
            icon: Icons.list_alt,
            screen: TransactionsScreen(),
          ),
          _Tab(
            label: 'Reports',
            icon: Icons.receipt_long,
            screen: ReportsScreen(),
          ),
        ];

      case UserRole.auditor:
        return [
          // The auditor's own workspace only exists while the feature is
          // switched on; with it off they keep read-only visibility.
          if (auditEnabled)
            const _Tab(
              label: 'Audit',
              icon: Icons.fact_check,
              screen: AuditSessionsScreen(),
            ),
          const _Tab(
            label: 'Stock',
            icon: Icons.inventory_2,
            screen: StockScreen(),
          ),
          const _Tab(
            label: 'Reports',
            icon: Icons.receipt_long,
            screen: ReportsScreen(),
          ),
        ];

      case UserRole.admin:
        return const [
          _Tab(label: 'Items', icon: Icons.category, screen: ItemsScreen()),
          _Tab(label: 'Stock', icon: Icons.inventory_2, screen: StockScreen()),
          _Tab(
            label: 'Reports',
            icon: Icons.receipt_long,
            screen: ReportsScreen(),
          ),
          _Tab(label: 'Users', icon: Icons.people, screen: UsersScreen()),
          _Tab(
            label: 'Settings',
            icon: Icons.settings,
            screen: SettingsScreen(),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final auditEnabled = context.watch<SettingsProvider>().auditEnabled;
    final user = session.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = _tabsFor(user.role, auditEnabled: auditEnabled);
    // The auditor's tab list shrinks when audit is switched off mid-session,
    // so the selected index is clamped rather than left dangling.
    final index = _index >= tabs.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) tab.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
