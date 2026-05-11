---
phase: 07-mr-popo-feedback-loop
plan: 03
subsystem: training-loop
tags: [start-training, max-iterations, safety-guard, interrupted-flag, partial-report, feedback-loop, bash-training-loop]

# Dependency graph
requires:
  - phase: 07-mr-popo-feedback-loop
    plan: 01
    provides: "MISSION.md 先頭 frontmatter の max_iterations フィールド — MAX_ITERATIONS 上書きソース② として resolve_max_iterations が読み取る"
  - phase: 07-mr-popo-feedback-loop
    plan: 02
    provides: "create-report.md § 4a の 8 フィールド frontmatter 仕様 — PHASE 3 プロンプトが本プランから参照し、completion_status: interrupted 込みの部分 REPORT.md 生成を保証"
provides:
  - "start-training.sh の TRAINING フェーズ (PHASE 2) MAX_ITERATIONS ガード (TRAINING_ITER カウンタ + .interrupted フラグ)"
  - "resolve_max_iterations() 関数: 優先順 ①env MAX_ITERATIONS > ②MISSION.md frontmatter > ③default 50 (無効値フォールバック込み)"
  - "EFFECTIVE_MAX_ITERATIONS 起動時解決 + source 判定ログ (env / mission.md / default)"
  - "PHASE 3 (REPORT) プロンプトに完了ステータス 3 分岐 (interrupted / completed / failed) と REPORT.md 先頭 frontmatter 8 フィールド書き込み指示"
  - "phase_commit メッセージ分岐: interrupted 時 `docs: training interrupted at iter N/MAX`、通常完了時は既存の `docs: training complete`"
  - ".gitignore に .interrupted を追加 (新安全網フラグの一貫性 Rule 2)"
affects:
  - "07-04 extract-feedback.sh: .interrupted フラグの有無で partial/complete 扱いを切り替え可能 (REPORT.md frontmatter の completion_status を見れば同等)"
  - "07-04 .planning/mr-popo-memory/ 保存: 部分 REPORT.md (completion_status: interrupted) も蓄積対象"
  - "07-05 MR_POPO_REVIEW_FEEDBACK.md: 中断レポートからの suggested_template_diff も差分提案原資として使える (むしろ『ダメな MISSION.md』学習シグナルとして価値が高い)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "bash 関数による優先順解決ロジック (env > 設定ファイル > default) の 3 段階フォールバック pattern"
    - "sed '/^---$/,/^---$/p' + grep -E で markdown frontmatter から値を抜き出す yq 非依存 pattern"
    - "bash regex [[ =~ ^[0-9]+$ ]] + -gt 0 検証による無効値 (非整数 / 0 / 負) の排除"
    - ".interrupted フラグを .done / .failed と別の第 3 状態として扱い、安全網発動を中立に表現するフラグ命名 pattern"
    - "run_claude プロンプト内 command substitution $(if ...; fi) による動的ステータス注入 (既存 $(cat ...) $([ -f ... ] && ...) 方式と整合)"

key-files:
  created: []
  modified:
    - "spirit-room/base/scripts/start-training.sh (+85 行 / -3 行: 定数 2 行・resolve_max_iterations 関数 26 行・EFFECTIVE 算出 10 行・.gitignore 1 行・PHASE 2 ガード 11 行・phase_commit 分岐 5 行・PHASE 3 完了ステータス 9 行・PHASE 3 frontmatter 指示 12 行・既存リトライログ書き換え 1 行)"

