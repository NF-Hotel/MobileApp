# NF Hotel mobile app

A Flutter app for the staff of NF Hotel. A member of staff signs in and sees the
rooms; housekeeping starts and completes cleaning and service. The app is a
client of the NF Hotel API (repository `NF-Hotel/NFHotel`, milestone MIL-029,
ADR-0015).

## How it reaches the API

- The app holds **no token of the web application**. It signs in with
  `POST /api/auth/login` and sends the staff token it gets in `X-Staff-Token`.
  The API accepts that token alone on the sign-in and the rooms routes only.
- The staff token is kept in the Keychain (iOS) or the Keystore-backed secure
  storage (Android), never in plain preferences. A token the API refuses, or that
  has expired (8 hours), returns the app to the sign-in.
- The role decides what the API allows: Housekeeping changes cleaning and
  service, and gets 403 on anything else.

## Flutter version

Flutter 3.47.7 (Dart 3.13.5), stable channel; `pubspec.yaml` needs Dart `^3.13.2`.
Windows desktop builds need Visual Studio with the "Desktop development with C++"
workload (`flutter doctor`).

## Run against the development server

Start the development server of the website repository (`bash scripts/dev-up.sh`).
It publishes `https://localhost:8443/` with a development certificate and, for
the app, `https://localhost:8443/mobile-api/`. `dev-up.sh` prints one account per
role (Manager, Receptionist, Housekeeping).

```bash
# Android emulator (the host is 10.0.2.2; this is the default)
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:8443/mobile-api

# Desktop or web on the same machine
flutter run --dart-define=API_BASE_URL=https://localhost:8443/mobile-api
```

A debug build accepts the self-signed certificate of the address in
`API_BASE_URL`; a release build trusts the system certificates only. A release
build and the public address of the API are not decided yet (ADR-0015).

## Tests

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze lib test
flutter test
```

The end-to-end check against the development server runs in a container, never
on the desktop of the host (`framework/process/gui-testing.md` in the website
repository).

## Layout

`lib/domain` (entities, the ports, `Result`), `lib/infrastructure` (the HTTP
client, the secure storage), `lib/presentation` (screens and view models by
feature), `lib/main.dart` (the composition root). The older sign-up screen and
its form (`presentation/NewUserScreen.dart`, `components/`, `Model/`) are not part
of this work: accounts are made by an administrator in the API.
