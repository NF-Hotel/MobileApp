# NF Hotel mobile app

A Flutter app for the staff of NF Hotel. A member of staff signs in with their
email and sees their rooms; they set a room's cleaning status and write, tick
off and delete notes on it. The app is a client of the LoginApi in `api/`
(ASP.NET Core minimal API, PostgreSQL through Dapper, `api/Program.cs`).

## How it reaches the API

- It signs in with `POST /auth/login` (email and password) and sends the JWT it
  gets as `Authorization: Bearer`. The app reads the name, role and expiry from
  the token's claims; it never checks the signature, the API does.
- The token is kept in the Keychain (iOS) or the Keystore-backed secure storage
  (Android), never in plain preferences. A token the API refuses, or that has
  expired (8 hours), returns the app to the sign-in.
- A new account without a name sets it once (`PUT /me/name`) before the rooms.
- The role decides what the API allows: a cleaner sees and changes only the rooms
  assigned to them; a technician and an admin see every room. Account and room
  administration (`/admin/...`) is not in this app yet.

## Flutter version

Flutter 3.47.7 (Dart 3.13.5), stable channel; `pubspec.yaml` needs Dart `^3.13.2`.
Windows desktop builds need Visual Studio with the "Desktop development with C++"
workload (`flutter doctor`).

## Run against the LoginApi

Start the API (`cd api && dotnet run`, .NET 10 SDK, see `api/global.json`). It
listens on `http://localhost:5142` and needs two user secrets and a reachable
database:

```bash
cd api
dotnet user-secrets set "ConnectionStrings:Default" "Host=...;Database=...;Username=...;Password=..."
dotnet user-secrets set "Jwt:Key" "<at least 32 random characters>"
```

Passwords are hashed in the API (PBKDF2-HMAC-SHA256, 600 000 iterations, salted;
`HashPassword` in `api/Program.cs`). The app sends the password as typed.

```bash
# Android emulator (the host is 10.0.2.2; this is the default)
flutter run

# Desktop or web on the same machine
flutter run --dart-define=API_BASE_URL=http://localhost:5142
```

The API serves plain http, so only a debug build on Android allows cleartext
(`android/app/src/debug/AndroidManifest.xml`).

## Release build

A release build is obfuscated: R8 shrinks and obfuscates the Java/Kotlin code
(`android/app/build.gradle.kts`), and the Dart code needs two flags:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols` for each release; without it a crash stack trace cannot be
read (`flutter symbolize -i <trace> -d build/symbols/app.android-arm64.symbols`).

## Tests

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze lib test
flutter test
```

The end-to-end check against a running LoginApi skips itself unless
`NFHOTEL_EMAIL` and `NFHOTEL_PASSWORD` are set (see `test/e2e/dev_server_test.dart`).

## Layout

`api/` (the LoginApi), `lib/domain` (entities, the ports, `Result`), `lib/infrastructure` (the HTTP
client, the secure storage), `lib/presentation` (screens and view models by
feature), `lib/main.dart` (the composition root). The older sign-up screen and
its form (`presentation/NewUserScreen.dart`, `components/`, `Model/`) are not part
of this work: accounts are made by an administrator in the API.
