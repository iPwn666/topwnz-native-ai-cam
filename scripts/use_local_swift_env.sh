#!/usr/bin/env bash
set -euo pipefail

SWIFT_ROOT="${SWIFT_ROOT:-/home/pwn/toolchains/swift-6.2.4-RELEASE-ubuntu24.04}"
SWIFT_BIN="$SWIFT_ROOT/usr/bin"
SWIFT_LIB="$SWIFT_ROOT/usr/lib/swift/linux"
COMPAT_ROOT="${SWIFT_COMPAT_ROOT:-/home/pwn/toolchains/compat-libs/noble}"
COMPAT_LIB="$COMPAT_ROOT/usr/lib/x86_64-linux-gnu"

if [[ ! -x "$SWIFT_BIN/swift" ]]; then
  echo "Local Swift toolchain not found at $SWIFT_ROOT" >&2
  exit 1
fi

export PATH="$SWIFT_BIN:$PATH"
ld_paths=("$SWIFT_LIB")
if [[ -d "$COMPAT_LIB" ]]; then
  ld_paths+=("$COMPAT_LIB")
fi
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
  ld_paths+=("$LD_LIBRARY_PATH")
fi
export LD_LIBRARY_PATH="$(IFS=:; echo "${ld_paths[*]}")"

exec "$@"
