#!/bin/bash
# usage: ./dl.sh <challenge_id> [dirname]   -> downloads into files/<dirname>/, auto-extracts
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
CID="$1"; NAME="${2:-chal$CID}"
RAW=$(api GET "/challenges/$CID/download/link")
URL=$(printf '%s' "$RAW" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("", end=""); raise SystemExit
if isinstance(d, str):
    print(d); raise SystemExit
for k in ("url", "link", "download_url", "signed_url", "path"):
    if isinstance(d, dict) and d.get(k):
        print(d[k]); raise SystemExit
print("", end="")
')
if [ -z "$URL" ]; then
  echo "[!] no link for $CID; raw response:"; printf '%s\n' "$RAW" | head -c 400; exit 1
fi
echo "[*] $CID -> $URL"
mkdir -p "$D/files/$NAME"
curl -sL "$URL" -o "$D/files/$NAME/dl.bin" -w "  HTTP %{http_code}  %{size_download} bytes\n"
file "$D/files/$NAME/dl.bin"
cd "$D/files/$NAME" || exit 1
if file dl.bin | grep -qi 'zip archive'; then
  7z x -phackthebox -y dl.bin > /dev/null 2>&1 || unzip -o -P hackthebox dl.bin > /dev/null 2>&1 \
    || 7z x -y dl.bin > /dev/null 2>&1
fi
ls -la
