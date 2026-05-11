---
status: all_fixed
phase: 07
fix_scope: all
findings_in_scope: 10
fixed: 9
skipped: 1
iteration: 2
fixed_at: 2026-04-24T00:00:00Z
review_path: .planning/phases/07-mr-popo-feedback-loop/07-REVIEW.md
---

# Phase 07: Code Review Fix Report

**Fixed at:** 2026-04-24 (iteration 2 / iteration 1 は 2026-04-23)
**Source review:** .planning/phases/07-mr-popo-feedback-loop/07-REVIEW.md
**Iteration:** 2 (Warning 4 件 + Info 5 件を統合レポート)

**Summary:**
- Findings in scope: 10 (Critical 0 + Warning 4 + Info 6)
- Fixed: 9 (Warning 4 / Info 5)
- Skipped: 1 (Info 1 — 将来の技術的負債として記録)

## Fixed Issues

### WR-01: `cd /workspace` の失敗ハンドリング欠落 (start-training.sh)

**Files modified:** `spirit-room/base/scripts/start-training.sh`
**Commit:** 2518e5f
**Iteration:** 1
**Applied fix:**
- `init_git_workspace()` の `cd /workspace` に失敗ハンドリングを追加:
  `cd /workspace || { log "[ERROR] /workspace に cd できない — git 初期化中止"; return 1; }`
- `phase_commit()` の `cd /workspace` にも同様のガードを追加:
  `cd /workspace || { log "[WARN] /workspace に cd できない — commit スキップ"; return 0; }`
- これで /workspace が存在しない・権限がない場合でも、/ や /room/ 配下に `.git`
  を誤って作ったり誤った場所で git add/commit が走るリスクを排除。

### WR-02: `extract-feedback.sh` の `_yq()` で yq 未インストール / 想定外出力に対する防御

**Files modified:** `spirit-room/base/scripts/extract-feedback.sh`
**Commit:** 1d51663
**Iteration:** 1
**Applied fix:**
- 冒頭コメントで yq バージョン前提を明記:
  「yq は mikefarah 版 Go yq v4+ (Python kislyuk 版は非サポート)」
  Dockerfile で固定バージョンをインストールする旨を記載。
- `_yq()` に `command -v yq >/dev/null 2>&1` ガードを追加し、yq バイナリが
  無い場合は空文字を返すよう変更 (command not found の stderr 汚染回避)。
- `echo "$FRONTMATTER"` を `printf '%s\n' "$FRONTMATTER"` に置換 (先頭
  `-e` / `-n` をフラグとして誤って解釈するリスクを排除)。IN-06 の指摘と
  本質的に同じ修正を同時に取り込んだ (IN-06 では 114 行目側も追加対応)。
- null / 空文字のフォールバックを一つの条件に集約しシンプル化
  (iteration 2 で IN-01 がさらに 1 行化して整理)。

### WR-03: awk の frontmatter 抽出が 2 つ目の `---` 欠落時に全文出力する

**Files modified:** `spirit-room/base/scripts/extract-feedback.sh`
**Commit:** 702ec80
**Iteration:** 1
**Applied fix:**
- awk 抽出の前に `CLOSE_COUNT=$(grep -c '^---$' "$REPORT_FILE")` で
  `---` の出現回数を事前確認。
- 2 回未満 (閉じ `---` 欠落) の場合は
  「REPORT.md の frontmatter が閉じていない」WARN ログを出して `exit 0`
  (feedback 抽出を silent に skip)。
- 閉じ `---` が存在する場合のみ既存の awk 抽出に進む。
- 壊れた REPORT.md / frontmatter 閉じ忘れで本文 Markdown が $FRONTMATTER
  に混入する silent failure を防止。
- 動作確認済み: broken=1 (skip), ok=2 (通過)。

### WR-04: start-training.sh の `sed -n '/^---$/,/^---$/p'` が frontmatter 閉じ忘れで全文拾う

**Files modified:** `spirit-room/base/scripts/start-training.sh`
**Commit:** 2a48047
**Iteration:** 1
**Applied fix:**
- `resolve_max_iterations()` 内の sed レンジ抽出を awk に置換:
  ```bash
  awk '
      /^---$/ { c++; if (c==1) next; if (c==2) exit }
      c==1 && /^max_iterations:[[:space:]]*[0-9]+/ { print; exit }
  ' "$MISSION_FILE"
  ```
- `c==2` 到達時に `exit` することで、閉じ `---` が無いファイルで本文末尾
  まで読み続ける sed の挙動を回避。
- 動作確認済み:
  - 閉じ `---` あり: frontmatter 内の `max_iterations: 42` を正しく抽出
  - 閉じ `---` なし: 本文の `max_iterations: 999` を無視して空文字を返す
    → 上位で default (50) にフォールバックされる

### IN-01: `_yq()` の null/空文字判定を 1 行に簡素化

