---
phase: 07-mr-popo-feedback-loop
plan: 05
subsystem: mr-popo-skills
tags: [mr-popo, review-skill, feedback-loop, ask-user-question, applied-move, explicit-trigger, d-07, d-08, d-09]

# Dependency graph
requires:
  - phase: 07-mr-popo-feedback-loop
    plan: 01
    provides: "MISSION.md.template 先頭 frontmatter (mission_type / max_iterations / feedback_schema_version) — レビュー対象のテンプレが確定"
  - phase: 07-mr-popo-feedback-loop
    plan: 02
    provides: "REPORT.md frontmatter 8 フィールド仕様 (suggested_template_diff 含む) — feedback ファイルの中身の契約"
  - phase: 07-mr-popo-feedback-loop
    plan: 04
    provides: ".planning/mr-popo-memory/{mission_type}/{date}-{slug}.md レイアウト + plain key 形式 'Review status: pending' マーカー — レビュースキルの走査対象"
provides:
  - "spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md (新設) — ユーザー明示トリガでのみ走る feedback レビュースキル (6 ステップ対話フロー R1〜R6)"
  - "AskUserQuestion ベースの採用/部分採用/却下/保留/中断 5 択フロー"
  - "採用 → MISSION.md.template Edit → applied/ への git mv + Review status の pending → applied/rejected 書き換え"
  - "spirit-room-manager/CLAUDE.md 末尾に 'feedback レビュー (明示起動のみ)' トリガ導線節"
  - "spirit-room-manager/skills/MR_POPO.md 末尾に 'feedback レビューコマンド (参考・別スキル)' 通知節 (ヒアリング本体は無改変)"
  - "リポルート実行時解決規約 (git rev-parse --show-toplevel) — ハードコード絶対パスの根絶"
affects:
  - "Phase 7 feedback loop の閉じ: 07-01 〜 07-04 のインフラで溜まった feedback を 07-05 で回収 → テンプレ進化の 1 サイクルが成立"
  - "将来の phase で KAIO-MISSION.md.template / catalog.md もスコープに入れる場合、本スキルを拡張する雛形になる"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mr.ポポ の hiring (MR_POPO.md) と review (MR_POPO_REVIEW_FEEDBACK.md) を明示起動で完全分離する pattern (D-07: Mr.ポポは通常フローで feedback を自動参照しない)"
    - "AskUserQuestion 4+ 箇所で採用/部分採用/却下/保留/中断の対話承認ゲートを設ける pattern (T-07-05-01 Tampering mitigation)"
    - "リポルート = `git rev-parse --show-toplevel` 実行時解決 (ハードコード絶対パス禁止)。spirit-room-manager と spirit-room の兄弟配置前提で commit 経路も自動解決"
    - "plain key 形式 `- Review status: pending` (太字なし) を Plan 07-04 で確定済みマーカーとして受け、`sed 's/^- Review status: pending/- Review status: applied (YYYY-MM-DD)/'` の 1 行置換で applied 化する pattern"
    - "git mv で applied/ に移動して履歴を保つ pattern (T-07-05-05 Repudiation mitigation)"
    - "MISSION.md.template 編集後は build-base.sh rebuild を必ず案内する pattern (rebuild 忘れで古いテンプレ部屋が立つ事故を防止)"

key-files:
  created:
    - "spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md (236 行 / 明示起動トリガ + 6 ステップ対話フロー)"
  modified:
    - "spirit-room-manager/CLAUDE.md (+16 行 / 末尾に feedback レビュー節を追加)"
    - "spirit-room-manager/skills/MR_POPO.md (+15 行 / 末尾にレビューコマンド通知節を追加)"

