#!/usr/bin/env bash
set -euo pipefail

XTOOL_APPIMAGE="${XTOOL_APPIMAGE:-$HOME/.local/bin/xtool}"
XTOOL_EXTRACT_DIR="${XTOOL_EXTRACT_DIR:-$HOME/.local/bin/squashfs-root}"
XTOOL_BIN="${XTOOL_BIN:-$XTOOL_EXTRACT_DIR/AppRun}"
SWIFT_WRAPPER="$(cd "$(dirname "$0")" && pwd)/use_local_swift_env.sh"

if [[ ! -x "$XTOOL_BIN" ]]; then
  if [[ ! -x "$XTOOL_APPIMAGE" ]]; then
    echo "xtool AppImage not found at $XTOOL_APPIMAGE" >&2
    exit 1
  fi
  tmpdir="$(dirname "$XTOOL_EXTRACT_DIR")"
  (
    cd "$tmpdir"
    "$XTOOL_APPIMAGE" --appimage-extract >/dev/null
  )
fi

if [[ -x "/home/pwn/toolchains/swift-6.2.4-RELEASE-ubuntu24.04/usr/bin/swift" ]]; then
  exec "$SWIFT_WRAPPER" "$XTOOL_BIN" "$@"
fi

exec "$XTOOL_BIN" "$@"
