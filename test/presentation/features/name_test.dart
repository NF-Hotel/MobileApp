import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/name/name_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSessionStore store;
  late SessionController session;
  late FakeAuthRepository auth;
  late NameViewModel viewModel;

  setUp(() async {
    store = FakeSessionStore(validSession(firstName: '', lastName: ''));
    session = SessionController(store: store, now: () => testNow);
    await session.restore();
    auth = FakeAuthRepository(Success(validSession()));
    viewModel = NameViewModel(auth: auth, session: session);
  });

  test('a saved name keeps the new session with it', () async {
    await viewModel.submit(' Hilda ', ' Berg ');

    expect(auth.names, ['Hilda Berg'], reason: 'the names are trimmed');
    expect(session.session?.hasName, isTrue);
    expect(store.saved?.displayName, 'Hilda Berg');
    expect(viewModel.errorMessage, isNull);
  });

  test('an empty name is not sent', () async {
    await viewModel.submit('Hilda', '  ');

    expect(auth.names, isEmpty);
    expect(viewModel.validate(''), Strings.required);
  });

  test('a name set meanwhile by an admin says to sign in again', () async {
    auth.nameResult = const Failed(ApiFailure(FailureKind.rejected));

    await viewModel.submit('Hilda', 'Berg');

    expect(viewModel.errorMessage, Strings.nameAlreadySet);
    expect(session.session?.hasName, isFalse);
  });
}