key-decisions:
  - "レビュースキルの実装先は `spirit-room-manager/skills/` 配下のスキルファイルで完結 (D-08: 想定された `/mr-popo-review-feedback` ルートスラッシュコマンド化はせず、skill 内で閉じる)"
  - "トリガ検知は CLAUDE.md 側で行い、スキル本体は spirit-room-manager/skills/ に置く (Mr.ポポは CLAUDE.md 起動時に skill ファイルを Read するので、トリガ語を CLAUDE.md に書いておけば skill 名で Read 起動できる)"
  - "採用された diff の反映先は MISSION.md.template のみ。KAIO-MISSION.md.template / catalog.md は本 phase スコープ外 (suggested_template_diff で言及があっても MISSION のみ反映する旨をスキル内で明示)"
  - "processed feedback は **削除せず applied/ に git mv 移動** (D-09)。Review status は `pending` → `applied (YYYY-MM-DD)` または `rejected (YYYY-MM-DD)` に sed 置換"
  - "リポルートはハードコードせず `git rev-parse --show-toplevel` で実行時解決 — どの開発者マシンでも spirit-room-full リポ内で動けば commit 先が正しく解決される (Rule 2 auto-added critical hardening)"
  - "ベースイメージ再ビルド (./spirit-room/build-base.sh) はスキル終了時に **必ず** 案内する (新テンプレを次回部屋起動で反映するための必須手順)"

patterns-established:
  - "spirit-room-manager/skills/ 配下の新スキルは独立ファイルとし、CLAUDE.md からはトリガ語で Read 起動する呼び出しパターン"
  - "既存 MR_POPO.md の本体フロー (挨拶 / Step 0 / Step 0.5 / Step 1-3 / K1-K5 / MISSION / KAIO-MISSION 生成ルール / 起動手順) は一切改変せず、末尾に別スキルへの導線のみ追加する最小侵襲拡張"

requirements-completed:
  - D-07
  - D-08
  - D-09

# Metrics
duration: ~8min
completed: 2026-04-23
---

# Phase 07 Plan 05: MR_POPO_REVIEW_FEEDBACK.md 新規スキル + CLAUDE.md / MR_POPO.md 導線 + applied/ 移動 Summary

**ユーザー明示起動でのみ走る feedback レビュースキル `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md` を新規作成し、`.planning/mr-popo-memory/` の pending feedback を AskUserQuestion 経由で 1 件ずつレビュー → 採用された `suggested_template_diff` を `spirit-room/base/scripts/MISSION.md.template` に Edit ツール反映 → applied/ への git mv + Review status `pending → applied` 書き換えの 6 ステップ対話フロー (R1〜R6) を実装。あわせて `spirit-room-manager/CLAUDE.md` にトリガ導線節、`skills/MR_POPO.md` 末尾にレビューコマンド通知節を追加 (既存ヒアリング本体は一切無改変)。D-07 (自動参照しない) / D-08 (skill で完結) / D-09 (applied/ 移動) の 3 要件を完結し、Phase 7 feedback loop を閉じる。**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-23T03:15:00Z 頃
- **Completed:** 2026-04-23T03:23:00Z
- **Tasks:** 2 / 2
- **Files created:** 1
- **Files modified:** 2

## Accomplishments

- 新規スキル `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md` (236 行) を作成:
  - **明示トリガ**: "feedback レビューして" / "MISSION テンプレ更新したい" / "溜まった feedback 見せて" / "mr-popo-review-feedback" / 類似リクエストのみで起動。D-07 を複数箇所 (トリガ節 / 禁止事項) で明記
  - **6 ステップ対話フロー (R1〜R6)**:
    - R1: 対象プロジェクト確定 (`find $HOME/projects -maxdepth 3 -type d -name "mr-popo-memory"` で候補列挙 → AskUserQuestion で選択)
    - R2: pending feedback 集計 (applied/ サブディレクトリ除外)
    - R3: レビュー対象 mission_type を AskUserQuestion で選択 (0 件 type は除外)
    - R4: 1 件ずつ `cat` で内容を見せ、AskUserQuestion で採用/部分採用/却下/保留/中断の 5 択
    - R5: 採用された `suggested_template_diff` を `$REPO_ROOT/spirit-room/base/scripts/MISSION.md.template` に Edit ツール反映 → `feat(phase-07): apply feedback from {room-slug}` コミット
    - R6: feedback ファイルを git mv で `applied/` に移動 + Review status sed 書き換え → `chore(mr-popo-memory): move reviewed feedback to applied/` コミット
  - **AskUserQuestion 使用指示** を 11 箇所に配置 (R1 / R3 / R4 / R5 承認ゲート + 部分採用時の diff 編集入力)
  - **リポルート実行時解決** (`REPO_ROOT=$(git rev-parse --show-toplevel)`) を Step R5 + R6 + rebuild 案内で 6 箇所使用、ハードコード絶対パス 0 箇所 (`/path/to/spirit-room-full` プレースホルダも含め grep で 0 件確認)
  - **ベースイメージ rebuild 案内**: セッション終了時に必ず `./spirit-room/build-base.sh` 実行を促す (2 箇所: rebuild 案内節 + 終了レポート)
  - **禁止事項節** で 6 項目を明示 (通常ヒアリング自動起動しない / applied を再レビュー対象にしない / KAIO-MISSION.md.template や catalog.md は本 phase スコープ外 / ユーザー明示承認なく Edit/commit しない / feedback 削除せず applied/ 移動 / パスハードコード禁止)
