# 利用可能ツールカタログ

あなたはこのカタログに記載されたツールを自由に組み合わせて使うことができる。
タスクの性質に応じて最適なものを自分で選択せよ。

> **注**: ベースイメージにプリインストールされているツールの完全な一覧と利用指針は `/room/CLAUDE.md` を参照せよ。このカタログはエージェントツール（claude / opencode）の使い分けと、追加インストール手順を中心に扱う。

---

## Claude Code (`claude`)
**得意領域**: コード生成・編集・リファクタリング・ファイル操作全般  
**起動**: `claude -p "..."` または対話モード `claude`  
**向いている場面**: コードベース全体を把握しながら実装を進めたい時  
**備考**: 現在の実行環境そのもの

---

## opencode (`opencode`)
**得意領域**: マルチプロバイダー対応、並列処理  
**起動**: `opencode -p "..."`  
**向いている場面**: 複数の実装案を試したい時、別プロバイダーを使いたい時  
**認証**: `opencode auth` で設定

---

## 標準ツール（常時利用可能）
| コマンド | 用途 |
|---|---|
| `python3` | スクリプト実行・テスト |
| `node` / `npm` | JS/TSの実行・パッケージ管理 |
| `git` | バージョン管理 |
| `curl` / `wget` | HTTP通信・API確認 |
| `jq` | JSON処理 |
| `tmux` | セッション管理・並列作業 |

---

## ディレクトリ規約
```
/workspace/     ← 成果物はここに置く（ホストと共有）
/mission/       ← MISSION.md（読み取り専用として扱う）
/catalog/       ← このファイル
/logs/          ← progress.log に進捗を記録すること
```

---

## 追加ツールのインストール
必要であれば以下でインストールできる。インストールしたものはcatalog.mdへの追記を推奨。

```bash
# Node.js パッケージ
npm install -g <package>

# Python パッケージ（Ubuntu 24.04 では --break-system-packages が必要）
pip3 install <package> --break-system-packages

# または venv を使う場合
python3 -m venv /workspace/.venv
source /workspace/.venv/bin/activate
pip install <package>
```

---

## 胡蝶の夢モード — Docker Compose (SPIRIT_ROOM_KOCHOU=1 時)

> **このセクションは `SPIRIT_ROOM_KOCHOU=1` 環境変数が設定されている時のみ適用される。**
> `env | grep SPIRIT_ROOM_KOCHOU` で確認せよ。未設定ならこのセクションは無視してよい。
>
> *胡蝶の夢* (荘子): 部屋 (夢) から現実 (host) の docker を動かせる DooD モード。
> 夢か現か、境界が溶ける感覚にちなむ命名。`spirit-room open --kochou` で起動される。

### 使える挙動

- ホスト側の docker daemon が叩ける (`/var/run/docker.sock` マウント済み)
- `docker compose up` でホスト上に兄弟コンテナを起動できる
- 部屋から兄弟コンテナへは `host.docker.internal:<PORT>` でアクセス可能

### 重要なルール

#### ボリュームパスは `${HOST_WORKSPACE}` を使う

compose.yaml は**ホスト dockerd** が解釈するので、コンテナ内パス (`/workspace/data`) ではなく**ホスト側の絶対パス**が必要。

```yaml
# これは動かない: コンテナ内の相対パスをホスト dockerd が解釈できない
services:
  app:
    volumes:
      - ./data:/app/data

# これを使う: HOST_WORKSPACE がホスト側の絶対パスを保持している
services:
  app:
    volumes:
      - ${HOST_WORKSPACE}/data:/app/data
```

#### `COMPOSE_PROJECT_NAME` は compose.yaml に書かない

既に `$COMPOSE_PROJECT_NAME` が部屋名 (`spirit-room-<フォルダ名>`) にセットされている。

compose.yaml に `name:` を書くと上書きされ、`spirit-room close` 時の兄弟コンテナ自動掃除が効かなくなる。**書かないこと**。

#### サービスへのアクセスは `host.docker.internal`

部屋内から compose サービスの `localhost:PORT` は見えない (兄弟コンテナはホストから見た別ネームスペース)。

```bash
# 部屋内からアクセスする場合
curl http://${SPIRIT_ROOM_HOST_GATEWAY:-host.docker.internal}:8080/
```

#### docker グループが使えない場合は `sudo`

起動ログに `docker grp: 合流失敗` または `HOST_DOCKER_GID 未取得` とあれば、`sudo docker ...` / `sudo docker compose ...` を使う (Phase 5 で goku に `NOPASSWD:ALL` 付与済み)。

#### 兄弟コンテナの TZ を部屋と揃える

部屋本体は Asia/Tokyo に固定されている (`docker run -e TZ=...` で上書き可)。兄弟コンテナは**デフォルトで UTC** なので、ログや `date` コマンドがズレたくない場合は明示的に揃える:

**推奨 (environment):**

```yaml
services:
  app:
    image: python:3.12
    environment:
      TZ: ${TZ:-Asia/Tokyo}   # 部屋の TZ を引き継ぐ (未設定なら Asia/Tokyo)
```

**代替 (volume マウント):** イメージに tzdata が無い / `TZ` を読まない古いランタイム向け。

```yaml
services:
  app:
    image: legacy:latest
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
```

両者は併用可。特に古い Python 2.7 のような tzdata 同梱ありのイメージはどちらでも効く。

### compose.yaml の最小例

```yaml
# nginx で動作確認する最小 compose.yaml
# /workspace/compose.yaml に置いて docker compose up -d で起動
services:
  web:
    image: nginx:alpine
    environment:
      TZ: ${TZ:-Asia/Tokyo}
    ports:
      - "8080:80"
    volumes:
      - ${HOST_WORKSPACE}/html:/usr/share/nginx/html:ro
```

起動確認:
```bash
docker compose up -d
curl http://${SPIRIT_ROOM_HOST_GATEWAY:-host.docker.internal}:8080/
```

掃除は部屋の外から `spirit-room close` を実行するだけ (兄弟コンテナも自動削除される)。

### セキュリティ注意

`/var/run/docker.sock` マウント = ホスト root 相当の権限。以下の操作はしないこと:

- 他の部屋 (`spirit-room-*`) を stop / rm する
- ホストのシステムコンテナを操作する
- ミッション範囲を超えた docker 操作全般
