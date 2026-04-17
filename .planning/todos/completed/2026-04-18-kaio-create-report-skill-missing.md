---
created: 2026-04-18T01:00:00.000Z
title: kaio モードで /create-report skill が見つからず REPORT フェーズが失敗する
area: tooling
files:
  - spirit-room/base/scripts/start-training-kaio.sh
  - spirit-room/base/scripts/create-report.md
  - spirit-room/base/Dockerfile
---

## Problem

界王星モード (`spirit-room kaio`) で start-training-kaio.sh が PHASE 3 (REPORT) に到達したとき、コンテナ内 Claude Code に `/create-report` skill が存在せず `Unknown command: /create-report` でコマンドが即失敗する。発覚: 2026-04-17 Phase 5 kaio UAT で v1.0 ship まで完走後、振り返り生成ステップで出力。

```
[2026-04-17 15:08:46] 界王星修行完了
[2026-04-17 15:08:46] === 界王星 PHASE 3: 振り返り (REPORT) ===
[2026-04-17 15:08:46] 別セッションで /create-report スキルを実行中...
Unknown command: /create-report
[2026-04-17 15:08:48] REPORT.md 生成完了
```

REPORT.md 自体はフォールバックで生成されるためワークフローはブロックされないが、skill 経由の整った振り返りにならず、品質が劣化する。影響範囲は kaio モード PHASE 3 のみ (通常モードには無関係)。

## Solution

想定アプローチ (どれが正道か要検証):

1. `/room/skills/` に `create-report.md` を `SKILL.md` 互換の slash-command として同梱し、コンテナ内 Claude が起動時に拾えるようにする
   - 現状 `spirit-room/base/scripts/create-report.md` は存在する (内容要確認)。これを `.claude/skills/create-report/SKILL.md` 形式で配布する必要
2. Dockerfile でビルド時に user-level `~/.claude/commands/` へインストールする
3. `start-training-kaio.sh` 側で `claude -p "$(cat /room/scripts/create-report.md)"` の素の prompt 投入に切り替える (skill 依存を外す)

(1) が最もクリーン。Claude Code が `/workspace/.claude/skills/` も読むので、`/room` に置いて Dockerfile で symlink するのが有力。

**Phase 化の目安**: 小タスク (1 plan, 30 分) で済む。単体 QUICK で対応可。
