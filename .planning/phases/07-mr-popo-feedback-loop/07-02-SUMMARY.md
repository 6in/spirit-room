---
phase: 07-mr-popo-feedback-loop
plan: 02
subsystem: training-templates
tags: [create-report, yaml-frontmatter, mission-template-feedback, mr-popo, feedback-loop, report-md]

# Dependency graph
requires:
  - phase: 07-mr-popo-feedback-loop
    plan: 01
    provides: "MISSION.md / KAIO-MISSION.md 先頭の YAML frontmatter (mission_type / max_iterations / feedback_schema_version) 標準 — REPORT.md frontmatter が同名 mission_type / feedback_schema_version キーで整合する前提"
provides:
  - "create-report.md の Step 4 に 2 層構成 (4a Frontmatter + 4b Body) を確立"
  - "REPORT.md 先頭 YAML frontmatter の 8 必須フィールド仕様 (feedback_schema_version / completion_status / mission_type + D-02 の 6 フィールド)"
  - "block scalar `|` による自由記述許容の suggested_template_diff フォーマット"
  - "本文テンプレに ## サマリ エグゼクティブ節を追加 (既存 8 節 + 1 = 9 節構成)"
affects:
  - "07-03 start-training.sh MAX_ITERATIONS ガード発火時に生成する部分 REPORT.md は同 frontmatter スキーマを使う (completion_status: interrupted)"
  - "07-04 extract-feedback.sh が yq で REPORT.md 先頭の frontmatter を抽出し .planning/mr-popo-memory/{mission_type}/ へ保存"
  - "07-05 MR_POPO_REVIEW_FEEDBACK.md が suggested_template_diff を原資にテンプレ差分提案を組む"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "REPORT.md 先頭に `---` 区切りの YAML frontmatter ブロックを置く pattern (MISSION.md.template と同じ規約)"
    - "machine-readable (4a frontmatter) + human-readable (4b markdown body) の 2 層構成による単一ファイル出力"
    - "block scalar `|` を使った複数行テキストフィールド (ambiguous_in_brief / overspecified_in_brief 等)"
    - "欠損値は空行ではなく `\"(なし)\"` 文字列で埋めて yq 抽出側の空行判定を回避する pattern"
    - "D-02 の 6 フィールド + D-03 schema_version + D-13 completion_status の計 8 フィールド固定スキーマ (v1)"

key-files:
  created: []
  modified:
    - "spirit-room/base/scripts/create-report.md (+65 行 / Step 4 の 2 層化 + 4a frontmatter 指示 + 本文テンプレに ## サマリ 追加 + Step 5 直前の最重要注意書き)"

key-decisions:
  - "frontmatter は REPORT.md の **先頭** (line 1) に固定 (D-01 の配置選択肢 先頭 vs 末尾 のうち先頭を採用 — MISSION.md.template と視覚的対称 + yq `--front-matter=extract` で `-1` 指定不要)"
  - "suggested_template_diff は unified diff / 自由記述 両方可の block scalar で許容 (Claude's Discretion の表現形式選択肢のうち両方許容を採用)"
  - "欠損値は `\"(なし)\"` 文字列で埋める規約 (空行にすると yq 抽出時に null 扱いでループ側の条件分岐が増えるため)"
  - "本文テンプレ先頭に ## サマリ 節を追加 (既存の ## ミッション / ## 成果 は保持) — must_haves.truths の 7 見出し要求と Plan verify スクリプトに整合させる Rule 2 追加"

patterns-established:
  - "create-report.md の改修は `4. Write REPORT.md` 節の中でのみ行い Step 1/2/3/5 は改変しない (plan の禁止事項通り)"
  - "frontmatter フィールド増減時は feedback_schema_version を上げ、start-training.sh / Mr.ポポ / extract-feedback.sh を同時改修する (D-03)"

requirements-completed:
  - D-01
  - D-02
  - D-03
  - D-13

# Metrics
duration: ~2min
completed: 2026-04-23
---

# Phase 07 Plan 02: create-report.md に MISSION_TEMPLATE_FEEDBACK YAML frontmatter 指示を追加 Summary

**REPORT.md 生成プロンプト (`create-report.md`) の Step 4 を 2 層構成 (4a 機械読み取り用 YAML frontmatter + 4b 人間読み用 Markdown) にリファクタし、8 必須フィールド (feedback_schema_version / completion_status / mission_type + D-02 の 6 フィールド) の仕様・情報源・フォーマット例を明示**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-23T02:52:44Z
- **Completed:** 2026-04-23T02:54:43Z
- **Tasks:** 1 / 1
- **Files modified:** 1

## Accomplishments

