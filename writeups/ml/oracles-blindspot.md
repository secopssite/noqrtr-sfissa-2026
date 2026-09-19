# Oracle's Blindspot — AI/ML, medium — 1000 pts

**Flag:** `HTB{r3g15try_0r4cl3_0v3rr1d3}`

Handout: `model.keras` (13.9 MB). A live instance accepts an image upload and, if the "Oracle"
recognises a "perfect glyph", returns a shard key.

---

## Step 1 — understand the model

```
Keras 3.10 functional CNN
input   (None, 32, 32, 1)   grayscale
body    VGG-ish 64 / 128 / 256 conv blocks + GlobalAveragePooling
head    Dense(10), softmax
preproc pixel / 255
```

The app is a single page; the upload is a multipart `POST /` with field `file`.

### Environment gotcha

Kali's default Python is **3.14, and TensorFlow publishes no 3.14 wheels.** Do not burn time
fighting pip:

```console
$ uv venv --python 3.12 && uv pip install tensorflow-cpu     # ~2 minutes
```

If you would rather avoid TensorFlow altogether: a `.keras` file is just a **ZIP**. Unzip it and read
`config.json` plus `model.weights.h5` with `h5py`/numpy.

## Step 2 — rule out the obvious hypothesis

The name suggests a planted backdoor trigger, so the first check is the first conv layer's filters
for an anomalous kernel. There is nothing there. **This is not a backdoored model** — it is a plain
classifier, and the task is a straightforward targeted adversarial example, white-box.

## Step 3 — targeted PGD, quantization-aware

The naive approach — optimise a float tensor, then save it as a PNG — **fails**. Writing to uint8
quantises every pixel, and the perturbation is small enough that rounding destroys it; confidence
collapses between the tensor you optimised and the file you upload.

The fix is to put the quantisation *inside* the optimisation loop with a straight-through estimator:
round in the forward pass, pass the gradient through unchanged.

```python
import tensorflow as tf

def quantize_ste(x):
    q = tf.round(x * 255.0) / 255.0
    return x + tf.stop_gradient(q - x)        # forward: q, backward: identity

x = tf.Variable(tf.fill((1, 32, 32, 1), 0.5))  # start from mid-gray
for _ in range(400):
    with tf.GradientTape() as tape:
        logp = tf.math.log(model(quantize_ste(x))[0, target] + 1e-12)
    g = tape.gradient(logp, x)
    x.assign(tf.clip_by_value(x + 0.05 * tf.sign(g), 0.0, 1.0))
```

400 steps, `sign(grad)` ascent on `log p[target]`, learning rate 0.05, starting from mid-gray. The
saved uint8 PNG retains confidence **1.000000** — no drop between optimisation and file.

## Step 4 — find the gated class

The server never states which class counts as the "perfect glyph". Rather than guess, generate one
adversarial image per class and upload all ten. **Class 4** is the one:

```
Oracle accepts glyph. Shard Key: HTB{r3g15try_0r4cl3_0v3rr1d3}
```

Ten uploads is cheaper than any amount of reasoning about which class was intended.

---

## Lessons

- **Optimise in the domain you will actually submit in.** Any float-space adversarial example that
  must survive uint8 PNG encoding needs quantisation inside the loop. A straight-through estimator
  costs two lines and is the difference between confidence 1.0 and a failed upload.
- **Check the boring hypothesis first.** "Backdoor trigger" is more interesting than "adversarial
  example", but inspecting the first-layer filters ruled it out in minutes and prevented a long hunt
  for a trigger that was never planted.
- **`.keras` is a ZIP.** When a framework install is fighting you, read `config.json` and
  `model.weights.h5` directly rather than installing a 500 MB dependency.
- When an unknown discrete parameter gates the win (here, the target class), enumerate it. Ten cheap
  attempts beat one clever deduction.
