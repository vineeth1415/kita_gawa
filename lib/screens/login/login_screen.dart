import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final session = context.read<SessionProvider>();
    final ok = await session.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.lastError ?? 'Sign in failed'),
        backgroundColor: AppColors.dispatch,
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: const Text(
          'Please contact your Administrator to reset your password.\n\n'
          'The Administrator can reset your password directly from the '
          'Admin > Users screen using your username.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signingIn = context.watch<SessionProvider>().signingIn;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSizes.screenPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: BrandLogo(
                        width: AppSizes.logoWidthLogin,
                        framed: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Stock Movement',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.2,
                          color: Color(0xFF6B6B75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      // Usernames are stored and looked up in lower case, so
                      // the field refuses to produce anything else.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9._\-]'),
                        ),
                        TextInputFormatter.withFunction(
                          (_, next) =>
                              next.copyWith(text: next.text.toLowerCase()),
                        ),
                      ],
                      validator: (v) => requiredField(v, label: 'Username'),
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => requiredField(v, label: 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: signingIn ? null : _submit,
                      child: signingIn
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _showForgotPasswordDialog(context),
                      child: const Text('Forgot password?'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask your administrator for an account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A8A93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
