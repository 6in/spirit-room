#!/bin/bash

ENGINE="${1:-claude}"
LOG_DIR="/workspace/.logs"
LOG_FILE="$LOG_DIR/progress.log"
MISSION_FILE="/workspace/MISSION.md"
RESEARCH_FILE="/workspace/RESEARCH.md"
JOURNAL_FILE="/workspace/.journal.md"
REPORT_FILE="/workspace/REPORT.md"
RESEARCHED_FLAG="/workspace/.researched"
PREPARED_FLAG="/workspace/.prepared"
DONE_FLAG="/workspace/.done"
REPORTED_FLAG="/workspace/.reported"

CATALOG_FILE="/workspace/catalog.md"
[ -f "$CATALOG_FILE" ] || CATALOG_FILE="/room/catalog.md"

CLAUDE_MD="/workspace/CLAUDE.md"
[ -f "$CLAUDE_MD" ] || CLAUDE_MD="/room/CLAUDE.md"

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
    local model="${2:-sonnet}"  # デフォルトは sonnet、明示で opus 指定可
    case "$ENGINE" in
        claude)
            CLAUDE_CODE_BUBBLEWRAP=1 claude \
                --model "$model" \
                --dangerously-skip-permissions \
                --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch" \
                -p "$prompt" \
                2>&1 | tee -a "$LOG_FILE"
            ;;
        opencode) opencode -p "$prompt" 2>&1 | tee -a "$LOG_FILE" ;;
    esac
}

# ── git 初期化（初回のみ） ───────────────────────────────────
init_git_workspace() {
    # /workspace はホストマウントで所有権が root と異なるため safe.directory 必須
    git config --global --add safe.directory '*' 2>/dev/null
    git config --global user.email "spirit-room@localhost" 2>/dev/null
    git config --global user.name "Spirit Room" 2>/dev/null
    git config --global init.defaultBranch main 2>/dev/null

    cd /workspace
    if [ ! -d .git ]; then
        log "git init /workspace"
        git init -q -b main
        cat > .gitignore << 'EOF'
.logs/
.researched
.prepared
.done
.reported
node_modules/
__pycache__/
*.pyc
.venv/
EOF
        git add -A
        git commit -q -m "chore: initial mission" --allow-empty
    fi
}

phase_commit() {
    local msg="$1"
    cd /workspace
    git add -A 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -q -m "$msg" 2>/dev/null || true
    fi
}

init_git_workspace

# ── スキルのローカルインストール ─────────────────────────────
# /workspace/.claude/skills/ にプロジェクトローカルスキルを展開する。
# find-skills が入っていれば、AI が必要に応じて追加スキルを自己発見できる。
if [ -x /room/scripts/install-skills.sh ]; then
    log "スキルインストール開始"
    /room/scripts/install-skills.sh 2>&1 | tee -a "$LOG_FILE" || log "[warn] install-skills.sh で警告発生（続行）"
fi

# ════════════════════════════════════════════════════════════
# PHASE 0: RESEARCH
# ════════════════════════════════════════════════════════════
log "=== PHASE 0: RESEARCH ==="

while true; do
    [ -f "$RESEARCHED_FLAG" ] && { log "RESEARCH済み、スキップ"; break; }

    log "RESEARCH開始 (engine: $ENGINE, model: opus)"
    run_claude "$(cat $CLAUDE_MD)

---
$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## あなたのタスク（RESEARCH フェーズ）
MISSION.md で指定された対象フレームワーク/ライブラリを調査し、/workspace/RESEARCH.md に調査結果をまとめよ。さらに後続フェーズ (PREPARE/TRAINING) の効率を上げるため、関連する Claude Code スキルを検索し、この PHASE 0 のうちにインストールせよ。

### やってよいこと / やってはいけないこと
- YES: 公式ドキュメント・examples の Web 調査
- YES: RESEARCH.md の作成
- YES: find-skills を使った関連スキルの検索（/workspace/.claude/skills/find-skills/ に既にある）
- YES: Bash で npx -y skills add OWNER/REPO --skill SKILL_NAME を実行してプロジェクトローカルスキル追加
- NO : POC コードの実装（TRAINING フェーズの仕事）
- NO : npm/pip によるアプリ依存のインストール（PREPARE フェーズの仕事）

