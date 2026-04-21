---
quick_id: 260420-j3q
slug: asia-tokyo
completed: 2026-04-20
status: complete
---

# Quick Task SUMMARY — TZ=Asia/Tokyo を部屋 & 兄弟コンテナに適用

## 実施内容

部屋コンテナのタイムゾーンを Asia/Tokyo に固定。ホストの `TZ` 環境変数で上書き可能。胡蝶の夢モードで立ち上げる兄弟コンテナにも同じ TZ を揃える方法を catalog.md に追記した。

## 変更ファイル

### 1. `spirit-room/base/Dockerfile`

- `ENV TZ=Asia/Tokyo` を追加
- apt install に `tzdata` を追加
- 新規 RUN レイヤーで `/etc/localtime` の symlink + `/etc/timezone` の書き込み + `/etc/environment` に `TZ=Asia/Tokyo` を焼く (`su - goku` login shell / PAM セッションでも引き継がれるため)

### 2. `spirit-room/base/entrypoint.sh`

- `/etc/sudoers.d/goku` の `Defaults env_keep` に `TZ` を追加
- goku の `~/.profile` に `export TZ=${TZ:-Asia/Tokyo}` を常時書き込む処理 (CLAUDE_CONFIG_DIR と同じパターン)。`docker run -e TZ=...` で上書きされたときも goku login shell に確実に伝わる

### 3. `spirit-room/spirit-room`

- `cmd_open` / `cmd_kaio` の両方の `docker run -d` に `-e TZ="${TZ:-Asia/Tokyo}"` を追加
- ホストに `TZ` が export されていればそれを優先、無ければ Asia/Tokyo をデフォルトで渡す

### 4. `spirit-room/base/catalog.md`

- 胡蝶の夢モードセクションに新サブセクション「兄弟コンテナの TZ を部屋と揃える」を追加
- 推奨: `environment: TZ: ${TZ:-Asia/Tokyo}` を compose.yaml に書く
- 代替: `/etc/localtime:/etc/localtime:ro` + `/etc/timezone:/etc/timezone:ro` ボリュームマウント
- 既存の nginx 最小例にも `environment: TZ: ${TZ:-Asia/Tokyo}` を追記

## 反映に必要な作業

**ベースイメージ再ビルドが必要:**

```bash
cd spirit-room
./build-base.sh
```

再ビルド後は新しく立ち上げた部屋 (close → open) から TZ が有効になる。起動中の部屋への反映は close → open の再起動で。

## 動作確認の観点 (次回ユーザーが走らせるとき)

```bash
# 部屋本体
spirit-room open ~/projects/tz-check
spirit-room enter ~/projects/tz-check
# 部屋の中で
date                      # JST で表示されること
env | grep TZ             # TZ=Asia/Tokyo
sudo env | grep TZ        # TZ=Asia/Tokyo (env_keep に入っていれば残る)

# 胡蝶の夢モード (兄弟コンテナ)
spirit-room open --kochou ~/projects/kochou-tz-check
spirit-room enter ~/projects/kochou-tz-check
# 部屋の中で
cat > /workspace/compose.yaml <<'EOF'
services:
  tz:
    image: alpine
    environment:
      TZ: ${TZ:-Asia/Tokyo}
    command: ["sh", "-c", "date"]
EOF
docker compose run --rm tz   # Fri Apr 20 ... JST 2026 のように JST で出ること
```

## 関連

- Phase 6 (✓ 2026-04-19): spirit-room --kochou フラグ (胡蝶の夢モード)
- Quick 260420-hkp: 胡蝶の夢モード Python 2.7 Hello World 仕様書 (ここで作った TZ 設定の恩恵を受ける)

## Next

- ユーザーがベースイメージを再ビルドして動作確認 (`./spirit-room/build-base.sh`)
- 問題なければ Phase 6 の squash merge にこの TZ 変更も同梱する (あるいは独立した chore として merge)
