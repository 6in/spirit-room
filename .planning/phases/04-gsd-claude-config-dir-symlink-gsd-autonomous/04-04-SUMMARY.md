---
phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous
plan: 04
subsystem: kaio-training-loop
tags: [kaio, training-loop, gsd, mr-popo, entrypoint]
requires:
  - 04-01 (entrypoint.sh の CLAUDE_CONFIG_DIR 分岐 + symlink)
  - 04-02 (spirit-room kaio ホスト CLI コマンド)
  - 04-03 (KAIO-MISSION.md.template)
provides:
  - 界王星モードの training loop (GSD install → /gsd-new-project → /gsd-autonomous → tag)
  - entrypoint tmux ペインから start-training-kaio への自動起動
  - Mr.ポポのモード選択ヒアリング (精神と時の部屋 / 界王星)
affects:
  - spirit-room/base/scripts/start-training-kaio.sh (NEW)
  - spirit-room/base/entrypoint.sh (tmux 分岐に界王星 branch 追加)
  - spirit-room-manager/skills/MR_POPO.md (Step 0 + 界王星ヒアリング + 起動手順)
tech-stack:
  added:
    - get-shit-done-cc (npx 経由で CLAUDE_CONFIG_DIR 下にインストール)
  patterns:
    - 非対話 claude -p + --permission-mode bypassPermissions
    - 2フラグ idempotency (.kaio-prepared / .kaio-done)
    - git tag v* をフォールバック完了シグナルとして検知
key-files:
  created:
    - spirit-room/base/scripts/start-training-kaio.sh
  modified:
    - spirit-room/base/entrypoint.sh
    - spirit-room-manager/skills/MR_POPO.md
decisions:
  - 既存 start-training.sh は1行も触らず、別ファイルで並走する構成
  - 界王星モードは CLAUDE_CONFIG_DIR + KAIO-MISSION.md + !.kaio-done の3条件で自動起動
  - Mr.ポポの挨拶行 (「よく来たな。ここは精神と時の部屋だ。」) は CLAUDE.md 固定につき保持
metrics:
  tasks_completed: 3
  files_created: 1
  files_modified: 2
  completed_date: 2026-04-16
---

# Phase 04 Plan 04: 界王星 training loop + Mr.ポポモード分岐 Summary

POC で検証済の「CLAUDE_CONFIG_DIR で GSD を隔離 → `claude -p --permission-mode bypassPermissions` で `/gsd-new-project` → `/gsd-autonomous` を非対話チェーン」プロンプトを `start-training-kaio.sh` として正式化し、entrypoint の tmux 起動分岐と Mr.ポポのヒアリングに配線した。Wave 1 (Plan 01/02/03) の成果 (entrypoint symlink, ホスト `spirit-room kaio`, KAIO-MISSION.md.template) がここで合流し、界王星モードが end-to-end で動作する骨格となった。

## Tasks Executed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | start-training-kaio.sh 新規作成 | `6be2f05` | spirit-room/base/scripts/start-training-kaio.sh |
| 2 | entrypoint.sh tmux に界王星分岐追加 | `9958cb0` | spirit-room/base/entrypoint.sh |
| 3 | Mr.ポポスキルに Step 0 + 界王星ヒアリング追加 | `3978c52` | spirit-room-manager/skills/MR_POPO.md |

## Implementation Notes

### start-training-kaio.sh

- `CLAUDE_CONFIG_DIR` 未設定時は `/workspace/.claude-home` をフォールバックに採用 (ただし entrypoint 経由では必ず設定される想定)。
- PHASE KAIO-1: `npx -y get-shit-done-cc@latest` を `CLAUDE_CONFIG_DIR` つきで実行し、完了したら `.kaio-prepared` を touch。
- PHASE KAIO-2: `while` ループ内で `claude --permission-mode bypassPermissions -p "..."` を起動。プロンプトは 04-CONTEXT.md の specifics 原文をそのまま埋め込み、末尾に「`git tag` が出たら `/workspace/.kaio-done` を作って exit」という完了シグナルを追記した。
- ループ内でフラグ未作成 & `git tag --list | grep '^v[0-9]'` がマッチした場合はラッパー側でも `.kaio-done` を作る保険を実装。
- 再入時は `.kaio-prepared` / `.kaio-done` によりスキップされ idempotent。

