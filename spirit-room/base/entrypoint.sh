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
tmux send-keys -t "$SESSION:training" \
    "echo '部屋[$ROOM_NAME] 準備完了 | start-training で修行開始 | status で確認'" C-m

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
