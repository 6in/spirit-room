#!/bin/bash
set -e

ROOM_NAME="${ROOM_NAME:-$(basename /workspace)}"

echo "
╔══════════════════════════════════════════════╗
║         精神と時の部屋 - Spirit Room         ║
║  部屋: $ROOM_NAME
╚══════════════════════════════════════════════╝
"

# ── サービス起動 ─────────────────────────────────────────────
service ssh start
service redis-server start
echo "[INFO] Redis起動完了"

# ── HOST_UID/GID 受け取り (fallback: 1000:1000) ─────────────
# 手動 docker run や CI 経由で HOST_UID/GID が渡されない場合も落ちないようにする。
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
echo "[INFO] HOST_UID/GID=${HOST_UID}:${HOST_GID}"

# ── goku ユーザーの冪等作成 ─────────────────────────────────
# D-01: ビルド時ではなくランタイムで作る (HOST_UID がホストごとに異なるため)
# D-02: 冪等。既に goku が居れば skip。GID も既存 group がなければ作る
# D-04: パスワードは root と同じ spiritroom
# D-05: NOPASSWD:ALL の sudo を付与 (POC 用途のため粒度は絞らない)
# useradd の -o は UID 重複許可 (既存ユーザー _apt 等と HOST_UID が衝突した場合の保険)
if ! id goku &>/dev/null; then
    getent group "$HOST_GID" >/dev/null || groupadd -g "$HOST_GID" goku
    useradd -m -u "$HOST_UID" -g "$HOST_GID" -s /bin/bash -o goku
    echo 'goku:spiritroom' | chpasswd
    echo 'goku ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/goku
    chmod 0440 /etc/sudoers.d/goku
    echo "[INFO] goku ユーザーを作成 (UID=$HOST_UID GID=$HOST_GID)"
else
    echo "[INFO] goku ユーザーは既に存在 (skip)"
fi

# ── 認証ボリュームと /workspace を goku 所有に ───────────────
# D-10/D-11: 起動ごとに chown を走らせ、既存の root 所有ファイルを一度で正常化する
# 対象: 認証ボリュームのマウント先 (通常モード: /root/.claude、kaio モード: /root/.claude-shared、opencode: /root/.config/opencode) および /workspace 本体
chown -R "$HOST_UID:$HOST_GID" /root/.claude 2>/dev/null || true
chown -R "$HOST_UID:$HOST_GID" /root/.config/opencode 2>/dev/null || true
[ -d /root/.claude-shared ] && chown -R "$HOST_UID:$HOST_GID" /root/.claude-shared 2>/dev/null || true
chown -R "$HOST_UID:$HOST_GID" /workspace 2>/dev/null || true
echo "[INFO] /workspace と認証ボリュームを $HOST_UID:$HOST_GID 所有に切替"

# ── 界王星モード: CLAUDE_CONFIG_DIR 分岐 ─────────────────────
# CLAUDE_CONFIG_DIR が設定されている = 界王星モード。
# 共有認証ボリュームは /root/.claude-shared にマウントされている前提 (spirit-room kaio 側で -v 指定)。
# その中の .credentials.json を $CLAUDE_CONFIG_DIR/.credentials.json に symlink することで、
# トークンリフレッシュが共有ボリュームに戻り、他の部屋にも伝播する。
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    echo "[INFO] 界王星モード: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"
    # D-13: CLAUDE_CONFIG_DIR 自身も goku 所有にする (/workspace 下なので整合)
    chown "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR" 2>/dev/null || true

    if [ -f /root/.claude-shared/.credentials.json ]; then
        ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
        # D-14: symlink 自体の所有者を goku に (chown -h)。実体ファイルは上の chown -R /root/.claude-shared で既に goku 所有
        chown -h "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR/.credentials.json" 2>/dev/null || true
        echo "[INFO] 認証情報を symlink: $CLAUDE_CONFIG_DIR/.credentials.json → /root/.claude-shared/.credentials.json (goku 所有)"
    else
        echo "[WARN] /root/.claude-shared/.credentials.json が見つからない。spirit-room auth を実行せよ"
    fi
fi

# ── 認証チェック ─────────────────────────────────────────────
if ! claude auth status &>/dev/null 2>&1; then
    echo "
╔══════════════════════════════════════════════╗
║  未認証: SSH接続後に以下を実行してください   ║
║  $ claude auth login                         ║
╚══════════════════════════════════════════════╝
"
else
    echo "[INFO] Claude Code 認証済み"
fi

# ── catalog.mdの優先順位: /workspace > /room ─────────────────
if [ -f /workspace/catalog.md ]; then
    echo "[INFO] catalog.md: /workspace/catalog.md を使用"
else
    echo "[INFO] catalog.md: デフォルト(/room/catalog.md)を使用"
fi

# ── goku として git config (goku HOME に root 側と同じ設定をミラー) ─
# D-12: Dockerfile L58-64 の root 用 git config はそのまま。goku HOME 側にも
# safe.directory='*' / user.email / user.name / init.defaultBranch を設定し、
# start-training.sh が goku で走っても dubious ownership エラーを出さないようにする。
su - goku -c "git config --global --add safe.directory '*' && \
    git config --global user.email 'spirit-room@localhost' && \
    git config --global user.name 'Spirit Room' && \
    git config --global init.defaultBranch main" || echo "[WARN] goku 用 git config 設定に失敗"

# ── tmuxセッション (goku として起動) ─────────────────────────
# D-08/D-09 ⑤: tmux は goku として起動。CLAUDE_CONFIG_DIR など環境変数は親 shell で展開して埋め込む
# (su - は login shell のため env が goku デフォルトにリセットされる)
# Pattern B3 L146: bash ではなく bash -s を使う (stdin script を明示的に指示)
SESSION="spirit-room"

# 分岐判定は親 shell (root) 側でフラグ化し、ヒアドキュメント内で展開する
_TRAINING_CMD="echo '部屋[${ROOM_NAME}] 準備完了 | start-training(-kaio) で修行開始 | status で確認'"
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]; then
    _TRAINING_CMD="start-training-kaio"
elif [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    _TRAINING_CMD="start-training"
fi

# kaio モード時は CLAUDE_CONFIG_DIR を goku セッション内でも使えるよう ~/.profile 経由で export
# (su - goku が login shell なので .profile が読まれる。冪等化のため重複追加を避ける)
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    su - goku -c "grep -q 'export CLAUDE_CONFIG_DIR=' ~/.profile 2>/dev/null || echo 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' >> ~/.profile" || true
fi

su - goku -c "bash -s" << EOF
    set -e
    tmux new-session -d -s "${SESSION}" -x 220 -y 50
    tmux rename-window -t "${SESSION}:0" "training"
    tmux send-keys -t "${SESSION}:training" "${_TRAINING_CMD}" C-m

    tmux new-window -t "${SESSION}" -n "logs"
    tmux send-keys -t "${SESSION}:logs" "tail -f /workspace/.logs/progress.log 2>/dev/null || (echo 'ログ待機中...'; while true; do sleep 2; tail -f /workspace/.logs/progress.log 2>/dev/null && break; done)" C-m

    tmux new-window -t "${SESSION}" -n "workspace"
    tmux send-keys -t "${SESSION}:workspace" "watch -n 2 'tree /workspace -L 3 -I .logs 2>/dev/null || ls -la /workspace'" C-m

    tmux select-window -t "${SESSION}:training"
EOF

echo "[INFO] tmux '$SESSION' 起動完了 (user=goku)"
echo "[INFO] 接続: tmux attach -t $SESSION (goku で接続すること)"

tail -f /dev/null
