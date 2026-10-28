import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/presentation/features/name/name_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// Asks a new account for its first and last name.
class NameScreen extends StatefulWidget {
  /// Creates the screen.
  const NameScreen({required this.viewModel, required this.session, super.key});

  /// What the screen shows and does.
  final NameViewModel viewModel;

  /// Who is signed in; the screen can sign them out.
  final SessionController session;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      unawaited(widget.viewModel.submit(_firstName.text, _lastName.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.nameTitle),
        actions: [
          IconButton(
            key: const ValueKey('signOut'),
            tooltip: Strings.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => unawaited(widget.session.signOut()),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) {
                  final error = viewModel.errorMessage;
                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(Strings.nameIntro),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('firstName'),
                          controller: _firstName,
                          enabled: !viewModel.isBusy,
                          autofillHints: const [AutofillHints.givenName],
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: Strings.firstName,
                          ),
                          validator: viewModel.validate,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('lastName'),
                          controller: _lastName,
                          enabled: !viewModel.isBusy,
                          autofillHints: const [AutofillHints.familyName],
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: Strings.lastName,
                          ),
                          validator: viewModel.validate,
                        ),
                        const SizedBox(height: 16),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              error,
                              key: const ValueKey('nameError'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton(
                          key: const ValueKey('saveName'),
                          onPressed: viewModel.isBusy ? null : _submit,
                          child: const Text(Strings.save),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
