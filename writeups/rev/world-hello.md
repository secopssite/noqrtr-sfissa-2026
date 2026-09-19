# World Hello — reversing, medium — 1000 pts

**Flag:** `HTB{RUNT1M3_G0_R3V34L5_1NT3NT}`

A 1.6 MB binary named `telemetry`. Running it prints nothing.

---

## Step 1 — triage

```console
$ file telemetry
telemetry: ELF 64-bit LSB executable, x86-64, statically linked, stripped
$ ./telemetry
(no output)
```

Go, statically linked, stripped, and built with `-gcflags=all=-l` (inlining disabled). Execution is
a dead end: `reportStatus` has a guard that never passes, so there is nothing to observe
dynamically. It must be read statically.

Worse, the binary is padded with roughly **750 decoy functions** (`main.noiseFuncN`) behind a
750-case jump table (`main.noiseDispatch`). Without symbols you cannot tell signal from noise.

## Step 2 — recover symbols from `.gopclntab`

The ELF symbol table is stripped, and both `go tool nm` and `objdump` refuse ("no symbol section").
But Go binaries carry `.gopclntab` — the runtime's own PC→function-name table, needed for panics and
stack traces — and **stripping does not remove it**.

Locate the go1.20+ header by its magic `0xfffffff1` (here at `0x4e6820`), then walk
`funcnametab` / `functab` / `_func.nameOff` to recover names and addresses.

```python
# work/75287_world_hello/pcln.py — parses the pclntab header and emits name -> addr
MAGIC = 0xfffffff1
# header: magic, pad, pad, minLC, ptrSize, nfunc, nfiles, textStart,
#         funcnameOffset, cuOffset, filetabOffset, pctabOffset, pclnOffset
```

That collapses ~750 functions down to the **ten that matter**:

```
main.main, reportStatus, buildCampaignTag, statA, statB, statC, statD,
buildRuntimeStats, noiseDispatch, seed
```

## Step 3 — read the four constant pieces

`statA`..`statD` are one-line functions returning constant Go string headers (pointer + length):

| fn | address | len | value |
|---|---|---|---|
| `statA` | `0x4d16d3` | 3 | `G0_` |
| `statB` | `0x4d1cde` | 8 | `RUNT1M3_` |
| `statC` | `0x4d1ce6` | 8 | `R3V34L5_` |
| `statD` | `0x4d1944` | 6 | `1NT3NT` |

## Step 4 — the joke

`buildRuntimeStats` boxes all four via `runtime.convTstring` into a 4-element `[]any` and calls
`fmt.Sprintf` with the format string at `.data 0x5820b0`:

```
%[2]s%[1]s%[3]s%[4]s
```

Those are **explicit argument-index verbs**. They reorder the arguments — `2, 1, 3, 4` — so the
naive reading (`G0_RUNT1M3_R3V34L5_1NT3NT`) is wrong and the real value is:

```
RUNT1M3_G0_R3V34L5_1NT3NT
```

This is the "World Hello" pun: the pieces are swapped, exactly as "Hello World" is.

## Step 5 — assemble the wrapper

`buildCampaignTag` calls `runtime.concatstring5(nil, a, b, c, d, e)`. Decode the Go register ABI to
map arguments:

```
rax = buf, rbx/rcx = a, rdi/rsi = b, r8/r9 = c, r10/r11 = d, [rsp]/[rsp+8] = e
```

Reading the `.data` string headers at `0x582070 / 80 / 90 / a0` gives `a="HT"`, `b="B"`, `c="{"`,
`e="}"`, with `d` = the Sprintf result.

```
"HT" + "B" + "{" + "RUNT1M3_G0_R3V34L5_1NT3NT" + "}"
```

No emulation and no debugger — once pclntab names the functions, the whole flag is static data.

---

## Lessons

- **Stripped Go is not stripped.** `.gopclntab` survives and hands you every function name. Parse it
  yourself (or use GoReSym / `pclntab` plugins) when `nm` refuses.
- **Decoy inflation is defeated by symbol recovery, not by reading more code.** 750 noise functions
  cost nothing once you can filter by name.
- **Read format strings character by character.** `%[n]s` argument-index verbs silently reorder
  output and are an easy way to make a correct-looking reconstruction wrong.
- Know your target's calling convention. Go's register ABI (since 1.17) is not the System V ABI, and
  misreading it will mis-assign every argument to `concatstring5`.
