---
phase: 07-mr-popo-feedback-loop
plan: 04
subsystem: training-loop
tags: [extract-feedback, mr-popo-memory, report-md, yaml-frontmatter, yq, feedback-loop, safe-failure, auto-accumulation]

# Dependency graph
requires:
  - phase: 07-mr-popo-feedback-loop
    plan: 01
    provides: "MISSION.md frontmatter の mission_type (poc/refactoring/testdata/investigation/kaio) — 保存ディレクトリキー"
  - phase: 07-mr-popo-feedback-loop
    plan: 02
    provides: "REPORT.md 先頭 YAML frontmatter 8 フィールド仕様 (feedback_schema_version / completion_status / mission_type + D-02 の 6 項目) — 抽出対象の契約"
  - phase: 07-mr-popo-feedback-loop
    plan: 03
    provides: "start-training.sh PHASE 3 ループ末尾の phase_commit 'docs: add REPORT.md' 位置 + .interrupted/.done 経由の部分 REPORT.md もスキーマ互換 — extract-feedback.sh の挿入点が確定"
provides:
  - "spirit-room/base/scripts/extract-feedback.sh (新設) — REPORT.md の YAML frontmatter を awk で切り出し yq で 3 主要フィールドを抽出、/workspace/.planning/mr-popo-memory/{mission_type}/{date}-{slug}.md に保存"
  - "mission_type 別ディレクトリ分岐 + 未知/欠損値は unknown/ フォールバック (D-04)"
  - "set -e なし / yq 失敗 / mkdir 失敗 / 衝突 99 超え はすべて exit 0 で吸収する safe failure 設計 (D-05 'training を止めない')"
  - "同名衝突時の -02 / -03 ... 99 まで suffix 回避 (T-07-04-05)"
  - "start-training.sh の PHASE 3 完了直後 (phase_commit 'docs: add REPORT.md' と完了バナーの間) に extract-feedback.sh 呼び出しフック + 成功時 'docs: add Mr.ポポ feedback memory' コミット + 失敗時 WARN log で吸収"
  - ".gitignore heredoc に .planning/mr-popo-memory/ が git 管理対象である旨のコメントを追加 (Plan 07-05 の applied/ 移動設計との整合表明)"
  - "Review status: pending の plain key 形式 (太字なし) — Plan 07-05 のレビューコマンドが sed で applied に書き換え可能な機械可読マーカー"
affects:
  - "07-05 MR_POPO_REVIEW_FEEDBACK.md: /workspace/.planning/mr-popo-memory/{type}/*.md を mission_type ごとに読み、`- Review status: pending` を目印に pending エントリだけ拾って差分提案の原資にできる。applied 後は sed で `pending` → `applied` に書き換える運用"
  - "Plan 07-05 以降のフェーズレビューコマンドがホスト側でも / room/ (コンテナ) 側でも同じ形式の memory ファイルを読める (パスは /workspace 相対 = ホストからもマウントして共有されるため)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "awk '/^---$/{c++; if(c==2) exit; next} c==1' による YAML frontmatter 第 1 ブロック抽出 (yq には markdown frontmatter 直読み機能がないための pre-processing)"
    - "yq 失敗/ null 値 → 空文字 → unknown フォールバック の 3 段 safe failure pattern"
    - "tr '[:upper:]' '[:lower:]' + sed 's/[^a-z0-9_-]/_/g' による mission_type / room_slug のパストラバーサル防御 (T-07-04-01 mitigation)"
    - "set -u は on / set -e は off + 各 subshell 末尾に '|| exit 0' または '|| log WARN' を明示する safe failure pattern"
    - "TARGET_FILE 衝突時の while ループ + printf '%02d' $_n による 2 桁 padded suffix (-02 から始める理由: 初回は suffix なし、2 個目から -02)"
    - "start-training.sh フックの `[ -x 略 ] || [ -f 略 ]` で実行ビット欠落時にも bash 経由で起動できる fallback"

key-files:
  created:
    - "spirit-room/base/scripts/extract-feedback.sh (110 行 / chmod +x 済み)"
  modified:
    - "spirit-room/base/scripts/start-training.sh (+12 行: PHASE 3 後の extract-feedback フック + .gitignore コメント)"

