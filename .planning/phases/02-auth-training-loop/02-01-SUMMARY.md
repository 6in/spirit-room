---
phase: 02-auth-training-loop
plan: 01
subsystem: training-loop
tags: [docker, bash, claude-code, training-loop, fix]
dependency_graph:
  requires: []
  provides: [fixed-run-claude, spirit-room-base-latest]
  affects: [spirit-room/base/scripts/start-training.sh]
tech_stack:
  added: []
  patterns: [dangerously-skip-permissions, allowedTools]
key_files:
  created: []
  modified:
    - spirit-room/base/scripts/start-training.sh
decisions:
  - "--dangerously-skip-permissions を追加してコンテナ内無人実行を有効化"
  - "LSを削除しGlob,Grepを追加（v2.1.x有効ツール名）"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-13"
  tasks_completed: 2
  files_modified: 1
---

# Phase 02 Plan 01: run_claude 修正 & spirit-room-base 再ビルド Summary

## One-liner

`start-training.sh` の `run_claude` に `--dangerously-skip-permissions` を追加し、`LS` を `Glob,Grep` に置き換えて `spirit-room-base:latest` を再ビルド。

## What Was Built

`run_claude` 関数の1行修正により、コンテナ内で `claude -p` が Bash ツールを無人実行できるようになった。これにより PHASE1/PHASE2 の修行ループがパーミッション確認プロンプトでハングする根本原因（LOOP-04）を解消した。

修正内容:
1. `--dangerously-skip-permissions` フラグを追加 — サンドボックスコンテナ内での無人実行に必須
2. `LS` を削除し `Glob,Grep` を追加 — Claude Code v2.1.x の有効ツール名
3. claude 分岐を複数行に展開 — CLAUDE.md の bash 規約に従い可読性向上

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | run_claude 関数を修正する | 48fe4b1 | spirit-room/base/scripts/start-training.sh |
| 2 | spirit-room-base イメージを再ビルド | (no file change) | spirit-room-base:latest (Docker image) |

## Verification Results

| Check | Result |
|-------|--------|
| `bash -n start-training.sh` | OK (構文エラーなし) |
| `grep -c dangerously-skip-permissions` | 1 |
| `grep -c Bash,Read,Write,Edit,Glob,Grep` | 1 |
| `grep "Bash,Read,Write,Edit,LS"` | 一致なし (除去済み) |
| `docker images spirit-room-base:latest` | spirit-room-base:latest 存在 |
| イメージ内 `dangerously-skip-permissions` | 1 (焼き込み確認) |
| イメージ内 `claude --version` | 2.1.104 (Claude Code) |

## Claude CLI Version Note

イメージ内の claude CLI は `2.1.104` で RESEARCH.md の期待値 (`2.1.x`) を満たす。

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. 修正は既存の trust boundary (`コンテナ内 claude -p → Bash ツール`) 内の変更のみ。
T-02-01 (accept) に基づき、`--dangerously-skip-permissions` はサンドボックスコンテナ内に限定される。

## Self-Check: PASSED

- spirit-room/base/scripts/start-training.sh: FOUND (48fe4b1)
- spirit-room-base:latest: FOUND (3b222ff0a06e)
- イメージ内 dangerously-skip-permissions: FOUND (count=1)
