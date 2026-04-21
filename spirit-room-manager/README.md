# Mr.ポポ (spirit-room-manager)

> 精神と時の部屋の管理人。ユーザーと会話して修行の目的を引き出し、MISSION.md を生成し、部屋を開く。

リポジトリ全体の概要は [../README.md](../README.md) を参照。ここでは Mr.ポポの起動方法とヒアリングフローを扱う。

## Mr.ポポとは

`spirit-room open` や `spirit-room kaio` を叩く前の **人間対 AI 対話層**。ユーザーから何をやりたいかを引き出し、それを MISSION.md (部屋内の Claude が読む指示書) に変換して部屋を開くところまで面倒を見る AI。

Claude Code をこのディレクトリで起動すると、[CLAUDE.md](./CLAUDE.md) の指示により **その Claude インスタンスが Mr.ポポ として振る舞う**。

## 起動方法

```bash
cd spirit-room-manager
claude
```

Mr.ポポから最初の一言が来る:

> よく来たな。ここは精神と時の部屋だ。

続いて `AskUserQuestion` で Step 0 (修行モード選択) が提示される。そこから順にヒアリングが進む。

## 修行モード (Step 0)

| モード | 特徴 | 起動先 |
|--------|------|--------|
| **精神と時の部屋** | POC 速攻型。フレームワークを触って動くところまで | `spirit-room open [--kochou]` |
| **界王星** | 重力 10 倍。GSD で requirements → phases → verify → tag まで本格実装 | `spirit-room kaio [--kochou]` |

## ヒアリングフロー

### 精神と時の部屋モード (Step 1-3)

| Step | 内容 | 形式 |
|------|------|------|
| 1-a | フレームワーク / ライブラリ | 選択肢 (LangGraph / Next.js / FastAPI / Prisma / React Flow / その他) |
| 1-b | 何を理解したいか | 選択肢 (概念 / 動作確認 / 実装パターン / その他) |
| 1-c | 調査観点 | multiSelect (API の癖 / 設計思想 / 性能 / 他との比較 / 特になし / その他) |
| 2 | 完了条件 | 選択肢 (動けばいい / テスト必須 / README まで / その他) |
| 3-a | 外部 API | 選択肢 (使ってよい / 使わない / その他) |
| 3-b | バージョン / 参考 URL | 選択肢 (なし / あり (自由記述)) |
| **3-c** | **胡蝶の夢モード** | 選択肢 (はい → `--kochou` / いいえ) |

完了後、Mr.ポポが MISSION.md を生成 → `spirit-room open [--kochou] ~/projects/<folder>` で部屋を開く。

### 界王星モード (K1-K5)

| Step | 内容 |
|------|------|
| K1-a | プロジェクト種別 (Web API / CLI / フロントエンド / バッチ / その他) |
| K1-b | 具体的に何を作りたいか (自由記述) |
| K2 | 機能要件 (自由記述、3〜5 個) |
| K3 | フェーズ分割のヒント (GSD 任せ / ヒントあり) |
| K4 | 成功条件 (pytest pass / git tag v1.0 / その他) |
| K5-a | 言語・ランタイム |
| K5-b | 外部 API |
| K5-c | 依存追加方針 |
| **K5-d** | **胡蝶の夢モード** (compose で他サービスを立てるか) |

完了後、`KAIO-MISSION.md` を生成 → `spirit-room kaio [--kochou] ~/projects/<folder>` で起動。GSD が部屋内で自律的に開発を進める。

## 胡蝶の夢モード (`--kochou`) 判定

Step 3-c / K5-d でプロジェクトが `docker compose` で他サービス (DB / nginx / Redis 等) を立てる必要があるかを必ず確認する。「はい」を選んだ場合のみ `--kochou` フラグ付きで部屋を起動する。

`--kochou` 付きで起動された部屋は:
- `/var/run/docker.sock` がマウントされ、部屋から `docker compose up` 可能
- `host.docker.internal:<PORT>` で兄弟コンテナに到達可能
- `spirit-room close` で部屋と兄弟コンテナがまとめて削除される

詳細は `../spirit-room/base/catalog.md` の「胡蝶の夢モード」セクション参照。

## ファイル構成

```
spirit-room-manager/
├── CLAUDE.md          # Claude 起動時の指示 (Mr.ポポ としての振る舞い)
├── HANDOVER.md        # 実装状態、設計決定、次のステップ (次のClaude向け)
├── README.md          # このファイル
└── skills/
    └── MR_POPO.md     # ヒアリング手順の詳細 (Step 0 / 1-3 / K1-K5 と MISSION.md 生成ルール)
```

## Mr.ポポに渡す事前仕様書 (BRIEF.md) パターン

ヒアリングを対話で進めるのが基本だが、事前に決まっている場合は BRIEF.md 形式で各 Step の回答をまとめて貼り付けることで短縮できる。例は `../.planning/quick/260420-hkp-python-2-7-hello-world/BRIEF.md` を参照。

## 命名規則

| モード | フォルダ名 | コンテナ名 |
|--------|-----------|-----------|
| 精神と時の部屋 | `[framework]-[goal]-poc` (例: `langgraph-subgraph-poc`) | `spirit-room-[folder]` |
| 界王星 | `kaio-[project]` (例: `kaio-todo-api`) | `spirit-room-[folder]-kaio` |

Mr.ポポ がヒアリング結果からフォルダ名を提案してくる。

## 報告フォーマット

部屋起動後、Mr.ポポは以下の形式で報告する:

```
部屋の準備ができました。

  フォルダ : ~/projects/[名前]
  コンテナ : spirit-room-[名前]

修行の状況確認:
  spirit-room logs ~/projects/[名前]
```

## 関連ドキュメント

- リポジトリ全体の概要: [../README.md](../README.md)
- CLI / Docker イメージの詳細: [../spirit-room/README.md](../spirit-room/README.md)
- Mr.ポポ の起動指示: [CLAUDE.md](./CLAUDE.md)
- ヒアリング手順の詳細: [skills/MR_POPO.md](./skills/MR_POPO.md)
- 実装状態と引継: [HANDOVER.md](./HANDOVER.md)
