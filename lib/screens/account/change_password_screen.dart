import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

/// Lets a signed-in user change their own password.
///
/// This is the only password change the app can perform itself. Usernames map
/// to synthetic addresses at a domain nobody receives mail at, so
/// `sendPasswordResetEmail` has nowhere to send anything, and setting *another*
/// account's password needs the Admin SDK — Blaze plan, Cloud Functions. A
/// genuinely forgotten password is therefore reset out of band with
/// `tool/reset_password.sh`; see docs/operations.md.
class ChangePasswordScreen extends StatefulWidget {
  final AuthService? authService;

  const ChangePasswordScreen({super.key, this.authService});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  late final AuthService _auth = widget.authService ?? AuthService();

  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.inward,
          content: Text('Password changed. Use the new one next time.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dispatch,
          content: Text(AuthService.describeError(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your password is what signs your name to every movement '
                  'you record. Change it if anyone else has seen it.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF5B5B66)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _currentController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      requiredField(v, label: 'Current password'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _newController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'At least 6 characters',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (v) => validateNewPassword(
                    v,
                    currentPassword: _currentController.text,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  onFieldSubmitted: (_) => _saving ? null : _save(),
                  validator: (v) => validatePasswordConfirmation(
                    v,
                    password: _newController.text,
                  ),
                ),
                const SizedBox(height: 30),
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
                      : const Text('Change password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
