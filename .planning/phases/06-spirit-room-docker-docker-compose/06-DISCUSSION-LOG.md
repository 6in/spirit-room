# Phase 6: spirit-room --docker (Compose 対応) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 06-spirit-room-docker-docker-compose
**Areas discussed:** Docker CLI の配置方式, goku の sock アクセス方式, --docker の cmd_kaio 対応, 兄弟コンテナのライフサイクルと警告表示

---

## Docker CLI の配置方式

### Q1: docker CLI + compose plugin をどこに入れますか？

| Option | Description | Selected |
|--------|-------------|----------|
| spirit-room-base に常時同梱 | 1 イメージで管理シンプル。--docker 未使用時は CLI があるだけで実害なし。Simplicity 制約と整合 | ✓ |
| 別イメージ spirit-room-docker:latest に分離 | 不要ケースで軽量。build-base.sh にタグ分岐が必要、--docker 時に BASE_IMAGE 切替 | |
| マルチステージで 2 タグ生成 (ARG INSTALL_DOCKER) | 中間案。イメージ層の統一性は保てるが CI 対応が必要 | |

**User's choice:** spirit-room-base に常時同梱
**Notes:** PROJECT.md の Simplicity を優先。イメージサイズ +100-150MB は許容。

### Q2: docker CLI + compose plugin のインストール手段は？

| Option | Description | Selected |
|--------|-------------|----------|
| get.docker.com スクリプト | curl 一発。docker-ce + docker-ce-cli + containerd + docker-compose-plugin が全て入る。dockerd 未起動で実害なし | |
| apt + docker 公式 repo | apt-get install docker-ce-cli docker-compose-plugin のみ。イメージ小さめ、依存明確 | |
| 静的バイナリ直接DL + compose plugin 単体DL | 最軽量だが apt repo に乗らないのでアップデートは手動 | |

**User's choice:** "最初からイメージに追加しておく。" (Other)
**Notes:** 手段は Claude 裁量。CONTEXT.md では get.docker.com を推奨線として記載。

### Q3: Docker CLI の Dockerfile 追加位置は？

| Option | Description | Selected |
|--------|-------------|----------|
| Node.js/Bun の後、SSH 設定の前 (新規レイヤー) | レイヤー機能分割に "Docker CLI" を挿入。後続キャッシュを壊さない | ✓ |
| レイヤー1 (基本パッケージ) に同居 | レイヤー数が減るがビルド時間長くなる | |
| 全然別の終盤 (SSH/Git の後) | キャッシュ破壊最小だが順序が inconsistent | |

**User's choice:** Node.js/Bun の後、SSH 設定の前

---

## goku の sock アクセス方式

### Q1: goku に docker.sock を触らせる方式は？

| Option | Description | Selected |
|--------|-------------|----------|
| entrypoint でホストの docker GID を動的取得 + goku を docker グループに所属 | --docker 時のみ CLI が -e HOST_DOCKER_GID を渡し、entrypoint で groupadd + usermod -aG。ホスト sock と整合 | ✓ |
| sudo docker ... を claude に使わせる (docker グループ不要) | Phase 5 の NOPASSWD:ALL に依存。Claude が毎回 sudo を打つ | |
| sock の permissions を 666 に緩める | ホスト側 sock の permissions を変える行為、セキュリティ的にNG | |

**User's choice:** ホスト docker GID 動的取得 + goku 所属
**Notes:** Phase 5 の HOST_UID/GID 方式と同じパターンで横展開。

### Q2: HOST_DOCKER_GID を CLI から渡す際のフォールバックは？

| Option | Description | Selected |
|--------|-------------|----------|
| 失敗時は HOST_DOCKER_GID を渡さず entrypoint が sudo フォールバック | Mac/Win Docker Desktop で stat 失敗するケースに対応。catalog.md で sudo 経路を案内 | ✓ |
| stat 失敗時はエラーで停止 | 動かない環境は非対応。Mac/Win ユーザーを捨てる | |
| デフォルト GID=999 fallback | サイレントバグあり | |

**User's choice:** 失敗時は env を渡さず sudo フォールバック

### Q3: GID 衝突時の扱いは？

| Option | Description | Selected |
|--------|-------------|----------|
| groupadd 失敗時は既存グループ取得 + usermod -aG (名前は無視、GID 番号のみ一致) | Phase 5 の name-resolution 教訓に従う。堅牢 | ✓ |
| -o オプションで docker という名前を重複作成 | Phase 5 で ubuntu ユーザー混乱があった経路と同種、避けたい | |
| 衝突するグループを groupdel | 何と衝突するかビルド時に分からず、entrypoint 側で多岡ケース分岐が必要になる | |

**User's choice:** 既存グループ取得 + 属させる

---

## --docker の cmd_kaio 対応

### Q1: --docker フラグはどのコマンドに適用しますか？

| Option | Description | Selected |
|--------|-------------|----------|
| cmd_open と cmd_kaio の両方に対応 | POC も kaio も compose を触る可能性あり。共通ロジック化で二度手間防止 | ✓ |
| cmd_open のみ (todo 原文) | 最小実装 | |
| cmd_kaio のみ | 本格開発専用にする案 | |

**User's choice:** 両方に対応

### Q2: --docker の共通ロジックの切り出し方は？

| Option | Description | Selected |
|--------|-------------|----------|
| ヘルパー関数 _docker_extra_args() を作り cmd_open/cmd_kaio から呼ぶ | bash の echo + 配列で展開。フラグ解析も共通化 | ✓ |
| cmd_open と cmd_kaio にそれぞれ分かりやすくコピペ | DRY 違反だが関数内完結で読みやすい | |
| cmd_kaio から cmd_open の docker run を呼ぶ大規模リファクタ | スコープ爆発、今回は避ける | |

