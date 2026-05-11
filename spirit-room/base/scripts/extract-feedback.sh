#!/bin/bash
# extract-feedback.sh - REPORT.md の YAML frontmatter を抽出し Mr.ポポ memory に保存する
#
# Phase 7 の D-04/D-05/D-06 実装。部屋完了時に start-training.sh から呼ばれる。
# yq で frontmatter をパースし、mission_type に応じたディレクトリに保存する。
# パース失敗や frontmatter 欠落時は WARN ログのみで正常終了する (部屋の終了フローは止めない)。
#
# 前提: yq は mikefarah 版 Go yq v4+ (https://github.com/mikefarah/yq)
#       Python kislyuk 版 (https://github.com/kislyuk/yq) は非サポート。
#       構文・出力フォーマットが異なるため、Dockerfile で固定バージョンをインストールすること。

set -u  # set -e は付けない (yq 失敗等でも部屋終了フローは続行させたい)

LOG_DIR="/workspace/.logs"
LOG_FILE="$LOG_DIR/progress.log"
REPORT_FILE="/workspace/REPORT.md"
MEMORY_BASE="/workspace/.planning/mr-popo-memory"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [extract-feedback] $*" | tee -a "$LOG_FILE"; }

# ── ガード: REPORT.md が無ければ何もしない ─────────────
if [ ! -f "$REPORT_FILE" ]; then
    log "[WARN] REPORT.md が見つからない — feedback 抽出スキップ"
    exit 0
fi

# ── frontmatter ブロックだけ切り出す ────────────────────
# WR-03: 閉じ `---` が無い壊れた REPORT.md では awk が本文まで全部拾ってしまうため、
# 先に閉じ `---` の存在を grep で確認してから抽出する。
CLOSE_COUNT=$(grep -c '^---$' "$REPORT_FILE" 2>/dev/null || echo 0)
if [ "${CLOSE_COUNT:-0}" -lt 2 ]; then
    log "[WARN] REPORT.md の frontmatter が閉じていない (--- が ${CLOSE_COUNT} 回のみ) — feedback 抽出スキップ"
    exit 0
fi

# awk で最初の --- と 2 番目の --- の間を出力 (YAML 本体のみ、--- 自体は含まない)
FRONTMATTER=$(awk '/^---$/{c++; if(c==2) exit; next} c==1' "$REPORT_FILE")

if [ -z "$FRONTMATTER" ]; then
    log "[WARN] REPORT.md に YAML frontmatter が見つからない — feedback 抽出スキップ"
    exit 0
fi

# ── yq でフィールド抽出 (失敗時も継続、値は空になる) ────
# WR-02/IN-06 対策:
#   - yq バイナリ非存在時は防御的に空文字を返す (command not found の stderr 汚染回避)
#   - `echo` の代わりに `printf '%s\n'` を使用 (先頭 -e / -n を誤ってフラグ解釈する事故防止)
_yq() {
    # $1 = yq expression (e.g. '.mission_type')
    # 失敗や null は空文字を返す
    command -v yq >/dev/null 2>&1 || { printf '%s\n' ""; return; }
    local _val
    _val=$(printf '%s\n' "$FRONTMATTER" | yq "$1" 2>/dev/null)
    [ "$_val" = "null" ] && _val=""
    printf '%s\n' "$_val"
}

MISSION_TYPE=$(_yq '.mission_type')
COMPLETION_STATUS=$(_yq '.completion_status')
SCHEMA_VERSION=$(_yq '.feedback_schema_version')

# ── mission_type の正規化 ──────────────────────────────
# 空 / null / 未知の値は unknown ディレクトリにフォールバック
if [ -z "$MISSION_TYPE" ]; then
    MISSION_TYPE="unknown"
fi
# 小文字化 + 英数アンハイフン以外は _ に置換 (パス安全)
MISSION_TYPE=$(echo "$MISSION_TYPE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')

# ── ファイル名組み立て (D-06: {date}-{room-slug}.md) ───
DATE_SLUG=$(date '+%Y-%m-%d')
ROOM_SLUG="${ROOM_NAME:-unknown-room}"
# ROOM_NAME は entrypoint で [^a-zA-Z0-9_-] が _ に正規化済みだが二重で保険
ROOM_SLUG=$(echo "$ROOM_SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')

TARGET_DIR="${MEMORY_BASE}/${MISSION_TYPE}"
mkdir -p "$TARGET_DIR" 2>/dev/null || {
    log "[ERROR] $TARGET_DIR の作成に失敗 — 抽出スキップ"
    exit 0
}

TARGET_FILE="${TARGET_DIR}/${DATE_SLUG}-${ROOM_SLUG}.md"

# ── 同名衝突時は -02 / -03 ... と suffix を付ける ──────
_n=2
while [ -e "$TARGET_FILE" ]; do
    TARGET_FILE="${TARGET_DIR}/${DATE_SLUG}-${ROOM_SLUG}-$(printf '%02d' $_n).md"
    _n=$((_n + 1))
    if [ "$_n" -gt 99 ]; then
        log "[ERROR] 同名ファイル衝突が 99 を超えた — 抽出スキップ"
        exit 0
    fi
done

# ── 保存ファイル本体を生成 (D-06 ヘッダ付き) ───────────
{
    echo "# Mr.ポポ feedback memory"
    echo ""
    echo "- **Room:** ${ROOM_SLUG}"
    echo "- **Date:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- **mission_type:** ${MISSION_TYPE}"
    echo "- **completion_status:** ${COMPLETION_STATUS:-unknown}"
    echo "- **feedback_schema_version:** ${SCHEMA_VERSION:-unknown}"
    echo "- **Source:** /workspace/REPORT.md (at extraction time, room=${ROOM_SLUG})"
    # Review status: pending は Plan 07-05 のレビューコマンドが applied に書き換える機械可読キー。
    # 太字マーカー無しで検索しやすく書く (sed 's/^- Review status: pending/- Review status: applied/')。
    echo "- Review status: pending"
    echo ""
    echo "## Feedback YAML (抽出結果)"
    echo ""
    echo '```yaml'
    # IN-06: `echo "$FRONTMATTER"` は先頭行が `-e` / `-n` で始まるとフラグ解釈される
    # 可能性があるため printf に統一 (YAML 先頭にそんな値が来る可能性は極小だが防御的に)。
    printf '%s\n' "$FRONTMATTER"
    echo '```'
} > "$TARGET_FILE" 2>/dev/null || {
    log "[ERROR] $TARGET_FILE への書き込み失敗"
    exit 0
}

log "[INFO] feedback を保存: $TARGET_FILE (mission_type=${MISSION_TYPE}, status=${COMPLETION_STATUS:-unknown})"

exit 0
