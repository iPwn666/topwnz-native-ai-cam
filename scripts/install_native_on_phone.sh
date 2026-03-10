#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRIMARY_HOST="${1:-}"
PRIMARY_PORT="${2:-22}"
PRIMARY_USER="${3:-root}"
KEY_PATH="${IPHONE_SSH_KEY:-$HOME/Dokumenty/ipho/iphone-audit-dashboard/keys/iphone_jb_ed25519}"
REMOTE_FILE="/var/mobile/Documents/InstallQueue/AIKameraNative.tipa"
SSH_TIMEOUT="${SSH_TIMEOUT:-30}"
USB_HOST="${INSTALL_USB_HOST:-127.0.0.1}"
USB_PORT="${INSTALL_USB_PORT:-2222}"
USB_USER="${INSTALL_USB_USER:-root}"
TAILNET_HOST="${INSTALL_TAILNET_HOST:-100.78.200.39}"
TAILNET_PORT="${INSTALL_TAILNET_PORT:-22}"
TAILNET_USER="${INSTALL_TAILNET_USER:-root}"
FALLBACK_HOST="${INSTALL_FALLBACK_HOST:-}"
FALLBACK_PORT="${INSTALL_FALLBACK_PORT:-2222}"
FALLBACK_USER="${INSTALL_FALLBACK_USER:-root}"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Missing SSH key at $KEY_PATH" >&2
  exit 1
fi

ssh_base=(
  ssh
  -F /dev/null
  -i "$KEY_PATH"
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

targets=()

add_target() {
  local host="$1"
  local port="$2"
  local user="$3"
  local triple="$host|$port|$user"
  local existing

  [[ -n "$host" && -n "$port" && -n "$user" ]] || return 0

  for existing in "${targets[@]:-}"; do
    [[ "$existing" == "$triple" ]] && return 0
  done

  targets+=("$triple")
}

stage_and_install() {
  local target_host="$1"
  local target_port="$2"
  local target_user="$3"

  "$ROOT/scripts/stage_native_build.sh" "$target_host" "$target_port" "$target_user" >/dev/null

  timeout "$SSH_TIMEOUT" "${ssh_base[@]}" -p "$target_port" "$target_user@$target_host" "
    export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin;
    helper=\$(find /var/containers/Bundle/Application -path '*/TrollStore.app/trollstorehelper' | head -n 1);
    if [[ -z \"\$helper\" ]]; then
      echo 'TrollStore helper not found' >&2;
      exit 1;
    fi;
    \"\$helper\" install '$REMOTE_FILE'
  "
}

"$ROOT/scripts/package_native_tipa.sh" >/dev/null

if [[ -n "$PRIMARY_HOST" ]]; then
  add_target "$PRIMARY_HOST" "$PRIMARY_PORT" "$PRIMARY_USER"
  add_target "$FALLBACK_HOST" "$FALLBACK_PORT" "$FALLBACK_USER"
else
  add_target "$USB_HOST" "$USB_PORT" "$USB_USER"
  add_target "$TAILNET_HOST" "$TAILNET_PORT" "$TAILNET_USER"
fi

for target in "${targets[@]}"; do
  IFS='|' read -r host port user_name <<<"$target"
  if stage_and_install "$host" "$port" "$user_name"; then
    echo "Installed AIKameraNative via TrollStore on $host:$port"
    exit 0
  fi
  echo "Install on $host:$port failed, trying next target..." >&2
done

echo "Install failed on all targets." >&2
exit 1
