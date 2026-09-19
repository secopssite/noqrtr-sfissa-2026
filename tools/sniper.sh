#!/bin/bash
# Idle until just before the gun, then poll hard and fire go.sh the instant challenges open.
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
START_EPOCH=$(date -u -d '2026-09-19T13:30:00Z' +%s)
NOW=$(date -u +%s)
LEAD=$((START_EPOCH - NOW - 45))
[ "$LEAD" -gt 0 ] && sleep "$LEAD"
echo "[*] hot-polling from $(date '+%H:%M:%S %Z')"
for i in $(seq 1 900); do
  M=$(api GET "/ctfs/$CTFID/menu" 2>/dev/null)
  if echo "$M" | grep -q '"userCanViewChallenges":true'; then
    echo "### EVENT LIVE $(date '+%H:%M:%S.%N %Z')"
    "$D/go.sh"
    exit 0
  fi
  sleep 2
done
echo "### TIMEOUT never opened"