key-decisions:
  - "resolve_max_iterations の無効値ポリシー: 非整数 / 0 を不許可とし次ソースへフォールバック (T-07-03-01 DoS 対策: env=0 で TRAINING が 1 度も回らない事故を防止)"
  - "sed+grep+awk による frontmatter 抽出を採用 (yq 依存回避で Dockerfile レイヤーの安定性を確保)。コンテナには yq が入っているが、本関数は単一ソースで完結させる方針"
  - ".interrupted と .done は相互排他。TRAINING ループ先頭で [ -f \"$DONE_FLAG\" ] を先にチェック → 未存在なら MAX ガード、の順で自然に排他 (D-12)"
  - "PHASE 3 プロンプトの完了ステータスブロックは $(if ...; fi) command substitution で動的に注入 (.interrupted / .done / それ以外の 3 分岐)"
  - "phase_commit メッセージを interrupted 時に 'training interrupted at iter N/MAX' に切り替え (既存 'training complete' メッセージは通常完了時のみに残す)"
  - ".gitignore への .interrupted 追加は Rule 2 (必要な整合性): 既存 .prepared / .done / .reported と同じ扱いをしないと中断時に workspace がコミット対象ノイズを拾う"

patterns-established:
  - "TRAINING_ITER 変数を PHASE 2 限定スコープで管理し、PHASE 0/1/3 のループは既存の未カウント形式を維持 (D-10: ガードは TRAINING のみ)"
  - "EFFECTIVE_MAX_ITERATIONS は init_git_workspace 直後に 1 回だけ解決して以降は再解決しない (解決結果は log に source 付きで残す: env / mission.md / default)"
  - "新しいフェーズフラグ (.interrupted) を追加したら .gitignore にも必ず追記する"

requirements-completed:
  - D-10
  - D-11
  - D-12
  - D-13

# Metrics
duration: ~4min
completed: 2026-04-23
---

# Phase 07 Plan 03: start-training.sh に MAX_ITERATIONS ガード + .interrupted + 部分 REPORT.md 生成を実装 Summary

**TRAINING フェーズ (PHASE 2) に反復カウンタ `TRAINING_ITER` と `EFFECTIVE_MAX_ITERATIONS` ガードを追加し、上限到達時は `/workspace/.interrupted` フラグ作成 → TRAINING を break → PHASE 3 (REPORT) で `completion_status: interrupted` 込みの部分レポートを生成する自己保護ループを確立**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-23T02:58:47Z
- **Completed:** 2026-04-23T03:02:49Z
- **Tasks:** 2 / 2
- **Files modified:** 1

## Accomplishments

- `resolve_max_iterations()` 関数を実装。優先順は ①env `MAX_ITERATIONS` (正整数) > ②MISSION.md frontmatter の `max_iterations` (正整数) > ③デフォルト 50。無効値 (非整数 / 0 / 負) は次ソースへフォールバックする T-07-03-01/02 mitigation を組み込み
- 定数 `INTERRUPTED_FLAG="/workspace/.interrupted"` と `DEFAULT_MAX_ITERATIONS=50` を追加 (D-10/D-12)
- `init_git_workspace` 直後に `EFFECTIVE_MAX_ITERATIONS` を解決し、source (`env` / `mission.md` / `default`) 付きでログ出力
- PHASE 2 (TRAINING) ループに `TRAINING_ITER` カウンタ + 超過判定 + `.interrupted` 作成 + `break` を実装 (D-10)
- PHASE 2 ループ後の `phase_commit` を interrupted 時と通常完了時で分岐 (`docs: training interrupted at iter N/MAX` / 既存 `docs: training complete`)
- PHASE 3 (REPORT) プロンプトに完了ステータスブロックを挿入: `.interrupted` → `completion_status: interrupted` + 部分レポート指示 / `.done` → `completion_status: completed` / どちらもなし → `completion_status: failed` の 3 分岐を `$(if ...; fi)` command substitution で動的注入
- PHASE 3 プロンプトに REPORT.md 先頭 YAML frontmatter の 8 必須フィールド (feedback_schema_version / completion_status / mission_type + D-02 の 6 項目) 書き込み指示を追加、`/room/scripts/create-report.md § 4a` を参照指示 (Plan 07-02 との整合)
- `.gitignore` ヒアドキュメント内に `.interrupted` を追加 (Rule 2: 既存 `.prepared` / `.done` / `.reported` と一貫させ、中断時に workspace が余計なトラッキングノイズを拾わないように)
- PHASE 0 (RESEARCH) / PHASE 1 (PREPARE) のループ構造・run_claude の `--allowedTools` 設定・既存 PHASE 3 本文 6 セクション見出し (サマリ / RESEARCH と実装の乖離 / 詰まりどころ / 方針変更 / 気づき・再利用したい知見 / 次に試すべきこと) は 1 文字も改変せず (禁止事項遵守)
- smoke test: `resolve_max_iterations` の 8 シナリオ (default / mission frontmatter / env 上書き / 無効 env フォールバック / env=0 フォールバック / 非数値 mission / mission=0 / whitespace 許容) 全 PASS を切り出しスクリプトで確認

