# fivem-docker

Dockerized FiveM setup: **FiveM server (txAdmin-managed) + a database**, started entirely via
`docker compose`. The database is **optional and switchable** (PostgreSQL *or* MariaDB, bundled or
external), so the stack drops into an existing ecosystem without forcing a second DB on you.

## What's inside

| Service     | Description |
| ----------- | ----------- |
| `fxserver`  | FiveM server from the official Linux artifacts. Boots into **txAdmin** by default — the game server is managed/started through the txAdmin web panel. Always runs. |
| `postgres`  | PostgreSQL 18 (Alpine). Optional — started only with the `postgres` profile. |
| `mariadb`   | MariaDB 11.8 LTS. Optional — started only with the `mariadb` profile. The DB most off-the-shelf FiveM resources (oxmysql, ESX, QBox…) expect. |

```
.
├── docker-compose.yml          # fxserver + optional postgres / mariadb
├── docker-compose.traefik.yml  # OPT-IN: Traefik reverse proxy + Cloudflare DNS companion
├── docker/fxserver.Dockerfile  # downloads the FiveM Linux artifacts
├── .env.example                # configuration (copy to .env)
└── server-data/                # your server (bind-mounted into the container)
    ├── server.cfg              # managed by txAdmin
    └── resources/[local]/      # drop your resources here (e.g. crizzly)
```

## Choosing a database

The database is selected with **`COMPOSE_PROFILES`** in `.env`. The `fxserver` itself always runs
and has **no hard dependency** on the DB, so you can also bring your own:

| `COMPOSE_PROFILES` | Result |
| ------------------ | ------ |
| `postgres` *(default)* | Start the bundled **PostgreSQL 18**. |
| `mariadb`              | Start the bundled **MariaDB 11.8 LTS** instead (FiveM/oxmysql standard). |
| *(empty)*             | Start **no** bundled DB — point `POSTGRES_HOST` / `MYSQL_HOST` at your existing database. |

> **Using an existing DB in your ecosystem?** Set `COMPOSE_PROFILES=` (empty), put your DB's
> hostname/IP in `POSTGRES_HOST` or `MYSQL_HOST` (plus credentials), and that's it — no duplicate
> database container is created. The fxserver gets `DATABASE_URL` / `MYSQL_CONNECTION_STRING` built
> from those values.

## Quick start

```bash
cp .env.example .env            # 1. configure (set passwords, pick the DB via COMPOSE_PROFILES)
docker compose up -d --build    # 2. build + start everything
```

Then:

1. **Open txAdmin:** <http://localhost:40120>
2. On first run, create an **admin account**.
3. Choose the **"Local" / existing server data** deployment method and point it at `/server-data`
   — txAdmin will detect the `server.cfg`.
