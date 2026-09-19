# ChronoLeak — AI/ML, hard — 1000 pts

**Flag:** `HTB{l0r4_l34k_s3cr3ts}`

Handout: a directory of **20 LoRA adapter checkpoints** (`adapter_t0` … `adapter_t19`), 167 MB each,
in `safetensors` format. No instance, no base model, no tokenizer prompt. Recover the secret the
adapter was fine-tuned on.

> A note on our own error: the first pass at this described *six* adapters, because a directory
> listing was read carelessly. There are twenty, and the count matters — it is what makes the
> position-by-position decode work.

---

## Step 1 — inventory the tensors

Each file holds three tensors:

| Tensor | Shape | Behaviour across checkpoints |
|---|---|---|
| `lm_head.base_layer.weight` | `[50272, 768]` | frozen, byte-identical in every file |
| `lora_A` | `[64, 768]` | effectively frozen |
| `lora_B` | `[50272, 64]` | zero at `t0`, grows monotonically |

`lora_A` never moves because **LoRA initialises `B` to zero**. The product `B·A` is therefore zero at
step 0, and the gradient with respect to `A` is proportional to `B` — which is zero — so `A` receives
no update on the first step and stays essentially fixed thereafter.

**All the leakage is in `B`.** With `alpha/r = 1`, the effective weight update is simply `ΔW = B·A`.

`t0` and `t1` are identical, leaving **18 usable transitions** — exactly the 18 predicted positions
of a 19-token sequence (position 0 is BOS and never a label).

That arithmetic lining up is the moment the challenge is solved in principle: **one SGD step per
token position.**

## Step 2 — the leak

For an `lm_head` trained with cross-entropy, the gradient for a single training step is

```
dW = (p − y) ⊗ h
```

where `y` is the one-hot true label. Every vocabulary row gets a small push proportional to its
predicted probability, and **the true token's row gets a large `−h` term**. So the row of `dW` with
by far the largest norm *is* the token that was trained at that step.

## Step 3 — rank the vocabulary without materialising `dW`

`dW` is `[50272, 768]` — about 154 MB per transition, times 18. Unnecessary.

Let `dB = B_{t+1} − B_t`. Then row *v* of `D_t = dB·A` has squared norm

```
‖dB_v · A‖² = dB_vᵀ (A Aᵀ) dB_v
```

`A Aᵀ` is only **64×64**. So the entire vocabulary ranking is a single einsum:

```python
G  = A @ A.T                                   # 64 x 64 Gram matrix
n2 = np.einsum('ij,jk,ik->i', dB, G, dB)       # squared norm of every vocab row
tok = int(n2.argmax())
```

At every step exactly one row sat an order of magnitude above the rest — a clean, unambiguous signal.

## Step 4 — decode

Because training applied one position per step, **the sequence of argmaxes is the token order**:

```
[' HT', 'B', '{', 'l', '0', 'r', '4', '_', 'l', '34', 'k', '_', 's', '3', 'cr', '3', 'ts', '}']
```

→ `HTB{l0r4_l34k_s3cr3ts}`

The tokenisation (` HT` + `B`, and merged pieces like `34`, `cr`, `ts`) is characteristic of a
GPT-2/OPT BPE vocabulary — consistent with the `50272` vocab size, which is OPT's.

## Step 5 — practical notes

- **`safetensors` is not required.** The format is an 8-byte little-endian header length, a JSON
  header, then raw tensor data. `np.memmap` past the header reads it directly, which avoids a
  dependency and keeps memory flat.
- **Do not load all 20 adapters at once** — that is gigabytes. Stream pairs: hold `B_t`, read
  `B_{t+1}`, difference, discard.
- **Do not attempt inference.** There is no base model in the handout, and you do not need one.

---

## Lessons

- **Publishing a sequence of training checkpoints publishes the training data.** This is gradient
  leakage: the difference between adjacent checkpoints of an output layer is a direct readout of
  which token was trained. Release only the final adapter — and recognise that even one adapter
  leaks membership information.
- **LoRA's zero-init on `B` concentrates all the signal in one matrix.** Knowing the initialisation
  scheme told us where to look before any data was touched.
- **Push the algebra before the compute.** Rewriting `‖dB_v·A‖²` as a quadratic form in a 64×64 Gram
  matrix turned 2.7 GB of intermediates into one `einsum`. Reaching for more RAM would have worked;
  reaching for the identity was faster.
- Verify your file inventory before reasoning from it. "Six adapters" and "twenty adapters" imply
  different solve structures.