## Task Commits

Each task was committed atomically:

1. **Task 1: MAX_ITERATIONS 解決関数と定数を追加** - `d7b4432` (feat)
2. **Task 2: PHASE 2 ガード + PHASE 3 interrupted 文脈伝達** - `2cdef34` (feat)

**Plan metadata commit:** (本 SUMMARY + STATE + ROADMAP を最終コミットで追加予定)

## Files Created/Modified

- `spirit-room/base/scripts/start-training.sh` (+85 行 / -3 行):
  - line 14-15: 定数 `INTERRUPTED_FLAG` / `DEFAULT_MAX_ITERATIONS` 追加
  - line 34-59: `resolve_max_iterations()` 関数定義 (25 行)
  - line 95: `.gitignore` ヒアドキュメントに `.interrupted` 追加
  - line 116-125: `EFFECTIVE_MAX_ITERATIONS` 解決 + source ログ (10 行)
  - line 231-248: PHASE 2 TRAINING_ITER カウンタ + ガード + `.interrupted` touch + break + iter 表示ログ
  - line 307-316: phase_commit interrupted/complete 分岐
  - line 344-352: PHASE 3 完了ステータスブロック ($(if ...; fi) 3 分岐)
  - line 358-369: PHASE 3 frontmatter 8 フィールド書き込み指示 + create-report.md § 4a 参照

## Decisions Made

- **無効値は次ソースへフォールバック (0 / 負 / 非整数)**: `=~ ^[0-9]+$` 正規表現 + `-gt 0` 数値比較を 2 段重ねでガード。T-07-03-01 DoS (`MAX_ITERATIONS=0` で TRAINING が 1 度も回らない) を防止。MISSION.md frontmatter が誤ってタイプミスされても default 50 に落ちる安全策
- **yq を使わず sed+grep+awk で frontmatter を抽出**: yq はコンテナに入っているが、本関数は単一依存で完結させ、将来ベースイメージ構成が変わっても壊れない堅牢性を優先 (`yq` 文字列はコメント含めて 0 件に整理)
- **TRAINING ループ先頭で `.done` チェック → MAX ガード → インクリメント の順**: `.done` と `.interrupted` の同時成立を構造的に避ける。既存の `.done` ループ先頭チェックを温存しつつ、その直後にガードを差し込む最小改修
- **phase_commit メッセージを interrupted 時に切り替え**: 既存 `docs: training complete` は成功時のみに残し、中断時は明示的に `docs: training interrupted at iter N/MAX` にすることで `git log` からも中断が追えるようにする。Plan 07-04 の extract-feedback.sh が git log を参照する場合にも有利
- **PHASE 3 完了ステータスは command substitution で動的注入**: `$(if [ -f "$INTERRUPTED_FLAG" ]; then ...; elif [ -f "$DONE_FLAG" ]; then ...; else ...; fi)` パターン。既存プロンプトの `$([ -f "$RESEARCH_FILE" ] && cat ...)` と同じ評価モデルで動作し、新しい評価メカニズムを導入しない
- **.gitignore に .interrupted を追加 (Rule 2)**: 既存 `.prepared` / `.done` / `.reported` と揃える。中断時に workspace で `git status` が `.interrupted` を untracked として見せない整合性確保。既存 frontmatter・ループ構造には一切影響なし

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - 整合性維持] `.gitignore` ヒアドキュメントに `.interrupted` を追加**
- **Found during:** Task 1 実装中、`.interrupted` フラグ定義追加時
- **Issue:** plan の `<action>` には `.gitignore` 更新指示が明記されていないが、既存の `init_git_workspace` 内ヒアドキュメントに `.prepared` / `.done` / `.reported` が列挙されており、`.interrupted` のみ抜けると `git status` が untracked として見せる・`git add -A` で誤追跡する恐れがあった
- **Fix:** ヒアドキュメント内 `.reported` の直後に `.interrupted` を 1 行追加 (既存 4 行フラグ列挙パターンに素直に追従)
- **Files modified:** `spirit-room/base/scripts/start-training.sh` line 95
- **Commit:** `d7b4432` (Task 1 に同梱)
- **Impact:** 新しいフラグ体系の一貫性確保。既存 workspace への影響なし (新規 `git init` 時のみ書かれる gitignore の内容)