### entrypoint.sh

- 既存の tmux training ペイン起動ブロックを書き換え、**最上位の if** を `[ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]` に変更。
- `elif` に従来の `[ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]` を残した。精神と時の部屋モードでは `CLAUDE_CONFIG_DIR` が設定されないため、必ずこちらに落ちて従来挙動と等価。
- idle メッセージは `start-training(-kaio)` にして両モードのヒントを統合。
- Plan 01 で入れた CLAUDE_CONFIG_DIR 認証 symlink ブロック (L18-33) はそのまま残っており、tmux ブロックとは独立して動作する。

### spirit-room-manager/skills/MR_POPO.md

- 挨拶行はそのまま、直後に **Step 0: モードの選択** を追加。1=精神と時の部屋, 2=界王星 の二択で案内する。
- 精神と時の部屋モードは既存 Step 1〜3 および MISSION.md 生成ルール・起動手順を完全保持。
- 界王星モードは新規セクション:
  - **界王星ヒアリング (K1〜K5)**: 目的 / 機能要件 / フェーズ分割の示唆 / 成功条件 / 制約
  - **KAIO-MISSION.md 生成ルール**: `/gsd-new-project` が非対話で読むので「各項目は明確な一文で書け」と明示
  - **界王星モード部屋の起動手順**: フォルダ命名 `kaio-[プロジェクト名]` → `spirit-room kaio` → `spirit-room list` 確認 → 報告フォーマット

## Verification

- `bash -n spirit-room/base/scripts/start-training-kaio.sh` → pass
- `bash -n spirit-room/base/entrypoint.sh` → pass
- `git diff 8b32f97 -- spirit-room/base/scripts/start-training.sh` → 空 (未変更)
- must_haves.artifacts の `contains` チェック:
  - start-training-kaio.sh に `CLAUDE_CONFIG_DIR`, `get-shit-done-cc`, `gsd-new-project`, `gsd-autonomous`, `bypassPermissions`, `.kaio-done`, `.kaio-prepared` が全て含まれる
  - entrypoint.sh に `start-training-kaio`, `KAIO-MISSION.md`, `.kaio-done` が含まれる
  - MR_POPO.md に `Step 0`, `界王星`, `spirit-room kaio`, `KAIO-MISSION`, `よく来たな`, `Step 1`, `Step 3` が含まれる

## Deviations from Plan

None - プラン通りに3タスク完遂。既存 `start-training.sh` は未変更、精神と時の部屋モードの実行パスも等価。

## Follow-ups / Out of Scope

- 実コンテナでの動作確認 (Docker イメージ再ビルド → `spirit-room kaio` 起動) は Wave 3 (Plan 05) で実施予定。
- `get-shit-done-cc` のバージョン固定は未対応 (`@latest` のまま)。将来的にバージョンピン留めが必要になったら別プランで。
- ベースイメージの Dockerfile 側で `start-training-kaio.sh` に実行権限が付与されているかは Wave 3 の build/run テストで確認する。ローカルでは `chmod +x` を既に実行済み。

## Self-Check: PASSED

- FOUND: spirit-room/base/scripts/start-training-kaio.sh
- FOUND: spirit-room/base/entrypoint.sh (界王星分岐 追加済)
- FOUND: spirit-room-manager/skills/MR_POPO.md (Step 0 追加済)
- FOUND commit: 6be2f05 (Task 1)
- FOUND commit: 9958cb0 (Task 2)
- FOUND commit: 3978c52 (Task 3)
- start-training.sh diff = empty (未変更 confirmed)
