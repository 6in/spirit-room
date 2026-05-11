# Phase 07: Mr.ポポ feedback loop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-23
**Phase:** 07-mr-popo-feedback-loop
**Areas discussed:** Feedback スキーマ形式, Feedback 蓄積構造, テンプレ反映承認フロー, MAX_ITERATIONS の挙動

---

## Feedback スキーマ形式

| Option | Description | Selected |
|--------|-------------|----------|
| YAML frontmatter | REPORT.md の先頭/末尾に ```yaml フェンスで 6 フィールドを書く。yq/jq でパース容易、Mr.ポポ側の読み込みが安定 | ✓ |
| Markdown セクション | ## MISSION_TEMPLATE_FEEDBACK 見出しの下に箇条書き。agent が書きやすいが正規表現パース、フィールド欠落検出が緩い | |
| JSON ブロック | ```json fenced block で構造化。最も厳密な型付け、jq で即パース。コメントが入れられないので agent の直感的記述がしにくい | |

**User's choice:** YAML frontmatter
**Notes:** 推奨通り採用。6 フィールドを YAML frontmatter で埋め込み

---

## Feedback 蓄積構造

| Option | Description | Selected |
|--------|-------------|----------|
| mission_type 別ディレクトリ | `.planning/mr-popo-memory/{mission_type}/{date}-{slug}.md` 形式。type 別に集約、参照コスト低 | ✓ |
| 部屋ごと個別ファイル (フラット) | `.planning/mr-popo-memory/{date}-{slug}.md`。シンプルだが部屋が増えると Mr.ポポが全部読まなきゃならずコストが線形に増える | |
| 1 ファイル追記 | `.planning/mr-popo-memory/feedback.md` にとにかく追記。最小構成だが 100 部屋で食えないサイズに | |

**User's choice:** mission_type 別ディレクトリ
**Notes:** スケール性重視。poc / refactoring / testdata / investigation 別に分離

---

## テンプレ反映承認フロー

| Option | Description | Selected |
|--------|-------------|----------|
| 人間承認必須 (Mr.ポポ起動時に読込+確認) | Mr.ポポが起動時に過去 feedback 読み、diff を yes/no 確認 | |
| 候補 diff をファイルに残してレビュー待ち (PR 風) | proposals/ ディレクトリに未決裁提案を蓄積、明示的に決裁 | |
| 自動適用 | feedback が溜まったら Mr.ポポが次回 MISSION.md 生成時に自動反映 | |
| **Other (user freeform)** | **カスタムスキル/プロンプトを設けて、それを実行したら、完了した部屋から出力された結果をユーザと確認しながら作成** | ✓ |

**User's choice:** Other — カスタムスキル起動 + 対話的レビュー
**Notes:** Mr.ポポ本体は起動時に feedback を自動では読まない。`/mr-popo-review-feedback` 的な明示コマンドをユーザーが叩いた時だけ、溜まった feedback と現行テンプレを並べて対話でテンプレ差分を作る設計。蓄積は自動、レビューは手動という分離。

確認質問で「蓄積自動 + レビューはコマンド起動対話式」という解釈を提示し「OK、その解釈で」で合意。

---

## MAX_ITERATIONS の挙動

| Option | Description | Selected |
|--------|-------------|----------|
| 設定可能 + 部分 REPORT | デフォルト 50、MISSION.md または環境変数で上書き可。発火時は .interrupted フラグ + 部分 REPORT.md 生成 (MISSION_TEMPLATE_FEEDBACK 込み) | ✓ |
| デフォルト 50、発火で停止のみ | 固定 50、発火時はログに記録して exit。シンプルだが部屋がなぜ詰まったかの解析がしにくい | |
| デフォルト 30、.failed フラグ | きつめの 30、.failed フラグで明示的に失敗とマーク。POC 向けにつらいことも、リファクタの微ループ N 回と相性が悪い | |

**User's choice:** 設定可能 + 部分 REPORT
**Notes:** デフォルト 50 + MISSION.md / 環境変数上書き + `.interrupted` フラグ + 部分 REPORT.md 生成で、発火時もデバッグ材料と feedback が次に活かせるようにする

---

## Claude's Discretion

以下は planner/executor の判断に委ねた:
- YAML frontmatter の REPORT.md 内配置 (先頭 / 末尾)
- `suggested_template_diff` の表現形式 (unified diff / 自由記述 / 両方)
- レビューコマンドの実装先 (spirit-room-manager スキル vs ルート `/mr-popo-review-feedback`)
- mission_type 初期語彙 (poc / refactoring / testdata / investigation から start)
- feedback スキーマのバージョニング方式

## Deferred Ideas

- Web UI / TUI モニタリング
- 構造化イベントログ / ハートビート / 意図表明
- ミッションタイプ別テンプレの具体拡充
- テンプレ階層の形式的設計
- feedback スキーマのバージョニング戦略