**Files modified:** `spirit-room/base/scripts/extract-feedback.sh`
**Commit:** df89f20
**Iteration:** 2
**Applied fix:**
- `_val=$(printf '%s\n' "$FRONTMATTER" | yq "$1" 2>/dev/null)` で空文字
  フォールバックが既に保証されているため、直後の分岐
  `if [ -z "$_val" ] || [ "$_val" = "null" ]; then printf ... else printf ...`
  を `[ "$_val" = "null" ] && _val=""` の 1 行に集約。
- 最終出力は `printf '%s\n' "$_val"` の単一呼び出しに統一。
- 挙動は等価 (空文字 / null どちらも空文字を返す) で可読性が向上。

### IN-02: `find $HOME/projects` のクォート

**Files modified:** `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md`
**Commit:** 5993ac2
**Iteration:** 2
**Applied fix:**
- Step R1 の例示コマンドを
  `find $HOME/projects -maxdepth 3 ...` から
  `find "$HOME/projects" -maxdepth 3 ...` に変更。
- $HOME にスペースが含まれる環境でのパス展開崩れを防止、かつ
  「ドキュメント内のシェル例は変数展開を必ずクォートする」という
  習慣づけ。

### IN-03: Step R6 の sed 例示に `$(date +%F)` 展開を明示

**Files modified:** `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md`
**Commit:** 3dfe774
**Iteration:** 2
**Applied fix:**
- `sed 's/^- Review status: pending$/- Review status: applied (YYYY-MM-DD)/'`
  の `YYYY-MM-DD` がリテラルで書かれていたのを排除。
- 代わりに
  ```bash
  TODAY=$(date +%F)
  sed -i "s/^- Review status: pending$/- Review status: applied (${TODAY})/" "$feedback_file"
  ```
  の 2 行セットを例示。却下時 (`rejected`) のバリエーションも同スタイルで
  併記し、Mr.ポポがリテラル文字列 "YYYY-MM-DD" を feedback に書き込む
  事故を防止。

### IN-05: YAML frontmatter 末尾コメントを HTML コメントに移動

**Files modified:**
- `spirit-room/base/scripts/MISSION.md.template`
- `spirit-room/base/scripts/KAIO-MISSION.md.template`

**Commit:** 52bbf6e
**Iteration:** 2
**Applied fix:**
- 両テンプレとも frontmatter 内の行末コメント
  (`# poc / refactoring / ...`, `# TRAINING フェーズの安全網 ...` 等) を削除し、
  frontmatter 閉じ `---` の直後に HTML コメント `<!-- ... -->` として再配置。
- スカラ値は完全保持:
  - MISSION.md.template: `max_iterations: 50`
  - KAIO-MISSION.md.template: `max_iterations: 100` (界王星モードは 2 倍)
- 利点:
  - ユーザーが生成 MISSION.md をコピペで埋める際に説明テキストが混入しない
  - yq のコメント剥離挙動が将来変わっても壊れない
  - 説明テキストは残っているので可読性は維持

### IN-06: TARGET_FILE 生成ブロックの `echo "$FRONTMATTER"` を `printf` 化

**Files modified:** `spirit-room/base/scripts/extract-feedback.sh`
**Commit:** 6f8d9a0
**Iteration:** 2
**Applied fix:**
- 114 行目付近、feedback ファイル生成ブロック (`{ ... } > "$TARGET_FILE"`)
  内の `echo "$FRONTMATTER"` を `printf '%s\n' "$FRONTMATTER"` に置換。
- _yq() 側 (WR-02 で printf 化済み) との整合を取り、FRONTMATTER 先頭行が
  `-e` / `-n` 始まりの YAML を含む不測のケースで echo のフラグ解釈によって
  行が消える事故を防止。
- 変更箇所にはコメントで防御の意図も明記。

## Skipped Issues

### IN-04: `spirit-room-manager/CLAUDE.md` と `MR_POPO.md` のコマンド一覧二重管理

**File:** `spirit-room-manager/CLAUDE.md:17-26`
**Reason:** レビュー本体で「今回は追加しなくてよいが将来の技術的負債として記録」
と明示されている。どちらを source of truth にするかは設計判断が必要で、
Phase 07 のスコープ外。本修正では両ファイルとも変更していない。将来別フェーズ
(例: ドキュメント整備 phase) で「CLAUDE.md 側は詳細は skills/MR_POPO.md 参照
に簡素化する」などの決定をしてから反映する。

**Original issue:** `MR_POPO.md` 側にも類似のコマンド一覧があり、
二重管理になっている。将来片方だけ更新されて drift する典型パターン。
どちらかを source of truth にして他方は参照すべき。

---

_Fixed: 2026-04-23 (iteration 1: WR-01〜04) / 2026-04-24 (iteration 2: IN-01/02/03/05/06)_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
