# public verification — crypto, easy — 1000 pts

**Flag:**
`HTB{be_careful_how_you_choose_your_RSA_parameters___small_d_makes_RSA_vulnerable_to_the_attack_of_Michael_J_Wiener_e8eb72ad225adf2d1386598daf72dd5f}`

A Flask app issuing RS256 JWTs. `/dashboard` returns the flag if your token decodes with
`is_admin: true`.

---

## Step 1 — read the source

`challenge/application/crypto/_jwt.py`:

```python
import jwt
pubkey = open('pubkey.pem', 'rb').read()

def create_token(username):
    privkey = open('privkey.pem', 'rb').read()
    return jwt.encode({'is_admin': False, 'username': username}, privkey, algorithm='RS256')

def check_admin(token):
    try:
        payload = jwt.decode(token, pubkey, algorithms=['RS256'])
        if not 'is_admin' in payload:
            return False
        return payload['is_admin']
    except:
        return False
```

Note what is **not** wrong here. `algorithms=['RS256']` is pinned, so the classic
`alg: none` and RS256→HS256 confusion attacks are both closed. The registration route also enforces
a 10–20 character username, but that only gates `/register` — it is irrelevant once we mint tokens
ourselves.

The only other thing the handout gives us is `pubkey.pem`. That is where the bug lives.

## Step 2 — notice the public key is the wrong shape

A normal 2048-bit RSA public key with `e = 65537` starts:

```
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
```

This one starts:

```
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAQEA...
```

and roughly halfway through contains a second long integer introduced by `MwKCAQEA`
(`0x02 0x82 0x01 0x01 0x00` — an INTEGER of 257 bytes). So this key is `(n, e)` where **`e` is a
full 2048-bit number**, not 65537.

That is the entire tell. In RSA, `e·d ≡ 1 (mod φ(n))`. A very large `e` implies a correspondingly
**small `d`** — and a small private exponent is exactly the precondition for **Wiener's attack**
(M. J. Wiener, *Cryptanalysis of Short RSA Secret Exponents*, 1990), which recovers `d` whenever
`d < ⅓·n^(1/4)`.

The flag text confirms the intent after the fact, but the key shape alone is enough to commit.

## Step 3 — Wiener's attack

The attack works because `e/n` is a very close approximation of `k/d`, so `k/d` appears among the
convergents of the continued-fraction expansion of `e/n`.

```python
from Cryptodome.PublicKey import RSA
from Cryptodome.Util.number import long_to_bytes
import gmpy2

key = RSA.import_key(open('pubkey.pem','rb').read())
n, e = key.n, key.e

def convergents(num, den):
    # continued-fraction expansion of num/den, yielding successive convergents
    cf = []
    while den:
        a, (num, den) = num // den, (den, num % den)
        cf.append(a)
        nn, dd = 1, 0
        for x in reversed(cf):
            nn, dd = dd + x * nn, nn
        yield dd, nn          # k, d

for k, d in convergents(e, n):
    if k == 0 or d % 2 == 0:
        continue
    phi = (e * d - 1) // k
    # x^2 - (n - phi + 1)x + n = 0  -> roots are p and q
    b = n - phi + 1
    disc = b * b - 4 * n
    if disc < 0:
        continue
    r, exact = gmpy2.isqrt_rem(disc)
    if exact == 0:                      # perfect square -> we have p, q
        p, q = (b + r) // 2, (b - r) // 2
        assert p * q == n
        print('recovered d =', d.bit_length(), 'bits')
        break
```

`d` comes out at **256 bits** against a 2048-bit modulus — comfortably inside Wiener's bound — and
yields `p` and `q`.

## Step 4 — rebuild a usable private key

The `d` Wiener hands you is the one satisfying `e·d ≡ 1 (mod φ(n))`, but `cryptography`/PyJWT want a
key consistent with the *Carmichael* λ. Reconstruct from the factors instead:

```python
import math
from Cryptodome.PublicKey import RSA

lam = (p - 1) * (q - 1) // math.gcd(p - 1, q - 1)
d   = pow(e, -1, lam)
priv = RSA.construct((n, e, d, p, q)).export_key()
open('privkey.pem','wb').write(priv)
```

## Step 5 — forge the token

```python
import jwt, requests

tok = jwt.encode({'is_admin': True, 'username': 'adminadminadmin'},
                 open('privkey.pem','rb').read(), algorithm='RS256')

r = requests.get(f'http://{HOST}:{PORT}/dashboard',
                 headers={'Authorization': f'Bearer {tok}'})
print(r.text)
```

The rendered dashboard contains the flag.

---

## Lessons

- **An oversized `e` is a red flag, always.** In production RSA, `e` is 3, 17 or 65537. A full-width
  `e` means someone chose `d` first — and a small `d` is fatal.
- Pinning `algorithms=[...]` correctly defends against algorithm confusion but does nothing if the
  key pair itself is weak. Validating the *algorithm* is not validating the *key*.
- Wiener is cheap to try: it is a few dozen lines and terminates fast. When you see RSA parameters
  you cannot explain, run it before reaching for anything heavier (Boneh–Durfee extends the bound to
  `d < n^0.292` if Wiener misses).