- `spirit-room/base/scripts/create-report.md` の Step 4 を `### 4a. Frontmatter (必須・ファイル先頭に固定)` + `### 4b. Body (既存の Markdown テンプレ)` の 2 層構成に再編
- 4a 節に 8 フィールドの型・意味を示した必須フィールド表と、情報源の拾い方 (`mission_type` は MISSION.md / KAIO-MISSION.md frontmatter から、`completion_status` は `.done` / `.interrupted` の有無から、他 4 項目は `.journal.md` と git log から) を明文化
- 4a 節に完全な YAML フォーマット例 (feedback_schema_version: 1 / completion_status: completed / mission_type: poc / block scalar で 6 フィールド記述) を追加。Claude がフォーマット逸脱しないよう具体例で固定
- 4a 節末尾に block scalar の改行規約・欠損値は `"(なし)"` で埋める規約・末尾 `---` の直後に空行を置く規約の 3 項目を明示
- 4b 節の既存 Markdown テンプレ本体 (line 115-181) は 1 行も改変せず、Body 見出し下にそのまま残置
- 本文テンプレ先頭に `## サマリ` 節を新設 (既存 `## ミッション` / `## 成果` / `## タイムライン` / `## 技術的な判断` / `## ハマりポイント` / `## コード品質` / `## 改善点・次のステップ` / `## 総評` は保持) — plan の must_haves.truths が要求する 7 見出しと plan verify スクリプトの `## サマリ` チェックに整合させるための追加
- Step 5 "Commit" の直前に「frontmatter ブロック (4a) は機械読み取り用なのでフォーマット厳守。yq/jq で解析されるため、バッククォート・行頭以外のコロン・typo は許されない」の最重要注意書きを挿入
- 変更 diff は +65 行の純追加のみ (既存行は 0 行削除)。Step 1 (Detect project type) / Step 2 (Infer the topic) / Step 3 (Research autonomously) / Step 5 (Commit) は全て無改変

## Task Commits

Each task was committed atomically:

1. **Task 1: create-report.md の Step 4 先頭に MISSION_TEMPLATE_FEEDBACK frontmatter 指示を挿入** - `f66d365` (feat)

**Plan metadata commit:** (本 SUMMARY + STATE + ROADMAP を最終コミットで追加予定)

## Files Created/Modified

- `spirit-room/base/scripts/create-report.md` (+65 行):
  - line 55: `REPORT.md は **2 層構成** で書く` の 1 行イントロ追加
  - line 57-108: `### 4a. Frontmatter (必須・ファイル先頭に固定)` 新規節 (52 行) — フィールド表 / 情報源 / YAML 例 / 注意点
  - line 110-113: `### 4b. Body (既存の Markdown テンプレ)` 見出し + イントロ
  - line 121-123: 本文テンプレに `## サマリ` 節を追加 (3 行)
  - line 185: Step 5 直前に「最重要: frontmatter フォーマット厳守」注記

## Decisions Made

- **frontmatter 配置は先頭固定** (D-01 の「先頭 vs 末尾」選択で先頭を採用): MISSION.md.template は既に先頭 frontmatter、REPORT.md も同じ形にすることで視覚的対称。yq `--front-matter=extract` を使う 07-04 の抽出コマンドが第 1 ブロックを常に取れる安定性もメリット
- **本文テンプレに ## サマリ 節を追加** (Rule 2: must_haves.truths 整合のため): 既存テンプレは `## ミッション` + `## 成果` で始まっており plan verify スクリプト (`grep '## サマリ'`) が空振りしていた。人間読者も「先出し要約」があるほうが便利なので純追加
- **suggested_template_diff は block scalar で自由度高**: unified diff / 自由記述どちらも block scalar `|` の中に書ける → agent が状況に応じて選べる柔軟性。一方で fieldname は固定 (typo を防ぐ)
- **欠損値は `"(なし)"` 文字列**: YAML で空行を入れると yq 側で null 扱いになり、07-04 の抽出スクリプトで if-not-null 分岐が必要になる。文字列統一で downstream をシンプルに保つ
- **全変更は step 4 内に閉じる**: plan の禁止事項 (step 1/2/3/5 改変禁止 / モード分岐削除禁止 / 本文見出し改変禁止) を完全遵守。Rule 1-4 いずれの deviation にも該当せず

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] 本文テンプレに `## サマリ` 節を追加**
- **Found during:** Task 1 の automated verify 実行時
- **Issue:** plan 内の verify スクリプトと acceptance_criteria が `grep '## サマリ'` を要求しているが、既存の `create-report.md` 本文テンプレは `## ミッション` + `## 成果` 構成で「サマリ」という見出しが存在しなかった。must_haves.truths も「サマリ / タイムライン / 技術的な判断 / ハマりポイント / コード品質 / 改善点 / 総評」の 7 見出し (計 9 見出しのうち 7 つ) を要求している。plan の意図として本文テンプレに先出しサマリ節が含まれていることを前提としている
- **Fix:** 本文テンプレの `## ミッション` の直前に `## サマリ` 節を 3 行追加 (説明: 「この修行で何をしたか・どこまで動いたかを 3-5 文で先出し要約する」)。既存節は削除・改変なし
- **Files modified:** `spirit-room/base/scripts/create-report.md` line 121-123
- **Commit:** `f66d365` (Task 1 のコミットに同梱)
- **Impact:** REPORT.md の読者体験向上 (先出し要約が入る) + plan verify の整合性確保。既存節を壊していないので 07-04 extract-feedback.sh 側への影響なし

