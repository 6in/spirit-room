# Phase 07: Mr.ポポ feedback loop - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

部屋のトレーニング結果 (REPORT.md) から `MISSION_TEMPLATE_FEEDBACK` を構造化形式で抽出し、過去 feedback を蓄積する仕組みを用意する。そのうえで、ユーザーが明示的にレビューコマンドを起動したときに、Mr.ポポと対話しながら MISSION.md テンプレートを進化させる流れを確立する。同時に `start-training.sh` に MAX_ITERATIONS ガードを導入し、無限ループを塞ぐ安全網を張る。

**In scope:**
- REPORT.md への MISSION_TEMPLATE_FEEDBACK (YAML frontmatter) 吐き出し仕込み
- 部屋完了時の feedback 自動抽出と `.planning/mr-popo-memory/{mission_type}/` への保存
- ユーザー明示起動のレビュースキル/コマンド (Mr.ポポと対話的にテンプレ差分を作成)
- MAX_ITERATIONS ガード (設定可能 + 発火時の部分 REPORT.md 生成 + `.interrupted` フラグ)
- MISSION.md.template / create-report.md / MR_POPO.md の必要改修

**Out of scope:**
- Web UI / TUI によるリアルタイムモニタリング (別フェーズ)
- ハートビート・意図表明・構造化イベント等、その他の観測規約 (別フェーズ)
- ミッションタイプ別テンプレートの具体設計・拡充 (このフェーズでは mission_type フィールドの導入と feedback loop のインフラだけ。実際の poc/refactoring/testdata 用テンプレ拡充は別フェーズ)

</domain>

<decisions>
## Implementation Decisions

### Feedback Schema
- **D-01:** `MISSION_TEMPLATE_FEEDBACK` は **YAML frontmatter** で REPORT.md に埋め込む。YAML fence (` ```yaml ... ``` `) を REPORT.md の先頭または末尾に置き、yq/jq でパース可能にする。markdown 箇条書きや JSON ブロックは採用しない
- **D-02:** 初期スキーマは元提案の 6 フィールド: `mission_type` / `ambiguous_in_brief` / `overspecified_in_brief` / `missing_from_catalog` / `completion_signal_mismatch` / `suggested_template_diff`
- **D-03:** スキーマ変更時は `start-training.sh` (プロンプト側) と Mr.ポポ (消費側) の両方を同時に更新する前提。バージョン管理方針 (例: `feedback_schema_version: 1`) は planner 判断

### Feedback 蓄積構造
- **D-04:** 蓄積ディレクトリは **`.planning/mr-popo-memory/{mission_type}/{date}-{slug}.md`** 形式。mission_type 別に集約することで Mr.ポポが「次の部屋は refactoring」と分かった時点で該当ディレクトリだけ参照すればよく、参照コストが O(全件) でなく O(同タイプ件数) に収まる
- **D-05:** 蓄積は**自動** — 部屋完了時 (REPORT.md 生成後) に `start-training.sh` (または Mr.ポポ) が REPORT.md の YAML frontmatter を抽出して適切な mission_type ディレクトリに保存する
- **D-06:** 保存ファイル 1 件 = 1 部屋分の feedback。ファイル名は `{date}-{room-slug}.md`。REPORT.md からコピーした feedback 本体 + room 名 + 日時をヘッダに持つ

### テンプレ反映の承認フロー
- **D-07:** テンプレ更新は **人間明示起動のカスタムコマンド/スキル** で行う。Mr.ポポ本体は起動時に feedback を自動では読まない (暴走防止 + LLM 幻覚漉し)
- **D-08:** 想定コマンド (仮称): `/mr-popo-review-feedback` もしくは Mr.ポポ内のサブフロー。ユーザーが明示的に実行すると、Mr.ポポが溜まった feedback と現行テンプレ (MISSION.md.template) を並べ、対話的に差分提案 → ユーザー確認 → テンプレ上書き
- **D-09:** レビュー後、採用された feedback ファイルは別ディレクトリ (例: `.planning/mr-popo-memory/{mission_type}/applied/`) へ移動するか、ヘッダにマークを付けて「反映済み」と区別する (具体方式は planner 判断)

### MAX_ITERATIONS ガード
- **D-10:** `start-training.sh` の TRAINING フェーズループに MAX_ITERATIONS ガードを追加。デフォルト **50 回**
- **D-11:** 上書きソース優先順: ①環境変数 `MAX_ITERATIONS` > ②MISSION.md 内フィールド `max_iterations` > ③デフォルト 50
- **D-12:** 発火時の挙動: `/workspace/.interrupted` フラグ作成 + その時点までの部分 REPORT.md 生成 (MISSION_TEMPLATE_FEEDBACK 含む)。フラグ名は `.done` / `.failed` と区別した `.interrupted` を採用 (「異常終了ではなく安全網発動」という意図を明示)
- **D-13:** 部分 REPORT.md は完全 REPORT.md と同じスキーマ (YAML frontmatter 必須)。ただし "completion_status: interrupted" のような補助フィールドで未完了を明示

