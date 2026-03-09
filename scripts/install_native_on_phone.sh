#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-100.78.200.39}"
PORT="${2:-22}"
USER_NAME="${3:-root}"
KEY_PATH="${IPHONE_SSH_KEY:-$HOME/Dokumenty/ipho/iphone-audit-dashboard/keys/iphone_jb_ed25519}"
REMOTE_FILE="/var/mobile/Documents/InstallQueue/AIKameraNative.tipa"
SSH_TIMEOUT="${SSH_TIMEOUT:-30}"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Missing SSH key at $KEY_PATH" >&2
  exit 1
fi

"$ROOT/scripts/package_native_tipa.sh" >/dev/null
"$ROOT/scripts/stage_native_build.sh" "$HOST" "$PORT" "$USER_NAME" >/dev/null

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
  -o StrictHostKeyChecking=accept-new
)

timeout "$SSH_TIMEOUT" "${ssh_base[@]}" "$USER_NAME@$HOST" "
  export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin;
  helper=\$(find /var/containers/Bundle/Application -path '*/TrollStore.app/trollstorehelper' | head -n 1);
  if [[ -z \"\$helper\" ]]; then
    echo 'TrollStore helper not found' >&2;
    exit 1;
  fi;
  \"\$helper\" install '$REMOTE_FILE'
"

echo "Installed AIKameraNative via TrollStore on $HOST"
