# Uncoding — reversing, easy — 1000 pts

**Flag:** `HTB{0n3_t1m3_p4d_tw0_t1m3_p4d_thr33_t1m3_p4d...}`

> The trailing `...` is **part of the flag**, not an abbreviation. It confused us on first read —
> verify against the decoded bytes, not against what looks like a sensible flag.

A 17 KB non-stripped C ELF that prints one of several "messages" by index.

---

## Step 1 — triage

```console
$ file uncoding
uncoding: ELF 64-bit LSB pie executable, x86-64, dynamically linked, not stripped
$ strings uncoding | grep HTB
(nothing)
```

Nothing stored in the clear — consistent with the event's stated design that flags are computed at
runtime rather than stored.

## Step 2 — find the message table

`.data` at `0x4080` holds a symbol `messages`: an array of 4 pointers into `.rodata`:

```
0x2008, 0x2068, 0x20f0, 0x2128
```

`main` reads an index from the user and calls `decrypt_message(i)`, which contains the giveaway:

```c
if (i == 3) { puts("That memory has been locked away!"); return; }
if (i < 0 || i > 3) { /* reject */ }
```

Entry **3 is deliberately unreachable at runtime**. That is the flag blob. Note the design: you
cannot simply run the binary and read the answer, so the intended path is static recovery of the
key.

## Step 3 — recover the key

`decrypt_message` XORs the blob byte-by-byte against a 16-byte pad that is materialised **inline on
the stack** rather than stored as a `.rodata` string:

```asm
movabs rax, 0xc3e2af1e8edad4c6
movabs rdx, 0xee602548c0d4060c
```

Little-endian, concatenated, that is the repeating key (indexed `i % 16`):

```
c6 d4 da 8e 1e af e2 c3 0c 06 d4 c0 48 25 60 ee
```

## Step 4 — decode offline

```python
data = open('uncoding','rb').read()
key  = bytes.fromhex('c6d4da8e1eafe2c30c06d4c0482560ee')

for off in (0x2008, 0x2068, 0x20f0, 0x2128):
    end  = data.index(b'\0', off)
    blob = data[off:end]
    print(hex(off), bytes(c ^ key[i % 16] for i, c in enumerate(blob)))
```

```
0x2008 b'Three hidden challenges test worthy traits, revealing three hidden keys to three magic gates'
0x2068 b"I suppose you could say they're invisible, hidden in a dark room that's at the centre of a maze..."
0x20f0 b"Nice racing, padawan. You're the first to finish."
0x2128 b'HTB{0n3_t1m3_p4d_tw0_t1m3_p4d_thr33_t1m3_p4d...}'
```

Blobs 0–2 are Star Wars flavour text — useful, because they confirm the key is right *before* you
trust the fourth line.

Because this is a PIE and these offsets sit in `.rodata`, the virtual addresses happen to equal the
file offsets, so indexing the raw file directly works. On a binary where they differ, resolve through
the program headers instead.

---

## Lessons

- **"Repeating XOR pad" is not a one-time pad**, despite what the flag text jokes about. Reusing a
  16-byte pad across four messages is precisely the failure the name is needling.
- A key built with `movabs` into stack locals is invisible to `strings` but trivially visible in
  disassembly. Always read the *constants* in the decrypt routine, not just its structure.
- Decode **every** blob, not just the one you want. The plaintexts you can already predict are your
  correctness check.
- Trust the bytes over your expectations: a flag really can end in `...}`.
