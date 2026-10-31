#!/usr/bin/env bash
# Runs the end-to-end test of the screens in a throwaway container with a virtual
# display (Xvfb), against the development server of the website repository. It never
# opens a window on the desktop of the host (AGENTS.md, "GUI testing").
#
# Usage: integration_test/run_in_docker.sh <env file with receptionist= and housekeeping=>
#   e.g. integration_test/run_in_docker.sh ../website/deploy/nfhotel-api/dev-staff.env
# Env:   API_BASE_URL (default https://host.docker.internal:8443/mobile-api)
#        FLUTTER_IMAGE (default ghcr.io/cirruslabs/flutter:stable)
# The env file is passed with --env-file, so no password is on a command line.
set -euo pipefail

env_file="${1:?usage: $0 <env file with receptionist= and housekeeping=>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${FLUTTER_IMAGE:-ghcr.io/cirruslabs/flutter:stable}"
base_url="${API_BASE_URL:-https://host.docker.internal:8443/mobile-api}"
export MSYS_NO_PATHCONV=1

docker run --rm --env-file "$env_file" -e "API_BASE_URL=$base_url" \
  -v "$root:/app:ro" "$image" bash -c '
set -e
apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb libgtk-3-dev clang cmake ninja-build pkg-config \
  libsecret-1-dev libjsoncpp-dev libglu1-mesa >/dev/null
mkdir /work && cd /app && tar --exclude=.git --exclude=.dart_tool --exclude=build -cf - . | tar -xf - -C /work
cd /work
# The image can carry an older Dart than pubspec.yaml asks for; relax the constraint in this copy only.
sed -i "s/sdk: \^3\.[0-9]*\.[0-9]*/sdk: ^3.12.0/" pubspec.yaml
rm -f pubspec.lock
flutter config --enable-linux-desktop >/dev/null 2>&1 || true
flutter pub get >/dev/null
xvfb-run -a -s "-screen 0 1280x800x24" \
  flutter test integration_test -d linux --dart-define="API_BASE_URL=$API_BASE_URL"
'
