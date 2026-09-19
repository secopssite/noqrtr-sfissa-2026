# Logics & Business — secure coding, medium — 1000 pts

**Flag:** `HTB{FR0NT_4ND_B4CK_TH3_BU51N355_3Y3_D035_533#!#$}`

The last flag on the board. A currency-exchange app to be **patched**, not exploited — and the
obvious fix is rejected, which is what makes it the best challenge of the event.

---

## Step 0 — the editor API

Same delivery mechanism as [Labors of Debugules](labors-of-debugules.md), with one difference: here
the API paths sit at the web root, **not** under `/challenge/`.

```bash
H=http://$HOST:$PORT
curl -s $H/editor_api/directory
curl -s -G $H/editor_api/file --data-urlencode "path=blueprints/routes.py"
curl -s -X POST $H/editor_api/save -H 'Content-Type: application/json' \
     -d '{"path":"...","content":"...","client_md5":"<md5 of CURRENT on-disk content>"}'
curl -s $H/editor_api/verify
```

Ignore `note.md`'s SMB instructions — SMB is not reachable anywhere on the host.

## Step 1 — the headline bug

`blueprints/routes.py`, lines 11-14:

```python
EXCHANGE_RATES = {
  'Schmeckle': {'Blemflark': 0.72, ...},
  'Blemflark': {'Schmeckle': 1.39, ...},
}
```

`0.72 × 1.39 = 1.0008` — a **risk-free +0.08 % round-trip gain**. Exchange
Schmeckle → Blemflark → Schmeckle in a loop and money is created from nothing. `exchange_currency()`
itself is sound; the flaw is entirely in the table.

*(Correction to an early hypothesis: `/api/exchange/history` at ~line 263 needs **no** change. It
reads `tx.amount * EXCHANGE_RATES['Blemflark']['Schmeckle']` — dereferencing the dict rather than
hardcoding a literal — so it follows the table automatically.)*

## Step 2 — the trap: the obvious fix is *also* rejected

The instinctive patch is `1.39 → 1.38`. **It fails.** So does
`Decimal.quantize(0.01, ROUND_DOWN)`.

Why: `0.72 × 1.38 = 0.9936`, a **0.64 % loss** per round trip. The validator rejects **value
destruction** just as it rejects value creation. It wants the round trip to be **value-neutral** —
the cross rates must be exact inverses.

```python
'Blemflark': {'Schmeckle': 1.3888888888888888, 'Blemflark': 1}   # == 1/0.72

exchanged_amount = float(Decimal(str(amount)) * Decimal(str(rate)))  # full precision, no quantize
```

`Decimal('0.72') * Decimal('1.3888888888888888') = 0.999999999999999936` — never profitable, neutral
to ~1e-16.

A note on a trap that turned out **not** to be one: the grader's `exploit.py` matches
`Exchanged \d+\.\d+ \w+ to \d+\.\d+ \w+`, and we expected an integer-valued fix to break it. It never
triggered — Python f-string floats always render a decimal point. The real trap is the one above.

## Step 3 — how we learned what the validator wanted

This is the transferable part. `/tmp/validate.py` is unreadable — the app runs as uid 100
(`challenger`) while the validator lives in `/app/editor`, mode `770`, owned `editor:editor`.

But we control `routes.py`, which means **arbitrary Python inside the app**. So: instrument the app
and let the validator tell us what it probes.

```python
@app.before_request
def _log_req():
    open('/tmp/_reqlog.txt','a').write(f'{request.method} {request.path} {request.get_data()}\n')

@app.after_request
def _log_resp(resp):
    open('/tmp/_reqlog.txt','a').write(f'-> {resp.status} {resp.get_data()[:400]}\n')
    return resp
```

plus a temporary `/api/_dbg` route to read the log back. Trigger `/editor_api/verify`, then read the
validator's **exact** probe sequence — including the credentials it logs in with
(`rick:!@#$$@Klopi#@#`, `morty:!@#$$@Klop!#@#`).

**Generalisable: when a grader is a black box but you control code it exercises, instrument the code
and let the grader reveal its own test suite.**

## Step 4 — the two bugs the probe log exposed

The rate table was not enough — the validator also tests for **missing sign validation**.

Its exact probe sequence, recovered from the log: it logs in as `rick` and `morty`, runs
a functionality pass, then probes `POST /api/loans {"amount": -1000}`, followed by a randomised
`exchange A Schmeckle->Blemflark` and `exchange floor(A*0.72, 2) Blemflark->Schmeckle`, bracketed by
`GET /api/balance` so it can read the deltas directly.

1. **`request_loan()` accepts negative amounts** — this is what the validator probes, and a guard is
   required to pass.
2. **`send_money()` has no positive check at all**, while `exchange()` does. The validator never
   probes this one, but it is a genuine account-drain bug. Confirmed live:
   transferring `amount: -5000` *reverses* the transfer and drains the recipient — account A went
   10000 → 15000 while account B went 10000 → 5000.

Both need an explicit `if amount <= 0: reject`.

We also had to **reset SQLite rows poisoned by the validator's own failed runs** — leftover
`-1000.0` pending loans and inflated balances from earlier probes, which caused later runs to fail
for reasons unrelated to the current patch.

## Step 5 — collect

```bash
curl -s $H/editor_api/verify
{"flag":"HTB{FR0NT_4ND_B4CK_TH3_BU51N355_3Y3_D035_533#!#$}"}
```

The container is torn down the instant `/verify` emits the flag — a follow-up save to strip the
debug hooks got connection-refused. (The instrumentation was for diagnosis only and is not in the
final `routes.py`.)

Two further environment notes: the API lives at `/api/...` on the web port **directly**, not under
`/challenge/` (that prefix serves the React frontend and returns 405 for API paths); and `app.py`
runs with `debug=True`, so the Flask reloader picks up saved edits with **no process kill needed**,
contrary to what `supervisord.conf` implies. The frontend is absent from the editor tree, so the fix
must be backend-only. `/app/main_app/report.pdf` — present on the instance but not in the handout —
is pure flavour text.

---

## A latent finding nobody needed

`app.py` sets `app.config['DEBUG'] = True` and calls `app.run(debug=True)`, so the **Werkzeug
debugger is live** on the Flask backend. Not exploitable here: nginx only proxies `/api/` to Flask
(`/` goes to the React dev server), and even RCE as `www-data` could not read the root-owned
`chmod 400` `/flag.txt`.

Seeded credentials, for completeness: `xenon:wubbalubbadubdub` (administrator, 1e9 Schmeckle), plus
`rick` and `morty` seeded with pre-computed bcrypt hashes through a `set_password(..., choice=True)`
bypass path.

---

## Lessons

- **"Remove the profit" is not the same as "make it correct".** A fix that turns an exploitable gain
  into a systematic loss is still a broken system. Cross rates must be exact inverses; the invariant
  is *neutrality*, not *non-positivity*.
- **Instrument the code the grader runs.** When the test harness is unreadable but exercises code you
  control, `before_request`/`after_request` logging turns a black box into a specification.
- **Sign validation is per-endpoint, not per-application.** `exchange()` had it; `send_money()` and
  `request_loan()` did not. A negative transfer is a transfer in the other direction.
- **Float arithmetic on money is a bug generator.** Use `Decimal` end to end — and be careful that
  rounding *toward* the house is still value destruction.
- **Reset state between grading runs.** A failed validator run can poison the database and make a
  correct patch look wrong.
