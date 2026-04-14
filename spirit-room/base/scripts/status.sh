#!/bin/bash

ROOM_NAME="${ROOM_NAME:-$(basename /workspace)}"

echo "
╔══════════════════════════════════════════════╗
║  Spirit Room [$ROOM_NAME]
╚══════════════════════════════════════════════╝
"

echo "── MISSION ──────────────────────────────────"
if [ -f /workspace/MISSION.md ]; then
    grep -E "^#|^\- \[" /workspace/MISSION.md | head -20
else
    echo "MISSION.mdなし"
fi

echo ""
echo "── ワークスペース ───────────────────────────"
tree /workspace -L 2 -I ".logs" 2>/dev/null || ls -la /workspace

echo ""
echo "── 最新ログ (20行) ──────────────────────────"
tail -20 /workspace/.logs/progress.log 2>/dev/null || echo "ログなし"

echo ""
echo "── 認証状態 ─────────────────────────────────"
claude auth status 2>&1 || echo "未認証"
