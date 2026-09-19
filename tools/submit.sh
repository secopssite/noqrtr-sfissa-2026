#!/bin/bash
# usage: ./submit.sh <challenge_id> "<flag>"   (wrong answers are unpenalised -> use as oracle)
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
CID="$1"; shift; ANS="$*"
B64=$(printf '%s' "$ANS" | base64 -w0)
echo "[$CID] '$ANS' -> $(api POST "/flags/own" "{\"challenge_id\":$CID,\"flag\":\"$B64\",\"flag_encoding\":\"base64\"}")"
