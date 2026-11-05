# syntax=docker/dockerfile:1
#
# Ergo's translation server, with Claude Code and Codex. The build context is the repository root, since it needs ../ErgoKit:
#
#   docker build -f ErgoServer/Dockerfile -t ergo-server .
#   docker run -p 8080:8080 -v ergo-data:/data ergo-server
#
# Two users: the server runs as `ergo`, and every CLI call runs as `ergo-runner`, which can't read /data.
# The server starts with three capabilities (setuid, setgid, chown) so it can switch to the runner with setpriv,
# and hand each run directory over with chown before the call and take it back afterwards.

ARG SWIFT_IMAGE=swift:6.4-noble
ARG RUN_IMAGE=ubuntu:noble

# MARK: - Build

FROM ${SWIFT_IMAGE} AS build
WORKDIR /src

COPY ErgoKit/ ErgoKit/
COPY ErgoServer/Package.swift ErgoServer/Package.resolved ErgoServer/
RUN cd ErgoServer && swift package resolve

COPY ErgoServer/ ErgoServer/
RUN cd ErgoServer \
	&& swift build -c release --product ErgoServer --static-swift-stdlib \
	&& bin="$(swift build -c release --show-bin-path)" \
	&& mkdir /staging \
	&& cp "$bin/ErgoServer" /staging/ \
	&& find "$bin" -maxdepth 1 -name '*.resources' -exec cp -R {} /staging/ \;

# MARK: - Run

FROM ${RUN_IMAGE}
ARG CLAUDE_CODE_VERSION=2.1.311
ARG CODEX_VERSION=0.166.0

# util-linux is setpriv
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates tzdata util-linux nodejs npm \
	&& npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" "@openai/codex@${CODEX_VERSION}" \
	&& npm cache clean --force \
	&& rm -rf /var/lib/apt/lists/*

RUN groupadd --system ergo \
	&& useradd --system --gid ergo --home-dir /data --shell /usr/sbin/nologin ergo \
	&& groupadd --system ergo-runner \
	&& useradd --system --gid ergo-runner --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin ergo-runner \
	&& mkdir -p /data /runs \
	&& chown ergo:ergo /data /runs \
	&& chmod 0700 /data \
	&& chmod 0711 /runs

WORKDIR /app
COPY --from=build /staging /app

# The key file is made by hand, 0600 and owned by ergo:
#   head -c 32 /dev/urandom | base64 > /data/vault.key
ENV ERGO_DATABASE_PATH=/data/ergo.sqlite \
	ERGO_VAULT_KEY_FILE=/data/vault.key \
	ERGO_RUNS_DIRECTORY=/runs \
	ERGO_CLAUDE_PATH=/usr/local/bin/claude \
	ERGO_CODEX_PATH=/usr/local/bin/codex \
	ERGO_RUNNER_USER=ergo-runner \
	ERGO_RUNNER_PREFIX="/usr/bin/setpriv --reuid=ergo-runner --regid=ergo-runner --clear-groups --inh-caps=-all --ambient-caps=-all --no-new-privs --"

VOLUME /data
EXPOSE 8080

# Root only long enough to drop to ergo, keeping just the three capabilities the runner switch needs
ENTRYPOINT [ \
	"/usr/bin/setpriv", "--reuid=ergo", "--regid=ergo", "--init-groups", \
	"--inh-caps=-all,+setuid,+setgid,+chown", "--ambient-caps=-all,+setuid,+setgid,+chown", \
	"--bounding-set=-all,+setuid,+setgid,+chown", \
	"--", "/app/ErgoServer" \
]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