**2. [Rule 2 - 禁止事項抽出の言い換え] `yq を使わず` コメントを `依存最小化のため` に書き換え**
- **Found during:** Task 1 verify 実行時
- **Issue:** plan の acceptance_criteria の 1 つ「`grep -c 'yq' start-training.sh` が 0」が、コメント行の説明文 `(yq を使わず sed+grep で堅牢に)` にマッチして 1 件検出されてしまい条件未達
- **Fix:** コメントを `# ② MISSION.md 先頭 frontmatter から拾う (依存最小化のため sed+grep で堅牢に)` に言い換え、yq 文字列を消去。機能的な変更なし (コメント文言のみ)
- **Files modified:** `spirit-room/base/scripts/start-training.sh` line 44
- **Commit:** `d7b4432` (Task 1 に同梱)
- **Impact:** acceptance_criteria pass 化。実装ロジックへの影響なし

その他の技術的ブロッカー・architectural 判断要求 (Rule 4) なし。plan の interfaces / 禁止事項はすべて遵守。

## Issues Encountered

- **PreToolUse:Edit hook の READ-BEFORE-EDIT 再掲**: 各 Edit の前に「Read し直せ」hook が都度発火したが、Edit 自体は先行の Read で必要箇所を既に読み込み済みなので正常に適用済み。中間状態のロールバックや再書き込みは発生せず (Phase 07-01 / 07-02 と同一パターン)
- **acceptance_criteria の `yq` 0 件条件**: コメント行がマッチして一度 1 件検出されたが、上述 Deviations で Rule 2 適用 (コメント言い換え) で解消
- 技術的ブロッカー・実装上の詰まりなし。plan 通り 2 タスクを順当に実装

## User Setup Required

None — スクリプト改修のみ。環境変数 `MAX_ITERATIONS` は**任意**で、未指定時は MISSION.md frontmatter または default 50 が使われるため既存ユーザーへの影響なし。実 run 検証 (実際に 50 回到達 → `.interrupted` 作成 → 部分 REPORT.md 生成) は Plan 07-04 の E2E で実施予定 (本 plan スコープ外)。

## Self-Check: PASSED

**Files exist:**
- FOUND: `spirit-room/base/scripts/start-training.sh` (modified)

**Commits exist:**
- FOUND: `d7b4432` (Task 1)
- FOUND: `2cdef34` (Task 2)

