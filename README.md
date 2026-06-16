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
docker compose logs -f fxserver           # server logs
docker compose ps                         # status
docker compose down                       # stop (volumes/data preserved)
docker compose down -v                    # stop + delete ALL data (DB + txData)
docker compose up -d --build fxserver     # rebuild after changing FXSERVER_VERSION / BASE_IMAGE
```
