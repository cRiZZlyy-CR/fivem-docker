# FiveM server image.
# Set FXSERVER_VERSION to a build id from the FiveM Linux artifacts server.
# Look up the current "recommended" / "latest" build ids here:
#   https://changelogs-live.fivem.net/api/changelog/versions/linux/server
#   https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/

# Base image is configurable (default debian:bookworm-slim). The FiveM artifacts
# bundle their own musl loader + libs, so the host distro only provides glibc to
# the thin wrapper tools below — debian:trixie-slim works equally well.
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG FXSERVER_VERSION
RUN test -n "$FXSERVER_VERSION" || { \
      echo "ERROR: FXSERVER_VERSION build-arg is required (FiveM Linux artifacts build id)."; \
      echo "See https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"; \
      exit 1; \
    }

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Download + extract the artifacts into /opt/cfx-server.
WORKDIR /opt/cfx-server
RUN curl -fSL "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FXSERVER_VERSION}/fx.tar.xz" -o /tmp/fx.tar.xz \
 && tar -xJf /tmp/fx.tar.xz -C /opt/cfx-server \
 && rm /tmp/fx.tar.xz

# server.cfg + resources/ are bind-mounted here by docker-compose at runtime.
WORKDIR /server-data
EXPOSE 30120/tcp
EXPOSE 30120/udp
EXPOSE 40120/tcp

# No "+exec server.cfg" → run.sh boots txAdmin, which manages the game server.
CMD ["bash", "-c", "exec /opt/cfx-server/run.sh"]
