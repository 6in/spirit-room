---
quick_id: 260420-j3q
slug: asia-tokyo
description: 部屋コンテナと胡蝶の夢モードの兄弟コンテナのタイムゾーンを Asia/Tokyo に固定 (環境変数で上書き可)
date: 2026-04-20
timestamp: 2026-04-20T04:45:16.966Z
---

# Quick Task: TZ=Asia/Tokyo を部屋 & 兄弟コンテナに適用

## 問題

現在の spirit-room 部屋コンテナは Ubuntu 24.04 ベースイメージのデフォルト (UTC) で動いており、ホスト (日本) とズレる。`date`, `git log`, `tail -f progress.log` などが UTC 表示になり混乱する。胡蝶の夢モードで起動する兄弟コンテナ (例: Python 2.7) も同じくデフォルトで UTC になる。

## 方針 (ユーザー選択)

**(A) Dockerfile で Asia/Tokyo に焼く + 環境変数で上書き可能**

- 部屋コンテナ: Dockerfile に `ENV TZ=Asia/Tokyo` + tzdata インストール + `/etc/localtime` symlink + `/etc/environment` に焼く
- 兄弟コンテナ: catalog.md で compose 側に `environment: TZ: ${TZ}` or `/etc/localtime` マウント指示を追記
- CLI (`spirit-room`) で `docker run -e TZ=${TZ:-Asia/Tokyo}` を渡すことで、ホスト環境変数での上書きパスも残す

## スコープ

### 変更ファイル (4)

1. `spirit-room/base/Dockerfile`
   - Layer 1 の apt install に `tzdata` を追加
   - `ENV TZ=Asia/Tokyo` を追加
   - 新レイヤーで `ln -snf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && echo Asia/Tokyo > /etc/timezone && echo 'TZ=Asia/Tokyo' >> /etc/environment` (su - goku でも TZ が見える状態にする)

2. `spirit-room/base/entrypoint.sh`
   - `/etc/sudoers.d/goku` の `env_keep` に `TZ` を追加 (`sudo` 配下でも保持)
   - goku の `~/.profile` に `export TZ=${TZ:-Asia/Tokyo}` を書く処理を追加 (login shell でも確実に伝搬)

3. `spirit-room/spirit-room`
   - `docker run` の共通 `-e` 引数に `-e TZ=${TZ:-Asia/Tokyo}` を追加
   - ホストに `TZ` が設定されていればそれが優先、無ければ Asia/Tokyo がデフォルト
   - `cmd_open` と `cmd_kaio` の両方に反映

4. `spirit-room/base/catalog.md`
   - 胡蝶の夢モードセクションに新サブセクション「兄弟コンテナの TZ を揃える」を追加
   - 推奨: `environment: TZ: ${TZ:-Asia/Tokyo}` を compose.yaml に書く
   - 代替: `/etc/localtime:/etc/localtime:ro` ボリュームマウント

### スコープ外

- ベースイメージの再ビルド (ユーザー任せ: `cd spirit-room && ./build-base.sh`)
- 既存 `spirit-room-base:latest` に対する上書き検証
- 既に起動中の部屋への TZ 反映 (close → open で再起動が必要)

## 完了条件

- [ ] Dockerfile に `tzdata`, `ENV TZ=Asia/Tokyo`, localtime/timezone/environment 設定が入る
- [ ] entrypoint.sh が `env_keep` と `~/.profile` に TZ を足す
- [ ] spirit-room CLI の `docker run` で `-e TZ=...` が渡される (open / kaio 両方)
- [ ] catalog.md に兄弟コンテナの TZ 指針が書かれる
- [ ] STATE.md の Quick Tasks Completed に 260420-j3q が追加される
- [ ] 全変更が 1 コミットにまとまる

## ブランチ戦略メモ

現在 `phase/06-spirit-room-docker` ブランチ (未マージ) 上で作業。TZ 変更は Phase 6 の DooD/compose まわりと密接なため、Phase 6 squash merge 前なら同じ squash に含めても良い。別ブランチに切り出すなら `chore/tz-asia-tokyo`。今回は現ブランチ上で atomic commit として実施。