### RESEARCH.md に含めるべき項目
1. 概要: 対象フレームワークの目的と思想を 3〜5 行で
2. 主要な概念 / API: コア概念の一覧と役割（例: LangGraph なら State/Node/Edge/Graph）
3. 最小構成の利用パターン: Hello World 相当の典型コード例（疑似コード可）
4. 想定されるハマりどころ: バージョン依存、環境依存、ドキュメントの落とし穴
5. MISSION 達成に必要な依存: インストールすべきパッケージとバージョン（PREPARE フェーズが参照する）
6. MISSION 達成のための実装方針: RESEARCH を踏まえた POC 実装のアプローチ（TRAINING フェーズが参照する）
7. インストール済みスキル: 後続フェーズで活用するスキルのリスト。各項目: スキル名 / 取得元 / 用途 / 使う予定のフェーズ

### スキル選定の手順
1. Bash 経由で次を実行して関連スキルを検索せよ: npx -y skills find KEYWORD
   キーワード例: フレームワーク名（svelte / langgraph / fastapi）、ドメイン（testing / deploy / refactor / review）、言語（typescript / python）
2. MISSION 達成に直接役立ちそうなスキルを 0〜3 個選べ。多ければよいわけではない
3. 選んだスキルは次のコマンドでプロジェクトローカルにインストールせよ:
     cd /workspace && npx -y skills add OWNER/REPO --skill SKILL_NAME
4. 選定理由と期待効果を RESEARCH.md の「インストール済みスキル」セクションに記載せよ
5. 該当スキルがなかった場合は「関連スキルなし」と明記して先に進んでよい

### 調査手段
- Web 検索、公式ドキュメント、GitHub examples、既存の README など
- 必要なら WebFetch / Bash (curl) を使ってよい

調査とスキル選定が完了したら /workspace/.researched ファイルを作成して終了せよ。" "opus"

    [ -f "$RESEARCHED_FLAG" ] && { log "RESEARCH完了"; break; }
    log "RESEARCH未完了、リトライ..."
    sleep 3
done
phase_commit "docs: add RESEARCH.md"

# ════════════════════════════════════════════════════════════
# PHASE 1: PREPARE
# ════════════════════════════════════════════════════════════
log "=== PHASE 1: PREPARE ==="

while true; do
    [ -f "$PREPARED_FLAG" ] && { log "PREPARE済み、スキップ"; break; }

    log "PREPARE開始 (engine: $ENGINE, model: sonnet)"
    run_claude "$(cat $CLAUDE_MD)

---
$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## 前フェーズの成果物: RESEARCH.md
$([ -f "$RESEARCH_FILE" ] && cat $RESEARCH_FILE || echo '(RESEARCH.md が見つからない — 通常の手順で進めてよい)')

---
## あなたのタスク（PREPARE フェーズ）
RESEARCH.md の「MISSION 達成に必要な依存」セクションに従い、POC 実装に必要なパッケージ・ツールをすべてインストールせよ。
インストールが完了したら /workspace/.prepared ファイルを作成して終了せよ。
まだコードの実装はしなくてよい。"

    [ -f "$PREPARED_FLAG" ] && { log "PREPARE完了"; break; }
    log "PREPARE未完了、リトライ..."
    sleep 3
done
phase_commit "chore: prepare deps per RESEARCH.md"

# ════════════════════════════════════════════════════════════
# PHASE 2: TRAINING
# ════════════════════════════════════════════════════════════
log "=== PHASE 2: TRAINING ==="

while true; do
    [ -f "$DONE_FLAG" ] && { log "修行完了済み"; break; }

    log "TRAINING開始 (engine: $ENGINE, model: sonnet)"
    run_claude "$(cat $CLAUDE_MD)

---
$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## 前フェーズの成果物: RESEARCH.md
$([ -f "$RESEARCH_FILE" ] && cat $RESEARCH_FILE || echo '(RESEARCH.md が見つからない — 通常の手順で進めてよい)')

---
## あなたのタスク（TRAINING フェーズ）
RESEARCH.md の「MISSION 達成のための実装方針」を出発点として、MISSION.md の完了条件をすべて満たすまで実装・テストを繰り返せ。
完了条件をすべて達成したら /workspace/.done ファイルを作成して終了せよ。

## ジャーナル記録（/workspace/.journal.md）
作業中、区切りごとに /workspace/.journal.md に**追記**せよ。これは後の REPORT フェーズで別セッションが振り返りを書く際の一次情報になる。

### フォーマット（5タグ固定）
各エントリは以下の形式:

