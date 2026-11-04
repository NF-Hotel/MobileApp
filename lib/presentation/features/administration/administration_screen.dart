import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/presentation/features/administration/administration_view_model.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/form_page.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The administration of a Manager (MIL-059): a new account at the top, and the
/// accounts under it, each with a menu of what can be changed.
class AdministrationScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const AdministrationScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final AdministrationViewModel viewModel;

  @override
  State<AdministrationScreen> createState() => _AdministrationScreenState();
}

class _AdministrationScreenState extends State<AdministrationScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = widget.viewModel;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.administration),
        actions: [
          IconButton(
            key: const ValueKey('refreshStaff'),
            tooltip: Strings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(viewModel.load()),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Strings.createAccount, style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(Strings.createAccountHint, style: textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  _CreateAccountCard(viewModel: viewModel),
                  const SizedBox(height: 32),
                  Text(Strings.users, style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: viewModel,
                    builder: (context, _) => _AccountList(viewModel: viewModel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the receipt or the refusal of a change. The messenger is taken before
/// the change, because the tile that asked for it may be gone after it.
void _show(ScaffoldMessengerState messenger, AdministrationOutcome outcome) {
  if (outcome.message.isEmpty) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(outcome.message),
      backgroundColor: outcome.saved ? null : AppColors.error,
    ),
  );
}

/// The form of a new account.
class _CreateAccountCard extends StatefulWidget {
  const _CreateAccountCard({required this.viewModel});

  final AdministrationViewModel viewModel;

  @override
  State<_CreateAccountCard> createState() => _CreateAccountCardState();
}

class _CreateAccountCardState extends State<_CreateAccountCard> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  StaffRole _role = StaffRole.housekeeping;

  @override
  void dispose() {
    for (final controller in [_first, _last, _userName, _email, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _email.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await widget.viewModel.create(
      NewStaffAccount(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        userName: _userName.text.trim(),
        temporaryPassword: _password.text,
        role: _role,
        email: email.isEmpty ? null : email,
      ),
    );
    if (!mounted) {
      return;
    }
    if (outcome.saved) {
      _formKey.currentState?.reset();
      for (final controller in [_first, _last, _userName, _email, _password]) {
        controller.clear();
      }
    }
    _show(messenger, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('newFirstName'),
                controller: _first,
                maxLength: AdministrationViewModel.maxNameLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: Strings.firstName,
                  counterText: '',
                ),
                validator: (value) => viewModel.validateRequired(
                  value,
                  Strings.firstNameRequired,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('newLastName'),
                controller: _last,
                maxLength: AdministrationViewModel.maxNameLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: Strings.lastName,
                  counterText: '',
                ),
                validator: (value) =>
                    viewModel.validateRequired(value, Strings.lastNameRequired),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('newUserName'),
                controller: _userName,
                maxLength: AdministrationViewModel.maxNameLength,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: Strings.userName,
                  counterText: '',
                ),
                validator: (value) => viewModel.validateRequired(
                  value,
                  Strings.accountUserNameRequired,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('newEmail'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: Strings.email),
                validator: viewModel.validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('newPassword'),
                controller: _password,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: Strings.temporaryPassword,
                  helperText: Strings.temporaryPasswordHint,
                  helperMaxLines: 2,
                ),
                validator: viewModel.validatePassword,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StaffRole>(
                key: const ValueKey('newRole'),
                initialValue: _role,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: Strings.roleLabel),
                items: [
                  for (final role in StaffRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(Strings.role(role)),
                    ),
                ],
                onChanged: (role) => setState(() => _role = role ?? _role),
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => FilledButton(
                  key: const ValueKey('createAccount'),
                  onPressed: viewModel.isBusy ? null : _create,
                  child: viewModel.isBusy
                      ? const ButtonSpinner()
                      : const Text(Strings.createAccount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The accounts, or a spinner, or the failure with a retry.
class _AccountList extends StatelessWidget {
  const _AccountList({required this.viewModel});

  final AdministrationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.state) {
      case AdministrationState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      case AdministrationState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormError(viewModel.errorMessage ?? ''),
            FilledButton(
              key: const ValueKey('retryStaff'),
              onPressed: () => unawaited(viewModel.load()),
              child: const Text(Strings.retry),
            ),
          ],
        );
      case AdministrationState.ready:
        if (viewModel.accounts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(Strings.noUsers),
          );
        }
        return Card(
          child: Column(
            children: [
              if (viewModel.isBusy) const LinearProgressIndicator(),
              for (final (index, account) in viewModel.accounts.indexed) ...[
                if (index > 0) const Divider(height: 1),
                _AccountTile(viewModel: viewModel, account: account),
              ],
            ],
          ),
        );
    }
  }
}

/// What can be done with one account, as the items of its menu.
enum _AccountAction {
  editName,
  editEmail,
  resetPassword,
  changeRole,
  toggleActive,
  delete,
}

/// One account: its name, user name, address, role and state, and its menu.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.viewModel, required this.account});

  final AdministrationViewModel viewModel;
  final StaffAccount account;

  @override
  Widget build(BuildContext context) {
    final own = viewModel.isOwn(account);
    final email = account.email;
    final name = own
        ? '${account.displayName} (${Strings.you})'
        : account.displayName;
    return ListTile(
      key: ValueKey('account-${account.id}'),
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(name),
      subtitle: Text(
        '${account.userName}${email == null ? '' : ' · $email'}\n'
        '${Strings.role(account.role)} · '
        '${Strings.accountState(account.isActive, account.mustChangePassword)}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<_AccountAction>(
        key: ValueKey('accountMenu-${account.id}'),
        tooltip: Strings.actions,
        enabled: !viewModel.isBusy,
        onSelected: (action) => unawaited(_run(context, action)),
        itemBuilder: (context) => [
          _item(_AccountAction.editName, Icons.person, Strings.editName),
          _item(
            _AccountAction.editEmail,
            Icons.alternate_email,
            Strings.editEmail,
          ),
          if (!own) ...[
            _item(
              _AccountAction.resetPassword,
              Icons.lock_reset,
              Strings.resetPassword,
            ),
            _item(_AccountAction.changeRole, Icons.badge, Strings.changeRole),
            account.isActive
                ? _item(
                    _AccountAction.toggleActive,
                    Icons.block,
                    Strings.disableAccount,
                  )
                : _item(
                    _AccountAction.toggleActive,
                    Icons.check_circle_outline,
                    Strings.enableAccount,
                  ),
            _item(
              _AccountAction.delete,
              Icons.delete,
              Strings.deleteAccount,
              danger: true,
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<_AccountAction> _item(
    _AccountAction action,
    IconData icon,
    String label, {
    bool danger = false,
  }) => PopupMenuItem(
    key: ValueKey('${action.name}-${account.id}'),
    value: action,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: danger ? AppColors.error : null),
      title: Text(label),
    ),
  );

  Future<void> _run(BuildContext context, _AccountAction action) async {
    final change = switch (action) {
      _AccountAction.editName => _editName,
      _AccountAction.editEmail => _editEmail,
      _AccountAction.resetPassword => _resetPassword,
      _AccountAction.changeRole => _changeRole,
      _AccountAction.toggleActive => _toggleActive,
      _AccountAction.delete => _delete,
    };
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await change(context);
    if (outcome != null) {
      _show(messenger, outcome);
    }
  }

  Future<AdministrationOutcome?> _editName(BuildContext context) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _FieldsDialog(
        title: Strings.editName,
        fields: [
          _Field(
            Strings.firstName,
            account.firstName ?? '',
            (value) =>
                viewModel.validateRequired(value, Strings.firstNameRequired),
            words: true,
          ),
          _Field(
            Strings.lastName,
            account.lastName ?? '',
            (value) =>
                viewModel.validateRequired(value, Strings.lastNameRequired),
            words: true,
          ),
        ],
      ),
    );
    return values == null
        ? null
        : viewModel.rename(account, values[0], values[1]);
  }

  Future<AdministrationOutcome?> _editEmail(BuildContext context) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _FieldsDialog(
        title: Strings.editEmail,
        hint: Strings.emailClearHint,
        fields: [
          _Field(
            Strings.email,
            account.email ?? '',
            viewModel.validateEmail,
            email: true,
          ),
        ],
      ),
    );
    return values == null ? null : viewModel.changeEmail(account, values[0]);
  }

  Future<AdministrationOutcome?> _resetPassword(BuildContext context) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _FieldsDialog(
        title: Strings.resetPasswordFor(account.userName),
        hint: Strings.temporaryPasswordHint,
        fields: [
          _Field(
            Strings.temporaryPassword,
            '',
            viewModel.validatePassword,
            secret: true,
          ),
        ],
      ),
    );
    return values == null ? null : viewModel.resetPassword(account, values[0]);
  }

  Future<AdministrationOutcome?> _changeRole(BuildContext context) async {
    final role = await showDialog<StaffRole>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(Strings.changeRoleFor(account.userName)),
        children: [
          for (final role in StaffRole.values)
            SimpleDialogOption(
              key: ValueKey('role-${role.name}'),
              onPressed: () => Navigator.of(context).pop(role),
              child: Row(
                children: [
                  Expanded(child: Text(Strings.role(role))),
                  if (role == account.role)
                    const Icon(Icons.check, color: AppColors.navy),
                ],
              ),
            ),
        ],
      ),
    );
    return role == null || role == account.role
        ? null
        : viewModel.changeRole(account, role);
  }

  Future<AdministrationOutcome?> _toggleActive(BuildContext context) async {
    if (!account.isActive) {
      return viewModel.setActive(account, true);
    }
    final confirmed = await _confirm(
      context,
      Strings.disableAccount,
      Strings.disableQuestion(account.userName),
      Strings.disable,
    );
    return confirmed ? viewModel.setActive(account, false) : null;
  }

  Future<AdministrationOutcome?> _delete(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      Strings.deleteAccount,
      Strings.deleteQuestion(account.userName),
      Strings.delete,
    );
    return confirmed ? viewModel.delete(account) : null;
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String question,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(question),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(Strings.cancel),
            ),
            TextButton(
              key: const ValueKey('confirmAction'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;
}

/// One field of a [_FieldsDialog].
class _Field {
  const _Field(
    this.label,
    this.initial,
    this.validator, {
    this.words = false,
    this.email = false,
    this.secret = false,
  });

  final String label;
  final String initial;
  final String? Function(String?) validator;
  final bool words;
  final bool email;
  final bool secret;
}

/// A dialog with a few text fields that answers with what was typed, or with
/// nothing when it is cancelled.
class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({required this.title, required this.fields, this.hint});

  final String title;
  final String? hint;
  final List<_Field> fields;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initial),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(
        context,
      ).pop([for (final controller in _controllers) controller.text]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            for (final (index, field) in widget.fields.indexed) ...[
              if (index > 0) const SizedBox(height: 16),
              TextFormField(
                key: ValueKey('dialogField-$index'),
                controller: _controllers[index],
                autofocus: index == 0,
                obscureText: field.secret,
                autocorrect: !field.secret && !field.email,
                keyboardType: field.email ? TextInputType.emailAddress : null,
                textCapitalization: field.words
                    ? TextCapitalization.words
                    : TextCapitalization.none,
                decoration: InputDecoration(labelText: field.label),
                validator: field.validator,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(
          key: const ValueKey('dialogSave'),
          onPressed: _save,
          child: const Text(Strings.saveButton),
        ),
      ],
    );
  }
}
