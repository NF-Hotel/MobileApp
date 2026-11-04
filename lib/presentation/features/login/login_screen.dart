import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/presentation/features/login/login_view_model.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The sign-in of a member of staff.
class LoginScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const LoginScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      unawaited(widget.viewModel.submit(_userName.text, _password.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navy, AppColors.navyDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      Strings.appTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Strings.signInTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.amber,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ListenableBuilder(
                          listenable: viewModel,
                          builder: (context, _) => _form(context),
                        ),
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

  Widget _form(BuildContext context) {
    final viewModel = widget.viewModel;
    final error = viewModel.errorMessage;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('userName'),
            controller: _userName,
            enabled: !viewModel.isBusy,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: Strings.userName,
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: viewModel.validateUserName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('password'),
            controller: _password,
            enabled: !viewModel.isBusy,
            obscureText: _hidePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: Strings.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hidePassword
                    ? Strings.showPassword
                    : Strings.hidePassword,
                icon: Icon(
                  _hidePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            validator: viewModel.validatePassword,
          ),
          const SizedBox(height: 16),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error,
                key: const ValueKey('loginError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            key: const ValueKey('signIn'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.navyDark,
              disabledBackgroundColor: AppColors.amber.withValues(alpha: 0.5),
              disabledForegroundColor: AppColors.navyDark,
            ),
            onPressed: viewModel.isBusy ? null : _submit,
            child: viewModel.isBusy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.navyDark,
                    ),
                  )
                : const Text(Strings.signInButton),
          ),
        ],
      ),
    );
  }
}
