# ASReview LAB — Server Stack (Coolify)

This repo deploys an authenticated, multi-user
[ASReview LAB](https://asreview.nl/) instance on
[Coolify](https://coolify.io/). Coolify's built-in Traefik proxy terminates
HTTPS and routes traffic directly to the application — there is no TLS,
NGINX, or reverse-proxy configuration in this stack.

**Two containers**: PostgreSQL and ASReview (Gunicorn on port 5006).

**All configuration lives in `.env`** — including ASReview's own settings.
There is no separate config file. Flask reads `ASREVIEW_LAB_*` environment
variables directly via
[`app.config.from_prefixed_env`](https://flask.palletsprojects.com/en/3.0.x/api/#flask.Config.from_prefixed_env).

---

## Repository layout

| File | Purpose | In git? |
|---|---|---|
| [`docker-compose.yml`](docker-compose.yml) | The two services. | ✅ |
| [`Dockerfile`](Dockerfile) | Builds the ASReview Python image. | ✅ |
| [`.env.example`](.env.example) | Annotated template for **all** configuration. | ✅ |
| `.env` | Real secrets and config. **Never commit.** Only used for local dev — on Coolify, paste values into the UI. | ❌ gitignored |
| [`.gitignore`](.gitignore) | Keeps secrets and certs out of git. | ✅ |

**Why a `.env.example` and not a `.env`?** Anything containing a secret is
kept out of git and ships as a template. Cloning the repo gives you
blueprints, never credentials.

---

## Deploy on Coolify

1. **Create a new resource** → *Public/Private Repository* → *Docker Compose*
   build pack → point to this repo.
2. **Environment Variables tab** — paste every variable from
   [`.env.example`](.env.example), replacing each `CHANGE_ME` with a strong
   value. Generate them with:
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(48))"
   ```
3. **Domains tab** — assign your domain to the **`asreview`** service.
   Coolify routes through Traefik on container port 5006.
4. **Deploy.**

That's it. No file mounts, no certificates, no proxy config.

### Optional: gzip / large uploads

- **Compression**: Coolify's Traefik does not enable compression by default.
  For browsers to receive gzipped JS, add a Traefik *compress* middleware in
  the Coolify UI under the service's *Proxy / Traefik* settings (or via
  labels if your Coolify version supports raw label injection). Without it,
  pages still work — they just transfer ~3× more bytes on first load.
- **Large dataset uploads**: Traefik streams request bodies with no default
  size limit. If your Coolify instance has set a custom limit, raise it
  there.

---

## Local development

```bash
cp .env.example .env
$EDITOR .env          # fill in every CHANGE_ME
```

The committed compose has no host port bindings (so it doesn't clash with
Coolify's proxy). For local browser access, add a one-line override:

```yaml
# docker-compose.override.yml  (gitignore it if you customise it)
services:
  asreview:
    ports:
      - "5006:5006"
```

Then `docker compose up` and open <http://localhost:5006>.

> ℹ️ For local HTTP testing, also flip
> `ASREVIEW_LAB_SESSION_COOKIE_SECURE` and
> `ASREVIEW_LAB_REMEMBER_COOKIE_SECURE` to `false` in your local `.env` —
> `Secure` cookies are dropped over plain HTTP.

---

## How ASReview config maps to env vars

Flask's `from_prefixed_env("ASREVIEW_LAB")` strips the prefix and stores the
rest in `app.config`. So `ASREVIEW_LAB_SECRET_KEY=foo` becomes
`app.config["SECRET_KEY"] = "foo"`.

Each value is run through `json.loads`, falling back to the raw string on
failure. In practice:

| You write | Flask sees |
|---|---|
| `ASREVIEW_LAB_ALLOW_ACCOUNT_CREATION=true` | `True` (bool) |
| `ASREVIEW_LAB_MAIL_PORT=465` | `465` (int) |
| `ASREVIEW_LAB_SESSION_COOKIE_SAMESITE=Lax` | `"Lax"` (string — JSON parse fails) |
| `ASREVIEW_LAB_SECRET_KEY=abc123-def_ghi` | `"abc123-def_ghi"` (string) |

⚠️ Avoid bare values like `null`, `true`, `false` for secret strings — they
would be parsed as `None`/booleans. Strings from `secrets.token_urlsafe` are
always safe.

### Keys recognised by ASReview v2

| Env var (in `.env`) | What it controls |
|---|---|
| `ASREVIEW_LAB_SECRET_KEY` | Flask session-signing key. **Required.** |
| `ASREVIEW_LAB_SECURITY_PASSWORD_SALT` | Password-hashing salt. **Required.** |
| `ASREVIEW_LAB_SESSION_COOKIE_SECURE` | `true` over HTTPS (Coolify default). |
| `ASREVIEW_LAB_REMEMBER_COOKIE_SECURE` | Same — `true` over HTTPS. |
| `ASREVIEW_LAB_SESSION_COOKIE_SAMESITE` | `Lax` for single-domain, `None` for cross-domain (also needs HTTPS). |
| `ASREVIEW_LAB_ALLOW_ACCOUNT_CREATION` | `false` to lock down sign-ups. |
| `ASREVIEW_LAB_EMAIL_VERIFICATION` | Requires the `MAIL_*` vars below. |
| `ASREVIEW_LAB_MAIL_*` | SMTP settings (SendGrid example in the template). |

**v1 → v2 deprecations** — these are silently ignored by ASReview v2 and
should be removed from any older configs you migrate:
`JWT_ACCESS_TOKEN_EXPIRES`, `JWT_REFRESH_TOKEN_EXPIRES`, `JWT_SESSION_COOKIE`,
`DISABLE_LOGIN`, `LOGIN_DISABLED`.

---

## Email server (SendGrid)

Account verification and password resets need SMTP. Self-hosting is more
work than it sounds; [SendGrid](https://sendgrid.com/)'s SMTP relay is free
for ≤ 100 emails/day.

1. SendGrid → *Email API* → *Integration Guide* → *SMTP Relay*. Create an
   API key.
2. Uncomment the `ASREVIEW_LAB_MAIL_*` block in your `.env` (or Coolify env
   vars) and fill in the credentials.
3. SendGrid → *Settings* → *Sender Authentication* — authorise the reply
   address.
4. Outbound port **465** must be open on the host.

---

## Security best practices

> 🚨 If you ever committed a real password or key, **rotate it immediately**,
> even from a private repo. Crawlers and history-mining tools index commits
> within minutes.

For the junior dev reading this:

1. **Never commit `.env`, `*.pem`, `*.key`.** All are gitignored — keep them
   that way.
2. **Generate every secret with a CSPRNG**, not by typing a password you
   like:
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(48))"
   ```
3. **Unique secrets per environment.** Dev, staging, and production must not
   share `SECRET_KEY`s or database passwords.
4. **Run `git status` before every commit.** Look for files that shouldn't be
   there.
5. **Rotate on suspicion.** Stolen laptop, exposed CI log, accidental Slack
   paste — assume compromised and rotate.

### If a secret leaks

1. Rotate the value everywhere it's used. The old one is still valid until
   you replace it.
2. Optionally scrub git history with
   [`git filter-repo`](https://github.com/newren/git-filter-repo):
   ```bash
   git filter-repo --invert-paths --path .env
   git push --force --all
   ```
   Coordinate with collaborators — this rewrites SHAs and forces re-clones.
   Assume the old value was scraped before the rewrite.

### What this repo does for you

- `.env` is gitignored, plus `*.pem` / `*.key` / `*.crt` and the now-unused
  `asreview_config.toml`.
- `.env.example` contains only obvious placeholders (`CHANGE_ME_*`).
- `docker-compose.yml` uses `${VAR:?}` for required variables, so the stack
  **refuses to start** if a critical secret is missing.

---

## Troubleshooting

**`POSTGRES_PASSWORD: variable is required`**
Compose refuses to start because the variable is empty. Fill it in via
Coolify's UI (or `.env` locally).

**Login works once, then the session drops**
`ASREVIEW_LAB_SESSION_COOKIE_SECURE=true` requires HTTPS. If you're testing
over plain HTTP locally, set it to `false` in your local `.env`. In
production, fix HTTPS instead.

**`port is already allocated` during Coolify deploy**
You committed a `ports:` block. Remove it, or keep it in a gitignored
`docker-compose.override.yml`.

**Browser shows 502 / connection refused**
The `asreview` container takes ~30 s to finish DB migrations on first
start. Check `docker logs <asreview-container>` — Gunicorn should print
`Listening at: http://0.0.0.0:5006`.

---

## License

See [LICENSE](LICENSE).
