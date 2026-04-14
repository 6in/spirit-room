# 引継書 - 精神と時の部屋プロジェクト

次のClaudeへ。このドキュメントを最初に読め。

---

## プロジェクト概要

Dockerコンテナを「精神と時の部屋」として使い、AIエージェントが自律的にフレームワークのPOCを実装する環境。ユーザーは後から次々出てくるエージェントフレームワークを、時間をかけずに理解したい。

---

## 現在の実装状態

### 完成しているもの

```
spirit-room/                      # ベースイメージ一式
├── base/
│   ├── Dockerfile                # ubuntu + Node.js + claude-code + opencode + SSH + tmux
│   ├── entrypoint.sh             # SSH起動 + tmux 3ペイン構成
│   ├── catalog.md                # デフォルトツールカタログ
│   └── scripts/
│       ├── start-training.sh     # 修行開始（claude or opencode）
│       ├── status.sh             # 進捗確認
│       └── MISSION.md.template
├── build-base.sh                 # イメージビルド
└── spirit-room                   # ホストCLI（open/enter/list/close/logs/auth）

spirit-room-manager/              # Mr.ポポ管理AI
├── CLAUDE.md                     # claudeが起動時に読む
└── skills/
    └── MR_POPO.md                # ヒアリング→MISSION生成→部屋起動スキル
```

### 未実装・作業中のもの

| 機能 | 状態 | メモ |
|---|---|---|
| Bun追加 | ✅完了 | レイヤー3に追加済み |
| モニタリングWeb UI | 未実装 | Bun + SSE + docker.sock（次のタスク） |
| `spirit-room monitor` コマンド | 未実装 | CLIに追加が必要 |
| ポート決定論的計算 | 未実装 | フォルダ名ハッシュ→ポート番号 |

---

## 設計の重要な決定事項

### フォルダ = 部屋
```bash
cd ~/projects/langgraph-poc
spirit-room open    # このフォルダがそのままコンテナにマウントされる
                    # コンテナ名も spirit-room-langgraph-poc になる
```

### 認証ボリュームの共有
```
spirit-room-auth        # Claude Code認証（全部屋で共有）
spirit-room-opencode-auth  # opencode認証（全部屋で共有）
→ spirit-room auth で一度だけ認証すれば全部屋で使える
```

### catalog.mdの優先順位
```
/workspace/catalog.md（プロジェクトフォルダ）> /room/catalog.md（デフォルト）
→ プロジェクト固有のツールを追加できる
```

### Mr.ポポの動き
```
~/spirit-room-manager/ で claude を起動
→ CLAUDE.md を読んで Mr.ポポとして動作
→ MR_POPO.md のヒアリング手順に従ってユーザーと会話
→ MISSION.md生成 → spirit-room open 実行
```

---

## ユーザーについて

- シニアアーキテクト、エンタープライズ系20年超
- 社内AIエージェント基盤の研究開発に関わっている
- 詳細説明より「設計の意図と判断の分岐点」を好む
- 動かしながら育てる派（完璧を最初から求めない）
- ベテランなので技術的な説明は省略してよい

---

## 次にやること

ユーザーが「動かしながらやっていく」と言っているので、
まず `./build-base.sh` を実行して実際に動く環境を作るところから始まる。

つまずきポイントとして予想されるもの：
1. `claude auth login` のDevice FlowがDockerコンテナ内で動くか
2. `claude -p` の `--allowedTools` フラグの正確なオプション名（バージョンで変わる）
3. opencode のインストールパッケージ名（`opencode-ai` が正しいか要確認）

---

## 会話のトーン

- 技術的な話は対等に
- 設計の分岐点では選択肢を提示して判断を仰ぐ
- 実装前に大量にファイルを作らない（ユーザーに止められた実績あり）
- ネーミングセンスを大事にする（Mr.ポポ等、世界観を壊さない）

---

## start-training.sh の設計（重要）

2フェーズのbashループで構成される。

```
PHASE 1: PREPARE
  while true; do
    [ -f .prepared ] && break   ← 先にチェック（再起動時のスキップ）
    claude -p "インストールして .prepared を作成せよ"
    sleep 3
  done

PHASE 2: TRAINING
  while true; do
    [ -f .done ] && break       ← 先にチェック
    claude -p "MISSION.mdを実装して .done を作成せよ"
    sleep 3
  done
```

- `.prepared` / `.done` フラグで冪等性を保証
- コンテナ再起動・Claudeプロセス再起動に対して安全にレジューム可能
- 「ループはbashで制御、判断はClaudeで」の設計哲学に従っている

## サービス構成（確定）

| サービス | 種別 | 備考 |
|---|---|---|
| SQLite | ベースイメージ組み込み | sqlite3 + libsqlite3-dev |
| Redis | ベースイメージ組み込み | entrypoint.shで自動起動 |
| PostgreSQL | Mr.ポポが都度判断 | docker-compose.ymlを生成 |
| MySQL | Mr.ポポが都度判断 | 同上 |
| MongoDB | Mr.ポポが都度判断 | 同上 |
