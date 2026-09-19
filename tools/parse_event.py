#!/usr/bin/env python3
"""Parse the event JSON into a triage table + chals.json."""
import json, sys

D = "/home/acidburn/ctf/events/NoQRTR2026"
d = json.load(open(f"{D}/event.json"), strict=False)
ch = d.get("challenges") or d.get("ctf", {}).get("challenges") or []

rows = []
for c in ch:
    cat = str(c.get("challenge_category") or c.get("category")
              or c.get("category_name") or "?")
    fi = c.get("flagsInfo") or []
    rows.append(dict(
        id=c.get("id"), cat=cat, pts=c.get("points", "?"), slv=c.get("solves", 0),
        name=c.get("name", ""),
        file=bool(c.get("filename") or c.get("hasDownload") or c.get("download")),
        docker=bool(c.get("hasDocker") or c.get("docker")),
        machine=bool(c.get("hasMachine") or c.get("machine")),
        ip=c.get("ip") or c.get("hostname") or "",
        nflags=len(fi), solved=bool(c.get("solved")),
        questions=[f.get("question", "") for f in fi],
    ))

rows.sort(key=lambda r: (r["cat"], -int(r["pts"] or 0)))
print(f"{'id':>6} {'category':<14} {'pts':>4} {'slv':>3} FDM  name")
for r in rows:
    t = ("F" if r["file"] else "-") + ("D" if r["docker"] else "-") + ("M" if r["machine"] else "-")
    mark = "*" if r["solved"] else " "
    extra = f"  ({r['nflags']} flags)" if r["nflags"] > 1 else ""
    ip = f"  {r['ip']}" if r["ip"] else ""
    print(f"{r['id']:>6} {r['cat']:<14} {r['pts']:>4} {r['slv']:>3} {t} {mark}{r['name']}{extra}{ip}")
print("TOTAL", len(rows))

json.dump(rows, open(f"{D}/chals.json", "w"), indent=1)
