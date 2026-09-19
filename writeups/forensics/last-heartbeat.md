# Last Heartbeat - 8GB — host forensics, medium — 10 flags, 1000 pts

A 7.8 GB handout named `eugene_or/`. Ten questions about a Windows host compromise.

---

## Step 0 — identify the container format (we got this wrong first)

The directory layout is:

```
Cache/  Config/  Export/  Log/  ModuleOutput/
```

Our first read was **Velociraptor collection**. That was wrong, and it sent the initial approach off
course. The decisive files are:

```
autopsy.db              (91 MB SQLite)
eugene_or.aut
SolrCore.properties
```

This is an **Autopsy case directory**. That completely changes the method: there is no disk image to
mount and no artifact parsers to run — **almost everything is one SQL query away.**

## Step 1 — query `autopsy.db` directly

| Table | Contents |
|---|---|
| `tsk_os_accounts` | user accounts |
| `tsk_files` | full filesystem listing: `parent_path`, `name`, `crtime`/`mtime`/`atime` as unix epoch |
| `blackboard_artifacts` + `blackboard_attributes` + `blackboard_attribute_types` | `TSK_WEB_DOWNLOAD`, `TSK_WEB_HISTORY`, `TSK_PROG_RUN` (prefetch, SRUM, UserAssist) |
| `tsk_files_path` | maps `obj_id` → extracted-file path on disk |

Eight of the ten questions fall straight out of this.

### The trap that silently sinks two answers

Autopsy stores datetimes as **`value_type = 5`, held in `value_int64`** (unix seconds, UTC). A dump
script that only handles `value_type` 0–3 renders **every timestamp as `None`** — it does not error,
it just quietly returns nothing. That kills Q8 and Q10 without telling you why.

```python
def attr_value(row):
    t = row['value_type']
    if t == 0: return row['value_text']
    if t == 1: return row['value_int32']
    if t == 2: return row['value_int64']
    if t == 3: return row['value_double']
    if t == 4: return row['value_byte']
    if t == 5: return row['value_int64']      # <-- DATETIME. Do not omit.
```

Note also that `tsk_files` contains `-slack` entries and `:Zone.Identifier` ADS as **separate rows** —
which matters enormously for the "how many files" counting questions.

## Step 2 — recover the malware from the EFE container

The disk image is not in the handout, but Autopsy's **Embedded File Extractor** already carved files
out of archives into:

```
ModuleOutput/EFE/<parent_obj_id>/0/<n>
```

These are **XOR-`0xCA`-encoded after a 32-byte `TSK_CONTAINER_XOR1_…` header**:

```python
d = open(path, 'rb').read()[32:]
open(out, 'wb').write(bytes(b ^ 0xCA for b in d))
```

`tsk_files_path` gives the `obj_id` → EFE path mapping. That is how the .NET malware and an
`instructions.txt` (telling the victim to disable AV) are recovered without the image.

**The C2 string is UTF-16LE**, so it needs `strings -e l` — plain `strings` misses it entirely.

## Step 3 — the ten answers

| # | Question | Answer |
|---|---|---|
| 1 | Only user account | `Simensky` |
| 2 | Files in Downloads incl. system files | `29` |
| 3 | File created 2024-09-24 21:39:34 UTC | `CBcmkyZ8v4tAc8PSDcEgvM-1200-80.jpg` |
| 4 | Suspicious executable on Desktop | `OfficeSetupPofessionalPlus2024.exe` |
| 5 | Zip it was extracted from | `C:\Users\Simensky\Desktop\OfficeSetup.zip` |
| 6 | Archive download URL | `http://office.setupdownload2024.htb/files/OfficeSetup.zip` |
| 7 | Downloads files from `ijcsmc.com` | `5` |
| 8 | First execution (PDT) | `2024-09-24 15:01:12` |
| 9 | C2 server (with port) | `http://office.updateservice2024.htb:80` |
| 10 | Access to the lure site (UTC) | `2024-09-24 21:59:14` |

Notes on the fiddly ones:

- **Q2** counts real files including `desktop.ini`, and **excludes** the `-slack` and
  `:Zone.Identifier` pseudo-rows.
- **Q4** — the filename contains a typo, `Pofessional`, which is genuine and must be reproduced.
- **Q8** is the only question in **PDT** (UTC−7 on these dates); the prefetch entry
  `OFFICESETUPPOFESSIONALPLUS202` has run count 1 at epoch `1727215272` = 22:01:12 UTC = 15:01:12 PDT.
- **Q10** epoch `1727215154`.

### The decoy

The lure host is `office.**setupdownload**2024.htb`; the C2 is `office.**updateservice**2024.htb`.
Deliberately similar, genuinely different — and Q6 and Q9 ask for one each.

---

## Lessons

- **Identify the evidence container before choosing tools.** Autopsy case ≠ Velociraptor collection
  ≠ KAPE triage ≠ raw image. Look for `*.aut` / `autopsy.db` before assuming.
- **`autopsy.db` is a first-class artifact.** Querying it beats driving the GUI for anything countable
  or timestamped, and it is scriptable.
- **A schema you partially handle fails silently.** `value_type = 5` returning `None` looks like
  missing data, not a bug in your parser. When a whole class of answers comes back empty, suspect the
  reader before the evidence.
- `strings -e l` for UTF-16LE. .NET and Windows binaries store most interesting strings that way.
- Distribution infrastructure and C2 infrastructure are separate by design. Answer each question
  about the host it actually names.