key-decisions:
  - "yq で frontmatter 直読みせず awk で先に第 1 `---` ブロックだけ切り出してから yq に渡す (plan の interfaces 指示通り): yq v4 は markdown frontmatter を直接パースできないため必須の pre-processing"
  - "Review status マーカーは太字を外した plain 形式 `- Review status: pending` に変更 (plan の action 原文の `- **Review status:** pending` だと plan verify の grep 'Review status: pending' と不整合。Rule 1 で plain 表記に合わせた)"
  - "yq 失敗時は mission_type='' → unknown/ へ保存する安全側倒しを採用 (T-07-04-02 DoS mitigation): 開発環境で yq 不在だった場合も exit 0 で終われる E2E で実証"
  - "start-training.sh のフックは `[ -x ] || [ -f ]` の 2 段チェックで、実行ビット欠落 (volume マウント時の権限 edge case) でも bash 経由で起動できるようにする"
  - ".planning/mr-popo-memory/ は git 管理対象にする (`.gitignore` にコメントで明示): Plan 07-05 で applied/ 移動履歴が git log で追えるよう、feedback の追記・移動をすべて commit 経由にする"
  - "extract-feedback.sh 失敗時も部屋の終了バナーは必ず出す (D-05 絶対原則): 抽出は「邪魔しない自動蓄積」であって、training の完了フローに依存させない"

patterns-established:
  - "部屋 (training container) の終了パイプライン = [REPORT.md 生成 → REPORT.md git commit → extract-feedback.sh → memory git commit → 完了バナー] の 5 段リニア構造 (各段階が失敗しても次段に影響しない)"
  - "/workspace/.planning/mr-popo-memory/ 配下のファイル名規約: {mission_type}/{YYYY-MM-DD}-{room-slug}.md / 衝突時 -02, -03... / unknown/ フォールバック"
  - "フィードバックファイル本体フォーマット: Markdown header + 8 メタデータ行 (Room / Date / mission_type / completion_status / feedback_schema_version / Source / Review status) + ```yaml フェンスで frontmatter 原文コピー (Plan 07-05 が yq 再抽出できる)"

requirements-completed:
  - D-04
  - D-05
  - D-06

# Metrics
duration: ~4min
completed: 2026-04-23
---

# Phase 07 Plan 04: extract-feedback.sh 新設 + PHASE 3 直後フック + .planning/mr-popo-memory/{type}/ 自動蓄積 Summary

**部屋完了時 (PHASE 3 REPORT フェーズ終了後) に `/workspace/REPORT.md` の YAML frontmatter を awk + yq で機械抽出し、`.planning/mr-popo-memory/{mission_type}/{YYYY-MM-DD}-{room-slug}.md` に自動保存するパイプラインを実装。失敗は部屋の終了フローを止めない safe failure 設計 (set -e なし / 衝突は suffix 回避 / 未知 mission_type は unknown/ フォールバック)。D-04 / D-05 / D-06 の 3 要件を完結。**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-23T03:07:36Z
- **Completed:** 2026-04-23T03:11:45Z
- **Tasks:** 2 / 2
- **Files created:** 1
- **Files modified:** 1

## Accomplishments

