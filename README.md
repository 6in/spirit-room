# 精神と時の部屋 (Spirit Room)

> Docker コンテナを AI 修行の場として使い、AIエージェント (Claude Code / opencode) が自律的にフレームワーク POC を実装するサンドボックス環境。

Dragon Ball Z の「精神と時の部屋」をモチーフにした AI 開発環境。**Mr.ポポ** (管理 AI) にフレームワーク名と目的を伝えれば、Claude Code が隔離コンテナ内で自律的に POC を完成させる。

## Core Value

**Mr.ポポにフレームワーク名と目的を伝えたら、Claude Code が自律的に POC を実装して動くところまで完成させる。**

## クイックスタート

### 1. ベースイメージをビルド (初回のみ)

```bash
cd spirit-room
./build-base.sh
```

### 2. CLI をインストール

```bash
sudo cp spirit-room/spirit-room /usr/local/bin/spirit-room
sudo chmod +x /usr/local/bin/spirit-room
```

### 3. 認証 (初回のみ)

```bash
spirit-room auth
# Claude Code の Device Flow 認証。共有ボリュームに保存され全部屋で共有される
```

### 4. Mr.ポポ に相談して修行を始める

```bash
cd spirit-room-manager
claude
# Mr.ポポ が起動。ヒアリングを受けて MISSION.md を生成 → 部屋を開く
```

## ディレクトリ構成

```
spirit-room-full/
├── spirit-room/              # コア基盤 (bash + Docker)
│   ├── spirit-room           # ホスト CLI (open/enter/list/close/logs/auth/kaio/monitor)
│   ├── build-base.sh         # ベースイメージビルドスクリプト
│   └── base/                 # コンテナイメージ定義 (Dockerfile, entrypoint, catalog.md, scripts)
│       └── README.md は spirit-room/README.md 参照
├── spirit-room-manager/      # Mr.ポポ (管理 AI) の格納場所
│   ├── CLAUDE.md             # Claude を Mr.ポポ として起動させる指示
│   └── skills/MR_POPO.md     # ヒアリング → MISSION.md 生成 → 部屋起動スキル
└── .planning/                # GSD (Get Shit Done) 開発計画資産
```

詳細は各サブディレクトリの README を参照:
- **[spirit-room/README.md](./spirit-room/README.md)** — CLI / Docker イメージ / 修行ループの仕組み
- **[spirit-room-manager/README.md](./spirit-room-manager/README.md)** — Mr.ポポ の使い方とヒアリングフロー

## 修行モード

| モード | 起動コマンド | 用途 |
|--------|-------------|------|
| **精神と時の部屋** | `spirit-room open` | POC 速攻型。フレームワークを触って動くところまで |
| **界王星** | `spirit-room kaio` | 重力 10 倍。GSD で requirements → phases → verify → tag まで本格実装 |
| **+ 胡蝶の夢モード** | `--kochou` フラグを付与 | Docker Compose POC 対応。部屋から兄弟コンテナを立てる (DooD) |

## 主要コマンド

```bash
spirit-room open [--kochou] [folder]   # 部屋を開く
spirit-room kaio [--kochou] [folder]   # 界王星モードで部屋を開く (GSD ベース)
spirit-room enter [folder]             # 部屋に入る (tmux アタッチ)
spirit-room list                       # 起動中の部屋一覧
spirit-room close [folder]             # 部屋を閉じる (--kochou 起動時は兄弟コンテナも自動削除)
spirit-room logs [folder]              # 修行ログを tail
spirit-room auth                       # Claude Code 認証 (一度だけ)
```

## 制約と設計原則

- **Tech Stack**: bash + Docker のみ (Node.js/Python 等をコア基盤には追加しない)
- **Simplicity**: 実装前に大量のファイルを作らない。動いてから育てる
- **Naming**: Dragon Ball 世界観 (Mr.ポポ、精神と時の部屋、界王星、胡蝶の夢) を守る

## 要件

- Docker デーモン (Linux / Docker Desktop)
- bash
- SSH クライアント
- 2+ GB RAM per アクティブ部屋
- 空きポート 2222 以上 (自動割り当て)

## 開発者向け

- **開発計画**: `.planning/` 配下 (GSD = Get Shit Done フレームワーク)
- **Phase 1-3**: 基盤構築 (Dockerfile / 認証 / 修行ループ / E2E)
- **Phase 4**: 界王星モード (GSD 駆動の本格開発)
- **Phase 5**: goku ユーザー (ホスト UID/GID 一致)
- **Phase 6**: 胡蝶の夢モード (`--kochou` = Docker-out-of-Docker)
- **Claude Code 向け指示**: [CLAUDE.md](./CLAUDE.md)

## ライセンス

TBD
