#!/bin/bash
# Fires the instant the event opens: dump challenges, then pull every attachment in parallel.
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh

api GET "/ctfs/$CTFID" > "$D/event.json"
python3 "$D/parse_event.py"

# parallel download of everything with an attachment (signed links live 5 min)
python3 -c "
import json
for c in json.load(open('$D/chals.json')):
    if c['file']:
        print(c['id'], c['name'])
" | while read -r cid name; do
    safe=$(printf '%s' "$name" | tr -cs 'A-Za-z0-9_.-' '_')
    ( "$D/dl.sh" "$cid" "${cid}_${safe}" > "$D/files/dl_$cid.log" 2>&1 ) &
done
wait

echo "=== downloaded ==="
find "$D/files" -maxdepth 2 -type f ! -name '*.log' -printf '%p  %s\n' | sort