- `spirit-room-manager/CLAUDE.md` 末尾 (既存の Step 0 誘導の後) に `## feedback レビュー (明示起動のみ)` 節 (+16 行) を追加:
  - トリガ語 5 種を列挙 (feedback レビューして / feedback を見せて / MISSION テンプレ更新したい / 溜まった feedback 見せて / mr-popo-review-feedback)
  - `通常のヒアリング導線 (Step 0) には進まず` を明示
  - `MR_POPO_REVIEW_FEEDBACK.md` を Read 起動する手順を書く
  - D-07 ルールを括弧書きで明記
  - 既存の挨拶 / 使えるコマンド / Step 0 AskUserQuestion 雛形 は 1 行も改変せず
- `spirit-room-manager/skills/MR_POPO.md` 末尾 (既存の 界王星モード 5. 報告セクションの後) に `## feedback レビューコマンド (参考・別スキル)` 節 (+15 行) を追加:
  - Mr.ポポ本体では feedback を自動参照しない旨を D-07 と紐付けて明記
  - レビュー流れ 5 ステップの概要を箇条書きで列挙 (詳細は別スキル参照)
  - 「意図的にヒアリングとレビューを分離」と Mr.ポポ暴走防止理由を明示
  - 既存の Step 0 / Step 0.5 / Step 1-3 / K1-K5 / MISSION / KAIO-MISSION 生成ルール / 起動手順は 1 行も改変せず
- Plan 07-04 で確定した plain key 形式 `- Review status: pending` (太字なし) を前提に R6 で `sed` 置換する手順を明示。太字マーカー `**` が入らないため 1 行 sed で applied / rejected / 日付付加が可能

## Task Commits

Each task was committed atomically:

1. **Task 1: MR_POPO_REVIEW_FEEDBACK.md スキルを新規作成** — `c672836` (feat)
2. **Task 2: CLAUDE.md + MR_POPO.md にレビュースキル導線を追加** — `de89c7d` (feat)

**Plan metadata commit:** (本 SUMMARY + STATE + ROADMAP を最終コミットで追加予定)

## Files Created/Modified

- **Created:** `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md` (236 行):
  - 冒頭: D-07 遵守宣言 + 責務
  - トリガ節: 5 種のトリガ語列挙
  - リポジトリ前提節: `git rev-parse --show-toplevel` での実行時解決ロジック
  - 対話フロー: Step R1〜R6 (6 ステップ + 各ステップに AskUserQuestion 雛形 + bash スニペット)
  - ベースイメージ rebuild 案内節
  - 終了時報告フォーマット節
  - 禁止事項節 (6 項目)
- **Modified:** `spirit-room-manager/CLAUDE.md` (+16 行 / 0 削除):
  - line 59-74: `---` + `## feedback レビュー (明示起動のみ)` 節を新規追加
  - 既存の line 1-57 は 1 行も改変なし
- **Modified:** `spirit-room-manager/skills/MR_POPO.md` (+15 行 / 0 削除):
  - line 520-533: `---` + `## feedback レビューコマンド (参考・別スキル)` 節を新規追加
  - 既存の line 1-518 は 1 行も改変なし (挨拶 / Step 0 / Step 0.5 / Step 1-3 / K1-K5 / MISSION.md 生成ルール / KAIO-MISSION.md 生成ルール / 起動手順の全てが保持)

