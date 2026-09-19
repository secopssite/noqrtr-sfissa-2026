#!/bin/bash
# dump the event: challenges, points, solves, container state
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
api GET "/ctfs/$CTFID" > "$D/event.json"
python3 - "$D/event.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]),strict=False)
ch=d.get('challenges') or d.get('ctf',{}).get('challenges') or []
print(f"{'id':>6} {'cat':<14} {'pts':>4} {'solv':>4}  name  [state]")
for c in sorted(ch,key=lambda c:(str(c.get('challenge_category') or c.get('category','')),-int(c.get('points') or 0))):
    st=[]
    if c.get('solved'): st.append('SOLVED')
    if c.get('hasDocker') or c.get('docker'): st.append('docker')
    if c.get('filename') or c.get('hasDownload'): st.append('file')
    if c.get('ip') or c.get('hostname'): st.append(str(c.get('ip') or c.get('hostname')))
    print(f"{c.get('id'):>6} {str(c.get('challenge_category') or c.get('category','')):<14} {c.get('points','?'):>4} {c.get('solves','?'):>4}  {c.get('name')}  [{','.join(st)}]")
print('\ntotal challenges:', len(ch))
PY
