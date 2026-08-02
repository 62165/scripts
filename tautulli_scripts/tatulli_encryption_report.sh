#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.tatulli_config.sh"

BASE_URL=""
TOKEN=""
USERS_ENDPOINT="/api/v2"
CLIENTS_ENDPOINT="/api/v2"
HISTORY_ENDPOINT="/api/v2"
TIMEOUT=20

usage() {
    cat <<'EOF'
Usage: ./tatulli_encryption_report.sh [options]

Defaults:
  Values are loaded from .tatulli_config.sh if present; otherwise pass them with flags.
  --users-endpoint /api/v2
  --clients-endpoint /api/v2

Optional:
  --base-url <url>         Base URL for the Tautulli API
  --token <token>          API key for authenticated requests
  --users-endpoint <path>  Users command path (default: /api/v2)
  --clients-endpoint <path> Clients command path (default: /api/v2)
  --history-endpoint <path> History command path (default: /api/v2)
  --timeout <seconds>      Curl timeout (default: 20)
  -h, --help               Show this help message

Local config:
  If present, the script will load settings from .tatulli_config.sh in this folder.
  You can override any value there or via command-line flags.

Examples:
  ./tatulli_encryption_report.sh
  ./tatulli_encryption_report.sh --base-url http://localhost:8181 --token "$TAUTULLI_API_KEY"
EOF
}

join_url() {
    local base="${1%/}"
    local path="${2#/}"
    echo "$base/$path"
}

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-url)
            BASE_URL="${2:-}"
            shift 2
            ;;
        --token)
            TOKEN="${2:-}"
            shift 2
            ;;
        --users-endpoint)
            USERS_ENDPOINT="${2:-}"
            shift 2
            ;;
        --clients-endpoint)
            CLIENTS_ENDPOINT="${2:-}"
            shift 2
            ;;
        --history-endpoint)
            HISTORY_ENDPOINT="${2:-}"
            shift 2
            ;;
        --timeout)
            TIMEOUT="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$BASE_URL" ]]; then
    echo "ERROR: --base-url is required." >&2
    usage >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required but was not found." >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required but was not found." >&2
    exit 1
fi

users_url="$(join_url "$BASE_URL" "$USERS_ENDPOINT")"
clients_url="$(join_url "$BASE_URL" "$CLIENTS_ENDPOINT")"
history_url="$(join_url "$BASE_URL" "$HISTORY_ENDPOINT")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

USERS_FILE="$TMP_DIR/users.json"
CLIENTS_FILE="$TMP_DIR/clients.json"
HISTORY_FILE="$TMP_DIR/history.json"

CURL_ARGS=("-sS" "--max-time" "$TIMEOUT")
if [[ -n "$TOKEN" ]]; then
    CURL_ARGS+=("-H" "Accept: application/json")
fi

echo "Querying Tautulli users from: $users_url"
echo "Querying Tautulli history from: $history_url"

if ! curl "${CURL_ARGS[@]}" "$users_url?apikey=$TOKEN&cmd=get_users" -o "$USERS_FILE"; then
    echo "ERROR: failed to fetch users from $users_url" >&2
    exit 1
fi

if ! curl "${CURL_ARGS[@]}" "$history_url?apikey=$TOKEN&cmd=get_history" -o "$HISTORY_FILE"; then
    echo "ERROR: failed to fetch history from $history_url" >&2
    exit 1
fi

python3 - "$USERS_FILE" "$HISTORY_FILE" <<'PY'
import json
import sys
from pathlib import Path

users_path = Path(sys.argv[1])
history_path = Path(sys.argv[2])


def load_json(path: Path):
    try:
        content = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    if not content.strip():
        return None
    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON from {path}: {exc}", file=sys.stderr)
        return None


def normalize_items(payload):
    if payload is None:
        return []
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        response = payload.get("response")
        if isinstance(response, dict):
            data = response.get("data")
            if isinstance(data, list):
                return data
            if isinstance(data, dict):
                rows = data.get("data")
                if isinstance(rows, list):
                    return rows
                sessions = data.get("sessions")
                if isinstance(sessions, list):
                    return sessions
                return [data]
        for key in ("data", "items", "users", "clients", "sessions"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
        return [payload]
    return []


def extract_name(item):
    if not isinstance(item, dict):
        return str(item)
    for key in ("name", "display_name", "username", "email", "user_name", "client_name", "title"):
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    for key in ("id", "user_id", "client_id"):
        value = item.get(key)
        if value is not None:
            return str(value)
    return "<unknown>"


def extract_history_label(item):
    if not isinstance(item, dict):
        return "<unknown>"

    user = item.get("friendly_name") or item.get("user") or item.get("username") or "<unknown user>"
    player = item.get("player") or item.get("product") or item.get("platform") or "<unknown player>"
    return f"{user} -> {player}"


def normalize_status(value):
    if isinstance(value, bool):
        return "encrypted" if value else "unencrypted"
    if isinstance(value, (int, float)):
        return "encrypted" if int(value) != 0 else "unencrypted"
    if isinstance(value, str):
        text = value.strip().lower()
        if text in {"encrypted", "enabled", "on", "true", "yes", "active", "secure", "protected"}:
            return "encrypted"
        if text in {"unencrypted", "disabled", "off", "false", "no", "inactive", "unprotected", "not_encrypted", "not encrypted"}:
            return "unencrypted"
        if text in {"unknown", "pending", "n/a", "na", "none"}:
            return "unknown"
    return "unknown"


def detect_encryption(item):
    if not isinstance(item, dict):
        return "unknown"

    for key in ("secure", "encrypted", "is_encrypted", "encryption_enabled", "encryption_on", "secured", "is_secured"):
        if key in item:
            return normalize_status(item[key])

    for key in ("encryption_status", "status", "security_status"):
        if key in item:
            return normalize_status(item[key])

    # Fall back to Tautulli-specific flags when present.
    if item.get("relayed") in {1, "1", True}:
        return "unencrypted"
    if item.get("location") in {"wan", "lan"}:
        return "unknown"

    return "unknown"


def summarize(title, payload):
    items = normalize_items(payload)
    groups = {"encrypted": {}, "unencrypted": {}, "unknown": {}}
    for item in items:
        status = detect_encryption(item)
        if title == "Historical Connections":
            label = extract_history_label(item)
            groups[status][label] = groups[status].get(label, 0) + 1
        else:
            label = extract_name(item)
            groups[status][label] = groups[status].get(label, 0) + 1

    print(f"{title}:")
    for status in ("encrypted", "unencrypted", "unknown"):
        entries = groups[status]
        print(f"  {status.title()} ({len(entries)} distinct entries):")
        if entries:
            for name, count in sorted(entries.items(), key=lambda item: (-item[1], item[0])):
                print(f"    - {name}: {count}")
        else:
            print("    - None")
    print()


users_payload = load_json(users_path)
history_payload = load_json(history_path)

summarize("Users", users_payload)
summarize("Historical Connections", history_payload)
PY
