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

```markdown
# REPORT: [プロジェクト名 / ミッション名]

**Date:** YYYY-MM-DD
**Mode:** 界王星 / 精神と時の部屋
**Status:** Completed / Partial

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

**5. Commit**

```bash
git add /workspace/REPORT.md
git commit -m "docs: add retrospective report (REPORT.md)"
```

Report: `Created /workspace/REPORT.md`
