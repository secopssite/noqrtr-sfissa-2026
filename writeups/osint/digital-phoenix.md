# Digital Phoenix Investigation — OSINT, easy — 6 flags, 1000 pts

Trace a darknet marketplace operator, "Phoenix", back to a real identity. Four simulated services on
one host:

| Service | Role |
|---|---|
| CryptoTalk | a forum |
| LinkedOut | a LinkedIn clone |
| Business Registry | a Canadian corporate registry |
| TechHelp | a Stack-Overflow-style Q&A site |

---

## Method

As with every OSINT challenge in this event, the platforms are **React SPAs with no backend** —
`curl` the index, pull `/assets/*.js`, and grep the bundles.

**One exception worth knowing:** TechHelp runs a **Vite dev server**, so its raw TypeScript is
fetchable. Start at `/src/main.tsx` and follow the import graph:

```
/src/main.tsx → App.tsx → context/QuestionsContext.tsx → data/mockData.ts
```

## The pivot chain

This is a well-constructed identity-resolution exercise — each artifact yields exactly one new
selector:

```
CryptoTalk forum
  "Phoenix Rising" marketplace thread
  author handle ............. alex_phoenix_crypto
  post body leaks email ..... a.martinez.crypto@protonmail.com
        │
        ▼
LinkedOut profile on the same handle
  names employer ............ "EBX Technologies"
        │
        ▼
Business Registry record BC-2020-789123
  legal entity .............. EBX TECHNOLOGIES LTD.
  director .................. MARTINEZ, ALEJANDRO NICOLAS
  address ................... 1247 Phoenix Street, Suite 301, Vancouver, Canada
        │
        ▼
TechHelp support question
  pastes an SSH config ...... IdentityFile ~/.ssh/phoenix-key-2022
```

## The answers

| Question | Answer |
|---|---|
| Physical address | `1247 Phoenix Street Suite 301 Vancouver Canada` |
| Business front | `EBX Technologies Ltd` |
| Real full name | `Alejandro Nicolas Martinez` |
| SSH key label | `phoenix-key-2022` |
| Leaked email | `a.martinez.crypto@protonmail.com` |
| Forum username | `alex_phoenix_crypto` |

---

## Format traps

These cost real time and are worth memorising for this author's challenges:

1. **`Ltd` takes no trailing period.** `EBX Technologies Ltd.` is **rejected**; `EBX Technologies Ltd`
   is accepted. The registry itself displays it *with* the period, so the handout actively misleads.
2. **The address must be reformatted to the question's template** —
   `Number Street_Name Street Suite Suite_Number City Country` — dropping the registry's commas.
3. **Decoy email.** LinkedOut displays `alex.martinez.crypto@protonmail.com`; the accepted answer is
   the forum-visible `a.martinez.crypto@protonmail.com`. One character of difference, two plausible
   sources — the question says "publicly leaked or made visible", which points at the forum post.

---

## Lessons

- **A Vite dev server serves your source.** `/src/main.tsx` and the import graph beneath it are the
  fastest route to mock data, and more complete than a built bundle.
- **Real OSINT pivots on selectors, not on content.** A handle reused across platforms, an email in a
  post body, a company name in a profile, a key comment in a pasted config — each is a join key.
  The SSH `IdentityFile` comment is a genuinely realistic leak: people paste configs into support
  forums constantly.
- **Answer in the format the question dictates**, not the format the source displays. When a question
  supplies a template in parentheses, it is specifying the exact expected string.
- The submission oracle is free — bracket the period/no-period and prefix variants rather than
  deliberating.
