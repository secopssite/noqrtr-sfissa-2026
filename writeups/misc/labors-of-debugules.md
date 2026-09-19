# Labors of Debugules — secure coding, easy — 1000 pts

**Flag:** `HTB{411_7H47_6R33K_5W347_R3411Y_P4Y5_0FF@#!}`

A **patch** challenge, not an exploitation one: find the vulnerabilities in a PHP shop application,
fix them without breaking functionality, and a hidden validator awards the flag.

---

## Step 0 — how you actually submit a patch (the hard part)

The handout's `note.md` says:

> One of the ports is a SMB share that you must mount on your host to make direct changes

**That is stale and misleading. Ignore it.** We burned significant effort on it:

- Raw SMB negotiate probes against **all 703 open ports** on the shared host returned **zero** hits.
- 139/445/1337 are `filtered`.
- The platform publishes every mapped port for other challenges (Digital Phoenix lists four), but
  these containers only ever publish **one**.

The handout's `config/supervisord.conf` also describes a root-owned validator:

```ini
[program:socat]
user=root
command=socat -dd TCP-LISTEN:1337,reuseaddr,fork exec:'python3 -u /tmp/validate.py'
```

In **this** challenge that block is commented out, as are the Dockerfile `COPY` lines for
`validate.py` and `semgrep_rules.yaml`. That difference is the clue: **the socat plumbing has been
replaced by an editor sidecar.**

The single published web port is not the application — it is an **HTB Editor web IDE**
(`<title>HTB Editor</title>`). Its JS bundle exposes a REST API that both edits the live source and
runs the validator:

```bash
H=http://$HOST:$PORT

# list the live file tree
curl -s $H/editor_api/directory

# read a file (this app lives under /challenge/)
curl -s -G $H/editor_api/file --data-urlencode "path=challenge/includes/img_viewer.php"

# write it back
curl -s -X POST $H/editor_api/save -H 'Content-Type: application/json' \
     -d '{"path":"...","content":"...","client_md5":"<md5 of CURRENT on-disk content>"}'

# run the hidden validator
curl -s $H/editor_api/verify        # -> {"flag":"HTB{...}"}
```

**`client_md5` is optimistic concurrency control** — it is the md5 of the file *as it currently is
on disk*, **not** of the content you are writing. A mismatch returns HTTP 409 with `server_md5`.
So always read-then-write.

## Step 1 — Labour I: local file inclusion

`includes/img_viewer.php :: getImageAsBase64()`:

```php
$imagePath = substr(__DIR__ . '/../public/assets/images/' . $productId . '.png', 0, 400);
```

`$productId` is concatenated raw — `../../../../flag.txt%00` style traversal applies. The `substr(...,
0, 400)` is a **red herring**: it only truncates an over-long path and provides no sanitisation
whatsoever.

Fix — validate the input shape, then canonicalise and confirm containment:

```php
if (!preg_match('/^[0-9]{1,10}$/', $productId)) { return null; }
$base = realpath(__DIR__ . '/../public/assets/images/');
$real = realpath($base . '/' . $productId . '.png');
if ($real === false || strpos($real, $base . DIRECTORY_SEPARATOR) !== 0) { return null; }
```

Allowlist first, `realpath` second. Either alone is weaker than both.

## Step 2 — Labour II: IDOR

`includes/product.php :: getRecentOrders()` joins all Orders with **no user filter**, and the source
even admits it:

```php
// For statistics purposes ;)
```

`public/home.php` renders the result as "Recent Purchases", leaking **every customer's username**.
Worse, products restricted to administrators appear in that feed, so the listing also identifies
which accounts are admins.

Fix — scope to the session user with a prepared statement:

```php
$stmt = $db->prepare('SELECT ... FROM Orders o ... WHERE o.user_id = :user_id');
$stmt->execute([':user_id' => $_SESSION['user_id']]);
```

Keep the existing 4-`<td>` row markup so the page still renders and the functionality check passes.

**Both fixes are required.** Patching only the LFI still fails validation — the validator probes for
both.

## Step 3 — housekeeping

`public/config.bak.php` contains
`$password = '749f09bade8aca755660eeb17792da880218d4fbdc4e25fbec279d7fe9f65d70'` and is referenced
nowhere. It is a backup file exposed in the webroot — remove it.

Then:

```bash
curl -s $H/editor_api/verify
```

Until the patch is correct this returns
`{"error":"Vulnerability check failed — the security issue has not been resolved."}`; when it is
correct it returns `{"flag":"HTB{...}"}`. There is no mount, no polling and no wait — **the flag is
simply the HTTP response body**, which is why this solve landed eleven minutes after the event opened.

Note that `/editor_api/file` rejects traversal (`../../../tmp/validate.py` → `Invalid file path`), so
the hidden validator cannot be read this way.

---

## Lessons

- **When the handout's instructions do not match the deployment, look for the sidecar.** The single
  published port answering with an unexpected title was the whole answer; the SMB hunt was hours we
  did not have. Fingerprint what *is* listening before chasing what *should* be.
- **`substr()` is not path sanitisation.** Neither is `str_replace('../','')`. Validate the input
  against an allowlist pattern, then `realpath()` and verify the prefix.
- **"For statistics purposes" is how IDORs are born.** An aggregate view over a per-user table needs
  the same authorisation as the per-user view.
- **A patch challenge grades functionality as well as security.** Preserve output formats exactly —
  the grader replays legitimate traffic and a blanket block fails the other half.
