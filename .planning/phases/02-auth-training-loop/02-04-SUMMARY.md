---
phase: 02-auth-training-loop
plan: "04"
subsystem: auth
tags: [docker, auth, claude-code, tty, ssh]
dependency_graph:
  requires: [02-02]
  provides: [interactive-auth-via-ssh]
  affects: [spirit-room/spirit-room]
tech_stack:
  added: []
  patterns: [ssh-tty-auth, temp-container-lifecycle]
key_files:
  modified:
    - spirit-room/spirit-room (cmd_auth)
decisions:
  - "SSH経由でcmd_authを実装: TTY問題を回避し、OAuthコードのペーストを可能にする"
  - "一時コンテナ(spirit-room-auth-temp)をport 2299で起動し認証後自動削除する方式を採用"
metrics:
  duration: "5min"
  completed: "2026-04-14T06:05:06Z"
  tasks_completed: 1
  files_modified: 1
---

# Phase 02 Plan 04: SSH-based Interactive Auth Summary

SSH経由の一時コンテナで `claude auth login` をインタラクティブに実行できるよう `cmd_auth` を修正。

## What Was Built

`spirit-room auth` コマンドが SSH 経由でインタラクティブ認証できるよう `cmd_auth` を完全に書き直した。

**変更前:** ホストの `~/.claude/.credentials.json` をコピーする方式。ホストに認証情報がないと失敗する。

**変更後:** 一時コンテナ `spirit-room-auth-temp` を port 2299 で起動し、SSH TTY セッション内で `claude auth login` を実行する方式。OAuth URL が表示され、ブラウザ認証後のコードをペーストできる。

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SSH経由でのclaude auth login実装 | 2816d71 | spirit-room/spirit-room |

## Deviations from Plan

**1つの軽微な追加 (Rule 2 - Missing cleanup)**

プランの実装例では `docker stop` のみだったが、`docker rm` も追加して一時コンテナが確実に削除されるようにした（`--rm` を使わずに手動管理とした理由: `-d` モードで `--rm` と組み合わせると一部 Docker バージョンで問題が発生するため）。

それ以外はプラン通りに実装。

## Known Stubs

なし。

## Threat Flags

なし（既存の SSH ポート利用パターンの延長、新規ネットワーク経路なし）。

## Self-Check: PASSED

- spirit-room/spirit-room 修正済み: FOUND
- commit 2816d71: FOUND
- 構文チェック: bash -n → OK
- ssh -t root@localhost パターン: FOUND
- ポート 2299: FOUND
- spirit-room-auth-temp: FOUND
