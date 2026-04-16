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

# ── 界王星モード: CLAUDE_CONFIG_DIR 分岐 ─────────────────────
# CLAUDE_CONFIG_DIR が設定されている = 界王星モード。
# 共有認証ボリュームは /root/.claude-shared にマウントされている前提 (spirit-room kaio 側で -v 指定)。
# その中の .credentials.json を $CLAUDE_CONFIG_DIR/.credentials.json に symlink することで、
# トークンリフレッシュが共有ボリュームに戻り、他の部屋にも伝播する。
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    echo "[INFO] 界王星モード: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    if [ -f /root/.claude-shared/.credentials.json ]; then
        ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
        echo "[INFO] 認証情報を symlink: $CLAUDE_CONFIG_DIR/.credentials.json → /root/.claude-shared/.credentials.json"
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

# ── tmuxセッション ───────────────────────────────────────────
SESSION="spirit-room"
tmux new-session -d -s "$SESSION" -x 220 -y 50

tmux rename-window -t "$SESSION:0" "training"
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]; then
    # 界王星モード: GSD 駆動チェーン
    tmux send-keys -t "$SESSION:training" "start-training-kaio" C-m
elif [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    # 精神と時の部屋モード (既存)
    tmux send-keys -t "$SESSION:training" "start-training" C-m
else
    tmux send-keys -t "$SESSION:training" \
        "echo '部屋[$ROOM_NAME] 準備完了 | start-training(-kaio) で修行開始 | status で確認'" C-m
fi

tmux new-window -t "$SESSION" -n "logs"
tmux send-keys -t "$SESSION:logs" \
    "tail -f /workspace/.logs/progress.log 2>/dev/null || (echo 'ログ待機中...'; while true; do sleep 2; tail -f /workspace/.logs/progress.log 2>/dev/null && break; done)" C-m

tmux new-window -t "$SESSION" -n "workspace"
tmux send-keys -t "$SESSION:workspace" \
    "watch -n 2 'tree /workspace -L 3 -I .logs 2>/dev/null || ls -la /workspace'" C-m

tmux select-window -t "$SESSION:training"

echo "[INFO] tmux '$SESSION' 起動完了"
echo "[INFO] 接続: tmux attach -t $SESSION"

tail -f /dev/null
