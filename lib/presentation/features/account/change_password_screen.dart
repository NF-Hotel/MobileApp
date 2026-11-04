import 'package:flutter/material.dart';

import 'package:mobil_application/presentation/features/account/change_password_view_model.dart';
import 'package:mobil_application/presentation/shared/form_page.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The change of the own password. At the first sign-in it is the only way on
/// ([forced]); from the rooms it is a page that goes back when done.
class ChangePasswordScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const ChangePasswordScreen({
    required this.viewModel,
    this.forced = false,
    this.onSignOut,
    super.key,
  });

  /// What the screen shows and does.
  final ChangePasswordViewModel viewModel;

  /// True when the member must change the password before anything else.
  final bool forced;

  /// Signs out; offered while the change is [forced], so nobody is stuck.
  final VoidCallback? onSignOut;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final changed = await widget.viewModel.submit(_current.text, _new.text);
    if (!changed || !mounted || widget.forced) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.passwordChanged)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final onSignOut = widget.onSignOut;
    return FormPage(
      title: Strings.changePassword,
      heading: widget.forced
          ? Strings.chooseNewPassword
          : Strings.changePassword,
      hint: widget.forced
          ? Strings.chooseNewPasswordHint
          : Strings.changePasswordHint,
      canGoBack: !widget.forced,
      actions: [
        if (widget.forced && onSignOut != null)
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
                  key: const ValueKey('currentPassword'),
                  controller: _current,
                  obscureText: true,
                  enabled: !viewModel.isBusy,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: Strings.currentPassword,
                  ),
                  validator: viewModel.validateCurrent,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('newPassword'),
                  controller: _new,
                  obscureText: true,
                  enabled: !viewModel.isBusy,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: Strings.newPassword,
                  ),
                  validator: viewModel.validateNew,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('confirmPassword'),
                  controller: _confirm,
                  obscureText: true,
                  enabled: !viewModel.isBusy,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: Strings.confirmPassword,
                  ),
                  validator: (value) =>
                      viewModel.validateConfirm(value, _new.text),
                ),
                const SizedBox(height: 24),
                if (error != null) FormError(error),
                FilledButton(
                  key: const ValueKey('savePassword'),
                  onPressed: viewModel.isBusy ? null : _submit,
                  child: viewModel.isBusy
                      ? const ButtonSpinner()
                      : const Text(Strings.saveButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
