---
phase: 07-mr-popo-feedback-loop
plan: 01
subsystem: training-templates
tags: [mission-template, yaml-frontmatter, mr-popo, hiring-workflow, feedback-loop, mission-type]

# Dependency graph
requires:
  - phase: 06-spirit-room-docker-docker-compose
    provides: "精神と時の部屋 + 界王星モードの基盤 CLI (--kochou / --docker) と既存 Mr.ポポ hiring workflow。Step 0 / K1〜K5 のベース構造"
provides:
  - "MISSION.md.template 先頭の YAML frontmatter (mission_type / max_iterations / feedback_schema_version) 標準"
  - "KAIO-MISSION.md.template 先頭の YAML frontmatter (mission_type: kaio 固定, max_iterations: 100)"
  - "Mr.ポポ hiring workflow の Step 0.5 mission_type 選択質問 (poc / refactoring / testdata / investigation)"
  - "Mr.ポポの MISSION.md / KAIO-MISSION.md 生成ルール節に frontmatter 書き込み指示"
affects:
  - "07-02 REPORT.md YAML frontmatter 仕込み (同名 mission_type キーを使う)"
  - "07-03 start-training.sh MAX_ITERATIONS ガード (MISSION.md の max_iterations 上書きソース②)"
  - "07-04 feedback 自動抽出 + .planning/mr-popo-memory/{mission_type}/ 保存 (mission_type でディレクトリ分岐)"
  - "07-05 レビューコマンド (mission_type ごとの feedback 絞り込みキー)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MISSION.md 先頭の YAML frontmatter (mission_type / max_iterations / feedback_schema_version) を 3 フィールド最小で持つ pattern"
    - "mission_type の初期語彙 4 種 (poc / refactoring / testdata / investigation) + kaio (界王星専用固定)"
    - "max_iterations のデフォルト値は mode 別に分岐 (精神と時の部屋=50 / 界王星=100)"
    - "D-07 遵守: Mr.ポポ本体は起動時に過去 feedback を自動参照しない (レビューは人間明示起動のみ)"

key-files:
  created: []
  modified:
    - "spirit-room/base/scripts/MISSION.md.template (frontmatter 5 行挿入)"
    - "spirit-room/base/scripts/KAIO-MISSION.md.template (frontmatter 5 行挿入)"
    - "spirit-room-manager/skills/MR_POPO.md (Step 0.5 + MISSION/KAIO-MISSION 生成ルールに frontmatter 指示 4 箇所追記)"

key-decisions:
  - "mission_type の初期語彙は poc / refactoring / testdata / investigation の 4 種。界王星モードは kaio 固定で Step 0.5 はスキップ"
  - "max_iterations デフォルトは精神と時の部屋モード 50 / 界王星モード 100 (GSD 段階開発は長丁場なため 2 倍)"
  - "feedback_schema_version: 1 を frontmatter に含める (D-03 スキーマ変更時の非互換検知根拠)"
  - "frontmatter は最小 3 フィールドに留める (feedback YAML 本体のスキーマは Plan 07-02 で REPORT.md 側に定義)"

patterns-established:
  - "MISSION.md / KAIO-MISSION.md の先頭行は必ず --- で始まる YAML frontmatter ブロックとする"
  - "Mr.ポポの hiring workflow では mission_type の値を Step 0.5 (通常モード) または固定値 (kaio) として確定し、生成する MISSION.md frontmatter に転写する"
  - "既存 hiring フロー (挨拶 / Step 0 / Step 1-3 / K1-K5 / 胡蝶の夢) を改変せず、純粋な追加挿入のみで機能拡張する"

requirements-completed:
  - D-02
  - D-11
  - D-14

# Metrics
duration: ~15min
completed: 2026-04-23
---

# Phase 07 Plan 01: MISSION テンプレ + Mr.ポポに mission_type frontmatter を標準化 Summary

**MISSION.md.template / KAIO-MISSION.md.template の先頭に mission_type / max_iterations / feedback_schema_version の 3 フィールドを持つ YAML frontmatter を追加し、Mr.ポポ skill に Step 0.5 mission_type ヒアリングと frontmatter 書き込み指示を実装**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-23T02:30:00Z 頃
- **Completed:** 2026-04-23T02:49:06Z
- **Tasks:** 2 / 2
- **Files modified:** 3

## Accomplishments

- MISSION.md.template と KAIO-MISSION.md.template の両方に 3 フィールド frontmatter (mission_type / max_iterations / feedback_schema_version) を挿入。既存本文 (修行フェーズ / 目的 / 完了条件 / 制約 等) は削除・改変なし
- Mr.ポポ skill に **Step 0.5: mission_type の選択** 節 (AskUserQuestion で poc / refactoring / testdata / investigation の 4 択) を追加
- MISSION.md 生成ルール節と KAIO-MISSION.md 生成ルール節それぞれに frontmatter 書き込みサンプル + 「先頭の YAML frontmatter は必須」の明示指示を追加
- 界王星モードは `mission_type: kaio` 固定であり Step 0.5 をスキップする旨の注記を K1 直前に挿入
- 既存フロー (挨拶「よく来たな。」/ Step 0 モード選択 / Step 1-3 / K1-K5 / 胡蝶の夢 --kochou) は一切改変せず、追加のみで機能拡張

## Task Commits

Each task was committed atomically:

1. **Task 1: MISSION.md.template / KAIO-MISSION.md.template に YAML frontmatter を追加** - `6b7fa05` (feat)
2. **Task 2: MR_POPO.md に mission_type ヒアリングと frontmatter 書き込み指示を追加** - `d59d355` (feat)

**Plan metadata commit:** (本 SUMMARY + STATE + ROADMAP を最終コミットで追加予定)

## Files Created/Modified

- `spirit-room/base/scripts/MISSION.md.template` - 先頭 5 行に frontmatter (mission_type: poc / max_iterations: 50 / feedback_schema_version: 1) を挿入
- `spirit-room/base/scripts/KAIO-MISSION.md.template` - 先頭 5 行に frontmatter (mission_type: kaio / max_iterations: 100 / feedback_schema_version: 1) を挿入
- `spirit-room-manager/skills/MR_POPO.md` - 4 箇所追記:
  - Step 0 分岐直後に Step 0.5 mission_type 選択節 (AskUserQuestion)
  - MISSION.md 生成ルール節のテンプレ冒頭に frontmatter サンプル
  - 界王星ヒアリング節に mission_type kaio 固定注記
  - KAIO-MISSION.md 生成ルール節に frontmatter 書き込み指示

## Decisions Made

- **初期語彙を 4 + 1 種に絞った** (poc / refactoring / testdata / investigation + kaio): D-14 で planner 判断とされた初期語彙。CONTEXT.md §specifics の推奨通り最小セットで開始し、将来 AskUserQuestion に option を追加するだけで拡張可能
- **max_iterations のデフォルトはモード別に分岐** (精神と時の部屋=50 / 界王星=100): 界王星モードは GSD で requirements → phases → plans → verify → audit → tag を自動で回すため、通常 POC の 2 倍の余裕を初期値に。Plan 07-03 のガード実装時に MISSION.md 側から per-mission 上書きも効く
- **feedback_schema_version: 1 を必須フィールド化**: D-03 のバージョン管理方針を受け、スキーマ変更時の非互換検知の根拠を最初から frontmatter に含める
- **frontmatter は 3 フィールドに留め、feedback 本体のスキーマは REPORT.md 側 (Plan 07-02)**: 責務分離。MISSION.md は入力 (指示書)、REPORT.md は出力 (feedback) という役割分担を徹底

## Deviations from Plan

None - plan executed exactly as written.

計画の <interfaces> に示されたピンポイント改修箇所を 4 箇所それぞれ正確に反映し、禁止事項 (既存挨拶・Step 1-3・K1-K5・胡蝶の夢 --kochou・「過去 feedback を自動で参照」文字列の非挿入) もすべて遵守。Rule 1-4 いずれにも該当する逸脱なし。

## Issues Encountered

- **hook 注意**: 各 Edit 前に PreToolUse:Edit hook が「READ-BEFORE-EDIT REMINDER」を出したが、直前 Edit 自体は正常に apply されていた。以降の Edit ごとに対象ファイルの該当領域を Read してから進めることで解消 (この間、中間状態のロールバックや再書き込みは発生せず)。
- その他の技術的ブロッカーなし。

## User Setup Required

None - ドキュメント改修のみ。環境変数やダッシュボード設定などの外部セットアップ不要。

## Self-Check: PASSED

- ✓ `spirit-room/base/scripts/MISSION.md.template` line 1-5 に frontmatter 存在 (mission_type: poc / max_iterations: 50 / feedback_schema_version: 1)
- ✓ `spirit-room/base/scripts/KAIO-MISSION.md.template` line 1-5 に frontmatter 存在 (mission_type: kaio / max_iterations: 100 / feedback_schema_version: 1)
- ✓ `spirit-room-manager/skills/MR_POPO.md` に Step 0.5 / header "mission_type" / 4 択 label / frontmatter サンプル (通常 + kaio) がすべて存在
- ✓ `git log --oneline` で `6b7fa05` と `d59d355` を確認
- ✓ plan-level must_haves.truths の 5 項目、artifacts の 3 ファイル、key_links の 2 件すべて満たす
- ✓ 既存フロー保持チェック (挨拶 1 件 / AskUserQuestion 25 件 / --kochou 11 件) すべて通過
- ✓ D-07 違反文字列「過去 feedback を自動で参照」0 件

## Next Phase Readiness

- **Plan 07-02 (REPORT.md への MISSION_TEMPLATE_FEEDBACK 仕込み)**: 本 plan で確定した `mission_type` / `feedback_schema_version` キーが REPORT.md の同名 frontmatter キーと一対一で対応する前提で設計可能
- **Plan 07-03 (MAX_ITERATIONS ガード)**: `start-training.sh` は MISSION.md から `max_iterations` フィールドを yq/grep で抜き出せる (上書きソース②)。前提成立
- **Plan 07-04 (feedback 自動抽出 + ディレクトリ振り分け)**: `.planning/mr-popo-memory/{mission_type}/` のディレクトリ分岐キーが MISSION.md frontmatter から取得可能
- **Plan 07-05 (レビューコマンド)**: mission_type での feedback 絞り込みが成立する
- 既存の Mr.ポポ hiring workflow を改変せずに機能拡張できたため、実運用中のユーザーへの影響なし (既存 MISSION.md は frontmatter なしでも後方互換。Plan 07-03 でガードを実装する際に「frontmatter なし = デフォルト 50」の fallback を組み込めばよい)

---
*Phase: 07-mr-popo-feedback-loop*
*Completed: 2026-04-23*
