---
phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous
plan: 01
subsystem: spirit-room/base
tags: [entrypoint, kaio, auth, symlink, backward-compat]
requires:
  - 共有認証ボリューム (spirit-room-auth) の存在 (既存)
provides:
  - CLAUDE_CONFIG_DIR 環境変数による界王星モード分岐
  - /root/.claude-shared/.credentials.json への symlink 生成ロジック
affects:
  - spirit-room/base/entrypoint.sh
tech-stack:
  added: []
  patterns:
    - 共有ボリューム + symlink によるトークンリフレッシュ伝播
    - 環境変数ガードによる後方互換分岐
key-files:
  created: []
  modified:
    - spirit-room/base/entrypoint.sh
decisions:
  - CLAUDE_CONFIG_DIR 未設定時は新ロジックを一切発火させず、既存の精神と時の部屋モードを完全に保全
  - 共有マウント先を /root/.claude (既存) と /root/.claude-shared (界王星) で分離し経路独立
metrics:
  tasks-completed: 1
  files-modified: 1
  lines-added: 17
  lines-removed: 0
  completed-date: 2026-04-16
---

# Phase 04 Plan 01: entrypoint.sh CLAUDE_CONFIG_DIR 分岐追加 Summary

**One-liner:** entrypoint.sh に `CLAUDE_CONFIG_DIR` ガード分岐を追加し、共有ボリューム上の `.credentials.json` を symlink することで界王星モードでの認証情報伝播基盤を構築した (既存モードは完全後方互換)。

## Objective

Phase 4 界王星モードの基盤として、部屋の entrypoint に `CLAUDE_CONFIG_DIR` 分岐と認証 symlink 処理を追加する。既存の精神と時の部屋モード (CLAUDE_CONFIG_DIR 未設定時) の挙動は一切変えない。

## What Was Built

### Task 1: entrypoint.sh に CLAUDE_CONFIG_DIR 分岐と symlink 処理を追加

`spirit-room/base/entrypoint.sh` の「サービス起動」ブロックの直後、「認証チェック」ブロックの直前に、界王星モード分岐ロジックを 17 行追加した。

- `[ -n "${CLAUDE_CONFIG_DIR:-}" ]` のガードで未設定時は完全にスキップ
- `mkdir -p "$CLAUDE_CONFIG_DIR"` で部屋ローカルディレクトリ作成
- `/root/.claude-shared/.credentials.json` が存在する場合のみ `ln -sf` で symlink
- 共有ファイルが存在しない場合は `[WARN]` で案内して継続 (ブロックしない)

**Commit:** `228e32b`

## Verification

- `bash -n spirit-room/base/entrypoint.sh` → syntax OK
- `grep -c 'CLAUDE_CONFIG_DIR'` → 8 件 (ガード・echo・コメント)
- `grep -c 'claude-shared/.credentials.json'` → 4 件 (コメント・条件・symlink・ログ)
- `grep -c 'ln -sf'` → 1 件 (symlink 作成)
- `git diff --stat` → `1 file changed, 17 insertions(+)` 追加のみ、既存行の削除・改変ゼロ
- CLAUDE_CONFIG_DIR 未設定時は `if` ブロックを通過せず、認証チェック以降は従来と完全等価

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

- **共有マウント先の分離**: 既存モードの `/root/.claude` 直接マウントはそのまま残し、界王星モードは `/root/.claude-shared` に分離マウントする前提とした。両経路が干渉しないため後方互換を機械的に保証できる (Plan 02 で -v 追加予定)。
- **set -e 下での WARN 継続**: `.credentials.json` 不在時も bash の失敗にせず `[WARN]` + 継続させた。初回部屋起動で未認証状態でも entrypoint 全体が落ちない設計。

## Next Steps

- **Plan 02**: ホスト側 `spirit-room kaio` サブコマンドで `-v spirit-room-auth:/root/.claude-shared` + `-e CLAUDE_CONFIG_DIR=/workspace/.claude-config` を渡す経路を実装すれば、界王星モードでこの symlink が発火する。

## Self-Check: PASSED

- FOUND: spirit-room/base/entrypoint.sh (17 行追加確認済み)
- FOUND: commit 228e32b (`git log --oneline` で確認)
- FOUND: CLAUDE_CONFIG_DIR ガード・symlink・警告分岐すべて存在
