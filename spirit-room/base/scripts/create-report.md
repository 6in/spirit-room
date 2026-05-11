Create a retrospective report (`REPORT.md`) by autonomously reading all project artifacts and writing a structured reflection. Zero input required — Claude reads context and writes it all.

## Steps

**1. Detect project type**

Check which mission file exists to determine the mode:

```bash
ls /workspace/KAIO-MISSION.md /workspace/MISSION.md 2>/dev/null
```

- `KAIO-MISSION.md` exists → 界王星モード (GSD artifacts in `.planning/`)
- `MISSION.md` exists → 精神と時の部屋モード (journal + phases)

**2. Infer the topic**

If `$ARGUMENTS` is non-empty, use it as the report focus hint.

Otherwise, infer from context — in priority order:

```bash
cat /workspace/KAIO-MISSION.md 2>/dev/null || cat /workspace/MISSION.md  # mission title
git log --oneline -5                                                      # recent work
ls .planning/ROADMAP.md 2>/dev/null                                       # GSD phases
```

**3. Research autonomously**

Read as needed to reconstruct the full picture:

界王星モード:
- `/workspace/KAIO-MISSION.md` — ミッション定義 (目的, 要件, 成功条件)
- `/workspace/.planning/ROADMAP.md` — フェーズ計画と進捗
- `/workspace/.planning/REQUIREMENTS.md` — 要件定義
- `/workspace/.planning/phases/*/SUMMARY.md` — 各プラン実行結果
- `/workspace/.planning/phases/*/PLAN.md` — 各プラン設計
- `git log --oneline -30` — コミット履歴
- `git diff --stat $(git log --reverse --format=%H | head -1)..HEAD` — 全体の変更量
- 主要ソースファイル (tree で特定して 3-5 個読む)
- `/workspace/.logs/progress.log` の最新 200 行

精神と時の部屋モード:
- `/workspace/MISSION.md` — ミッション定義
- `/workspace/RESEARCH.md` — 事前調査
- `/workspace/.journal.md` — 作業ジャーナル ([TRY]/[STUCK]/[PIVOT]/[AHA]/[DONE])
- `git log --oneline -30` — コミット履歴
- 主要ソースファイル
- `/workspace/.logs/progress.log` の最新 200 行

Goal: answer "何を目指し、何が起き、何を学び、次に何をすべきか？"

**4. Write REPORT.md**

REPORT.md は **2 層構成** で書く。(4a) 先頭 YAML frontmatter (機械読み取り用) → (4b) 本文 Markdown (人間読み用)。

### 4a. Frontmatter (必須・ファイル先頭に固定)

`/workspace/REPORT.md` の **line 1** から `---` で始まる YAML frontmatter ブロックを必ず書き出す。次の Phase 7 feedback loop (Mr.ポポが過去知見を蓄積するパイプライン) がこのブロックを `yq` で機械抽出するため、フォーマット逸脱は許されない。**bullet 形式や JSON ブロックは禁止。必ず YAML frontmatter**。

#### 必須フィールド (計 8 つ)

| フィールド | 型 | 意味 |
|-----------|-----|------|
| `feedback_schema_version` | int | 固定で `1` (D-03 スキーマ変更時に上げる) |
| `completion_status` | string | `completed` / `interrupted` / `failed` のいずれか。`.done` が存在すれば completed、`.interrupted` なら interrupted、それ以外は failed |
| `mission_type` | string | MISSION.md / KAIO-MISSION.md の frontmatter と同じ値 (`poc` / `refactoring` / `testdata` / `investigation` / `kaio`)。読み取って転写する |
| `ambiguous_in_brief` | string (YAML block scalar `\|`) | MISSION.md で曖昧だった項目を箇条書きで。なければ空文字または `"(なし)"` |
| `overspecified_in_brief` | string (block scalar) | MISSION.md で過剰指定だった項目。なければ `"(なし)"` |
| `missing_from_catalog` | string (block scalar) | catalog.md に載っていなかったが必要だったツール・API。なければ `"(なし)"` |
| `completion_signal_mismatch` | string (block scalar) | 完了判定 (`.done` / test exit 等) と実装の乖離。なければ `"(なし)"` |
| `suggested_template_diff` | string (block scalar) | MISSION.md.template / catalog.md への具体改善提案。unified diff でも自由記述でも可。**必ず書く** (このフィールドが Mr.ポポのテンプレ更新の原資なので「なし」は極力避ける) |

#### 情報源の拾い方

