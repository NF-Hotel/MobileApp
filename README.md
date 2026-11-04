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
- The service notes of a room use `/api/room-service-notes`, and the staff
  accounts `/api/staff`. Both routes have to be on the staff-token list
  (`StaffTokenRoutes`) and the nginx filter
  (`ops/deploy/nginx/snippets/mobile-api.conf`) of the website repository
  (ADR-0015, MIL-059).

## Service notes

Under each room, Housekeeping and Managers write a note, which also reports that
the room needs service. Everybody can tick a note as done and untick it for five
minutes. After that it is in the history of the room, where only a Manager can
untick it. The API decides all of this; the app reads the notes again every 30
seconds and shows the answer.

## The own account and the administration (MIL-059)

- A member whose password a Manager set must choose a new one before anything
  else; the API refuses every other call until then. An account without a name
  is asked for it after the sign-in. Every member can change the own password
  from the rooms.
- A Manager opens the administration from the rooms. It creates accounts (first
  and last name, user name, optional e-mail, temporary password, role) and, per
  account, edits the name and the e-mail, sets a temporary password, changes
  the role, disables or enables it, and deletes it. The API keeps the rules: the
  own account and the last active Manager can be neither disabled, deleted nor
  given another role, and every change is in the audit trail.

## Look

The screens follow the earlier prototype of the app: a navy and amber theme,
Playfair Display for headings and Inter for text, and the housekeeping
pictures in `lib/Assets`. The fonts are bundled in `assets/google_fonts`
(SIL Open Font License) and never fetched at run time.

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
