# SuiteCRM 8 + OpenClaw

A one-command Docker distribution of **SuiteCRM 8.9.2** with an **OpenClaw agent** pre-wired to manage it through the V8 JSON:API. No hand-configuration, no manual OAuth2 client seeding, no per-install skill wiring. Runs on any Linux, macOS, or Windows machine with Docker.

If you just want the CRM, stop the OpenClaw services in `docker-compose.yml`. If you only want the agent skill for an existing SuiteCRM install, copy `openclaw/skills/suitecrm/` into your own OpenClaw setup.

## Quick start

```bash
git clone https://github.com/Aakeeo/suitecrm-openclaw.git
cd suitecrm-openclaw
cp .env.example .env
docker compose up -d
```

First boot takes 3–5 minutes (silent install of SuiteCRM + database tables + Symfony cache warmup). Follow progress with:

```bash
docker compose logs -f suitecrm
```

When you see `=== SuiteCRM installation complete ===`, open:

- **CRM UI** — <http://localhost:8080> — log in with `admin` / `admin123`
- **OpenClaw gateway** — <http://localhost:18789>

Prefer to skip building the images locally? Use the pre-built variant:

```bash
docker compose -f docker-compose.prebuilt.yml up -d
```

That pulls published images from GHCR and comes up in under a minute on a warm network.

## What's inside

| Service | Role | Host port | Version |
|---|---|---|---|
| `suitecrm-db` | Database | — | MariaDB 10.11 |
| `suitecrm-app` | CRM web app | — | SuiteCRM 8.9.2 on PHP 8.2 / Apache |
| `suitecrm-caddy` | Reverse proxy | 8080, 8443 | Caddy 2 |
| `openclaw-gateway` | Agent runtime | 18789, 18790 | Latest `ghcr.io/openclaw/openclaw` + jq/curl |
| `openclaw-cli` | Interactive CLI (profile `cli`) | — | Same image as gateway |

An OAuth2 client for the agent is inserted into the CRM on first boot, so the skill can authenticate with zero manual setup. Client ID and secret are in `.env`.

## Run your first skill

Open an agent session inside the stack:

```bash
docker compose --profile cli run --rm openclaw-cli
```

The `suitecrm` skill is auto-mounted at `/home/node/.openclaw/skills/suitecrm/`, and the agent already has `SUITECRM_URL`, `SUITECRM_CLIENT_ID`, `SUITECRM_CLIENT_SECRET`, `SUITECRM_USER`, and `SUITECRM_PASS` set. Try:

- *"List my accounts."*
- *"Create a lead named Jane Smith, email jane@acme.com, from Acme Corp."*
- *"Summarise activity on the Acme Corp account over the last 30 days."*

Three worked examples live in [`openclaw/skills/suitecrm/examples/`](openclaw/skills/suitecrm/examples/):

- [summarize-account-activity](openclaw/skills/suitecrm/examples/summarize-account-activity/) — pre-call brief in one shot
- [draft-followup-from-case-note](openclaw/skills/suitecrm/examples/draft-followup-from-case-note/) — assemble the inputs for a support follow-up
- [flag-stale-accounts](openclaw/skills/suitecrm/examples/flag-stale-accounts/) — weekly hygiene report

Each is a plain walkthrough with the exact `curl` + `jq` calls, copy-paste runnable.

## Smoke-test the API without the agent

```bash
set -a && source .env && set +a

TOKEN=$(curl -s -X POST "$SITE_URL/Api/access_token" \
  -d "grant_type=password" \
  -d "client_id=$OAUTH2_CLIENT_ID" \
  -d "client_secret=$OAUTH2_CLIENT_SECRET" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" | jq -r '.access_token')

curl -s "$SITE_URL/Api/V8/meta/modules" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.api+json" | jq '.data | keys | .[0:10]'
```