**Plan automated verify (Task 1 + Task 2):**
- FOUND: `INTERRUPTED_FLAG="/workspace/.interrupted"` (定数定義)
- FOUND: `DEFAULT_MAX_ITERATIONS=50`
- FOUND: `resolve_max_iterations()` (関数定義 + 1 回呼び出し = grep 2 件)
- FOUND: `EFFECTIVE_MAX_ITERATIONS=` (9 件 >= 5)
- FOUND: `TRAINING_ITER=0` (初期化), `TRAINING_ITER=$((TRAINING_ITER + 1))` (増分)
- FOUND: `touch "$INTERRUPTED_FLAG"` (発火時作成)
- FOUND: `MAX_ITERATIONS (${EFFECTIVE_MAX_ITERATIONS})` (ガードログ)
- FOUND: `training interrupted at iter` (phase_commit interrupted 分岐)
- FOUND: `completion_status: interrupted`, `completion_status: completed`, `completion_status: failed` (3 分岐全て)
- FOUND: `feedback_schema_version: 1`, `suggested_template_diff`, `ambiguous_in_brief`, `overspecified_in_brief`, `missing_from_catalog`, `completion_signal_mismatch` (8 フィールド中 frontmatter 必須 6 項目 + mission_type + completion_status)
- FOUND: `create-report.md` § 4a 参照
- FOUND: `docs: training complete` が 1 件残存 (既存通常完了メッセージ保持)
- FOUND: `docs: training interrupted` が 1 件 (新設)
- FOUND: `RESEARCH と実装の乖離` が 1 件 (既存本文見出し保持)
- NOT FOUND: `yq` (0 件 — 依存ゼロ確認)
- `bash -n spirit-room/base/scripts/start-training.sh` exit 0

**Smoke test (resolve_max_iterations 8 シナリオ):**
- PASS: default → 50
- PASS: mission frontmatter → 77
- PASS: env=123 overrides mission → 123
- PASS: env="abc" → falls back to mission 77
- PASS: env=0 → falls back to mission 77 (T-07-03-01 mitigation)
- PASS: mission="not-a-number" → default 50
- PASS: mission=0 → default 50
- PASS: whitespace `max_iterations:   42` → 42

**Structural preservation check:**
- PHASE 0 (RESEARCH) `while true` loop intact
- PHASE 1 (PREPARE) `while true` loop intact
- PHASE 3 (REPORT) `while true` loop intact, `.reported` フラグチェック位置不変
- `--allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch"` unchanged
- 既存 phase_commit メッセージ "docs: add RESEARCH.md" / "chore: prepare deps per RESEARCH.md" / "docs: add REPORT.md" 不変
- 既存 PHASE 3 本文見出し 6 項目すべて保持

## Next Phase Readiness

- **Plan 07-04 (extract-feedback.sh 新設 + `.planning/mr-popo-memory/{type}/` 自動蓄積)**: `.interrupted` / `.done` / `.reported` のフラグ組み合わせから completion_status を独立に判定可能。REPORT.md 先頭 frontmatter には本プランの PHASE 3 プロンプト指示で `completion_status: interrupted/completed/failed` が書き込まれているため、`yq --front-matter=extract` で直接取得できる。部分 REPORT.md も同スキーマで蓄積対象に自動的に含まれる前提成立
- **Plan 07-05 (MR_POPO_REVIEW_FEEDBACK.md レビューコマンド)**: 中断レポート (`completion_status: interrupted`) は「ダメな MISSION.md」学習シグナルとして価値が高く、むしろ正常完了レポートより suggested_template_diff が濃い内容になる見込み。Mr.ポポのレビュー UX で interrupted レポートを優先表示する戦略が取れる
- **既存 spirit-room 運用への影響**: 後方互換。env `MAX_ITERATIONS` 未指定 + MISSION.md に `max_iterations:` フィールドなしのレガシー MISSION.md は default 50 回で動作継続 (Plan 07-01 で新 frontmatter が追加された MISSION.md は per-mission 上書きが効く)
- **ベースイメージ再ビルドの要否**: 本変更は `base/scripts/start-training.sh` なので `./build-base.sh` による image 再ビルドが必要 (plan 外だが運用上の注意。Phase 07 最終完了時に 1 回実施すれば十分)

---
*Phase: 07-mr-popo-feedback-loop*
*Completed: 2026-04-23*
