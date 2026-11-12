import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/audit_session.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/audit_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'audit_count_screen.dart';

/// The auditor's workspace: start a verification walk-through, or revisit a
/// past one.
///
/// This whole tab only exists while an admin has switched audit on, and the
/// security rules refuse audit writes when it is off — so the feature really
/// is disabled, not merely hidden.
class AuditSessionsScreen extends StatefulWidget {
  const AuditSessionsScreen({super.key});

  @override
  State<AuditSessionsScreen> createState() => _AuditSessionsScreenState();
}

class _AuditSessionsScreenState extends State<AuditSessionsScreen> {
  final _repository = AuditRepository();
  bool _starting = false;

  Future<void> _startSession() async {
    final user = context.read<SessionProvider>().user!;
    setState(() => _starting = true);
    try {
      // An auditor who left a session open resumes it rather than starting a
      // second one, so counts are never split across two sessions.
      final existing = await _repository.fetchOpenSessionFor(user.uid);
      final session = existing ?? await _repository.startSession(user: user);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AuditCountScreen(session: session),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start the audit: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsProvider>().auditEnabled;
    final dateFormat = DateFormat('EEE, d MMM yyyy · h:mm a');

    return AppScaffold(
      title: 'Stock Audit',
      body: Column(
        children: [
          Padding(
            padding: AppSizes.screenPadding,
            child: SizedBox(
              height: AppSizes.primaryButton,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.audit,
                ),
                icon: const Icon(Icons.fact_check, size: 28),
                label: Text(
                  _starting ? 'Starting…' : 'Start Verification',
                  style: const TextStyle(fontSize: 21),
                ),
                onPressed: (!enabled || _starting) ? null : _startSession,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Past verifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AuditSession>>(
              stream: _repository.watchSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snapshot.data ?? const <AuditSession>[];
                if (sessions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fact_check_outlined,
                    message:
                        'No verifications yet.\n'
                        'Start one to count physical stock against the system.',
                  );
                }
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final started = session.startedAt;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: session.isOpen
                            ? Colors.amber.withValues(alpha: 0.25)
                            : AppColors.audit.withValues(alpha: 0.12),
                        child: Icon(
                          session.isOpen ? Icons.edit_note : Icons.check,
                          color: session.isOpen
                              ? const Color(0xFF8A6100)
                              : AppColors.audit,
                        ),
                      ),
                      title: Text(
                        started == null
                            ? session.businessDate
                            : dateFormat.format(started),
                      ),
                      subtitle: Text(
                        session.isOpen
                            ? 'In progress · ${session.startedByName}'
                            : '${session.itemsCounted} counted · '
                                  '${session.itemsWithVariance} with variance'
                                  '${session.correctionsApplied ? ' · corrected' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AuditCountScreen(session: session),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