- `mission_type`: `/workspace/MISSION.md` または `/workspace/KAIO-MISSION.md` の先頭 frontmatter を読んで取る。見つからなければ `unknown`
- `completion_status`: `/workspace/.done` があれば `completed`、`/workspace/.interrupted` があれば `interrupted`、どちらもなく修行途中なら `failed`
- `ambiguous_in_brief` / `overspecified_in_brief` / `missing_from_catalog`: `.journal.md` の `[STUCK]` / `[PIVOT]` エントリと git log の試行錯誤から抽出
- `completion_signal_mismatch`: MISSION.md の「完了条件」と実装ファイル構成を突き合わせて乖離を書く
- `suggested_template_diff`: 上記 4 項目を踏まえて Mr.ポポに送る「次回こうしろ」の差分

#### フォーマット例 (これを忠実に踏襲すること)

```yaml
---
feedback_schema_version: 1
completion_status: completed
mission_type: poc
ambiguous_in_brief: |
  - 完了条件「動けばいい」は曖昧 — エラーハンドリング要否が読み取れない
  - RESEARCH 観点「API の癖」の粒度指示がない
overspecified_in_brief: |
  - (なし)
missing_from_catalog: |
  - LangGraph の astream_events API が catalog.md に載っていなかった
completion_signal_mismatch: |
  - MISSION は .done だけで終わる想定だが、実装では stream cleanup が漏れた
suggested_template_diff: |
  - Step 2 完了条件オプションに "REST API なら curl 200 確認" を追加
  - RESEARCH 観点に "streaming 対応" 選択肢を追加
---
```

**注意点:**
- block scalar `|` の後ろには **スペースで改行しない** — 直後に改行し、内容はインデント付きで書く
- 値が存在しない場合は空にせず `"(なし)"` 文字列を入れる (yq 抽出時に空行判定を回避)
- `completion_status: interrupted` の場合は本文側 (4b) でも未完了箇所を明示する
- **frontmatter の末尾 `---` の直後に空行を 1 つ**置いてから本文 Markdown に入る

### 4b. Body (既存の Markdown テンプレ)

frontmatter のあとに、これまで通り人間読み用の Markdown 本文を書く。フォーマットは以下のまま:

```markdown
# REPORT: [プロジェクト名 / ミッション名]

**Date:** YYYY-MM-DD
**Mode:** 界王星 / 精神と時の部屋
**Status:** Completed / Partial

## サマリ

この修行で何をしたか・どこまで動いたかを 3-5 文で先出し要約する (読者がここだけで全体像を掴めるように)。

## ミッション

ミッション定義の目的を 1-2 文で要約。

## 成果

- 完成した機能を箇条書き (動作するもののみ)
- GSD フェーズ: N 個中 M 個完了 (界王星モードの場合)
- テスト結果: pass/fail/skip の数

## タイムライン

git log から主要コミットを時系列で抽出。各コミットに一言コメント。

```
[HH:MM] abcdef0 - 初期セットアップ
[HH:MM] 1234567 - コア機能実装
[HH:MM] 89abcde - テスト追加
```

## 技術的な判断

実装中に行った設計判断を ADR 風に記録。各判断について:

### 判断 1: [タイトル]

- **状況**: 何が問題だったか
- **選択**: 何を採用したか
- **代替案**: 何を検討して却下したか
- **結果**: 良かった点・注意点

(重要な判断が複数あれば繰り返す。3-5 個が目安)

## ハマりポイント

progress.log や journal から抽出した詰まった箇所:

- 何で詰まったか
- どう解決したか (または回避したか)
- 同じ罠にハマらないための教訓

## コード品質

- ファイル構成の評価 (tree 出力ベース)
- テストカバレッジの感触
- 依存関係の妥当性

## 改善点・次のステップ

- もう一度やるなら変えること
- 拡張するなら次に何をするか
- 残っている技術的負債

## 総評

3-5 文で修行全体を振り返る。何が一番の学びだったか。
```

日本語で書くこと。簡潔に、しかし具体的に。推測より事実を優先。

**最重要:** frontmatter ブロック (4a) は**機械読み取り用**なのでフォーマット厳守。yq/jq で解析されるため、バッククォート・行頭以外のコロン・typo は許されない。本文 (4b) は人間読み用なので自由度あり。

**5. Commit**

```bash
git add /workspace/REPORT.md
git commit -m "docs: add retrospective report (REPORT.md)"
```

Report: `Created /workspace/REPORT.md`
