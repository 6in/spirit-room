---
created: 2026-04-18T11:10:31.873Z
title: spirit-room に --docker フラグ追加 (Docker Compose 対応)
area: tooling
files:
  - spirit-room/spirit-room
  - spirit-room/base/Dockerfile
  - spirit-room/base/catalog.md
---

## Problem

修行内容として「Docker Compose で起動するプロダクトを操作する POC」をやらせたい。現状の部屋 (コンテナ) からはホストの Docker を触れないので、Claude が `docker compose up` などを実行できない。

DooD (Docker-out-of-Docker) 方式 = ホストの `/var/run/docker.sock` をマウント + docker CLI を部屋に入れる、で軽量に実現可能。ただし compose 特有の落とし穴が2つある:

1. **ボリュームパス問題**: compose.yaml の `./data:/app/data` は **ホスト dockerd** が解釈するので、部屋の `/workspace/data` ではなくホストのパスを渡す必要がある
2. **ネットワーク到達**: compose が起動した兄弟コンテナの `localhost:PORT` は部屋から見えない

## Solution

TBD — 実装方針:

### CLI (spirit-room/spirit-room)
- `spirit-room open --docker [folder]` フラグを追加
- フラグ指定時の `docker run` 追加オプション:
  - `-v /var/run/docker.sock:/var/run/docker.sock`
  - `--add-host=host.docker.internal:host-gateway` (Linux でも有効)
  - `-e HOST_WORKSPACE="$(realpath "$folder")"` (compose.yaml 側で `${HOST_WORKSPACE}/data:/app/data` と書けるように)
  - `-e SPIRIT_ROOM_HOST_GATEWAY="host.docker.internal"`

### Dockerfile (spirit-room/base/Dockerfile)
- docker CLI + compose plugin を追加 (`curl -fsSL https://get.docker.com | sh` で OK、dockerd は不要)
- イメージサイズ増を許容するか、`--docker` 専用イメージ (`spirit-room-docker:latest`) に分けるか要検討

### Catalog (spirit-room/base/catalog.md)
- compose でボリュームを書くときは `${HOST_WORKSPACE}` を使うこと
- compose のサービスへは `host.docker.internal:PORT` でアクセスすること
- 部屋内からホストの全コンテナを操作可能になるのでミッション範囲を超えた操作はしないこと

### セキュリティ注意
- socket マウント = ホスト root 相当の権限を Claude に渡す
- opt-in (`--docker` フラグ必須) にすることでデフォルトは安全側

### 代替案 (将来検討)
- Sysbox ランタイムで nested docker を安全化
- 共有 user-defined network に部屋と compose サービスを参加させる方式
