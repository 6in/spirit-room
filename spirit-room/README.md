# 精神と時の部屋 - Spirit Room

> フォルダ = 部屋。`spirit-room open` で修行開始。

---

## ファイル構成

```
spirit-room/
├── base/
│   ├── Dockerfile               # ベースイメージ定義
│   ├── entrypoint.sh            # 起動スクリプト（イメージに焼き込む）
│   ├── catalog.md               # デフォルトツールカタログ
│   └── scripts/
│       ├── start-training.sh    # 修行開始コマンド
│       ├── status.sh            # 進捗確認コマンド
│       └── MISSION.md.template  # MISSIONテンプレート
├── build-base.sh                # ベースイメージビルド
└── spirit-room                  # ホスト側CLIコマンド
```

---

## セットアップ（初回のみ）

```bash
# 1. ベースイメージをビルド
./build-base.sh

# 2. CLIをインストール
sudo cp spirit-room /usr/local/bin/spirit-room
sudo chmod +x /usr/local/bin/spirit-room

# 3. Claude Code 認証
spirit-room auth
# → ブラウザでDevice Flow認証
# → 認証情報はボリューム spirit-room-auth に保存（全部屋で共有）
```

---

## 使い方

```bash
# 部屋を開く（カレントフォルダ）
cd ~/projects/langgraph-poc
spirit-room open

# 部屋を開く（フォルダ指定）
spirit-room open ~/projects/mastra-trial

# 部屋に入る
spirit-room enter ~/projects/langgraph-poc

# 起動中の部屋一覧
spirit-room list

# 修行ログを見る（ホストから）
spirit-room logs ~/projects/langgraph-poc

# 部屋を閉じる
spirit-room close ~/projects/langgraph-poc
```

---

## プロジェクトフォルダの構成

```
~/projects/langgraph-poc/     ← spirit-room open するフォルダ
├── MISSION.md                ← 目的と完了条件（必須）
├── catalog.md                ← ツールカタログ上書き（任意）
├── .logs/
│   └── progress.log          ← 修行ログ（自動生成）
└── (成果物がここに生まれる)
```

---

## 部屋の中でやること

```bash
# 部屋に入ったら
tmux attach -t spirit-room   # 自動でついてる

# 修行開始
start-training               # Claude Codeで
start-training opencode      # opencodeで

# 進捗確認
status

# MISSIONテンプレートを見る
cat /room/scripts/MISSION.md.template
```

---

## catalog.mdのカスタマイズ

フォルダに `catalog.md` を置くとデフォルトより優先される。
新しいフレームワークを試すたびに育てていくと部屋が賢くなる。

```bash
cp /room/catalog.md ~/projects/langgraph-poc/catalog.md
vim ~/projects/langgraph-poc/catalog.md  # LangGraph の説明を追記
```

---

## ベースイメージの更新タイミング

| 操作 | 再ビルド |
|---|---|
| MISSION.md / catalog.md 変更 | 不要 |
| start-training.sh 修正 | **必要** |
| Claude Code バージョンアップ | **必要** |
| 新ツール追加 | **必要** |

```bash
./build-base.sh
```
