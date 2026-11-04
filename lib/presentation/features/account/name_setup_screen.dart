import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/presentation/features/account/name_setup_view_model.dart';
import 'package:mobil_application/presentation/shared/form_page.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// Asks for the name of an account that has none, after the sign-in (MIL-059).
class NameSetupScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const NameSetupScreen({required this.viewModel, this.onSignOut, super.key});

  /// What the screen shows and does.
  final NameSetupViewModel viewModel;

  /// Signs out, so nobody is stuck on this step.
  final VoidCallback? onSignOut;

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      unawaited(widget.viewModel.submit(_first.text, _last.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final onSignOut = widget.onSignOut;
    return FormPage(
      title: Strings.yourName,
      heading: Strings.welcome,
      hint: Strings.addYourName,
      canGoBack: false,
      actions: [
        if (onSignOut != null)
          IconButton(
            key: const ValueKey('signOut'),
            tooltip: Strings.signOut,
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
      ],
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final error = viewModel.errorMessage;
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('firstName'),
                  controller: _first,
                  enabled: !viewModel.isBusy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(
                    labelText: Strings.firstName,
                  ),
                  validator: viewModel.validateFirstName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('lastName'),
                  controller: _last,
                  enabled: !viewModel.isBusy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.familyName],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: Strings.lastName,
                  ),
                  validator: viewModel.validateLastName,
                ),
                const SizedBox(height: 24),
                if (error != null) FormError(error),
                FilledButton(
                  key: const ValueKey('saveName'),
                  onPressed: viewModel.isBusy ? null : _submit,
                  child: viewModel.isBusy
                      ? const ButtonSpinner()
                      : const Text(Strings.continueButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