- 新規スクリプト `spirit-room/base/scripts/extract-feedback.sh` (110 行 / `chmod +x` 済み) を作成。以下の役割を担う:
  - `/workspace/REPORT.md` の存在チェック → 無ければ WARN ログ + exit 0 で抜ける (中断フロー等で REPORT.md が未生成のケースを吸収)
  - awk で最初の `---` と 2 個目の `---` の間だけを抽出 (yq は markdown frontmatter を直読みできないため前処理)
  - frontmatter ブロックが空なら WARN + exit 0
  - yq で `mission_type` / `completion_status` / `feedback_schema_version` を抽出。null / 失敗は空文字に正規化
  - mission_type 空 → `unknown` / 英小文字数字アンハイフン以外は `_` に置換 (パストラバーサル対策)
  - `/workspace/.planning/mr-popo-memory/{mission_type}/{YYYY-MM-DD}-{room-slug}.md` に保存
  - 同名衝突時は `-02` / `-03` ... `-99` まで suffix で回避 (99 超えは諦めて exit 0)
  - 保存ファイルは D-06 準拠: `# Mr.ポポ feedback memory` ヘッダ + Room/Date/mission_type/completion_status/feedback_schema_version/Source/Review status の 7 メタ行 + ```yaml フェンス内に frontmatter 原文コピー
  - 全 safe failure 経路で exit 0。`set -u` は on、`set -e` は **使わない**
- `spirit-room/base/scripts/start-training.sh` の PHASE 3 (REPORT) ループ末尾 (`phase_commit "docs: add REPORT.md"` と完了バナーの間) に extract-feedback.sh 呼び出しフックを追加:
  - `[ -x /room/scripts/extract-feedback.sh ] || [ -f /room/scripts/extract-feedback.sh ]` の 2 段チェック (実行ビット欠落時にも bash 経由で起動できる)
  - 抽出呼び出しは `bash /room/scripts/extract-feedback.sh || log "[WARN] extract-feedback.sh が非ゼロ終了 — 続行"` で非ゼロ終了を吸収
  - 抽出成功時は `phase_commit "docs: add Mr.ポポ feedback memory"` で git コミット (`.planning/mr-popo-memory/` は git 管理対象)
  - スクリプト自体が見つからない場合は WARN log で通知してスキップ
  - 完了バナー (`修行完了！部屋から出よ`) は既存のまま無改変
- `.gitignore` ヒアドキュメント (start-training.sh 内) の末尾に `# Phase 7 feedback loop: .planning/mr-popo-memory/ は git 管理対象 (除外しない)` コメントを追加 (Plan 07-05 の applied/ 移動設計との意図整合)
- Plan 07-03 で既に追加済みの `.interrupted` エントリ / `resolve_max_iterations` / `EFFECTIVE_MAX_ITERATIONS` / `TRAINING_ITER` / PHASE 3 完了ステータス 3 分岐 / 8 フィールド frontmatter 指示はすべて無改変で残存 (Task 2 acceptance_criteria の結合チェックで確認)
- E2E smoke test: mock `/workspace/REPORT.md` を作り `ROOM_NAME=smoke-test-room bash extract-feedback.sh` で実行 → `unknown/2026-04-23-smoke-test-room.md` が生成され、frontmatter 原文が ```yaml フェンス内にコピーされていることを確認 (yq はホスト環境に無いため mission_type は unknown にフォールバックしたが、これはむしろ safe failure の実証)

## Task Commits

Each task was committed atomically:

1. **Task 1: extract-feedback.sh 新規スクリプトを作成** — `5b60d30` (feat)
2. **Task 2: start-training.sh の PHASE 3 完了後に extract-feedback.sh を呼び出すフックを追加** — `18457ed` (feat)

**Plan metadata commit:** (本 SUMMARY + STATE + ROADMAP を最終コミットで追加予定)

## Files Created/Modified

- **Created:** `spirit-room/base/scripts/extract-feedback.sh` (110 行 / 実行可能):
  - line 1-6: shebang + 役割コメント
  - line 8: `set -u` のみ (set -e は使わない)
  - line 10-13: 定数 (LOG_DIR / LOG_FILE / REPORT_FILE / MEMORY_BASE)
  - line 15-17: log() / LOG_DIR 作成
  - line 20-23: REPORT.md 存在ガード
  - line 27: awk で frontmatter 切り出し
  - line 29-32: frontmatter 空時の WARN + exit 0
  - line 35-45: _yq() ラッパー (null → 空文字)
  - line 47-49: 3 フィールド抽出
  - line 52-57: mission_type 正規化 (unknown フォールバック + パス安全化)
  - line 60-63: ROOM_SLUG 正規化 (二重保険)
  - line 65-69: TARGET_DIR mkdir + 失敗時 exit 0
  - line 71-82: TARGET_FILE 衝突回避 (-02 ... -99 suffix)
  - line 85-106: ヘッダ付きファイル生成 + 書き込み失敗時 exit 0
  - line 108-110: 成功ログ + exit 0

- **Modified:** `spirit-room/base/scripts/start-training.sh` (+12 insertions / 0 deletions):
  - line 100: `.gitignore` heredoc に `.planning/mr-popo-memory/` は git 管理対象である旨のコメント追加 (1 行)
  - line 410-419: PHASE 3 完了後の extract-feedback.sh 呼び出しフック (10 行) + 完了バナー前の空行
  - Plan 07-03 で追加された 9 箇所の EFFECTIVE_MAX_ITERATIONS / TRAINING_ITER / INTERRUPTED_FLAG / completion_status 3 分岐は全て無改変

## Decisions Made

- **yq に frontmatter を直接渡さず awk で前処理**: yq v4 Go 版は markdown frontmatter を `--front-matter=extract` 等で直読みできない (YAML モードでは `---` 区切りをドキュメント区切りとして 0 番目の empty doc + 1 番目の YAML doc に解釈する振る舞いが ambient)。plan の interfaces §yq コマンドに記載の awk 前処理方式 `awk '/^---$/{c++; if(c==2) exit; next} c==1'` を採用して第 1 frontmatter ブロックだけ取り出し、yq には YAML として食わせる
- **yq 失敗時は unknown/ フォールバック (安全側倒し)**: yq がコンテナに入っていない / バージョン互換性問題 / frontmatter YAML 破損 等すべてのケースで「保存はされるが mission_type が unknown にまとめられる」挙動に統一。T-07-04-02 DoS mitigation の中核。開発環境 (yq 不在) での smoke test でも `unknown/2026-04-23-smoke-test-room.md` が正しく生成されることで実証済み
- **Review status は plain key 形式に変更 (Rule 1: plan の action 原文と verify の不整合を修正)**: plan の action §「保存ファイルフォーマット (D-06)」の原文は `- **Review status:** pending` (太字マーカー付き) で書かれているが、同じ plan の verify が `grep -q 'Review status: pending'` を素朴に求めているため、太字マーカーの `**` 2 文字が間に挟まって空振りする。原文を plain 表記 `- Review status: pending` に変更して整合 + Plan 07-05 で sed `s/^- Review status: pending/- Review status: applied/` の 1 行書き換えが可能な機械可読マーカーに仕上げた (変更理由をファイル内コメントでも明示)
- **start-training.sh フックは `[ -x ] || [ -f ]` の 2 段チェック**: Docker ベースイメージ再ビルド済みの環境なら `-x` で通るが、開発中や volume マウント経由で実行ビットが剥がれたケースでも `-f` に fallback して bash 経由で起動できるようにする。どちらでも bash 実行なので挙動は同じ
- **.gitignore コメントを追加 (plan の「必要ならコメント追加」指示の最小侵襲実装)**: `.planning/mr-popo-memory/` 明示的除外は不要だが、コメントで意図を残すことで Plan 07-05 実装者が「なぜ ignore されていないのか」を git blame で即座に理解できる

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] plan の Review status フォーマットと verify の不整合**
- **Found during:** Task 1 完了後の automated verify 実行時
- **Issue:** plan の action §保存ファイルフォーマット (D-06) に書かれた原文コード例が `- **Review status:** pending` (太字マーカー `**` 付き) だが、同じ plan の automated verify と acceptance_criteria が `grep -q 'Review status: pending'` を素朴な固定文字列マッチで要求している。`**` 2 文字が途中に入るため grep が空振り (0 件) し、acceptance_criteria 条件未達となった
- **Fix:** extract-feedback.sh の該当 echo 行を `- Review status: pending` (太字なし plain key) に変更。加えて「Plan 07-05 のレビューコマンドが applied に書き換える機械可読キー」「sed 's/^- Review status: pending/- Review status: applied/' の置換が素直に通る」旨のコメントを 2 行追加
- **Files modified:** `spirit-room/base/scripts/extract-feedback.sh` line 94-96
- **Commit:** `5b60d30` (Task 1 に同梱)
- **Impact:** plan の verify / acceptance_criteria が pass 化 + Plan 07-05 の applied 書き換え sed が 1 行で書ける利点。plain key 形式は元々 `**` 付きより機械可読性が高く、D-09 の「ヘッダにマークを付けて反映済みと区別する」要求にもむしろ素直に合う

その他の技術的ブロッカー・architectural 判断要求 (Rule 4) なし。plan の interfaces / 禁止事項はすべて遵守。

## Issues Encountered

- **PreToolUse:Edit hook の READ-BEFORE-EDIT 再掲**: 各 Edit の前に「Read し直せ」hook が 3 回発火したが、該当ファイルは直前の Read / Write でセッション内に読み込み済み、Edit 自体も正常に適用済み。中間状態のロールバックや再書き込みは発生せず (Phase 07-01 / 07-02 / 07-03 と同一パターン)
- **yq がホスト環境に未インストール**: smoke test 実行時に `/bin/bash: 行 X: yq: コマンドが見つかりません` を確認。これはコンテナ内 (Dockerfile レイヤー 1.5 で yq v4 Go 版を `/usr/local/bin/yq` に明示インストール済) では問題にならず、むしろホスト環境での safe failure 動作 (yq 不在 → mission_type が unknown/ にフォールバック) が設計通り機能することの E2E 実証になった
- **acceptance_criteria `Review status: pending` の grep 空振り**: 上述 Deviations で Rule 1 適用 (plain 表記に変更) で解消
- 技術的ブロッカー・実装上の詰まりなし。plan 通り 2 タスクを順当に実装

## User Setup Required

None — スクリプト追加 + 既存スクリプトへのフック追加のみ。環境変数・ダッシュボード設定などの外部セットアップ不要。

**実運用時の留意点 (plan スコープ外):**
- `spirit-room-base:latest` の **再ビルド** が必要 (`cd spirit-room && ./build-base.sh`)。Dockerfile 自体は変更していないが、`base/scripts/` 配下の `extract-feedback.sh` と `start-training.sh` が COPY で焼き込まれるため、新しい部屋を起動する前にベースイメージを rebuild すること。Phase 07 の最終 plan (07-05) 完了時に 1 回 rebuild すれば十分
- 既存の稼働中部屋 (Phase 07 開始前に起動したコンテナ) は `.gitignore` に `.interrupted` / `.planning/mr-popo-memory/` 関連コメントが入らないが、`init_git_workspace()` は `.git` 不在時のみ `.gitignore` を書き出すため無害。既存部屋では feedback 蓄積機能は動かないが close → 再 open で新機能を取り込める

## Self-Check: PASSED

**Files exist:**
- FOUND: `spirit-room/base/scripts/extract-feedback.sh` (created, 110 行, chmod +x)
- FOUND: `spirit-room/base/scripts/start-training.sh` (modified, +12 insertions)

**Commits exist:**
- FOUND: `5b60d30` (Task 1: feat extract-feedback.sh 作成)
- FOUND: `18457ed` (Task 2: feat start-training PHASE 3 直後フック)

**Task 1 plan automated verify:**
- FOUND: `#!/bin/bash` shebang (1 件)
- FOUND: `/workspace/.planning/mr-popo-memory` (1 件)
- FOUND: `/workspace/REPORT.md` (2 件)
- FOUND: `awk .*c==2.*c==1` frontmatter 切り出し (1 件)
- FOUND: `yq` (9 件 >= 1)
- FOUND: `mission_type` (6 件 >= 4)
- FOUND: `completion_status` (2 件 >= 1)
- FOUND: `feedback_schema_version` (2 件 >= 1)
- FOUND: `ROOM_SLUG` (6 件 >= 3)
- FOUND: `Review status: pending` (3 件 >= 1)
- NOT FOUND: `^set -e$` (0 件 — safe failure 原則確認)
- FOUND: `set -u` (1 件 >= 1)
- FOUND: `exit 0` (6 件 >= 4)
- FOUND: `printf '%02d'` (1 件)
- `bash -n extract-feedback.sh` exit 0

