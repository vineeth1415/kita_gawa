import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/user_admin_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

/// Creates a staff account and assigns its role.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UserAdminService();

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.store;
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final admin = context.read<SessionProvider>().user!;
    setState(() => _saving = true);

    try {
      final created = await _service.createStaffAccount(
        username: _usernameController.text,
        displayName: _displayNameController.text,
        password: _passwordController.text,
        role: _role,
        createdBy: admin.uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.inward,
          content: Text(
            '${created.displayName} can now sign in as "${created.username}"',
          ),
        ),
      );
    } on UsernameTakenException catch (e) {
      _snack('Username "${e.username}" is already taken');
    } catch (error) {
      _snack(AuthService.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dispatch),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New user')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    helperText: 'Shown against every movement they record',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => requiredField(v, label: 'Full name'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'What they type to sign in',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9._\-]'),
                    ),
                    TextInputFormatter.withFunction(
                      (_, next) => next.copyWith(text: next.text.toLowerCase()),
                    ),
                  ],
                  validator: validateUsername,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'Share it with them directly',
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
                  validator: validatePassword,
                ),
                const SizedBox(height: 26),
                const Text(
                  'Role',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RadioGroup<UserRole>(
                  groupValue: _role,
                  // RadioGroup requires a non-null callback, so the
                  // saving guard lives inside it rather than on the widget.
                  onChanged: (value) {
                    if (_saving || value == null) return;
                    setState(() => _role = value);
                  },
                  child: Column(
                    children: [
                      // The auditor is an optional role; offering it while
                      // audit is switched off would only create an account
                      // that can do nothing.
                      for (final role in UserRole.values)
                        if (role != UserRole.auditor ||
                            context.watch<SettingsProvider>().auditEnabled)
                          RadioListTile<UserRole>(
                            value: role,
                            title: Text(role.label),
                            subtitle: Text(role.description),
                            contentPadding: EdgeInsets.zero,
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
