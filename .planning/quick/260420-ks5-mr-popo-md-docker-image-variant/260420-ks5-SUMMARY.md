---
phase: quick
plan: 260420-ks5
subsystem: spirit-room-manager
tags: [docs, mr-popo, mission-template, docker-image-variant, performance]
requires: []
provides:
  - MR_POPO.md に軽量 Docker image variant (`-slim`/`-alpine`) 選好の恒久的指針を組み込み
affects:
  - spirit-room-manager/skills/MR_POPO.md
tech-stack:
  added: []
  patterns:
    - MISSION.md 生成時に image variant を軽量版優先で指示
key-files:
  created: []
  modified:
    - spirit-room-manager/skills/MR_POPO.md
decisions:
  - Docker image は `-slim`/`-alpine` をデフォルト選好とし、フル版は GUI 等の依存が判明した場合のみ使用する (2026-04-20 Python 2.7 Hello World 修行実測根拠)
metrics:
  duration: ~5min
  completed: 2026-04-20
  tasks: 1
  files: 1
  commits:
    - 4600b70
---

# Quick 260420-ks5: MR_POPO.md 軽量 Docker image variant 選好指針追加 Summary

**One-liner:** MR_POPO.md の「調査観点」デフォルト文直下に `-slim`/`-alpine` 優先の指針段落を追加し、Python 2.7 修行で得た 7× pull 高速化 (14 分 → 2 分) を MISSION 生成ルールに恒久化した。

## Objective (Recap)

2026-04-20 の Python 2.7 Hello World 修行 (quick 260420-hkp) で、`python:2.7` フル版と `python:2.7-slim` の間に以下の実測差が判明した:

| | Run 1 (`python:2.7`) | Run 2 (`python:2.7-slim`) | 改善 |
|---|---|---|---|
| image サイズ | ~900 MB | ~100 MB | 9× 小さい |
| pull 時間 | 14 分 | 2 分 13 秒 | **約 7× 高速** |
| PREPARE フェーズ全体 | 19:30 | 2:46 | **約 7× 高速** |
| 全体 (PREPARE+TRAINING) | 26 分 | 8 分 | 3.2× 高速 |

この知見を MR_POPO が生成する毎回の MISSION.md に反映させるため、MR_POPO.md のスキル文書に variant 選好ルールを埋め込む。

## Work Completed

### Task 1: 調査観点デフォルト文に段落追加

- **File:** `spirit-room-manager/skills/MR_POPO.md`
- **Location:** line 191 (調査観点デフォルト説明) の直後に空行 + 新段落 (line 193)
- **Commit:** `4600b70`
- **Diff:** `+2 -0` (空行 1 + 段落 1 行)

追加内容:

> **Docker image variant の選好:** POC 用途で公式 Docker image を使う場合、可能な限り `-slim` / `-alpine` の軽量バリアントを優先して指定せよ。実測で `python:2.7` フル版 (~900 MB) の pull に 14 分かかった一方、`python:2.7-slim` (~100 MB) は 2 分で完了し、PREPARE フェーズ全体が 19:30 → 2:46 と 7× 高速化した (2026-04-20 検証)。フル版でしか動かない依存 (例: apt で GUI ライブラリを要求する等) が明確に判明した場合のみフル版にフォールバックせよ。

### 既存構造の保全

- Step 0/1/2/3, 界王星ヒアリング (K1〜K5), KAIO-MISSION.md 生成ルール、修行フェーズ一覧、完了条件等は一切触っていない。
- MISSION.md 生成ルール内の markdown コードブロック構造 (line 178-213 相当) は保持。
- 追加位置は `## 調査観点` セクション内・`## 完了条件` セクション開始の直前。

## Verification

- `grep -n "Docker image variant の選好" MR_POPO.md` → line 193 に 1 箇所
- `grep -n "python:2.7-slim" MR_POPO.md` → line 193 に 1 箇所
- `git diff --stat` → 変更ファイルは `spirit-room-manager/skills/MR_POPO.md` のみ
- `git show --stat HEAD` → `1 file changed, 2 insertions(+)` (削除 0)
- `git diff --diff-filter=D HEAD~1 HEAD` → 削除ファイルなし

## Success Criteria (from plan)

- [x] `git diff --stat` で変更ファイルが `spirit-room-manager/skills/MR_POPO.md` のみ
- [x] 追加行は 4 行以内 (実績: 2 行 — 空行 1 + 段落 1 行)
- [x] 削除行は 0
- [x] 段落は日本語、実測値 (14 分 → 2 分、19:30 → 2:46、7× 高速化) を根拠として含む
- [x] 「Docker image variant の選好」段落が MR_POPO.md に 1 箇所だけ存在
- [x] 既存の Step 0/1/2/3, 界王星, KAIO 関連セクションが改変されていない

## Deviations from Plan

None — plan を一切逸脱せず、指定された挿入位置・段落本文・制約をそのまま実装した。

## Impact

- **即効性:** 次回以降の MR_POPO ヒアリングで生成される MISSION.md で、公式 Docker image を使うフレームワーク (Python / Node / Ruby / Java 等) の POC では自動的に `-slim` / `-alpine` が選ばれる。
- **修行効率:** PREPARE フェーズで pull 時間を最大 7× 削減できる見込み。ユーザーが部屋を開いてから POC が動き始めるまでの体感時間が大幅に短縮。
- **適用範囲:** 胡蝶の夢モード (compose) で複数サービスを立てる場合にも効果が累積するため、マルチサービス POC では更に大きな時短効果が期待できる。

## Files Modified

- `spirit-room-manager/skills/MR_POPO.md` — line 192-193 に空行 + 新段落を挿入

## Commits

- `4600b70` docs(quick-260420-ks5): MR_POPO.md に軽量 Docker image variant 選好指針を追加

## Self-Check: PASSED

- [x] FOUND: `spirit-room-manager/skills/MR_POPO.md` line 193 に新段落
- [x] FOUND: commit `4600b70` in git log
- [x] No unintended deletions (git diff --diff-filter=D HEAD~1 HEAD で空)
- [x] No other files modified (git diff --stat で 1 file)
