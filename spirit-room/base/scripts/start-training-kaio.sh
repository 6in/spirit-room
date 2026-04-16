#!/bin/bash
set -e

# ════════════════════════════════════════════════════════
# 界王星モード training loop
# 重力10倍の環境で GSD ワークフローを非対話に回す
# ════════════════════════════════════════════════════════

LOG_DIR="/workspace/.logs"
LOG_FILE="$LOG_DIR/progress.log"
MISSION_FILE="/workspace/KAIO-MISSION.md"
PREPARED_FLAG="/workspace/.kaio-prepared"
DONE_FLAG="/workspace/.kaio-done"

# CLAUDE_CONFIG_DIR は entrypoint で設定されている前提。念のため default を用意
: "${CLAUDE_CONFIG_DIR:=/workspace/.claude-home}"
export CLAUDE_CONFIG_DIR

mkdir -p "$LOG_DIR" "$CLAUDE_CONFIG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ── KAIO-MISSION.md 存在確認 ─────────────────────────────
if [ ! -f "$MISSION_FILE" ]; then
    log "[ERROR] KAIO-MISSION.md が見つからない: $MISSION_FILE"
    log "  テンプレート: /room/scripts/KAIO-MISSION.md.template"
    exit 1
fi

log "╔══════════════════════════════════════════════╗"
log "║           界王星モード 修行開始             ║"
log "║        CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
log "╚══════════════════════════════════════════════╝"

# ════════════════════════════════════════════════════════
# PHASE KAIO-1: GSD インストール (idempotent)
# ════════════════════════════════════════════════════════
log "=== 界王星 PHASE 1: GSD セットアップ ==="
if [ -f "$PREPARED_FLAG" ]; then
    log "GSD セットアップ済、スキップ"
else
    log "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR に GSD をインストール中..."
    # get-shit-done-cc は runtime 選択の対話プロンプトを出す。'1'(Claude Code) を
    # 既定にしつつ、後続プロンプトも全てデフォルトで回すため yes '' で paipe する。
    # `npx -y` はパッケージ取得の確認だけで、インストーラ本体の質問には効かない。
    yes '' | CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx -y get-shit-done-cc@latest 2>&1 | tee -a "$LOG_FILE" || true

    # 界王星スキルをプロジェクトの .claude/commands/ にインストール
    mkdir -p /workspace/.claude/commands
    cp /room/scripts/create-report.md /workspace/.claude/commands/create-report.md
    log "スキル /create-report インストール完了"

    touch "$PREPARED_FLAG"
    log "GSD セットアップ完了"
fi

# ── ホスト .claude.json から oauthAccount を継承 ──────────────
# GSD インストーラが生成する $CLAUDE_CONFIG_DIR/.claude.json は
# oauthAccount が null で、claude -p が 401 になる。
# ホストから readonly でマウントした /root/.host-claude.json から
# oauthAccount をマージして認証を成立させる。
CLAUDE_JSON="$CLAUDE_CONFIG_DIR/.claude.json"
HOST_CLAUDE_JSON="/root/.host-claude.json"
if [ -f "$HOST_CLAUDE_JSON" ] && [ -f "$CLAUDE_JSON" ]; then
    if jq -e '.oauthAccount' "$CLAUDE_JSON" >/dev/null 2>&1; then
        log "oauthAccount は既に設定済、マージスキップ"
    else
        log "ホスト .claude.json から oauthAccount を継承中..."
        TMP=$(mktemp)
        jq --slurpfile host "$HOST_CLAUDE_JSON" \
            '.oauthAccount = $host[0].oauthAccount' \
            "$CLAUDE_JSON" > "$TMP" && mv "$TMP" "$CLAUDE_JSON"
        log "oauthAccount マージ完了"
    fi
fi

# ════════════════════════════════════════════════════════
# PHASE KAIO-2: 非対話で /gsd-new-project → /gsd-autonomous
# ════════════════════════════════════════════════════════
log "=== 界王星 PHASE 2: GSD 駆動チェーン ==="

while true; do
    [ -f "$DONE_FLAG" ] && { log "修行完了済み"; break; }

    log "claude -p で /gsd-new-project → /gsd-autonomous を非対話起動"

    # POC validated prompt (04-CONTEXT.md specifics セクション原文 + Completion signal 追記)
    # IS_SANDBOX=1: root で bypassPermissions を使うための明示的な許可フラグ
    # (Docker コンテナ内は root 固定なので必須)
    IS_SANDBOX=1 CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" claude \
        --permission-mode bypassPermissions \
        -p "Context: This is a POC verifying whether GSD workflows can run end-to-end without human input, from inside an automated training environment. You are running via 'claude -p' so there is NO human available to answer AskUserQuestion prompts — any question you ask will just block.

Task: Read /workspace/KAIO-MISSION.md. Run /gsd-new-project using the mission content as answers. Then run /gsd-autonomous to completion.

Rules:
- Never ask the user anything. For any question the skill would normally ask, pick the recommended/default answer and keep going.
- Prefer the simplest, shortest path to a completed phase.
- If a step genuinely cannot proceed without input, make the most reasonable assumption, log it in a comment, and continue.

Completion signal: once /gsd-autonomous has produced a git tag (e.g. v1.0) for the completed milestone, write an empty file /workspace/.kaio-done and exit." \
        2>&1 | tee -a "$LOG_FILE"

    if [ -f "$DONE_FLAG" ]; then
        log "界王星修行完了"
        break
    fi

    # タグがあれば完了とみなす (ラッパー保険)
    if (cd /workspace && git tag --list 2>/dev/null | grep -qE '^v[0-9]'); then
        log "git tag 検知、.kaio-done を作成"
        touch "$DONE_FLAG"
        break
    fi

    log "未完了、5秒後にリトライ..."
    sleep 5
done

# ════════════════════════════════════════════════════════
# PHASE KAIO-3: 振り返りレポート
# ════════════════════════════════════════════════════════
log "=== 界王星 PHASE 3: 振り返り (REPORT) ==="

REPORT_FILE="/workspace/REPORT.md"
if [ -f "$REPORT_FILE" ]; then
    log "REPORT.md 既存、スキップ"
else
    log "別セッションで /create-report スキルを実行中..."
    IS_SANDBOX=1 CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" claude \
        --permission-mode bypassPermissions \
        -p "/create-report" \
        2>&1 | tee -a "$LOG_FILE"
    log "REPORT.md 生成完了"
fi

echo "
╔══════════════════════════════════════════════╗
║       界王星修行完了！重力10倍を乗り越えた  ║
║       REPORT.md で振り返りを確認せよ         ║
╚══════════════════════════════════════════════╝
" | tee -a "$LOG_FILE"
