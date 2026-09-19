# bankflip — crypto, medium — 1000 pts

**Flag:**
`HTB{cbc_bit_flipping_is_caused_by_lack_of_integrity_checking___use_authenticated_encryption_instead_6a3305b96e15b6ed6175fb766502b5ab}`

A toy bank. Register, log in, deposit money, and a `/golden-class` endpoint hands over the flag once
your balance exceeds 10000 — which the deposit flow will never legitimately let you reach.

---

## Step 1 — locate the token format

`crypto/tokenizer.py` issues the session as:

```
transaction_token = base64( IV || AES-CBC-Encrypt(key, "username=<U>&timestamp=<T>&balance=<B>") )
```

There is **no MAC**. CBC without integrity protection is malleable: flipping a bit in ciphertext
block *i* flips the corresponding bit in plaintext block *i+1*, at the cost of randomising block *i*
entirely.

## Step 2 — find the sink

```python
def extract_deposit_money(token):
    msg = decrypt(token)
    # username is taken between the first '=' and the first '&'
    ...
    return int(msg.split(b'deposit=')[1])
```

So the server credits whatever follows the literal `deposit=`. Our plaintext contains `balance=`.
Both strings are **exactly 8 bytes**, which means we can transform one into the other with a pure
in-place XOR — no length change, no re-padding.

```
b'balance=' ^ b'deposit='  ->  the 8-byte mask to apply
```

## Step 3 — align `balance=` to a block boundary

Plaintext layout, with username length `n`:

```
username=<U>&timestamp=<T>&balance=<B>
|________|   |__________|   |______|
    9+n          +11+10+1
```

`balance=` starts at offset `9 + n + 11 + 10 + 1 = 31 + n`.

We want it at a multiple of 16 so the flip lands cleanly at the start of a block. Registration
allows usernames of 10–20 characters:

- **`n = 17` → offset 48** — exactly the start of plaintext block 3.

To modify plaintext block 3, we flip **ciphertext block 2**. Accounting for the 16-byte IV prefix,
that is raw token bytes **48..63**.

## Step 4 — why the collateral damage is harmless

Flipping ciphertext block 2 destroys plaintext block 2 — offsets 32..47. That region holds only
timestamp digits and a `&`. Crucially:

- the **first `=`** sits at offset 8, and
- the **first `&`** sits at offset 26,

both *before* offset 32. The username-extraction logic reads between those two markers, so it is
untouched and the token still authenticates as us.

And block 3 is the **last** block, so its PKCS#7 padding decrypts intact — the flip does not break
unpadding.

This is why `n = 17` is the right choice and not merely a convenient one: it is the only alignment
that puts the target at a block boundary while keeping the damage inside a don't-care region.

## Step 5 — exploit

```python
import base64, requests

USER = 'A' * 17
# register with balance 4999, log in, grab transaction_token
...

raw = bytearray(base64.b64decode(token))
mask = bytes(a ^ b for a, b in zip(b'balance=', b'deposit='))
for i in range(8):
    raw[48 + i] ^= mask[i]
forged = base64.b64encode(bytes(raw)).decode()
```

`update_user_balance` simply *adds* the parsed amount, and the token is not single-use — so replay
it:

```python
for _ in range(3):
    requests.post(f'http://{HOST}:{PORT}/deposit',
                  cookies={'transaction_token': forged})
# 4999 -> 9998 -> 14997 -> 19996
requests.get(f'http://{HOST}:{PORT}/golden-class', cookies={'transaction_token': forged})
```

Balance clears the 10000 gate and `/golden-class` returns the flag.

---

## Lessons

- **CBC without a MAC is not confidentiality, it is a write primitive.** Encrypt-then-MAC, or use an
  AEAD (AES-GCM, ChaCha20-Poly1305). The flag text says exactly this.
- When hunting bit-flip targets, look for **equal-length** keyword pairs — they let you rewrite
  semantics without touching length or padding.
- Map which plaintext bytes you are allowed to destroy *before* choosing the alignment. The attack
  succeeds here only because the garbled block contains nothing the parser reads.
- Replayable tokens turn a one-shot state change into an unbounded one. Deposit was idempotent by
  design; nothing bound the token to a single use.
