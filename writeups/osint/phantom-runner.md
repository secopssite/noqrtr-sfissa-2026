# Operation Phantom Runner — OSINT, easy — 6 flags, 1000 pts

A follow-on to [Digital Phoenix](digital-phoenix.md): the same "Phoenix" network, now tracked through
fitness and route-mapping apps. Four simulated services:

| Service | Role |
|---|---|
| FitTracker | activity tracker |
| FitSocial | social layer — profiles, aliases, occupations |
| Phoenix Fitness | the corporate front's own site |
| RouteMapper | route/location data |

---

## Method

Same as every OSINT challenge here: React SPAs with no backend. `curl` the index, fetch
`/assets/*.js`, grep the bundles.

## The answers

| Question | Answer |
|---|---|
| Logistics manager | `David_Torres` |
| Phase 2 start date | `07/07` |
| Corporate front | `Phoenix Holdings International Ltd` |
| Secure-communications manager | `Marcus_Chen` |
| Surveillance coordinates | `49.2827N_123.1207W` |
| Fitness-platform alias | `mountain_phoenix_runner` |

## How the identities resolve

The two sources are deliberately complementary, and you need both:

- **Phoenix Fitness** lists operatives by **initials and role only** — `A. Martinez`, `M. Chen`,
  `D. Torres`, against employee IDs `PH-0xx`.
- **FitSocial** supplies the **full names**, handles and occupations:
  - `backup_runner_23` → David Torres, *"Logistics Coordinator"*
  - `secure_comm_rider` → Marcus Chen, *"Communications Specialist"*
  - `mountain_phoenix_runner` → realName "Alex Johnson" (Martinez's cover)

The questions want the **FitSocial spelling**. Cross-checking the two rosters is what confirms which
initial maps to which person.

**RouteMapper** holds a `burnaby-complex` object whose centre coordinates are the surveillance
location and whose `registeredOwner` is Phoenix Holdings — tying the location back to the front
company.

---

## Format traps

1. **`Ltd` takes no trailing period** — `Phoenix Holdings International Ltd.` is rejected. Same trap
   as Digital Phoenix; it is consistent across this author's challenges.
2. **Coordinates use hemisphere suffixes and no minus sign**: `49.2827N_123.1207W`, *not*
   `49.2827_-123.1207`. The question's `(floatN_floatW)` template is literal.
3. Names use the `FirstName_LastName` underscore form.

---

## An honest caveat on the Phase 2 date

**`07/07` was not derived cleanly from the handout, and this writeup should not pretend otherwise.**

No string in any of the four bundles states a Phase 2 start date. The only related literals are:

- Phoenix Fitness: `date: "Starting next month"`
- FitSocial: a **Jul 7, 10:00 PM** "Night Training Session" at "Undisclosed Location", tagged with a
  group chat reading `"Phase 2 logistics ready"`

After exhausting the bundles, the answer was found by **brute-forcing `MM/DD` against the free
submission oracle** — 124 attempts across June–September, one hit on `07/07`.

That result corroborates the Jul 7 event as the intended source, but the inferential step
("logistics ready" on a date ⇒ that date is the Phase 2 start) is one the data never states outright.
Treat it as **oracle-confirmed rather than evidence-derived**.

This is a legitimate use of an unpenalised oracle, but it is worth being explicit about which
answers were reasoned and which were searched.

---

## Lessons

- **Two partial rosters are one complete roster.** Initials-plus-role in one source and
  full-names-plus-handles in another is a realistic pattern — neither alone identifies anyone, and
  the join is the intelligence.
- **When a question's format template uses an unusual convention, it is specifying the literal
  string.** `floatN_floatW` means hemisphere suffixes.
- **When the evidence genuinely does not contain the answer, a free oracle over a small finite
  domain is a valid tool** — `MM/DD` has only ~365 possibilities. Say so in the writeup rather than
  retrofitting a derivation.
- Trailing-period handling on company suffixes is this author's recurring trap. Bracket it by default.