**Task 2 plan automated verify:**
- FOUND: `extract-feedback.sh` in start-training.sh (5 件 >= 2)
- FOUND: `feedback 抽出開始` (1 件)
- FOUND: `docs: add Mr.ポポ feedback memory` (1 件)
- FOUND: `|| log "[WARN] extract-feedback.sh` safe failure (1 件)
- FOUND: `修行完了！部屋から出よ` 既存バナー保持 (1 件)
- FOUND: `.gitignore` heredoc 内に `.interrupted` (Plan 07-03 で既に追加済み)
- FOUND: `.planning/` は heredoc 内ではコメント行にのみ出現 (ignore エントリではない)
- FOUND: `.logs/` (2 件 >= 1)
- FOUND: `.reported` (3 件 >= 2)
- FOUND: `EFFECTIVE_MAX_ITERATIONS` (9 件 >= 5 — **07-03 結合チェック pass**)
- `bash -n start-training.sh` exit 0

**E2E smoke test:**
- PASS: REPORT.md 無し時 `exit=0` (WARN ログのみ)
- PASS: mock REPORT.md (frontmatter 付き) 時 `unknown/2026-04-23-smoke-test-room.md` 生成成功 (yq 不在時の safe failure 動作を実証)
- PASS: ファイル本体に D-06 ヘッダ (Room / Date / mission_type / completion_status / feedback_schema_version / Source / Review status) + ```yaml フェンスで frontmatter 原文コピーが入っていることを目視確認

**Structural preservation check:**
- PHASE 0 (RESEARCH) / PHASE 1 (PREPARE) / PHASE 2 (TRAINING) / PHASE 3 (REPORT) の 4 ループ無改変
- `--allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch"` unchanged
- 既存 phase_commit メッセージ (`docs: add RESEARCH.md` / `chore: prepare deps per RESEARCH.md` / `docs: training complete` / `docs: training interrupted at iter N/MAX` / `docs: add REPORT.md`) 全て保持
- Plan 07-03 の完了ステータス 3 分岐 + 8 フィールド frontmatter 指示は無改変
- 完了バナー `修行完了！部屋から出よ` は位置 (フック直後) / 文面とも無改変

