# moneybot-sandbox — isolated build/test environment for UNTRUSTED bounty/competition code.
#
# Security contract (do not weaken):
#   • NO secrets are ever baked in here or passed in at runtime. The wrapper (scripts/sandbox-run.sh)
#     starts this with a cleared environment and mounts ONLY the repo's work/ dir at /work.
#   • The agent runs everything dev-related INSIDE this box with generous permissions; a trashed
#     container costs nothing (docker rm + rebuild).
#   • The host keeps the tokens, the ledger, git, and every money/identity action. Those never enter here.
#
# Rebuild after editing:  scripts/sandbox-build.sh   (that also removes the running container so the
# next sandbox-run picks up the new image).
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Generous, world-accessible toolchain (apt installs land in /usr/bin, /usr/lib — readable by any uid,
# which matters because the container runs as the HOST user so build artifacts stay editable on the host).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client \
      build-essential cmake pkg-config \
      python3 python3-pip python3-venv python3-dev \
      nodejs npm \
      golang-go \
    && rm -rf /var/lib/apt/lists/*

# uv / uvx (fast Python package+env manager — the tool that started this). Copy into a world-accessible
# bin so the non-root host user can execute it.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && cp /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/ \
    && chmod a+rx /usr/local/bin/uv /usr/local/bin/uvx

# NOTE: add rust here if a bounty needs it (kept out of v1 to stay lean):
#   ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
#   RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path \
#       && chmod -R a+rX /opt/rustup /opt/cargo
#   ENV PATH="/opt/cargo/bin:${PATH}"
# ...then rebuild (scripts/sandbox-build.sh). Adding a toolchain is a HUMAN edit (rule 7), not the agent's.

WORKDIR /work
