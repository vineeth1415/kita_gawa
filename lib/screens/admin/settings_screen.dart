import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/brand_logo.dart';

/// Admin settings — currently the one switch the requirement calls for.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saving = false;

  Future<void> _toggleAudit(bool enabled) async {
    final admin = context.read<SessionProvider>().user!;
    setState(() => _saving = true);
    try {
      await context.read<SettingsProvider>().setAuditEnabled(
        enabled,
        admin.uid,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: AppSizes.screenPadding,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fact_check, color: AppColors.audit),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Stock verification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_saving)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        Switch(
                          value: settings.auditEnabled,
                          onChanged: _toggleAudit,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When enabled, Auditor accounts can run periodic '
                    'verification sessions: counting physical stock against '
                    'the figures the store has recorded, and '
                    'optionally correcting the difference.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF5B5B66)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    settings.auditEnabled
                        ? 'Auditors can verify stock now.'
                        : 'Auditors can view stock and reports, but cannot '
                              'start a verification.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: settings.auditEnabled
                          ? AppColors.inward
                          : const Color(0xFF6B6B75),
                    ),
                  ),
                  if (settings.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last changed '
                      '${DateFormat('d MMM yyyy, h:mm a').format(settings.updatedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8A93),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Framed here, unlike on the white login and splash screens: this
          // page sits on the tinted scaffold, where the logo's opaque white
          // background would otherwise read as a stray rectangle.
          const Center(child: BrandLogo(width: 180)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Stock Movement · Firestore project kitagawa-inventory-app',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A93)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
