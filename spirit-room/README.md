# 精神と時の部屋 - Spirit Room

> フォルダ = 部屋。`spirit-room open` で修行開始。

リポジトリ全体の概要は [../README.md](../README.md) を参照。ここでは CLI / Docker イメージ / 修行ループの詳細を扱う。

---

## ファイル構成

```
spirit-room/
├── spirit-room                 # ホスト CLI (bash)
├── build-base.sh               # ベースイメージビルド
└── base/
    ├── Dockerfile              # ubuntu 24.04 + Node/Bun + Claude Code + opencode + Docker CLI + SSH
    ├── entrypoint.sh           # goku ユーザー作成、SSH、tmux 3 ペイン
    ├── catalog.md              # 部屋内の利用可能ツールと胡蝶の夢モード ガイダンス
    ├── CLAUDE.md               # 部屋内の Claude 向け指示
    ├── scripts/
    │   ├── start-training.sh        # 4 フェーズ修行ループ (RESEARCH→PREPARE→TRAINING→REPORT)
    │   ├── start-training-kaio.sh   # 界王星モード用修行ループ (GSD 連携)
    │   ├── status.sh                # 進捗確認
    │   ├── MISSION.md.template      # 精神と時の部屋モード用 MISSION
    │   └── KAIO-MISSION.md.template # 界王星モード用 MISSION
    └── skills/                 # 部屋内でデフォルト有効化されるスキル (find-skills 等)
```

---

## セットアップ (初回のみ)

```bash
# 1. ベースイメージをビルド
./build-base.sh

# 2. CLI をインストール
sudo cp spirit-room /usr/local/bin/spirit-room
sudo chmod +x /usr/local/bin/spirit-room

# 3. Claude Code 認証
spirit-room auth
# → ブラウザで Device Flow 認証
# → 認証情報はボリューム spirit-room-auth に保存 (全部屋で共有)
```

---

## 起動モードの使い分け

| モード | コマンド | 用途 |
|--------|---------|------|
| 精神と時の部屋 | `spirit-room open [folder]` | POC 速攻型。Mr.ポポ経由で MISSION.md を生成して修行 |
| 界王星 | `spirit-room kaio [folder]` | GSD で requirements → phases → verify → tag まで本格実装 |
| + 胡蝶の夢 | `--kochou` フラグ | Docker Compose POC 対応 (DooD = Docker-out-of-Docker) |

```bash
# 通常モード
spirit-room open ~/projects/langgraph-poc

# 界王星モード
spirit-room kaio ~/projects/kaio-todo-api

# 胡蝶の夢モード (compose を使う POC)
spirit-room open --kochou ~/projects/nginx-demo
spirit-room kaio --kochou ~/projects/kaio-compose-app
```

---

## 主要 CLI コマンド

```bash
spirit-room open  [--kochou] [folder]   # 部屋を開く
spirit-room kaio  [--kochou] [folder]   # 界王星モードで部屋を開く
spirit-room enter [folder]              # 部屋に入る (tmux アタッチ)
spirit-room list                        # 起動中の部屋一覧
spirit-room close [folder]              # 部屋を閉じる (--kochou 時は兄弟コンテナも削除)
spirit-room logs  [folder]              # 修行ログを tail
spirit-room auth                        # Claude Code 認証 (一度だけ)
```

---

## プロジェクトフォルダの構成

```
~/projects/langgraph-poc/     ← spirit-room open するフォルダ = 部屋本体
├── MISSION.md                ← Mr.ポポが生成 (必須)
├── catalog.md                ← ツールカタログ上書き (任意)
├── compose.yaml              ← 胡蝶の夢モード時の兄弟コンテナ定義 (任意)
├── .logs/progress.log        ← 修行ログ (自動生成)
├── .prepared / .done         ← フェーズ冪等フラグ
├── .journal.md               ← PHASE 2 作業ログ
├── RESEARCH.md               ← PHASE 0 成果物
├── REPORT.md                 ← PHASE 3 成果物
├── README.md                 ← 実装サマリ (必須)
└── (POC の成果物がここに生まれる)
```

---

## 部屋の中でやること