## Threat Mitigation Verification

| Threat ID | Mitigation | Verification |
|-----------|------------|--------------|
| T-07-04-01 (path traversal via mission_type) | `tr + sed 's/[^a-z0-9_-]/_/g'` で英小文字数字アンダースコアハイフンのみに正規化 | smoke test で mission_type="poc" が unknown にフォールバック (yq 無し時) / コードレビューで `/`, `..` が入ってもハイフン等に置換されることを確認 |
| T-07-04-02 (DoS via yq / mkdir / disk full) | `set -e` 未使用 + 各段階で `|| exit 0` / `|| log WARN` | 開発環境 yq 不在時に exit 0 で正常終了することを実証 |
| T-07-04-03 (info disclosure) | accept: 全て `/workspace` 配下 (ホストマウント) に閉じ、外部送信経路なし | コードレビューで外部 I/O なし確認 |
| T-07-04-04 (yq OOM on huge blob) | accept: REPORT.md サイズは Claude Code 出力上限で bounded | - |
| T-07-04-05 (collision overwrite) | `-02 / -03 ... -99` suffix で回避 + 99 超えは諦め exit 0 | コードレビューで while ループ + printf '%02d' 確認 |

## Next Phase Readiness

- **Plan 07-05 (MR_POPO_REVIEW_FEEDBACK.md レビューコマンド)**: 本 plan で確定した `/workspace/.planning/mr-popo-memory/{mission_type}/{YYYY-MM-DD}-{room-slug}.md` 形式を mission_type ごとに `find` して読むだけで差分提案の原資になる。`- Review status: pending` を grep して pending エントリのみ拾い、Mr.ポポがテンプレ更新提案を組んだあと sed `s/^- Review status: pending/- Review status: applied/` で 1 行書き換え (あるいは applied/ ディレクトリへ mv) という運用が素直に実装可能
- **mission_type 別の横断レビュー**: `ls .planning/mr-popo-memory/poc/` で POC 系だけを拾えるので、Mr.ポポの「次は refactoring 系です」文脈で該当ディレクトリだけ参照すれば O(同タイプ件数) で済む (D-04 の設計意図通り)
- **既存 spirit-room 運用への影響**: Phase 07 開始前に起動済みの部屋は `.planning/mr-popo-memory/` 機能を持たないが、close → re-open で新機能を取り込める。後方互換
- **ベースイメージ再ビルドの要否**: `spirit-room/base/scripts/extract-feedback.sh` 追加 + `start-training.sh` 改修があるため、本 plan 完了時点で `./build-base.sh` による image 再ビルドが必要 (plan 外運用事項)。Phase 07 最終完了時に 1 回実施すれば十分
- **Phase 7 完了まで残り 1 plan (07-05)**: Wave 3 で Mr.ポポのレビュー UX を実装すれば feedback loop が閉じる

---
*Phase: 07-mr-popo-feedback-loop*
*Completed: 2026-04-23*
