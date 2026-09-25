#!/usr/bin/env bash
# Prompt for an OpenCode Go API key in THIS terminal only.
# Never paste the key into chat, tickets, or git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/revocred-api/.env.local"

if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Run this in your own terminal so the key is not captured by a chat/agent log:" >&2
  echo "  $ROOT/scripts/enter-opencode-go-key.sh" >&2
  exit 1
fi

echo "OpenCode Go key for REVO (DeepSeek V4.1 Flash)"
echo "Get it at https://opencode.ai/auth — input is hidden and will not be printed."
echo
printf "Paste key, then Enter: "
IFS= read -rs KEY
echo
KEY="${KEY//$'\r'/}"
KEY="${KEY#"${KEY%%[![:space:]]*}"}"
KEY="${KEY%"${KEY##*[![:space:]]}"}"

if [[ -z "$KEY" ]]; then
  echo "No key entered. Nothing written."
  exit 1
fi
if [[ "$KEY" == *$'\n'* || "$KEY" == *' '* ]]; then
  echo "That does not look like a single API key. Nothing written."
  exit 1
fi

umask 077
touch "$ENV_FILE"
tmp="$(mktemp)"
grep -vE '^(OPENCODE_GO_API_KEY|OPENCODE_GO_MODEL|OPENCODE_GO_BASE_URL)=' "$ENV_FILE" > "$tmp" || true
printf 'OPENCODE_GO_API_KEY=%s\nOPENCODE_GO_MODEL=deepseek-v4.1-flash\nOPENCODE_GO_BASE_URL=https://opencode.ai/zen/go/v1\n' "$KEY" >> "$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"
unset KEY

echo "Saved to gitignored revocred-api/.env.local (permissions 600)."
echo "Restart the API so it loads the key:"
echo "  make local-stop && make local-preview"
echo "or restart make api-run-local"