4. Enter your **Cfx.re license key** in txAdmin (from <https://portal.cfx.re>). txAdmin stores it in
   `txData`, **not** in `server.cfg`.
5. **Start** the server from txAdmin → it then runs on port **30120** (TCP/UDP).

> The game server (30120) only runs **after** you start it from txAdmin — that's normal txAdmin
> behavior. On the next `docker compose up`, txAdmin auto-starts the server thanks to the persistent
> `txData` volume.

## Configuration (`.env`)

| Variable                | Meaning |
| ----------------------- | ------- |
| `COMPOSE_PROFILES`      | Which bundled DB to start: `postgres`, `mariadb`, or empty (external DB). |
| `FXSERVER_VERSION`      | FiveM Linux artifacts build id. Default = Cfx.re **recommended** build. Look up recommended/latest via the [changelog API](https://changelogs-live.fivem.net/api/changelog/versions/linux/server) or the [folder list](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/). |
| `BASE_IMAGE`            | Base image for the fxserver build (default `debian:bookworm-slim`; `debian:trixie-slim` also works). |
| `POSTGRES_VERSION`      | PostgreSQL image tag (default `18-alpine`). |
| `POSTGRES_*`            | Postgres user / password / db / port. |
| `POSTGRES_HOST`         | DB host the **container** connects to (`postgres` = bundled; or your external host). |
| `MARIADB_VERSION`       | MariaDB image tag (default `11.8` LTS). |
| `MYSQL_*`               | MariaDB user / password / root password / db / port. |
| `MYSQL_HOST`            | DB host the **container** connects to (`mariadb` = bundled; or your external host). |
| `TXADMIN_PORT`          | Host port for the txAdmin panel (default 40120). |
| `GAME_PORT`             | Host port for the game server, TCP+UDP (default 30120). |
| `SERVER_PASSWORD`       | Optional connect password. |
| `DATABASE_URL`          | Host-side connection string for psql/GUI tools (uses `localhost`). Not read by Compose. |
| `TXADMIN_HOST` · `ACME_EMAIL` · `CF_*` | Reverse proxy + Cloudflare settings — only used by `docker-compose.traefik.yml`. See [Reverse proxy (Traefik) + Cloudflare](#reverse-proxy-traefik--cloudflare). |

## Your own resources

Put your resources under `server-data/resources/[local]/<name>/` and enable them with
`ensure <name>` in `server.cfg`. Changes are visible in the container immediately (bind mount) —
a resource `restart` via txAdmin or the server console is enough.

### Connecting a resource to the database

The fxserver container receives two connection strings as env vars (built from your `.env`):

- **`DATABASE_URL`** — `postgresql://<user>:<pass>@<POSTGRES_HOST>:5432/<db>`
- **`MYSQL_CONNECTION_STRING`** — `mysql://<user>:<pass>@<MYSQL_HOST>:3306/<db>?charset=utf8mb4`

Use whichever matches your stack:

- **PostgreSQL, JS server script:** `process.env.DATABASE_URL` (e.g. with the `pg` npm module).
- **PostgreSQL, Lua:** set the URL as a ConVar in `server.cfg` (`set database_url "..."`) and read it
  with `GetConvar('database_url', '')`.
- **MySQL/MariaDB via [oxmysql](https://github.com/overextended/oxmysql):** oxmysql reads the
  `mysql_connection_string` **convar**, so set it in `server.cfg` (host = the service name `mariadb`,
  or your external host):

  ```cfg
  set mysql_connection_string "mysql://fivem:CHANGE_ME@mariadb:3306/fivem?charset=utf8mb4"
  ```

  Keep real credentials out of git — prefer configuring this through txAdmin. If your password
  contains reserved characters (`; , / ? : @ & = + $ #`), use the key=value form instead:
  `set mysql_connection_string "host=mariadb;port=3306;user=fivem;password=CHANGE_ME;database=fivem"`.

## Reverse proxy (Traefik) + Cloudflare

Optional, label-driven integration in **`docker-compose.traefik.yml`**. It adds a **Traefik v3**
reverse proxy and a **Cloudflare DNS companion** (`tiredofit/traefik-cloudflare-companion`) that
auto-creates DNS records from Traefik's `Host()` labels. The base stack is untouched — this file
just layers on top and hands the ports to Traefik.

> **How FiveM behaves behind a proxy/Cloudflare** (this drives the whole design):
>
> | Endpoint | Through Traefik | Through Cloudflare |
> | -------- | --------------- | ------------------ |
> | **txAdmin panel** (HTTP) | ✅ HTTPS via Traefik (Let's Encrypt) | ✅ orange-cloud proxy OK |
> | **Game port 30120** (TCP + UDP/ENet) | ⚠️ L4 forward only | ❌ **never** — DNS-only (grey cloud) |
>
> Cloudflare's proxy/tunnel only carries HTTP/HTTPS, so the **game port must stay direct** (a
> DNS-only A record to the server's real IP). And because Traefik forwards the game port at L4,
> **FXServer sees Traefik's container IP for every player** — if you rely on real player IPs (IP
> bans, rate-limiting, some anticheats), keep the game port published directly (see
> [Panel-only variant](#panel-only-keep-the-game-port-direct) below).

### Setup

1. **Fill in the proxy/Cloudflare block in `.env`** (`TXADMIN_HOST`, `ACME_EMAIL`, `CF_API_TOKEN`,
   `CF_TARGET_DOMAIN`, `CF_DOMAIN`, `CF_ZONE_ID`). The Cloudflare token is a **scoped API token**
   with `Zone:Read` + `DNS:Edit` (template *"Edit zone DNS"*) — reused by both Traefik (for the
   Let's Encrypt DNS-01 challenge) and the companion.

2. **Create the game-port DNS record manually** (the companion only handles HTTP hosts): an
   **A record set to "DNS only" (grey cloud)** pointing at the server's real IP, e.g.
   `play.example.com → <server-ip>`. The panel record (`TXADMIN_HOST`) is created automatically as
   a proxied record.

3. **Start with both files:**

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d --build
   ```

   In Cloudflare, set the panel's SSL/TLS mode to **Full (strict)** — Traefik presents a real
   Let's Encrypt certificate.

> Requires **Docker Compose v2.24+** (the file uses the `!reset` tag to drop the base port
> publishing). Tip: to make a plain `docker compose up` use this stack, set
> `COMPOSE_FILE=docker-compose.yml:docker-compose.traefik.yml` in `.env`.

### What the labels do

| Router (label on `fxserver`) | Entrypoint | Purpose |
| ---------------------------- | ---------- | ------- |
| `txadmin` — HTTP, TLS, `Host()` rule | `websecure` (:443) | txAdmin panel over HTTPS → companion creates its DNS record |
| `fivem-tcp` — TCP, `HostSNI` catch-all | `fivem-tcp` (:30120) | game TCP (connect/info endpoint + stream), raw L4 |
| `fivem-udp` — UDP, no rule | `fivem-udp` (:30120/udp) | game UDP / ENet gameplay, raw L4 |

Only the `txadmin` router has a `Host()` rule, so the companion creates **only** the panel's DNS
record (proxied). The game routers have no hostname — that's why the game DNS record is manual and
grey-cloud.

### Optional `server.cfg` listing ConVars

For the server browser to advertise your public game host (not the container IP), uncomment the
**"Reverse proxy / server listing"** block in [`server-data/server.cfg`](server-data/server.cfg)
and set your game host (`sv_listingHostOverride`, `sv_endpoints`, `sv_forceIndirectListing`,
`sv_proxyIPRanges`).

### Panel-only (keep the game port direct)

If you only want the **txAdmin panel** behind Traefik/Cloudflare and prefer the game port published
straight to the host (recommended when you need real player IPs), delete the three game-port pieces
from `docker-compose.traefik.yml` — the `fivem-tcp` / `fivem-udp` entrypoints (in Traefik's
`command`), their `30120` `ports:` lines on the `traefik` service, and the `traefik.tcp.*` /
`traefik.udp.*` labels on `fxserver` — and change the `fxserver` port reset to republish just the
game port directly (`!override` replaces the base list, so the txAdmin port stays Traefik-only):

```yaml
  fxserver:
    ports: !override
      - "${GAME_PORT:-30120}:30120/tcp"
      - "${GAME_PORT:-30120}:30120/udp"
```

## Platform support

The **same `docker compose up` works on Windows and Linux automatically** — Docker runs the
container as Linux/amd64 either way. Requirement: an **x86_64 (amd64)** host, since FiveM's server
is x86_64-only.

| Host                                  | Status                 | Notes |
| ------------------------------------- | ---------------------- | ----- |
| **Linux** x86_64 (VPS/server)         | ✅ works (recommended)  | Native, fastest, most stable. |
| **Windows** (x86_64) + Docker Desktop | ✅ works automatically  | `docker compose up` runs the amd64 Linux container in Docker's VM. |

Nothing to configure on either — the `platform: linux/amd64` pin in `docker-compose.yml` handles it.

## Useful commands

```bash
docker compose up -d --build              # build + start (uses COMPOSE_PROFILES from .env)
docker compose --profile mariadb up -d    # one-off: start with MariaDB regardless of .env
docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d --build  # + Traefik & Cloudflare
docker compose logs -f fxserver           # server logs
docker compose ps                         # status
docker compose down                       # stop (volumes/data preserved)
docker compose down -v                    # stop + delete ALL data (DB + txData)
docker compose up -d --build fxserver     # rebuild after changing FXSERVER_VERSION / BASE_IMAGE
```
