#!/bin/bash
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
curl -s -H "Authorization: Bearer $CT" "https://ctf.hackthebox.com/api/ctfs/vpn/download/$CTFID" -o "$D/noqrtr.ovpn" -w "HTTP %{http_code} %{size_download}\n"
head -3 "$D/noqrtr.ovpn"
