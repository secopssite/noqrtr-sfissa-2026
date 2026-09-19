# The Digital Sentinel — OSINT, easy — 11 flags, 1000 pts

"SOCMINT-OS Campus Threat Investigation" — a simulated social-media intelligence workstation
profiling a campus activist, **Jordan Davidson** (`JusticeR`). Four personas surfaces: an Instagram
clone, an HR Portal, a Discord clone and a Reddit clone.

---

## Method — one command

The instance is a **static React/Vite SPA served by nginx with no backend API**. Every persona
surface is a React component with its data hardcoded as a JS object literal.

```console
$ curl -s http://$HOST:$PORT/assets/index-taxktm2j.js > bundle.js     # 283 KB
```

Grep that file and every answer appears as an exact string. **No fuzzing, no rendering, no clicking.**

This also sidesteps two obstacles built into the UI:

- a fake **15-second "session expires"** timer that interrupts browsing, and
- a **30 % chance "private account" gate** that randomly hides the Instagram posts.

Both exist to make the intended path slow and flaky. Reading the bundle makes them irrelevant.

## The answers

| # | Question | Answer | Source in bundle |
|---|---|---|---|
| 1 | IG caption, Sept 30 2:55 PM (no emoji) | `plotting at my usual spot` | posts array `Fp[0]` |
| 2 | Employee ID | `2024-0847` | HR record `qe` |
| 3 | Date in the 'tick tock ⏰' post | `October 5th` | `Fp[2]`: "tick tock ⏰ October 5th approaches" |
| 4 | Physical identifier, dress-code exception | `Visible tattoo (star, left wrist)` | `qe.managerNotes` |
| 5 | Work schedule | `Tue/Thu/Sat 14:00-22:00` | `qe.schedule` |
| 6 | Who posted "especially tue/thu/sat shifts... so boring" | `JusticeR` | #general messages `Vp[4]` |
| 7 | Uniform colours | `brown and green` | `Vp[6]` |
| 8 | Instagram handle | `@justice_rises_2025` | IG profile component |
| 9 | Instagram bio (no emoji) | `Student activist \| Truth seeker \| They can't silence us all` | IG profile component |
| 10 | Reddit username | `u/Justice_Rises_2025` | Reddit profile component |
| 11 | Full name in HR record | `Jordan Davidson` | `qe.name` |

The scenario is an OPSEC-failure lesson: a work schedule posted publicly, a "usual spot", a
countdown, uniform colours and a distinguishing tattoo — enough to place a named person at a known
location at a known time.

---

## The decoys

The bundle contains a set of fake **"forensic evidence file"** blobs — `instagram_screenshots.zip`,
`discord_chat_export.txt`, threat-assessment reports — rendered as flavour text. They restate the
same facts **with altered wording**:

| Question | Evidence-file version (wrong) | Live component data (accepted) |
|---|---|---|
| Sept 22 caption | `my second home` | `this place used to mean something` |
| Discord username | `JusticeR#4821` | `JusticeR` |
| Bio | TikTok profile: `Student \| Truth teller \| Making change happen 🔥` | Instagram bio as above |

Each question names its surface — *"in the #general channel"*, *"on the Instagram profile"* — and
that naming is the disambiguator. The `#general` **channel view** shows the plain username, so
`JusticeR` is correct and the export's `JusticeR#4821` is not.

## Format notes

- Q8 wants the `@` prefix; Q10 wants the `u/` prefix.
- Q1 and Q9 say "without emojis" / "exclude emojis" — strip emoji codepoints but preserve all other
  text, spacing and punctuation exactly.

---

## Lessons

- **A static SPA has no secrets.** If the data ships to the client, reading it from the bundle is
  strictly better than interacting with the app — exact strings, no UI gating, no randomness.
- **Deliberate UI friction is a tell.** A 15-second session timer and a random "private account"
  gate exist to slow the intended path. Their presence is a hint that a faster path exists.
- **A near-duplicate with different wording is a decoy, not corroboration.** When two sources state
  the same fact differently, the question's own phrasing tells you which one is authoritative.
- Prefix-bearing identifiers (`@handle`, `u/user`) are part of the answer.
