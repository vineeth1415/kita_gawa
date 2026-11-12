import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/items_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/working_day_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/brand_logo.dart';
import '../home/home_shell.dart';
import '../login/login_screen.dart';

/// The gate every launch passes through.
///
/// It shows the brand while Firebase resolves the cached session and the
/// user's role is read from Firestore, then routes on the outcome. Because
/// the role determines which screens even exist for a user, nothing else can
/// be built until this resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    // Firestore listeners are started and torn down alongside the session, so
    // a signed-out app holds no open snapshot streams.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (session.isSignedIn) {
        context.read<SettingsProvider>().start();
        context.read<ItemsProvider>().start();
        context.read<WorkingDayProvider>().start();
        context.read<ReportsProvider>().start();
      } else {
        context.read<SettingsProvider>().stop();
        context.read<ItemsProvider>().stop();
        context.read<WorkingDayProvider>().stop();
        context.read<ReportsProvider>().stop();
      }
    });

    return switch (session.status) {
      SessionStatus.initializing => const _SplashBody(),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.signedIn => const HomeShell(),
      SessionStatus.noProfile => const _AccessProblem(
        title: 'This account is not set up',
        message:
            'Your sign-in worked, but no role has been assigned to it yet. '
            'Ask an administrator to add your account before using the app.',
      ),
      SessionStatus.deactivated => const _AccessProblem(
        title: 'Account deactivated',
        message:
            'An administrator has deactivated this account. '
            'Contact them if you think this is a mistake.',
      ),
    };
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(width: AppSizes.logoWidthSplash, framed: false),
            SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 20),
            Text(
              'Stock Movement',
              style: TextStyle(fontSize: 15, color: Color(0xFF6B6B75)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessProblem extends StatelessWidget {
  final String title;
  final String message;

  const _AccessProblem({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSizes.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(width: 200, framed: false),
                const SizedBox(height: 40),
                const Icon(
                  Icons.no_accounts,
                  size: 56,
                  color: AppColors.dispatch,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5B5B66),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.read<SessionProvider>().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