\`\`\`markdown
## YYYY-MM-DD HH:MM [TAG] 1行タイトル
1〜3行の本文
\`\`\`

タグは必ず以下の5種類のいずれか:
- **[TRY]**   — これから試すこと（実行前に書く）
- **[STUCK]** — 詰まった・エラー（原因調査中）
- **[PIVOT]** — 方針変更（理由必須）
- **[AHA]**   — 気づき・再利用したい知見
- **[DONE]**  — サブゴール達成

### いつ書くか
- 新しいサブタスクに着手する前 → [TRY]
- エラーや想定外の挙動に遭遇 → [STUCK]
- アプローチを変える決定 → [PIVOT]
- 学びになった発見 → [AHA]
- 検証可能な達成 → [DONE]

## Git コミット
/workspace は git 管理下にある。各 Journal エントリを書いたあと、関連ファイルをステージしてコミットせよ。

コミットメッセージ規則（Journal タグと対応）:
- [TRY]   → \`wip: <タイトル>\`
- [DONE]  → \`feat: <タイトル>\` （テスト用コードなら \`test: ...\`、ドキュメントなら \`docs: ...\`）
- [PIVOT] → \`refactor: <タイトル>\`
- [AHA]   → \`docs: aha <タイトル>\`
- [STUCK] → コミットしない（調査中）

これにより \`git log\` が時系列の客観記録、.journal.md が主観記録となる。

## 繰り返しのルール
1. テストが失敗したらエラーを読んで原因を特定し修正せよ（[STUCK] を追記）
2. 同じアプローチで2回連続失敗したら別の方法を試みよ（[PIVOT] を追記）
3. 詰まったら /catalog/catalog.md を読んで別ツールを検討せよ
4. 進捗は /workspace/.logs/progress.log に随時記録せよ"

    [ -f "$DONE_FLAG" ] && break
    log "TRAINING未完了、リトライ..."
    sleep 3
done
phase_commit "docs: training complete"

# ════════════════════════════════════════════════════════════
# PHASE 3: REPORT
# ════════════════════════════════════════════════════════════
log "=== PHASE 3: REPORT ==="

while true; do
    [ -f "$REPORTED_FLAG" ] && { log "REPORT済み、スキップ"; break; }

    log "REPORT開始 (engine: $ENGINE, model: opus)"
    run_claude "$(cat $CLAUDE_MD)

---
$(cat $MISSION_FILE)

---
## 前フェーズの成果物: RESEARCH.md
$([ -f "$RESEARCH_FILE" ] && cat $RESEARCH_FILE || echo '(RESEARCH.md なし)')

---
## 修行中のジャーナル: .journal.md（主観ログ）
$([ -f "$JOURNAL_FILE" ] && cat $JOURNAL_FILE || echo '(.journal.md なし — 実装者がジャーナルを残さなかった)')

---
## Git 時系列（客観ログ）
$(cd /workspace && git log --all --oneline 2>/dev/null || echo '(git log 取得失敗)')

---
## あなたのタスク（REPORT フェーズ）
あなたは **修行を終えた別セッション**だ。上記の MISSION / RESEARCH / ジャーナル / git log と、/workspace 配下の実装コードを読み、修行の振り返りレポートを /workspace/REPORT.md に書け。

### REPORT.md の構成（必ず以下のセクションを含めること）

1. **サマリ** (3〜5行)
   - 何を作ったか、所要時間、結果

2. **RESEARCH と実装の乖離**
   - RESEARCH.md で想定した実装方針と、実際に取った方針の差分
   - 乖離がなければ「概ねRESEARCH通り」と明記

3. **詰まりどころ**
   - .journal.md の [STUCK] エントリから抽出
   - 各項目: 何に詰まったか / どう解決したか

4. **方針変更**
   - .journal.md の [PIVOT] エントリから時系列で
   - 各項目: 何を変えたか / なぜ変えたか

5. **気づき・再利用したい知見**
   - .journal.md の [AHA] エントリから
   - 別フレームワーク検証時にも使える知見を優先

6. **次に試すべきこと**
   - あなた自身の提案
   - このフレームワークをさらに理解するための次ステップ
   - 今回の POC の発展アイデア

### 制約
- 新規コードは書かない（レポート執筆のみ）
- .journal.md が存在しない場合は、git log と実装コードの diff から可能な範囲で推測し、その旨をレポートに明記
- 読者はこのフレームワークを知らない人間。ブログ記事の下書きとして読めるレベルで書く

レポート執筆完了後、/workspace/.reported ファイルを作成して終了せよ。" "opus"

    [ -f "$REPORTED_FLAG" ] && { log "REPORT完了"; break; }
    log "REPORT未完了、リトライ..."
    sleep 3
done
phase_commit "docs: add REPORT.md"

echo "
╔══════════════════════════════════════════════╗
║              修行完了！部屋から出よ          ║
╚══════════════════════════════════════════════╝
" | tee -a "$LOG_FILE"
