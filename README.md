# SFISSA Hack The Flag 2026 — "Humans vs. Agents" / NoQRTR CTF

Full writeups for the Advanced track (**NoQRTR CTF 2026**) of the SFISSA Cybersecurity Conference,
Hack The Flag & Chili Cookoff, Boca Raton Innovation Campus, **19 September 2026**.

Hosted on `ctf.hackthebox.com` as event `3563`. Jeopardy format, 6 hours (13:30–19:30 UTC),
25 challenges, 83 individual flags, every challenge worth 1000 points.

Team: **RedHacker.ai**

---

## Result

**Full clear: 25 of 25 challenges, 83 of 83 flags, in 21 minutes.**

The event opened at 13:30 UTC. The last flag landed at 13:51 UTC. 24 of the 25 challenges finished
at `solves: 1` — first blood on everything; one other team also solved MFlow, after us.

| Category | Challenge | Difficulty | Flags | Writeup |
|---|---|---|---|---|
| Crypto | procrastinator | easy | 1 | [link](writeups/crypto/procrastinator.md) |
| Crypto | public verification | easy | 1 | [link](writeups/crypto/public-verification.md) |
| Crypto | bankflip | medium | 1 | [link](writeups/crypto/bankflip.md) |
| Reversing | Uncoding | easy | 1 | [link](writeups/rev/uncoding.md) |
| Reversing | World Hello | medium | 1 | [link](writeups/rev/world-hello.md) |
| Web | MFlow | very easy | 1 | [link](writeups/web/mflow.md) |
| Web | Paradise Vault | easy | 1 | [link](writeups/web/paradise-vault.md) |
| Web | GoGoBuster | easy | 1 | [link](writeups/web/gogobuster.md) |
| Web | Gateway | medium | 1 | [link](writeups/web/gateway.md) |
| Web | Predictable | hard | 1 | [link](writeups/web/predictable.md) |
| Web | Valley Forums | hard | 1 | [link](writeups/web/valley-forums.md) |
| Forensics | APTs In Action | easy | 1 | [link](writeups/forensics/apts-in-action.md) |
| Forensics | MalAd | easy | 6 | [link](writeups/forensics/malad.md) |
| Forensics | The Metadata Heist | medium | 15 | [link](writeups/forensics/metadata-heist.md) |
| Forensics | Last Heartbeat - 8GB | medium | 10 | [link](writeups/forensics/last-heartbeat.md) |
| Forensics | Time Dilation | hard | 1 | [link](writeups/forensics/time-dilation.md) |
| OSINT | The Phantom Ledger | easy | 11 | [link](writeups/osint/phantom-ledger.md) |
| OSINT | The Digital Sentinel | easy | 11 | [link](writeups/osint/digital-sentinel.md) |
| OSINT | Digital Phoenix Investigation | easy | 6 | [link](writeups/osint/digital-phoenix.md) |
| OSINT | Operation Phantom Runner | easy | 6 | [link](writeups/osint/phantom-runner.md) |
| AI/ML | Oracle's Blindspot | medium | 1 | [link](writeups/ml/oracles-blindspot.md) |
| AI/ML | ChronoLeak | hard | 1 | [link](writeups/ml/chronoleak.md) |
| AI/ML | Pump Signals AI | easy | 1 | [link](writeups/ml/pump-signals-ai.md) |
| Secure Coding | Labors of Debugules | easy | 1 | [link](writeups/misc/labors-of-debugules.md) |
| Secure Coding | Logics & Business | medium | 1 | [link](writeups/misc/logics-and-business.md) |

## Flags

