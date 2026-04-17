FROM ubuntu:24.04
LABEL maintainer="spirit-room"
LABEL description="精神と時の部屋 - ベースイメージ"

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20

# ── レイヤー1: 基本パッケージ ────────────────────────────────
RUN apt-get update && apt-get install -y \
    curl wget git vim nano unzip less \
    openssh-server tmux \
    python3 python3-pip python3-venv pipx \
    build-essential \
    sudo \
    ca-certificates gnupg \
    jq tree \
    sqlite3 libsqlite3-dev \
    redis-server \
    ripgrep fd-find fzf bat \
    httpie shellcheck \
    htop ncdu lsof \
    dnsutils iputils-ping netcat-openbsd \
    xz-utils zip p7zip-full \
    git-delta \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ── レイヤー1.5: 追加ツール（apt にないもの） ────────────────
# yq (Go版): apt に古いPython版があるため公式バイナリで導入
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# uv (Astral社の高速 Python パッケージマネージャー)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true

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
# root の chpasswd は残す (entrypoint で sudo 経由の管理用途に root を保持するが SSH ログインは禁止)。
# goku のパスワード設定と UID 割当は entrypoint.sh 側でランタイム処理 (HOST_UID がホストごとに異なるため)。
# HIGH-01 対応: Ubuntu 24.04 ベースイメージには uid=1000/gid=1000 の 'ubuntu' ユーザーがデフォルトで存在する。
# HOST_UID=1000 (Linux 一般ユーザーの最頻値) だと useradd -o で UID 重複しつつ goku が作られ、
# getpwuid(1000) が 'ubuntu' を返す等の name-resolution 混乱が起こるため、ビルド時に ubuntu を削除しておく。
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && (userdel -r ubuntu 2>/dev/null || true) \
    && (groupdel ubuntu 2>/dev/null || true)

# ── Git 設定 ─────────────────────────────────────────────────
# /workspace はホストからマウントされるため所有権が root と一致しない。
# git の dubious ownership エラーを回避するため全ディレクトリを safe に設定。
RUN git config --global --add safe.directory '*' \
    && git config --global user.email 'spirit-room@localhost' \
    && git config --global user.name 'Spirit Room' \
    && git config --global init.defaultBranch main

# ── スクリプト・デフォルトcatalogをイメージに焼き込む ─────────
# /workspace はマウントポイント、/room は部屋の共有リソース
RUN mkdir -p /workspace /room /logs

COPY entrypoint.sh          /entrypoint.sh
COPY scripts/               /room/scripts/
COPY catalog.md             /room/catalog.md
COPY CLAUDE.md              /room/CLAUDE.md
COPY skills/                /room/skills/

RUN chmod +x /entrypoint.sh /room/scripts/*.sh \
    && ln -s /room/scripts/start-training.sh      /usr/local/bin/start-training \
    && ln -s /room/scripts/start-training-kaio.sh /usr/local/bin/start-training-kaio \
    && ln -s /room/scripts/status.sh              /usr/local/bin/status

EXPOSE 22
WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
