#!/bin/bash
set -euo pipefail
ID="$1"
STATE="$HOME/.local/state/nimbus"
LIST="$STATE/pins.json"
[ -f "$LIST" ] || exit 0
F=$(jq -r --arg id "$ID" '.[] | select(.id==$id) | .file // empty' "$LIST" 2>/dev/null || true)
if [ -n "$F" ]; then rm -f "$F" || true; fi
jq --arg id "$ID" '[.[] | select(.id != $id)]' "$LIST" > "$LIST.tmp" && mv "$LIST.tmp" "$LIST"
