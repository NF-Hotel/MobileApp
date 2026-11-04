import 'package:flutter/material.dart';

/// A page with one form: a heading and a hint over a card, in the middle of the
/// screen and no wider than a phone.
class FormPage extends StatelessWidget {
  /// Creates the page.
  const FormPage({
    required this.title,
    required this.heading,
    required this.hint,
    required this.child,
    this.actions = const <Widget>[],
    this.canGoBack = true,
    super.key,
  });

  /// The title in the app bar.
  final String title;

  /// The heading over the card.
  final String heading;

  /// The text under the heading.
  final String hint;

  /// The content of the card.
  final Widget child;

  /// The buttons in the app bar.
  final List<Widget> actions;

  /// False when the page is a step that cannot be left, such as the first
  /// change of the password.
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: canGoBack,
        actions: actions,
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
                  Text(heading, style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(hint, style: textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: child,
                    ),
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

/// The text of a failure under a form, in the colour of errors.
class FormError extends StatelessWidget {
  /// Creates the text.
  const FormError(this.message, {super.key});

  /// What went wrong.
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

/// The small spinner inside a button while its call runs.
class ButtonSpinner extends StatelessWidget {
  /// Creates the spinner.
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}
