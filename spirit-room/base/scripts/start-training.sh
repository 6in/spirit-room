#!/bin/bash

ENGINE="${1:-claude}"
LOG_DIR="/workspace/.logs"
LOG_FILE="$LOG_DIR/progress.log"
MISSION_FILE="/workspace/MISSION.md"
PREPARED_FLAG="/workspace/.prepared"
DONE_FLAG="/workspace/.done"

CATALOG_FILE="/workspace/catalog.md"
[ -f "$CATALOG_FILE" ] || CATALOG_FILE="/room/catalog.md"

mkdir -p "$LOG_DIR"

# ── MISSION.mdの存在確認 ─────────────────────────────────────
if [ ! -f "$MISSION_FILE" ]; then
    echo "[ERROR] MISSION.mdが見つかりません: $MISSION_FILE"
    echo "  テンプレート: cat /room/scripts/MISSION.md.template"
    exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

run_claude() {
    local prompt="$1"
    case "$ENGINE" in
        claude)
            claude \
                --dangerously-skip-permissions \
                --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
                -p "$prompt" \
                2>&1 | tee -a "$LOG_FILE"
            ;;
        opencode) opencode -p "$prompt" 2>&1 | tee -a "$LOG_FILE" ;;
    esac
}

# ════════════════════════════════════════════════════════════
# PHASE 1: PREPARE
# ════════════════════════════════════════════════════════════
log "=== PHASE 1: PREPARE ==="

while true; do
    [ -f "$PREPARED_FLAG" ] && { log "PREPARE済み、スキップ"; break; }

    log "PREPARE開始 (engine: $ENGINE)"
    run_claude "$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## あなたのタスク（PREPARE フェーズ）
MISSION.mdを読み、POCの実装に必要なパッケージ・ツールをすべてインストールせよ。
インストールが完了したら /workspace/.prepared ファイルを作成して終了せよ。
まだコードの実装はしなくてよい。"

    [ -f "$PREPARED_FLAG" ] && { log "PREPARE完了"; break; }
    log "PREPARE未完了、リトライ..."
    sleep 3
done

# ════════════════════════════════════════════════════════════
# PHASE 2: TRAINING
# ════════════════════════════════════════════════════════════
log "=== PHASE 2: TRAINING ==="

while true; do
    [ -f "$DONE_FLAG" ] && { log "修行完了済み"; break; }

    log "TRAINING開始 (engine: $ENGINE)"
    run_claude "$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## あなたのタスク（TRAINING フェーズ）
MISSION.mdの完了条件をすべて満たすまで実装・テストを繰り返せ。
完了条件をすべて達成したら /workspace/.done ファイルを作成して終了せよ。

## 繰り返しのルール
1. テストが失敗したらエラーを読んで原因を特定し修正せよ
2. 同じアプローチで2回連続失敗したら別の方法を試みよ
3. 詰まったら /catalog/catalog.md を読んで別ツールを検討せよ
4. 進捗は /workspace/.logs/progress.log に随時記録せよ"

    [ -f "$DONE_FLAG" ] && break
    log "TRAINING未完了、リトライ..."
    sleep 3
done

echo "
╔══════════════════════════════════════════════╗
║              修行完了！部屋から出よ          ║
╚══════════════════════════════════════════════╝
" | tee -a "$LOG_FILE"