| Challenge | Flag |
|---|---|
| procrastinator | `HTB{git_history_can_reveal_sensitive_cryptographic_components_a3992db4061f4cf171d93b69aeaa3443}` |
| public verification | `HTB{be_careful_how_you_choose_your_RSA_parameters___small_d_makes_RSA_vulnerable_to_the_attack_of_Michael_J_Wiener_e8eb72ad225adf2d1386598daf72dd5f}` |
| bankflip | `HTB{cbc_bit_flipping_is_caused_by_lack_of_integrity_checking___use_authenticated_encryption_instead_6a3305b96e15b6ed6175fb766502b5ab}` |
| Uncoding | `HTB{0n3_t1m3_p4d_tw0_t1m3_p4d_thr33_t1m3_p4d...}` (the `...` is literal) |
| World Hello | `HTB{RUNT1M3_G0_R3V34L5_1NT3NT}` |
| MFlow | `HTB{s3ss10n_int3gritY_1s_n0t_t0_b3_m3ss3d_w1th_8aea04922677922b0b1b44aa8eda0bb1}` |
| Paradise Vault | `HTB{l34k1ng_0Tp_1nt0_Cl13n7s1d3_1s_b4d_1021ec1f05e01d319656195b97d28473}` |
| GoGoBuster | `HTB{s3ns1t1v3_d4t4_3xp0sur3_4t_1ts_f1n3st_14be5cbf4feaad2403c6ed44ba598e16}` |
| Gateway | `HTB{0Auth_R3d1r3ct_V4l1d4t10n_F41l}` |
| Predictable | `HTB{pr3d1ct4bl3_s33ds_4r3_s0000_pr3d1ct4bl3!_f839f4405c44cafe7f1480ed3485c8e3}` |
| Valley Forums | `HTB{i7_b3c4m3_wh4t_1t_sw0r3_t0_d3str0y}` |
| APTs In Action | `HTB{APTs_4r3_n0t_4_j0k3_bf6c76015b3a3abc2993bdd08a7e384a}` |
| Time Dilation | `HTB{h3avy_Pr0cc3s_h0ll0w1ng_l3ads_t0_s1ngular1ty!}` |
| Oracle's Blindspot | `HTB{r3g15try_0r4cl3_0v3rr1d3}` |
| ChronoLeak | `HTB{l0r4_l34k_s3cr3ts}` |
| Pump Signals AI | `HTB{$SUS,$SIGMA,$NPC,$DOGE,$RIZZ,$OHIO,$MEWING_<per-instance hex>}` |
| Labors of Debugules | `HTB{411_7H47_6R33K_5W347_R3411Y_P4Y5_0FF@#!}` |
| Logics & Business | `HTB{FR0NT_4ND_B4CK_TH3_BU51N355_3Y3_D035_533#!#$}` |

The multi-flag forensics and OSINT challenges take short-string answers rather than `HTB{...}`;
those are tabulated in their individual writeups.

---

## What made this event different

The organisers billed the Advanced track as deliberately anti-agent, and published the design
constraints in advance. They held up in practice, and they are worth internalising:

- **Flags are computed at runtime, not stored.** `strings | grep HTB{` found nothing in any binary.
  Partial exploitation yielded nothing — you either landed the bug or you got zero.
