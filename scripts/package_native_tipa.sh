#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/native/AIKameraNative/xtool/AIKameraNative.app"
OUT_DIR="$ROOT/data/artifacts/native"
INFO_TEMPLATE="$ROOT/native/AIKameraNative/Resources/Info.plist"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing build output: $APP_DIR" >&2
  echo "Run ./scripts/xtool-native.sh dev build in native/AIKameraNative first." >&2
  exit 1
fi

if [[ ! -f "$INFO_TEMPLATE" ]]; then
  echo "Missing Info.plist template: $INFO_TEMPLATE" >&2
  exit 1
fi

cp "$INFO_TEMPLATE" "$APP_DIR/Info.plist"

version="$(
  sed -n '/CFBundleShortVersionString/{n;s:.*<string>\(.*\)</string>.*:\1:p;q;}' "$APP_DIR/Info.plist"
)"
build="$(
  sed -n '/CFBundleVersion/{n;s:.*<string>\(.*\)</string>.*:\1:p;q;}' "$APP_DIR/Info.plist"
)"

if [[ -z "$version" || -z "$build" ]]; then
  echo "Failed to read version metadata from $APP_DIR/Info.plist" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$ROOT/tmp"
tmpdir="$(mktemp -d "$ROOT/tmp/aikamera-package.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/Payload"
cp -R "$APP_DIR" "$tmpdir/Payload/AIKameraNative.app"

artifact="$OUT_DIR/AIKameraNative_${version}-${build}.tipa"
rm -f "$artifact"
(cd "$tmpdir" && zip -qry "$artifact" Payload)

echo "$artifact"
