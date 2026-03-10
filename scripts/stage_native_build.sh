#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-100.78.200.39}"
PORT="${2:-22}"
USER_NAME="${3:-root}"
LOCAL_TIPA="${4:-$(ls -1t "$ROOT"/data/artifacts/native/AIKameraNative_*.tipa 2>/dev/null | head -n1)}"
REMOTE_DIR="/var/mobile/Documents/InstallQueue"
REMOTE_FILE="$REMOTE_DIR/AIKameraNative.tipa"
KEY_PATH="${IPHONE_SSH_KEY:-$HOME/Dokumenty/ipho/iphone-audit-dashboard/keys/iphone_jb_ed25519}"
SSH_TIMEOUT="${SSH_TIMEOUT:-20}"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Missing SSH key at $KEY_PATH" >&2
  exit 1
fi

if [[ -z "${LOCAL_TIPA:-}" || ! -f "$LOCAL_TIPA" ]]; then
  echo "Missing local AIKameraNative package. Run ./scripts/package_native_tipa.sh first." >&2
  exit 1
fi

ssh_base=(
  ssh
  -F /dev/null
  -i "$KEY_PATH"
  -p "$PORT"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o IdentityAgent=none
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=8
)

scp_base=(
  scp
  -F /dev/null
  -i "$KEY_PATH"
  -P "$PORT"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o IdentityAgent=none
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=8
)

timeout "$SSH_TIMEOUT" "${ssh_base[@]}" "$USER_NAME@$HOST" "mkdir -p '$REMOTE_DIR' && chown mobile:mobile '$REMOTE_DIR' 2>/dev/null || true"
timeout "$SSH_TIMEOUT" "${scp_base[@]}" "$LOCAL_TIPA" "$USER_NAME@$HOST:$REMOTE_FILE"
timeout "$SSH_TIMEOUT" "${ssh_base[@]}" "$USER_NAME@$HOST" "chown mobile:mobile '$REMOTE_FILE' 2>/dev/null || true"

echo "$REMOTE_FILE"