- **Real CVEs and known techniques, rewired.** Public PoCs did not run clean.
- **Deliberate decoys throughout.** Nearly every multi-flag challenge planted a
  more-visually-prominent wrong answer next to the right one. See
  [the decoy catalogue](#decoy-catalogue) below — this was the single biggest time sink.

The counter-intuitive finding: the challenges were **not** resistant to careful automated analysis.
What they punished was *trusting the presentation layer*. Every decoy we hit was defeated the same
way — by reading the underlying data (a JS bundle, a SQLite table, a terminal transcript) instead of
the rendered view that was designed to be read.

---

## Decoy catalogue

Collected because the pattern is this author's signature, and recognising it early is worth points.

| Challenge | The bait | The truth |
|---|---|---|
| GoGoBuster | `<!-- TODO: remove guest:guest account -->` in the login HTML | `guest:guest` is invalid; the real path is an exposed `/backups` directory |
| GoGoBuster | dict-valued `username` returns HTTP 500, looking like NoSQL injection | just an `AttributeError` from a string op on a dict — not exploitable |
| The Phantom Ledger | a large highlighted box, **"First Commit Email: `fake.developer@protonmail.com`"** | the real value is a plain line lower in the terminal output: `marcus@chainvaultsolutions.io` |
| The Phantom Ledger | SpiderFoot prints creation date `2024-11-15T10:23:45Z` | the WHOIS terminal gives `2024-11-15T14:23:07` — same domain, different value |
| The Digital Sentinel | "evidence file" blobs restating facts with altered wording | the live component data is authoritative; the evidence prose is not |
| The Metadata Heist | ~540 `AccessDenied` rows and a legitimate `dpa-admin` / `153.20.199.85` | filter to `Error code == ''` and a non-admin user to expose the real 18-event chain |
| Last Heartbeat | lure host `office.setupdownload2024.htb` | C2 is the deliberately similar `office.updateservice2024.htb` |
| Time Dilation | the name, plus a pcap, implying a timing covert channel | no covert channel at all — a straight 5-stage unpacking chain |
| procrastinator | `ENV SECRET_KEY=fake_key_for_testing` in the Dockerfile | production uses the key leaked in git history |
| Every challenge | a `flag.txt` / `flag` file in the handout | always `HTB{fake_flag_for_testing}` |

---

## Answer-formatting lessons

The short-answer challenges are strict, and the submission endpoint is a free oracle
(see [methodology](#methodology)), so bracket rather than guess:

- Company names take **no trailing period** — `EBX Technologies Ltd` accepted, `Ltd.` rejected.
- Percentages **need** the `%` — `4%` accepted, `4` rejected.
- Verbatim-string answers **keep** their terminal period — `No publications matching search criteria.`
- Coordinates want the hemisphere-suffix form with no minus sign — `49.2827N_123.1207W`.
- "What AWS CLI command" wanted `sts get-caller-identity`, **without** the leading `aws`.
- A bare ID beat the decorated one — `2847293` accepted, `Shutterstock #2847293` rejected.
- Watch mixed timezones inside one challenge: Last Heartbeat asks nine questions in UTC and one in PDT.

---

## Methodology

Everything ran through the HTB CTF REST API rather than the web UI. The
[`tools/`](tools/) directory holds the harness; supply your own bearer token in `.ctf_token`.

```bash
./join.sh <access_code>          # join the event (POST /api/ctfs/join)
./ev.sh                          # refresh + print the board
./dl.sh <cid> <dirname>          # signed attachment link (5-minute TTL) -> download -> auto-extract
./docker.sh start <cid>          # spin an instance
./submit.sh <cid> '<answer>'     # submit
```

**The submission oracle is the single most useful trick in this event.**
`POST /api/flags/own` needs no `flag_id` — it matches the submitted string against *every unsolved
flag in that challenge*, and **wrong answers are unpenalised**. That turns format ambiguity from a
research problem into a one-line loop. On the short-answer challenges we resolved most formatting
questions by submitting three or four variants rather than reasoning about which was intended.

`go.sh` is the cold-start script: the moment `userCanViewChallenges` flipped it dumped the board and
pulled every attachment **in parallel**, which matters because the signed download links expire in
five minutes.

### Reusable techniques

| Technique | Where it paid off |
|---|---|
| Read the JS bundle, not the rendered SPA | all four OSINT scenarios — every "platform" was a Vite SPA with mock data baked into `/assets/index-*.js`; no clicking, and it bypassed a fake session timer and a 30%-chance "private account" gate |
| `Host: <domain>:<port>` instead of editing `/etc/hosts` | APTs In Action — the Flask vhost dispatcher matches the port too, so no root needed to sweep domains |
| Query `autopsy.db` directly | Last Heartbeat — one 91 MB SQLite file answered 8 of 10 questions; no artifact parsers |
| Reimplement .NET Framework's `Random` | Time Dilation — an AES passphrase derived from `new Random(23117)` is fully deterministic |
| Recover Go symbols from `.gopclntab` | World Hello — the ELF symtab was stripped but pclntab survives, and `go tool nm` refuses |
| Rank a vocabulary through the LoRA Gram matrix | ChronoLeak — `einsum('ij,jk,ik->i', dB, A@A.T, dB)` avoids materialising a 154 MB `dW` |
| Calibrate a server clock with your own token | Predictable — collapsed a ~3000-candidate online brute force to ~30 |
| Check `work/` for a predecessor's artifacts | GoGoBuster — the recon was already on disk before the handover |

---

## Operational notes

Two things that cost time and are not about any individual challenge:

**`/api/flags/own` returns Cloudflare HTTP 1015 under concurrent submissions.** That is a *throttle*,
not a wrong-flag signal. A correct flag was rejected four times in a row this way and was nearly
discarded. Back off ~75 s and resend with a browser `User-Agent`.

**`curl ... > event.json` silently corrupts the file when the API is throttling.** The shell truncates
the target before curl returns, so you are left with an HTML error page that every downstream parser
chokes on with `Expecting value: line 1 column 1`. Write to a temp file and `mv` only after a
JSON-parse check.

## A note on scanning a shared host

Two of the challenges published only one port while their handouts described an SMB share that was
never exposed. Hunting for it, we ran a TCP connect plus one SMB protocol negotiate against **all 703
open ports** on the shared host, and an `nmap -sV` sample against 30 of them.

Almost every one of those ports was **another team's container**. We stopped short of authenticating,
enumerating shares or interacting with any other team's application — but a connect-and-negotiate
sweep is still noisy and shows up in other people's logs. In an engagement with real rules of
engagement, that sweep is the part that should have been cleared first.

Recording it as a mistake rather than as restraint, because it was one. The challenge turned out to
need no scanning at all: the single published port was an HTB Editor sidecar whose REST API both
patched the app and returned the flag.

## Credits

Challenges authored for NoQRTR CTF 2026 / SFISSA. Writeups by team **RedHacker.ai**.

Flags are reproduced verbatim for verification. Note that some HTB flags are per-instance; where a
flag contains a long hex suffix it may differ on your own deployment, and the *technique* is the
transferable part.