その他の技術的ブロッカー・architectural 判断要求 (Rule 4) なし。

## Issues Encountered

- **PreToolUse:Edit hook の READ-BEFORE-EDIT 再掲**: 各 Edit 前に「Read し直せ」hook が 2 回発火したが、Edit 自体は正常に適用済み (差分が想定通り入っていることを Read で確認)。挙動としては Phase 07-01 と同じパターンで、中間状態のロールバックや再書き込みは発生せず
- **acceptance_criteria の `## サマリ` 要求と既存テンプレの不一致**: 上記 Deviations で Rule 2 適用済み。plan は先に書かれ、実ファイルがそれに追いついていなかった構造
- 技術的ブロッカーなし

## User Setup Required

None — プロンプト改修のみ。環境変数・ダッシュボード設定などの外部セットアップ不要。実 run 検証 (REPORT.md が実際に frontmatter 付きで生成されるか) は Plan 07-04 の E2E で実施予定 (本 plan スコープ外)。

## Self-Check: PASSED

- ✓ `spirit-room/base/scripts/create-report.md` に `4a. Frontmatter` 節が存在 (line 57)
- ✓ 同 `4b. Body` 節が存在 (line 110)
- ✓ 8 必須フィールド (feedback_schema_version / completion_status / mission_type / ambiguous_in_brief / overspecified_in_brief / missing_from_catalog / completion_signal_mismatch / suggested_template_diff) すべて grep で検出可能
- ✓ 既存本文テンプレの 8 節 (ミッション / 成果 / タイムライン / 技術的な判断 / ハマりポイント / コード品質 / 改善点・次のステップ / 総評) 保持 + 新 `## サマリ` 節追加 = 計 9 節
- ✓ Step 1-3 / Step 5 の既存内容無改変 (界王星 4 件 / 精神と時の部屋 3 件の既存文言保持)
- ✓ `git commit -m "docs: add retrospective report` の既存 step 5 コマンド保持
- ✓ `git log --oneline` で `f66d365` を確認
- ✓ plan の automated verify スクリプト全 16 条件 pass
- ✓ plan の acceptance_criteria 全 22 条件 pass (count minimums すべてクリア)
- ✓ plan-level must_haves.truths の 6 項目、artifacts の 1 ファイル、key_links の 2 件すべて満たす
- ✓ commit diff 確認: 削除ファイルなし / 純追加のみ

## Next Phase Readiness

- **Plan 07-03 (MAX_ITERATIONS ガード + `.interrupted` + 部分 REPORT.md 生成)**: 本 plan で確定した `completion_status: interrupted` フィールドを部分 REPORT.md で使える。`start-training.sh` 側で `.interrupted` 作成後にこの create-report.md を呼べば、自動で `completion_status: interrupted` 込みの frontmatter が書かれる前提成立
- **Plan 07-04 (extract-feedback.sh 新設 + `.planning/mr-popo-memory/{type}/` 自動蓄積)**: REPORT.md 先頭の `---` frontmatter を `yq --front-matter=extract` で抽出すれば 8 フィールドが取れる。`mission_type` でディレクトリ分岐、`feedback_schema_version` で非互換検知、残り 6 フィールドをそのままコピーして保存ファイル本体とする前提成立
- **Plan 07-05 (MR_POPO_REVIEW_FEEDBACK.md レビューコマンド)**: `suggested_template_diff` の block scalar (unified diff または自由記述) を Mr.ポポに並べれば差分提案の原資になる。`mission_type` で絞り込み済み feedback を読むだけでよい
- **Downstream への波及なし**: 既存の `create-report.md` の Step 1/2/3/5 に依存している呼び出し側 (start-training.sh / start-training-kaio.sh / /create-report skill コマンド等) は改修不要。純追加ゆえ後方互換

---
*Phase: 07-mr-popo-feedback-loop*
*Completed: 2026-04-23*
