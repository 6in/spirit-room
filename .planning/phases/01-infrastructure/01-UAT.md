---
status: complete
phase: 01-infrastructure
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md]
started: 2026-04-13T07:00:00Z
updated: 2026-04-13T07:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: spirit-room-base:latest が存在する状態で `docker rmi spirit-room-base:latest` で削除し、`cd spirit-room && ./build-base.sh` をゼロから実行する。エラーなしでビルドが完了し、`docker images spirit-room-base:latest` に新しいイメージが表示される。
result: pass

### 2. Docker イメージビルド確認
expected: `docker images spirit-room-base:latest` を実行すると、spirit-room-base:latest がリストに表示される。イメージIDが存在し、サイズが表示される（約1.6GB）。
result: pass

### 3. spirit-room open — コンテナ起動と SSH 接続
expected: `./spirit-room/spirit-room open [任意のフォルダ]` を実行するとコンテナが起動し、`ssh root@localhost -p 2222` (パスワード: spiritroom) で接続できる。
result: pass

### 4. Redis 起動確認
expected: コンテナ起動後、SSH でコンテナに入り `redis-cli ping` を実行すると `PONG` が返る。
result: pass

### 5. tmux 3ウィンドウ確認
expected: コンテナ内で `tmux list-windows -t spirit-room` を実行すると training・logs・workspace の3つのウィンドウが表示される。
result: pass

### 6. spirit-room enter — tmux セッションアタッチ
expected: `./spirit-room/spirit-room enter [フォルダ]` を実行するとコンテナの tmux セッションにアタッチし、3つのペインが確認できる。`Ctrl-b d` でデタッチできる。
result: pass

### 7. spirit-room close — コンテナ停止・削除
expected: `./spirit-room/spirit-room close [フォルダ]` を実行すると、コンテナが停止・削除される。`docker ps -a` にそのコンテナが表示されない。
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
