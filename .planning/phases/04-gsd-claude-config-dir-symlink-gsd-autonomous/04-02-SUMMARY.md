---
phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous
plan: 02
subsystem: host-cli
tags: [spirit-room, cli, kaio-mode, docker]
requires:
  - spirit-room/spirit-room (existing cmd_open, helpers)
provides:
  - cmd_kaio subcommand for 界王星モード room launch
affects:
  - spirit-room/spirit-room
tech-stack:
  added: []
  patterns:
    - "cmd_* dispatcher pattern (追記のみ)"
    - "-kaio suffix for container-name namespace separation"
key-files:
  created: []
  modified:
    - spirit-room/spirit-room
decisions:
  - "コンテナ名衝突回避のため -kaio サフィックスを末尾に付与（既存 spirit-room open と共存可能）"
  - "CLAUDE_CONFIG_DIR=/workspace/.claude-home を docker run -e で注入（Plan 01 の entrypoint 分岐に対応）"
  - "共有認証ボリュームは /root/.claude-shared にマウント（entrypoint 側で .claude-home 下に symlink/統合される想定）"
  - "opencode 認証ボリュームと ~/.claude.json ro マウントは Phase 4 スコープ外として deferred（POC では不要）"
metrics:
  duration: "約5分"
  completed: "2026-04-16"
  tasks: 1
  files_changed: 1
---

# Phase 04 Plan 02: cmd_kaio サブコマンド追加 Summary

ホスト CLI `spirit-room` に界王星モード専用の `kaio` サブコマンドを追加し、既存 `open` フローを一切壊さずに CLAUDE_CONFIG_DIR 切替と共有認証ボリュームのマウント先変更を実現した。

## Objective Achieved

- `spirit-room kaio [folder]` で界王星モードの部屋を起動可能
- コンテナには `CLAUDE_CONFIG_DIR=/workspace/.claude-home` が設定される
- 共有認証ボリューム `spirit-room-auth` は `/root/.claude-shared` にマウント
- 既存 `spirit-room open` 経路は 1 行も書き換えていない（純粋追記）
- `-kaio` サフィックスによって同一フォルダでも `open` 版と共存可能

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | cmd_kaio 関数と dispatcher を追加 | e1d5eab | spirit-room/spirit-room |

## Implementation Details

### `cmd_kaio()` の差分ポイント

1. **コンテナ名**: `"$(folder_to_name "$folder")-kaio"` で末尾サフィックス
2. **環境変数**: `-e CLAUDE_CONFIG_DIR=/workspace/.claude-home`
3. **認証マウント**: `-v "${AUTH_VOLUME}:/root/.claude-shared"`（`/root/.claude` ではない）
4. **外した項目**（Phase 4 スコープ外 / deferred）:
   - `OPENCODE_AUTH_VOLUME` のマウント
   - `${HOME}/.claude.json:/root/.claude.json:ro` バインドマウント
5. **起動メッセージ**: 「界王星を開く (重力10倍)」で Dragon Ball 世界観を踏襲

### 既存再利用

- `folder_to_name()`, `find_free_port()`, `AUTH_VOLUME` 定数はそのまま流用
- 4スペースインデント・`[INFO]`/`[ERROR]` プレフィックス・`set -e` 規約を遵守

### usage / dispatcher

- `usage()` に `spirit-room kaio [フォルダ]  界王星を開く（GSD駆動の本格開発モード・重力10倍）` を追加
- main `case` に `kaio) cmd_kaio "${2:-}" ;;` を追加

## Verification

```
bash -n spirit-room/spirit-room                  # SYNTAX OK
grep -c 'cmd_kaio' spirit-room/spirit-room       # 2 (定義 + dispatcher)
grep -c 'cmd_open' spirit-room/spirit-room       # 3 (変更前と同じ: 定義 + dispatcher + コメント参照)
grep 'CLAUDE_CONFIG_DIR=/workspace/.claude-home' # OK
grep '/root/.claude-shared'                      # OK
grep 'kaio)'                                     # OK
```

`git diff` で `cmd_open()` 本体（L50-91）は 1 行も変更されていないことを確認済み。

## Deviations from Plan

None - プランどおりに実装。

## Deferred Items

Phase 4 範囲外として明示的に外した項目（CONTEXT.md および 04-02 PLAN の指示に従う）:

- **opencode 認証ボリュームマウント** — 界王星モードでは claude-code 専用とし、後続フェーズで必要になれば追加
- **`~/.claude.json` ro バインドマウント** — プロジェクトローカル設定を `/workspace/.claude-home` に閉じ込める設計と整合しないため除外。将来的に `.claude.json` 共有が必要になれば別途検討

## Success Criteria Check

1. ✅ `spirit-room kaio [folder]` が新コンテナを起動でき、`docker inspect` で `CLAUDE_CONFIG_DIR=/workspace/.claude-home` を観測可能（静的検証: bash -n + grep）
2. ✅ 共有認証ボリュームが `/root/.claude-shared` にマウントされており、Plan 01 の entrypoint 分岐と整合
3. ✅ 既存 `spirit-room open` 経路は一切影響を受けない（`cmd_open` 本体ゼロ変更）

## Self-Check: PASSED

- spirit-room/spirit-room: FOUND（modified）
- commit e1d5eab: FOUND in git log
- cmd_kaio 関数定義: FOUND
- kaio) case branch: FOUND
- CLAUDE_CONFIG_DIR=/workspace/.claude-home: FOUND
- /root/.claude-shared マウント: FOUND
- cmd_open 本体変更: なし（追記のみ）
