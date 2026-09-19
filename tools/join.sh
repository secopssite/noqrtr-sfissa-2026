#!/bin/bash
# usage: ./join.sh <access_code> [team_id]
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
CODE="$1"; TEAM="${2:-}"
if [ -z "$TEAM" ]; then
  TEAM=$(api GET "/ctfs/join/candidate-teams/$CTFID" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["id"])')
  echo "[*] using candidate team id $TEAM"
fi
api POST "/ctfs/join" "{\"id\":$CTFID,\"team_id\":$TEAM,\"consent\":true,\"code\":\"$CODE\"}"
echo
