#!/usr/bin/env bash
#
# Generates AuraScan.xcodeproj from project.yml and, optionally, builds it.
#
#   ./bootstrap.sh            generate the project
#   ./bootstrap.sh --open     generate, then open it in Xcode
#   ./bootstrap.sh --build    generate, then build for the iOS Simulator
#   ./bootstrap.sh --test     generate, then run the unit tests
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
note() { printf '\033[36m==>\033[0m %s\n' "$1"; }

[[ "$(uname -s)" == "Darwin" ]] || die "This needs macOS with Xcode installed."

xcode-select -p >/dev/null 2>&1 || die \
  "Xcode command line tools not found. Install Xcode, then run: xcode-select --install"

if ! command -v xcodegen >/dev/null 2>&1; then
  note "xcodegen not found — installing"
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  elif command -v mint >/dev/null 2>&1; then
    mint install yonaskolb/XcodeGen
  else
    die "Install XcodeGen first: brew install xcodegen  (https://brew.sh)"
  fi
fi

note "Generating AuraScan.xcodeproj from project.yml"
xcodegen generate

# Pick a simulator that actually exists on this machine rather than pinning a
# device name that may not be installed.
simulator_destination() {
  local name
  name=$(xcrun simctl list devices available -j \
    | /usr/bin/python3 -c '
import json,sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and "iPhone" in d["name"]:
            best = d["name"] if best is None else best
print(best or "")')
  [[ -n "$name" ]] || die "No available iPhone simulator found. Add one in Xcode > Settings > Components."
  printf 'platform=iOS Simulator,name=%s' "$name"
}

case "${1:-}" in
  --open)
    note "Opening Xcode"
    open AuraScan.xcodeproj
    ;;
  --build)
    dest=$(simulator_destination)
    note "Building for: $dest"
    xcodebuild -project AuraScan.xcodeproj -scheme AuraScan -destination "$dest" build
    ;;
  --test)
    dest=$(simulator_destination)
    note "Testing on: $dest"
    xcodebuild -project AuraScan.xcodeproj -scheme AuraScan -destination "$dest" test
    ;;
  "")
    note "Done. Next: ./bootstrap.sh --open   (or --build / --test)"
    ;;
  *)
    die "Unknown option: $1 (expected --open, --build or --test)"
    ;;
esac
