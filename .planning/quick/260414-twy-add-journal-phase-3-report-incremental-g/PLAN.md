---
quick_id: 260414-twy
type: quick
created: 2026-04-14
---

# Quick Task: Journal + PHASE 3 REPORT + git commits

## 目的

修行中の AI の**主観的な足跡**（詰まり・方針変更・発見）を `.journal.md` に残し、`/workspace` を git 管理下に置いて時系列の**客観的証拠**を残す。PHASE 2 完了後に PHASE 3 (REPORT) を追加し、両者を統合した振り返りレポート `REPORT.md` を別セッションで生成する。

## 設計

### Journal フォーマット

`/workspace/.journal.md` に追記形式。5タグ固定：

```markdown
## 2026-04-14 10:05 [TRY] サブゴール名
1〜3行の本文

## 2026-04-14 10:07 [STUCK] 問題の見出し
1〜3行の本文

## 2026-04-14 10:08 [PIVOT] 方針変更の見出し
理由を含む1〜3行

## 2026-04-14 10:12 [AHA] 気づきの見出し
1〜3行

## 2026-04-14 10:15 [DONE] 達成したサブゴール
1〜3行
```

### Git 運用

- PHASE 0 開始時に `/workspace` で `git init`、`.gitignore` に `.logs/ .researched .prepared .done` を追加
- 各フェーズ完了時＋各 Journal エントリ時にコミット
- コミットメッセージは Journal の見出しと対応させる
  - `[TRY] ...` → `wip: ...`
  - `[DONE] ...` → `feat: ...`
  - `[PIVOT] ...` → `refactor: ...`
  - `[STUCK] ...` → コミットしない（デバッグ中）
  - `[AHA] ...` → `docs: aha ...`

### PHASE 3 (REPORT)

- 入力: MISSION.md / RESEARCH.md / .journal.md / git log / 実装コード
- 出力: `/workspace/REPORT.md`
- フラグ: `/workspace/.reported`
- 構成:
  1. **サマリ** (3〜5行)
  2. **RESEARCH と実装の乖離** (RESEARCH.md で想定した方針と、実際に取った方針の差分)
  3. **詰まりどころ** (Journal の STUCK エントリから抽出)
  4. **方針変更** (Journal の PIVOT エントリから時系列で)
  5. **気づき・再利用したい知見** (Journal の AHA エントリから)
  6. **次に試すべきこと** (AI 自身の提案)

## 変更ファイル

1. `spirit-room/base/scripts/start-training.sh`
   - `REPORTED_FLAG` / `JOURNAL_FILE` / `REPORT_FILE` 追加
   - PHASE 0 の冒頭で `git init` と `.gitignore` 作成（初回のみ）
   - PHASE 0 / PHASE 1 / PHASE 2 の終わりでフェーズ境界コミット
   - PHASE 2 プロンプトに Journal 追記と `git commit` の指示を追加
   - PHASE 3 (REPORT) ブロック新規追加

2. `spirit-room/base/scripts/MISSION.md.template`
   - 完了条件に `.journal.md` と `REPORT.md` を追記
   - 4フェーズ構造に更新（RESEARCH → PREPARE → TRAINING → REPORT）

3. `spirit-room-manager/skills/MR_POPO.md`
   - 4フェーズ構造に更新

4. `spirit-room/build-base.sh` 実行（イメージ再ビルド）

## 完了条件

- [ ] `start-training.sh` に PHASE 3 (REPORT) ブロックが存在
- [ ] `.researched` / `.prepared` / `.done` / `.reported` 4フラグで制御
- [ ] PHASE 0 開始時に `git init` が走る（既存 .git があればスキップ）
- [ ] PHASE 2 プロンプトに Journal フォーマット説明と git commit 指示が含まれる
- [ ] MISSION.md.template が 4フェーズ構造に更新済み
- [ ] MR_POPO.md が 4フェーズ構造に更新済み
- [ ] `spirit-room-base:latest` 再ビルド済みで変更反映
- [ ] `bash -n start-training.sh` 構文チェック通過
