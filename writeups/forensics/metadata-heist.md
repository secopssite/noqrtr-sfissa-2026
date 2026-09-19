# The Metadata Heist — cloud forensics, medium — 15 flags, 1000 pts

An AWS incident-response scenario in account `888751817612`. Artifacts only, no instance:

```
application_logs.txt   (700 KB)
event_history.csv      (178 KB — a CloudTrail Event History export)
permission.json
trusted-entities.json
vpc_flow_logs.log
```

The attack is the canonical cloud kill chain: **SSRF → IMDS → role credentials → IAM privilege
escalation → backdoor user → Secrets Manager exfiltration.**

---

## Step 1 — find the SSRF in four greps

```console
$ grep -n '169.254.169.254' application_logs.txt
```

Only **four** hits in 700 KB. Two are the successful IMDS fetches, both originating from
`236.34.84.254` against the endpoint `/api/fetch`:

```
10:14:55  GET http://169.254.169.254/latest/meta-data/iam/security-credentials/
10:15:10  GET http://169.254.169.254/latest/meta-data/iam/security-credentials/dpa-vendor-api-role
```

`169.254.169.254` is the EC2 Instance Metadata Service link-local address. The first request
enumerates the attached role; the second retrieves its temporary credentials.

## Step 2 — cut the CloudTrail noise (this is the real work)

`event_history.csv` is ~560 rows and mostly deliberate noise. Two filters reduce it to the 18 events
that matter:

1. **`User name != dpa-admin`** — `dpa-admin` from `153.20.199.85` (key `ASIA453N4QOMESMYGS2Z`) is a
   **decoy**: a legitimate administrator working normally throughout the window.
2. **`Error code == ''`** — drops ~540 `AccessDenied` rows from the attacker's blind service
   enumeration, which tell you they were probing but nothing about what succeeded.

What survives is the attack.

## Step 3 — the timeline

| UTC | Event |
|---|---|
| 10:14:55 | `POST /api/fetch` — SSRF to IMDS, credentials listing |
| 10:15:10 | SSRF to `.../security-credentials/dpa-vendor-api-role` — **credentials stolen** |
| 10:55:12 | First authenticated call: `sts:GetCallerIdentity` with `ASIA453N4QOAFGOIE6PO` (**40 min later**) |
| 10:55:18+ | ~540 `AccessDenied` service-enumeration events |
| 10:55:46 | `iam:ListUsers` — permitted by `permission.json` |
| 11:03:47 | **`iam:AttachRolePolicy`** `IAMFullAccess` → `dpa-vendor-api-role` — **privilege escalation** |
| 11:03:56 | `iam:CreateUser` `dev-test-user` (`AIDA453N4QOME67YDE3PE`) |
| 11:04:07 | `iam:AttachUserPolicy` `AdministratorAccess` → `dev-test-user` |
| 11:04:23 | `iam:CreateAccessKey` `AKIA453N4QOMDQGZVU2F` |
| 11:16:30 | `dev-test-user` `sts:GetCallerIdentity` — first backdoor action |
| 11:16:42 | `secretsmanager:ListSecrets` |
| 11:17:08 | `GetSecretValue` **`dpa-prod-db-credentials`** (+ `kms:Decrypt`) |
| 11:17:15 | `GetSecretValue` `dpa-staging-db-credentials` |
| 11:17:22 | `GetSecretValue` `dpa-app-api-keys` |

The 40-minute gap between theft and first use is itself an answer, and a realistic detail — stolen
IMDS credentials are often used from elsewhere, later.

## Step 4 — the fifteen answers

| # | Question | Answer |
|---|---|---|
| 1 | Vulnerable endpoint | `/api/fetch` |
| 2 | Attacker source IP | `236.34.84.254` |
| 3 | First SSRF to IMDS (UTC) | `2026-02-24T10:14:55Z` |
| 4 | Full IMDS credential URL | `http://169.254.169.254/latest/meta-data/iam/security-credentials/dpa-vendor-api-role` |
| 5 | Trusted service principal | `ec2.amazonaws.com` |
| 6 | Compromised instance ID | `i-00f03fafb833d6dd0` |
| 7 | Harvested access key | `ASIA453N4QOAFGOIE6PO` |
| 8 | Minutes between SSRF and first API call | `40` |
| 9 | Privesc API action | `AttachRolePolicy` |
| 10 | Policy attached to the role | `arn:aws:iam::aws:policy/IAMFullAccess` |
| 11 | Role on the instance | `dpa-vendor-api-role` |
| 12 | Backdoor user | `dev-test-user` |
| 13 | Policy on the backdoor user | `arn:aws:iam::aws:policy/AdministratorAccess` |
| 14 | First CLI command with the new key | `sts get-caller-identity` |
| 15 | Exfiltrated production secret | `dpa-prod-db-credentials` |

### Formatting gotchas

- **Q14 wanted `sts get-caller-identity` — *without* the leading `aws`.** `aws sts get-caller-identity`
  was rejected. The free submission oracle resolved this in one extra try.
- Q3 requires the exact `YYYY-MM-DDTHH:MM:SSZ` form.
- Q8 wants a bare integer.
- Policy answers need the complete `arn:aws:iam::aws:policy/...` string.
- `vpc_flow_logs.log` is **not needed for any question** — a whole file of pure distraction.

---

## Lessons

- **IMDSv1 is the bug.** Enforcing IMDSv2 (`HttpTokens: required`) makes the SSRF harmless, since
  the PUT-token handshake cannot be performed through most SSRF primitives. Also set
  `HttpPutResponseHopLimit: 1`.
- **`iam:AttachRolePolicy` on your own role is full account compromise.** A role that can modify IAM
  can grant itself `IAMFullAccess` and then `AdministratorAccess`. Treat any IAM-write permission on
  a workload role as equivalent to root.
- **Filter CloudTrail by outcome before reading it.** `Error code == ''` separates what an attacker
  *tried* from what they *achieved*; the AccessDenied flood is volume, not signal.
- **Name-based decoys are cheap and effective.** `dpa-admin` looks like the suspect because it is an
  admin. Anchor on the credential ID and source IP tied to the confirmed SSRF instead.
