#!/bin/bash
set -euo pipefail
ID="$1"
STATE="$HOME/.local/state/nimbus"
PINS="$STATE/pins"
LIST="$STATE/pins.json"
mkdir -p "$PINS"
[ -f "$LIST" ] || printf '[]' > "$LIST"

LINE=$(cliphist list 2>/dev/null | grep -m1 -P "^\Q${ID}\E\t" || true)
PREVIEW="${LINE#*$'\t'}"
TS=$(date +%s%N)

if [[ "$PREVIEW" == *"binary data"* ]]; then
  F="$PINS/${TS}.png"
  cliphist decode "$ID" > "$F" 2>/dev/null || true
  jq --arg id "$TS" --arg f "$F" --arg t "$PREVIEW" '. + [{id:$id,type:"image",file:$f,text:$t}]' "$LIST" > "$LIST.tmp"
else
  TXT=$(cliphist decode "$ID" 2>/dev/null | head -c 8000 || true)
  jq --arg id "$TS" --arg t "$TXT" '. + [{id:$id,type:"text",text:$t}]' "$LIST" > "$LIST.tmp"
fi
mv "$LIST.tmp" "$LIST"