### Claude's Discretion
以下は実装時に planner/executor が決めてよい:
- YAML frontmatter の REPORT.md 内配置 (先頭 vs 末尾)
- `suggested_template_diff` の表現形式 (unified diff / 自由記述 / 両方可)
- レビューコマンドの実装先 (spirit-room-manager 内のスキルか、ルート `/mr-popo-review-feedback` か)
- mission_type の初期語彙 (poc / refactoring / testdata / investigation だけで start、後から追加可能にする)
- feedback スキーマのバージョニング方式

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 背景
- `.planning/quick/260421-uiu-work-refactoring-java-java-10-gradle/260421-uiu-SUMMARY.md` — 本フェーズの発端となったリファクタ実験の成果 (3 問インタビュー + 2 フェーズループが POC 以外に噛み合わない証拠)

### 改修対象ファイル
- `spirit-room/base/scripts/start-training.sh` — 2 フェーズループ本体。MAX_ITERATIONS と REPORT.md 生成プロンプトの改修対象
- `spirit-room/base/scripts/create-report.md` — REPORT.md 生成テンプレ。MISSION_TEMPLATE_FEEDBACK YAML frontmatter の差し込み点
- `spirit-room/base/scripts/MISSION.md.template` — MISSION.md テンプレ。`mission_type` / `max_iterations` フィールド追加の対象
- `spirit-room/base/scripts/KAIO-MISSION.md.template` — 界王星モード用 MISSION。同等改修
- `spirit-room-manager/skills/MR_POPO.md` — Mr.ポポ hiring workflow。mission_type 判定ロジック + レビューコマンド起点の追加対象

### 参考: 既存 CONTEXT.md
- `.planning/phases/06-spirit-room-docker-docker-compose/06-CONTEXT.md` — Phase 6 の decision 書式。スタイル参考
- `.planning/phases/04-gsd-claude-config-dir-symlink-gsd-autonomous/04-CONTEXT.md` — Phase 4 の CONTEXT.md (ミッション系改修の前例)

### プロジェクト規約
- `./CLAUDE.md` — 応答言語 (日本語)、ブランチ戦略、AskUserQuestion 規約、GSD ワークフロー強制

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **create-report.md**: REPORT.md 生成時に agent が参照するインストラクション。MISSION_TEMPLATE_FEEDBACK YAML ブロックの追加は**ここへの追記が主戦場**
- **start-training.sh のループ構造**: `.prepared` / `.done` フラグによる idempotent ループが既にある。MAX_ITERATIONS はこのループカウンタに仕込めばよい
- **MISSION.md.template の structured sections**: 目的 / 完了条件 / 実装スコープ / 制約 の 4 節構成。mission_type / max_iterations を先頭の metadata として追加するのが自然
- **spirit-room CLI の folder → container 名変換**: `folder_to_name()` で mission slug が既に生成されている。feedback ファイルの `{date}-{slug}.md` 命名にも同規則を流用可能

### Established Patterns
- **bash + Docker のみ構成**: Phase 7 の新機能 (feedback 抽出、ファイル保存) も bash / docker ベースで実装する (PROJECT.md 規約)
- **tee -a progress.log でのログ方針**: 自動蓄積時の stdout ログもこのパターンに従う
- **エラーハンドリング**: `set -e` + `[INFO]` / `[ERROR]` prefix でユーザー向けメッセージ

### Integration Points
- **spirit-room open の直後 / 完了**: feedback 抽出のトリガーポイント候補。start-training.sh 末尾が自然
- **Mr.ポポの Step 0 (モード選択)**: 既に kaio / 通常モード判定が入っている。mission_type 判定もここに拡張
- **spirit-room CLI の close サブコマンド**: feedback 抽出が `start-training.sh` ではなく CLI 側で走る設計にした場合はここも候補

</code_context>

<specifics>
## Specific Ideas

- **レビューコマンドの UX イメージ** (ユーザーのメンタルモデル):
  「気が向いたときにコマンド叩く → Mr.ポポが『refactoring 系で 3 件、poc 系で 2 件 feedback が溜まってます。どれからレビュー?』と聞いてくる → 1 件ずつ diff を見せて yes/no/編集して承認」
- **mission_type 初期語彙**: poc / refactoring / testdata / investigation の 4 種から start (将来追加容易な設計)
- **テストデータ生成部屋**は本 phase では作らない (Phase 7 はあくまで feedback loop のインフラを整えるのが主眼。mission_type の具体的テンプレ拡充は別 phase)

</specifics>

<deferred>
## Deferred Ideas

- **Web UI / TUI モニタリング**: 本セッションで議論したが phase 7 スコープ外。feedback loop が回って指示書の質が上がれば監視の必要性も下がる、という仮説検証も含めて保留
- **構造化イベントログ / ハートビート / 意図表明**: モニタリング規約として議論したが、これは観測側の話で feedback loop (上流改善) とは別軸。別 phase 候補
- **ミッションタイプ別テンプレ拡充** (refactoring 用テンプレ、testdata 用テンプレの具体設計): feedback loop が回り始めた後、蓄積結果を元に別 phase で着手する方が筋が良い
- **テンプレ階層の形式的設計** (refactoring 汎用 / refactoring/java-gradle 特化 等): Phase 7 の初期実装では単一階層で進め、階層化は将来判断
- **feedback スキーマのバージョニング戦略**: 初期は v1 固定で進め、後方互換性が必要になった時点で別 phase

</deferred>

---

*Phase: 07-mr-popo-feedback-loop*
*Context gathered: 2026-04-23*