**User's choice:** ヘルパー関数化

### Q3: --docker 有無はどこまでコンテナに確認済みにしますか？

| Option | Description | Selected |
|--------|-------------|----------|
| -e SPIRIT_ROOM_DOCKER=1 を渡し entrypoint/status/catalog から見えるようにする | 単一ソース、分岐が明確 | ✓ |
| 他の env の有無で推測 (HOST_DOCKER_GID がある = --docker) | env を増やさないが stat 失敗ケースで混乱 | |

**User's choice:** SPIRIT_ROOM_DOCKER=1 を明示渡し

### Q4: kaio モードの兄弟コンテナ名に規則を与えますか？

| Option | Description | Selected |
|--------|-------------|----------|
| 規則なし、catalog.md で COMPOSE_PROJECT_NAME=$ROOM_NAME を推奨のみ | シンプル、Claude の自由度も保てる | ✓ |
| CLI から -e COMPOSE_PROJECT_NAME=$ROOM_NAME を強制渡し | 名前空間分離が確実 | (実質こちらも採用: D-14 で CLI から強制渡すことに) |
| 何もしない | 部屋を忘れたコンテナ混ざるリスク | |

**User's choice:** catalog.md で示唆 (ただし D-14 で CLI 側でも -e COMPOSE_PROJECT_NAME を強制渡すことに発展)
**Notes:** catalog.md と CLI の二重安全網にした。close 時の filter クエリも安定する。

---

## 兄弟コンテナのライフサイクルと警告表示

### Q1: spirit-room close 時の兄弟コンテナの扱いは？

| Option | Description | Selected |
|--------|-------------|----------|
| ユーザー任せ (部屋のみ破棄) | 現状のシンプルな振る舞い維持、catalog.md で事前 down を案内 | |
| close 時に label を見て compose down 試行 | CLI から COMPOSE_PROJECT_NAME を強制渡し、close 時に label filter で検出 | ✓ |
| 専用フラグ --with-siblings | 明示的だがフラグ増加 | |

**User's choice:** close 時に label を見て自動掃除

### Q2: close 時の compose down ロジックの実装方針は？

| Option | Description | Selected |
|--------|-------------|----------|
| CLI が -e COMPOSE_PROJECT_NAME=$name を強制渡し、close 時は docker ps --filter label で rm -f | env の優先度が最高なので安定。room_name と 1:1 対応 | ✓ |
| CLI は渡さず catalog.md で推奨のみ | 強制力なし、有効にしない人は落とせない | |
| basename $HOST_WORKSPACE マッチで探す | 部屋外の同名プロジェクトを巻き添えにするリスク大 | |

**User's choice:** CLI 強制 + label filter

### Q3: close 時に兄弟を見つけた時のフローは？

| Option | Description | Selected |
|--------|-------------|----------|
| 確認無しで rm -f | 既に本体も stop + rm しているので統一 | ✓ |
| Y/n 確認 | spirit-room CLI は非対話なので一貫性を壊す | |
| --with-siblings フラグ必須 | おまけ感に欠ける | |

**User's choice:** 確認なし rm -f (統一)

### Q4: --docker フラグ時のセキュリティ警告はどう出しますか？

| Option | Description | Selected |
|--------|-------------|----------|
| バナー内に「socket マウント = ホスト root 相当」の一行を常時表示。確認プロンプトなし | opt-in フラグで意思表示済み、注意喚起で十分 | ✓ |
| 初回のみ y 確認 + ack ファイル | 手順複雑化、Simplicity 違反 | |
| CLI 警告なし、catalog.md と README のみ | 警告なしは危険 | |

**User's choice:** バナー内に一行警告

### Q5: catalog.md に追加する --docker モード向けの内容はどう構成しますか？

| Option | Description | Selected |
|--------|-------------|----------|
| 既存 catalog.md に条件付きセクション追加 ("## Docker Compose モード (SPIRIT_ROOM_DOCKER=1 時)") | 1 ファイル維持、条件付き解釈を明記 | ✓ |
| 別ファイル catalog-docker.md を新規、entrypoint で分岐案内 | ファイル増、entrypoint 分岐増 | |
| テンプレートでビルド時差し替え | Simplicity 違反 | |

**User's choice:** 条件付きセクションを既存ファイルに追加

---

## Claude's Discretion (議論中に Claude 判断と確認された項目)

- `get.docker.com` スクリプトのリトライ・タイムアウト設計 (Q1-2 のユーザー回答が "Other — 最初から入れておく" で手段未指定)
- entrypoint の docker グループ合流で使う getent/usermod の具体的コマンド構文
- catalog.md の Docker セクション内で出す compose.yaml の例示スニペット (具体的なサービス構成)
- `_docker_extra_args()` が echo stream を返すか bash 配列を返すかの実装詳細

## Deferred Ideas (議論中に出たが Phase 6 スコープ外)

- Sysbox / user-defined network 等の代替アーキテクチャ (todo 代替案)
- `--with-siblings` 等の close オプション化
- Mr.ポポが MISSION 内容から --docker を自動判定
- Docker Desktop (Mac/Win) 固有の詳細調整
- MISSION.md.template の compose POC 用項目追加
- `spirit-room close --dry-run`
- build-base.sh の `--with-docker` 専用タグ出力オプション (常時同梱で決着)