You should see a list of module names — `Accounts`, `Contacts`, `Leads`, etc. If you get a 401, regenerate the OAuth2 secret, rewrite `.env`, and restart: `docker compose restart suitecrm openclaw-gateway`.

## Add your own skill

The gateway mounts `./openclaw/skills/` into the container as read-only. To add a new skill, drop a folder in there and restart the gateway:

```
openclaw/skills/
├── suitecrm/                    # included
│   ├── SKILL.md
│   ├── references/modules.md
│   └── examples/...
└── your-skill/                  # add this
    ├── SKILL.md                 # required — frontmatter + prose
    └── references/*.md          # optional
```

Minimal `SKILL.md` template:

```markdown
---
name: your-skill
description: One sentence on what it does and when the agent should reach for it.
metadata:
  openclaw:
    requires:
      bins: ["curl", "jq"]
      env: ["YOUR_API_URL", "YOUR_API_KEY"]
---

# Your Skill

Explain how to authenticate, the base URL, and the 3–5 most useful operations as copy-pasteable commands. Keep it short — the agent reads this every time it uses the skill.
```

Add the env vars to `.env` and `docker-compose.yml` under the `openclaw-gateway` service, then:

```bash
docker compose restart openclaw-gateway
```

See the [SuiteCRM skill](openclaw/skills/suitecrm/SKILL.md) for a real example to copy from.

## Project layout

```
.
├── docker-compose.yml              # build-from-source, default
├── docker-compose.prebuilt.yml     # pulls pre-built images from GHCR
├── .env.example
├── Caddyfile
├── suitecrm/
│   ├── Dockerfile
│   └── entrypoint.sh               # Installs CRM, generates OAuth2 keys, seeds client
├── config/
│   ├── apache-vhost.conf
│   └── php.ini
├── openclaw/
│   ├── Dockerfile                  # Extends ghcr.io/openclaw/openclaw with jq + curl
│   └── skills/
│       └── suitecrm/
│           ├── SKILL.md
│           ├── references/modules.md
│           └── examples/
│               ├── summarize-account-activity/
│               ├── draft-followup-from-case-note/
│               └── flag-stale-accounts/
└── .github/
    └── workflows/release.yml       # Builds + pushes images to GHCR on tag
```

## Common ops

```bash
# Stop everything
docker compose down

# Full reset (deletes CRM data)
docker compose down -v

# Rebuild images after editing Dockerfiles
docker compose up -d --build

# Shell into a service
docker exec -it suitecrm-app bash
docker exec -it openclaw-gateway bash
```

## Gotchas

- **Host ports 8080 / 8443 already in use**: set `HTTP_PORT` and `HTTPS_PORT` in `.env` to free ports, then update `SITE_URL` to match (`http://localhost:<new-port>`).
- **Special characters in `ADMIN_PASS`**: `!`, `&`, `=` break the password-grant OAuth2 flow. Stick to alphanumerics.
- **First boot is slow**: the silent SuiteCRM installer creates ~300 tables and warms the Symfony cache. Watch with `docker compose logs -f suitecrm`.
- **Admin password changed via the UI and the skill stops working**: update `ADMIN_PASS` in `.env` and `docker compose restart openclaw-gateway`, or keep using the original.
- **Default OAuth2 secret is a placeholder**: `.env.example` ships with a well-known secret. Regenerate it with `openssl rand -hex 32` before exposing the stack to anything other than your laptop.

## Background

Long-form on why this exists and how it fits a broader CRM-as-process approach: <https://www.aakeeo.com/blog/openclaw-suitecrm-integration>.

If you need a production SuiteCRM 8 implementation, custom modules, or an integration built into an existing stack, Aakeeo Technologies builds and supports these in healthcare, logistics, and financial services. Services: <https://www.aakeeo.com/services/suitecrm-implementation>.

## Licence

MIT. SuiteCRM itself is AGPL-3.0 — see <https://github.com/salesagility/SuiteCRM-Core>.
