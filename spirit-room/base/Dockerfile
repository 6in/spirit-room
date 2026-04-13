FROM ubuntu:24.04
LABEL maintainer="spirit-room"
LABEL description="精神と時の部屋 - ベースイメージ"

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20

# ── レイヤー1: 基本パッケージ ────────────────────────────────
RUN apt-get update && apt-get install -y \
    curl wget git vim nano unzip \
    openssh-server tmux \
    python3 python3-pip python3-venv \
    build-essential \
    ca-certificates gnupg \
    jq tree \
    sqlite3 libsqlite3-dev \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# ── レイヤー2: Node.js ───────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── レイヤー3: Bun ───────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# ── レイヤー4: Claude Code ───────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── レイヤー5: opencode ──────────────────────────────────────
RUN npm install -g opencode-ai

# ── SSH設定 ─────────────────────────────────────────────────
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ── スクリプト・デフォルトcatalogをイメージに焼き込む ─────────
# /workspace はマウントポイント、/room は部屋の共有リソース
RUN mkdir -p /workspace /room /logs

COPY entrypoint.sh          /entrypoint.sh
COPY scripts/               /room/scripts/
COPY catalog.md             /room/catalog.md

RUN chmod +x /entrypoint.sh /room/scripts/*.sh \
    && ln -s /room/scripts/start-training.sh /usr/local/bin/start-training \
    && ln -s /room/scripts/status.sh         /usr/local/bin/status

EXPOSE 22
WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