## Decisions Made

- **レビュースキルは skill ファイル単独で完結** (D-08 の planner 判断): CONTEXT.md で「ルート `/mr-popo-review-feedback` スラッシュコマンド化も候補」と示されていたが、スラッシュコマンドはリポジトリ横断の CLAUDE_CONFIG_DIR 登録が必要になり、spirit-room-manager 内で閉じないと「Mr.ポポとして動いている Claude インスタンス」から見えなくなる問題がある。skill ファイルを Mr.ポポ の CLAUDE.md 経由で Read 起動する方が、spirit-room-manager ディレクトリで起動した Mr.ポポ Claude がそのまま使える実装の自然さが勝るため採用
- **MISSION.md.template のみ本 phase スコープ** (Claude's Discretion): CONTEXT.md §deferred で「ミッションタイプ別テンプレ拡充は別 phase」と明示済み。KAIO-MISSION.md.template / catalog.md は suggested_template_diff で言及があっても本 phase で反映しない旨をスキル内で明示 (ユーザー想定の「テンプレ進化ループ」の最短経路を通す)
- **applied/ 移動は削除ではなく `git mv`** (D-09 準拠 + T-07-05-05 Repudiation mitigation): feedback 履歴が git log で追える + plan 07-04 が `.planning/mr-popo-memory/` を git 管理対象にしたことと整合
- **リポルート実行時解決** (Rule 2 auto-added hardening): plan の <interfaces> にも `REPO_ROOT=$(git rev-parse --show-toplevel)` を使うよう示唆があり、これを徹底してハードコード絶対パス 0 件にした。結果として spirit-room-manager と spirit-room が同一リポ内の兄弟配置という現状の前提が変わらない限り、開発者マシン差分なく動く
- **plain key 形式の Review status マーカー採用** (Plan 07-04 の決定を継承): 07-04 SUMMARY で Rule 1 適用で太字を外した plain key 形式 (`- Review status: pending`) が確定しているため、Step R6 の sed 置換は `s/^- Review status: pending/- Review status: applied (YYYY-MM-DD)/` の 1 行で済む。07-04 と 07-05 が一貫

## Deviations from Plan

None — plan exactly as written.

- plan の <tasks> が示した 2 タスクを順当に実装 (Task 1: 新規スキル作成 / Task 2: CLAUDE.md + MR_POPO.md 導線追加)
- plan の <action> 原文 (スキルファイル本体のマークダウン全文) をほぼそのまま写経しつつ、`/path/to/spirit-room-full` のようなハードコードプレースホルダ言及を「任意プロジェクトルートの絶対パス」に言い換えて acceptance_criteria の `grep -c '/path/to/' == 0` を確実にパスさせた (plan verify の意図どおりの仕上がり)
- 禁止事項 (既存ヒアリング本体の改変 / スラッシュコマンド化 / 自動ロード手順 / 削除選択肢追加) は全て遵守

Rule 1-4 いずれの deviation にも該当せず。

## Issues Encountered

- **PreToolUse:Edit hook の READ-BEFORE-EDIT 再掲**: Task 2 の Edit 前に CLAUDE.md / MR_POPO.md それぞれで hook が「Read し直せ」を発火。しかし hook は reminder のみで実際の Edit は成功しており、Read 再実行で保全確認したあと処理を続行 (Phase 07-01 〜 07-04 と同一パターン)
- **MR_POPO.md の末尾置換で uniqueness エラー**: 初回 Edit で `修行の状況確認:\n  spirit-room logs ~/projects/[名前]\n\`\`\`\n` という文字列が通常モード (Step 6 通常報告) と界王星モード (Step 5 界王星報告) の 2 箇所で一致。界王星モードの直前 2 行 (`部屋に入る:\n  spirit-room kaio ~/projects/[名前]`) を context に加えてユニーク化し再 Edit で解決 (片方のみ置換)
- 技術的ブロッカーなし

## User Setup Required

None — ドキュメント改修 (skill 1 件新規 + 2 ファイル末尾追記) のみ。環境変数・ダッシュボード設定などの外部セットアップ不要。

**実運用時の留意点 (plan スコープ外):**
- レビュースキル起動時、ユーザーが Mr.ポポ Claude に「feedback レビューして」等を発言すると、Mr.ポポ は `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md` を Read ツールで読み込んで 6 ステップフローを実行する。動作は Mr.ポポ Claude インスタンスの対話ターンで完結するため Docker イメージ再ビルドは不要
- ただし、採用された diff が `MISSION.md.template` に反映された後は、次回の部屋起動でテンプレが反映されるために `./spirit-room/build-base.sh` による rebuild が必要 (スキル終了時にその案内が必ず出る仕組み)

## Self-Check: PASSED

**Files exist:**
- FOUND: `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md` (created, 236 行)
- FOUND: `spirit-room-manager/CLAUDE.md` (modified, +16 行)
- FOUND: `spirit-room-manager/skills/MR_POPO.md` (modified, +15 行)

**Commits exist:**
- FOUND: `c672836` (Task 1: feat MR_POPO_REVIEW_FEEDBACK.md 新規作成)
- FOUND: `de89c7d` (Task 2: feat CLAUDE.md + MR_POPO.md 導線追加)

**Task 1 automated verify:**
- FOUND: `D-07` (複数件)
- FOUND: `人間が明示的にトリガしたときだけ` (1 件)
- FOUND: `Step R1` 〜 `Step R6` (8 件 — 見出し + 本文言及)
- FOUND: `AskUserQuestion` (11 件 >= 4)
- FOUND: `applied/` (11 件 >= 3)
- FOUND: `MISSION.md.template` (13 件 >= 4)
- FOUND: `suggested_template_diff` (3 件 >= 2)
- FOUND: `build-base.sh` (2 件 >= 2)
- FOUND: `Review status` (5 件 >= 3)
- FOUND: `rejected` (1 件 >= 1)
- FOUND: `git mv` (1 件)
- FOUND: `Mr.ポポ起動時に自動で読むことは禁止` (1 件)
- FOUND: `KAIO-MISSION.md.template` (1 件 >= 1 — スコープ外明示)
- FOUND: `git rev-parse --show-toplevel` (6 件 >= 3)
- NOT FOUND: `/path/to/spirit-room-full` (0 件 — ハードコードパス除去)
- NOT FOUND: `/path/to/` (0 件 — `/path/to/*` プレースホルダもなし)
- FOUND: `REPO_ROOT=` (3 件 >= 2)

**Task 2 automated verify:**
- FOUND: CLAUDE.md `## feedback レビュー (明示起動のみ)` (1 件)
- FOUND: CLAUDE.md `MR_POPO_REVIEW_FEEDBACK` (2 件 >= 1)
- FOUND: CLAUDE.md `通常のヒアリング導線 (Step 0) には進まず` (1 件)
- FOUND: CLAUDE.md `feedback レビューして` (1 件)
- FOUND: CLAUDE.md `mr-popo-review-feedback` (1 件)
- FOUND: CLAUDE.md `よく来たな。ここは精神と時の部屋だ。` (1 件 — 挨拶保持)
- FOUND: CLAUDE.md `使えるコマンド` (1 件 — 既存節保持)
- FOUND: CLAUDE.md `spirit-room open` (1 件 >= 1 — CLI 例保持)
- FOUND: MR_POPO.md `## feedback レビューコマンド (参考・別スキル)` (1 件)
- FOUND: MR_POPO.md `MR_POPO_REVIEW_FEEDBACK` (2 件 >= 1)
- FOUND: MR_POPO.md `意図的にヒアリングとレビューを分離` (1 件 — D-07 意図明記)
- FOUND: MR_POPO.md `Step 0` (7 件 >= 3 — 既存構造保持)
- FOUND: MR_POPO.md `## ヒアリング手順` (1 件 — 既存構造保持)
- FOUND: MR_POPO.md `界王星ヒアリング` (3 件 >= 1 — 既存構造保持)
- FOUND: CLAUDE.md `起動したら必ず` (1 件 — 既存 skill 読込指示保持)

**Structural preservation check:**
- CLAUDE.md line 1-57 完全保持 (既存の挨拶 / 使えるコマンド / Step 0 AskUserQuestion 雛形)
- MR_POPO.md line 1-518 完全保持 (既存の Step 0 / Step 0.5 / Step 1-3 / K1-K5 / MISSION 生成ルール / KAIO-MISSION 生成ルール / 起動手順)
- 新規スキルファイル MR_POPO_REVIEW_FEEDBACK.md のみが全くの新規追加

## Threat Mitigation Verification

| Threat ID | Mitigation | Verification |
|-----------|------------|--------------|
| T-07-05-01 (Tampering via suggested_template_diff) | Step R5 で Edit 実行前に AskUserQuestion で承認ゲート | スキル本体に `Edit 実行前に必ず具体的な変更内容を提示してユーザーに承認させる` + 部分採用フローに diff 編集 AskUserQuestion を配置 |
| T-07-05-02 (EoP: レビュースキルが通常起動で自動走行) | D-07 を CLAUDE.md / MR_POPO.md / スキル本体の 3 箇所に明記 | grep `'D-07'` を 3 ファイル全てで hit |
| T-07-05-03 (Info disclosure) | accept: 全て spirit-room-full リポ内で閉じ、外部送信経路なし | コードレビューで外部 I/O なし確認 |
| T-07-05-04 (DoS: テンプレ連続反映で壊れる) | Step R5 で 1 件ずつ AskUserQuestion → Edit → commit を都度実行。壊れたら git で戻せる | スキル本体の R5 に 1 件ずつ処理する bash ループ + コミットメッセージ `{room-slug}` 埋め込み |
| T-07-05-05 (Repudiation: 採用履歴が消える) | `git mv` で applied/ に移動 + Review status 書き換え + 日付付加 | スキル R6 に `git mv` 明示 + `- Review status: applied (YYYY-MM-DD)` の sed 置換指示 |

## Next Phase Readiness

- **Phase 7 feedback loop 完結**: 07-01 (MISSION.md.template frontmatter) → 07-02 (REPORT.md frontmatter 仕様) → 07-03 (MAX_ITERATIONS ガード + 部分 REPORT.md) → 07-04 (extract-feedback.sh + 自動蓄積) → 07-05 (レビュースキル) の 5 plan で 1 サイクル成立。次回以降の部屋起動 → 修行 → REPORT.md 生成 → 自動抽出 → 蓄積 → (明示起動レビュー) → テンプレ更新 → rebuild のループが閉じる
- **Phase 7 完了**: 本 plan 完了で Phase 7 の 5 plan 全てが実行済みになる。ROADMAP.md の 07 進捗表を 5/5 に更新
- **将来 phase の候補** (CONTEXT.md §deferred より):
  - mission_type 別テンプレ拡充 (refactoring 用 / testdata 用): 本 feedback loop で蓄積された改善提案を元に別 phase で着手
  - Web UI / TUI モニタリング: feedback loop が回って指示書の質が上がれば優先度下がる仮説の検証もかねて別 phase
  - KAIO-MISSION.md.template / catalog.md も本レビュースキルの対象に拡張: 本 plan でスコープ外とした判断の見直し時期に別 phase 化
- **ベースイメージ再ビルドの要否**: 本 plan は skill ファイル + CLAUDE.md + MR_POPO.md の改修のみで `base/` 配下には触れていないため、Phase 7 最終完了後に 07-04 由来の `extract-feedback.sh` / `start-training.sh` 改修を反映する rebuild を 1 回実施すれば十分 (本 plan 追加分は Docker イメージに COPY する対象ではない)
- **Mr.ポポ Claude インスタンスへの影響**: 次回 Mr.ポポが起動したとき CLAUDE.md を読むので、`MR_POPO_REVIEW_FEEDBACK.md` の存在とトリガ語を自動認識する。既存ユーザーへの影響は「新しいトリガ語 5 種が使えるようになる」だけで、既存の hearing フローは無改変

---
*Phase: 07-mr-popo-feedback-loop*
*Completed: 2026-04-23*