```bash
# 部屋に入ると tmux 3 ペイン (training / logs / workspace) が自動で立ち上がる

# 修行開始
start-training               # Claude Code で
start-training opencode      # opencode で
start-training-kaio          # 界王星モード用

# 進捗確認
status

# MISSION テンプレートを見る
cat /room/scripts/MISSION.md.template
cat /room/scripts/KAIO-MISSION.md.template

# 胡蝶の夢モードの使い方を確認
cat /room/catalog.md   # "胡蝶の夢モード" セクション参照
```

---

## catalog.md のカスタマイズ

プロジェクトフォルダに `catalog.md` を置くとデフォルト (`base/catalog.md`) より優先される。新しいフレームワークを試すたびに育てていくと部屋が賢くなる。

```bash
cp /room/catalog.md ~/projects/langgraph-poc/catalog.md
vim ~/projects/langgraph-poc/catalog.md   # LangGraph の説明を追記
```

---

## 胡蝶の夢モード (`--kochou`) の概要

Phase 6 で追加された DooD (Docker-out-of-Docker) モード。部屋から `/var/run/docker.sock` 経由でホストの dockerd を操作し、compose で兄弟コンテナを立てる。

**使える挙動:**
- `docker compose up -d` でホスト上に兄弟コンテナを起動
- 部屋から兄弟への到達は `host.docker.internal:<PORT>` 経由
- `spirit-room close` で部屋本体と兄弟コンテナを一括削除

**必ず守るルール** (詳細は `base/catalog.md` の胡蝶の夢セクション参照):
- compose.yaml のボリュームは `${HOST_WORKSPACE}/...` でホスト絶対パスを経由すること
- `name:` / `container_name:` を書かない (close 時の兄弟掃除が効かなくなる)
- 兄弟コンテナの TZ を揃えたければ `environment: TZ: ${TZ:-Asia/Tokyo}` を書く

**セキュリティ:** socket マウントはホスト root 相当の権限。`--kochou` は opt-in 設計、デフォルトでは付与されない。

---

## タイムゾーン

部屋本体は **Asia/Tokyo** に固定 (Dockerfile `ENV TZ=Asia/Tokyo`)。上書きは `docker run -e TZ=...` で可能。兄弟コンテナは compose 側で明示的に指定する (上記参照)。

---

## ベースイメージの更新タイミング

| 操作 | 再ビルド |
|---|---|
| MISSION.md / プロジェクト側 catalog.md 変更 | 不要 |
| `base/` 配下 (Dockerfile / entrypoint.sh / catalog.md / scripts / skills / CLAUDE.md) 修正 | **必要** |
| Claude Code / opencode のバージョン上げ | **必要** |
| 新ツール追加 | **必要** |

```bash
./build-base.sh
```

---

## 内部構成

### コンテナレイアウト

| パス | 内容 |
|------|------|
| `/workspace/` | プロジェクトフォルダ (read-write マウント) |
| `/room/` | 部屋共有リソース (scripts / catalog.md / CLAUDE.md / skills) — イメージ内 read-only |
| `/logs/` | `progress.log` のシンボリック先 |
| `/home/goku/.claude/` | 共有認証ボリューム (`spirit-room-auth`) |
| `/home/goku/.config/opencode/` | 共有認証ボリューム (`spirit-room-opencode-auth`) |

### goku ユーザー (Phase 5)

部屋は root ではなく **goku** ユーザーで動く (ホスト UID/GID と一致)。`/workspace` の成果物がホスト側でも自ユーザー所有になり、sudo chown 不要。

### 4 フェーズ修行ループ (start-training.sh)

1. **PHASE 0 (RESEARCH)**: `/workspace/RESEARCH.md` を作成
2. **PHASE 1 (PREPARE)**: 依存インストール → `.prepared` 作成
3. **PHASE 2 (TRAINING)**: POC 実装 → `.done` 作成
4. **PHASE 3 (REPORT)**: 別セッションが `.journal.md` を読んで `REPORT.md` 執筆

各フェーズは冪等 (`.prepared` / `.done` で再開可能)。

---

## 関連ドキュメント

- リポジトリ全体の概要: [../README.md](../README.md)
- Mr.ポポ (管理 AI) の使い方: [../spirit-room-manager/README.md](../spirit-room-manager/README.md)
- Claude Code 向け開発指示: [../CLAUDE.md](../CLAUDE.md)
- 開発計画 (GSD): `../.planning/`
