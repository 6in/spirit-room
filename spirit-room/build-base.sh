#!/bin/bash
# spirit-room-base イメージをビルドする
# 初回または Claude Code / opencode のバージョンを上げたい時だけ実行

set -e

IMAGE_NAME="spirit-room-base"
TAG="${1:-latest}"

echo "
╔══════════════════════════════════════════════╗
║  Spirit Room ベースイメージをビルド中...     ║
║  イメージ: $IMAGE_NAME:$TAG
╚══════════════════════════════════════════════╝
"

docker build \
    --progress=plain \
    -t "$IMAGE_NAME:$TAG" \
    ./base

echo "
╔══════════════════════════════════════════════╗
║  ビルド完了: $IMAGE_NAME:$TAG
╚══════════════════════════════════════════════╝
"

docker images "$IMAGE_NAME"
