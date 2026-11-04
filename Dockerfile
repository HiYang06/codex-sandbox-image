# syntax=docker/dockerfile:1.7

ARG CODEX_VERSION=0.164.0

FROM --platform=$BUILDPLATFORM curlimages/curl:8.12.1@sha256:94e9e444bcba979c2ea12e27ae39bee4cd10bc7041a472c4727a558e213744e6 AS codex-download

ARG TARGETOS
ARG TARGETARCH
ARG CODEX_VERSION
ARG CODEX_SHA256_AMD64=3ec55053109608d5038f7e50750f7d25f768dfd740fef071aa710e2559b63aac

RUN set -eu; \
    if [ "${TARGETOS}/${TARGETARCH}" != "linux/amd64" ]; then \
        echo "Codex sandbox images only support linux/amd64" >&2; exit 1; \
    fi; \
    archive="/tmp/codex-package-amd64.tar.gz"; \
    url="https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-package-x86_64-unknown-linux-musl.tar.gz"; \
    curl --fail --location --silent --show-error --output "${archive}" "${url}"; \
    printf '%s  %s\n' "${CODEX_SHA256_AMD64}" "${archive}" | sha256sum -c -; \
    mkdir -p /tmp/out; \
    tar -xzf "${archive}" -C /tmp/out bin/codex bin/codex-code-mode-host; \
    test -x /tmp/out/bin/codex; \
    test -x /tmp/out/bin/codex-code-mode-host

FROM debian:bookworm-slim@sha256:df52e55e3361a81ac1bead266f3373ee55d29aa50cf0975d440c2be3483d8ed3

RUN --mount=type=tmpfs,target=/var/lib/apt/lists \
    apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates \
    && useradd --create-home --user-group --shell /bin/bash user \
    && install -d -o user -g user /home/user/inspectgo

COPY --from=codex-download --chown=0:0 /tmp/out/bin/codex /usr/local/bin/codex
COPY --from=codex-download --chown=0:0 /tmp/out/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host

WORKDIR /home/user
CMD ["/bin/bash"]
