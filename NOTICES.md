# Third-party notices

Everything in this repository — the Dockerfiles, `docker-compose.yml` files, `entrypoint.sh`, the `suitecrm` skill, the worked examples, the Caddy and Apache configs — is released under the MIT licence (see `LICENSE`).

The **Docker images** published from this repository bundle third-party software under different licences. When you pull, run, or redistribute these images, you are subject to those licences for the parts they cover.

## SuiteCRM

- Upstream: <https://github.com/salesagility/SuiteCRM-Core>
- Version bundled: 8.9.2
- Licence: **AGPL-3.0**
- Licence text: <https://github.com/salesagility/SuiteCRM-Core/blob/master/LICENSE.txt>

SuiteCRM is downloaded at image build time from SalesAgility's official GitHub release; no modifications are made. If you run the `ghcr.io/aakeeo/suitecrm-app` image as a network service that users interact with, AGPL-3.0 requires you to make the complete corresponding source available to those users. The upstream source satisfies that requirement as long as you run an unmodified SuiteCRM; if you fork or patch SuiteCRM, you must publish your changes under AGPL-3.0 as well.

## OpenClaw

- Upstream: <https://github.com/openclaw/openclaw>
- Base image: `ghcr.io/openclaw/openclaw:latest`
- Licence: see upstream repository

The `ghcr.io/aakeeo/openclaw-suitecrm-agent` image is a thin layer on top of the upstream OpenClaw image that adds `jq` and `curl`. Consult the upstream repository for the applicable licence.

## Other third-party components in the images

- PHP (`php:8.2-apache-bookworm`) — The PHP License, plus the Debian base
- MariaDB 10.11 — GPL-2.0
- Caddy 2 — Apache-2.0
- Various PHP extensions and system libraries — their respective licences

These are standard Debian and upstream images pulled unmodified.
