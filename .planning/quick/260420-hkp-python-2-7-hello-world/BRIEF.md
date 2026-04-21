# Mr.ポポ への仕様書 — Python 2.7 Hello World 修行 (胡蝶の夢モード)

> **これは Mr.ポポ (spirit-room-manager) に渡す "事前回答つき仕様書"。** 部屋の Claude が読む MISSION.md ではない。
> Mr.ポポ はこの内容を Step 0〜3 のヒアリング回答として受け取り、MISSION.md を生成し `spirit-room open --kochou` で部屋を開く。

## 使い方 (ユーザー視点)

1. 新しいセッションを `cd spirit-room-manager && claude` で起動 (Claude が Mr.ポポ になる)
2. 最初に Mr.ポポ から「よく来たな。ここは精神と時の部屋だ。」+ Step 0 (モード選択) が出る
3. 下記の回答を順に返す。各ステップで `AskUserQuestion` が出るので「その他 (自由記述)」を選んで該当セクションを貼る

---

## 事前回答

### Step 0: モード選択
**回答**: `精神と時の部屋` (POC 速攻型)

理由: Python 2.7 で Hello World を出すだけの最小 POC。GSD による本格開発 (界王星) は不要。

---

### Step 1-a: フレームワーク/ライブラリ
**回答**: `その他 (自由記述)` → **"Python 2.7 + Docker Compose (胡蝶の夢モード)"**

補足: 選択肢の LangGraph / Next.js / FastAPI / Prisma / React Flow は該当しない。フレームワークというより **ランタイム環境そのもの (Python 2.7)** と **それを兄弟コンテナで借りてくる仕組み (docker compose via DooD)** が題材。

---

### Step 1-b: 何を理解したいか
**回答**: `動作確認` (とりあえず動くところまで)

補足: 胡蝶の夢モード (Phase 6 で追加された `--kochou`) で「部屋に入っていないランタイムを兄弟コンテナで補う」パターンが本当に動くかの一次検証。

---

### Step 1-c: 特に調査したい観点
**回答** (multiSelect): `設計思想` + `API の癖`

- **設計思想**: DooD (Docker-out-of-Docker) がなぜ socket マウントだけで動くのか、`${HOST_WORKSPACE}` / `host.docker.internal` / `COMPOSE_PROJECT_NAME` がそれぞれどの問題を解いているのか
- **API の癖**: Python 2 の `print` 文 (括弧なし) と Python 3 の `print()` 関数の違い — どちらで書いたかで Python 2.7 が本当に動いているかが判別できる

---

### Step 2: 完了条件
**回答**: `動けばいい` (hello world 相当で可)

補足: 下記コマンドが `Hello from Python 2.7!` を出力すれば完走扱い:

```bash
docker compose run --rm py27 python /work/hello.py
# または docker グループ合流失敗時:
sudo docker compose run --rm py27 python /work/hello.py
```

ただし、`README.md` に「胡蝶の夢モードでしか出来ないこと / 普通の部屋との違い」を 5 行程度で書くことは必須にしてほしい (動いただけでは学びが残らないため)。

---

### Step 3-a: 外部 API
**回答**: `使わない` (ローカル完結)

補足: Docker Hub からの `python:2.7` イメージ pull のみ。OpenAI / Anthropic 等の外部 API は不要。

---

### Step 3-b: バージョン・参考 URL
**回答**: `あり (自由記述)` → 下記:

- **Python イメージ**: `python:2.7` (Docker Hub 公式、https://hub.docker.com/_/python)
- **胡蝶の夢モード仕様**: `/room/catalog.md` の "胡蝶の夢モード — Docker Compose" セクション (`spirit-room/base/catalog.md:66-139`)
- **Python 2 `print` 文**: `print "Hello"` (括弧なし) で書く。`print("Hello")` は 2/3 両方で動くので判別にならないのであえて避ける

---

### Step 3-c: 胡蝶の夢モード
**回答**: `はい (--kochou で起動)`

補足: 本題材の存在意義そのもの。部屋に Python 2.7 は入っていない (Ubuntu 24.04 は Python 3 のみ)、兄弟コンテナで補うのが目的。起動コマンドは必ず `spirit-room open --kochou <folder>`。

---

## Mr.ポポ へのお願い (MISSION.md 生成時の要点)

MISSION.md を生成するとき、以下を **必ず含める**:

1. **前提チェック**: 部屋の Claude は最初に `env | grep SPIRIT_ROOM_KOCHOU` で `SPIRIT_ROOM_KOCHOU=1` があるかを確認。無ければ「`--kochou` 付きで起動し直してください」と中断する (勝手に再起動しない)。
2. **compose.yaml の制約**:
   - ボリュームは `${HOST_WORKSPACE}:/work` (ホスト絶対パス経由)。`./` や `/workspace/` 直書きしない
   - `name:` / `container_name:` は書かない (既に `COMPOSE_PROJECT_NAME` が部屋名にセットされている。上書きすると `spirit-room close` の兄弟掃除が効かなくなる)
3. **hello.py の書き方**: `print "Hello from Python 2.7!"` (**括弧なし**)。Python 3 では SyntaxError になる書き方を意図して採用する。
4. **実行コマンド**: `docker compose run --rm py27 python /work/hello.py`。docker グループ合流に失敗したログ (`docker grp: 合流失敗`) が出ていたら `sudo docker compose run ...` に切り替えて良い (Phase 5 で goku に `NOPASSWD:ALL` 付与済み)。
5. **ボーナス検証** (.journal.md に `[DONE]` で残す): 部屋内の `python3 /workspace/hello.py` で SyntaxError が出ることを確認 → 「だからこそ兄弟コンテナが必要だった」の証拠にする。
6. **README.md**: 実装概要 + 「胡蝶の夢モードでしか出来ないこと」を 5 行程度で書かせる。

## フォルダ名の提案

Mr.ポポ の命名規則 (`[フレームワーク]-[目的の短縮]-poc`) に沿うと: **`python27-kochou-hello`**

```bash
mkdir -p ~/projects/python27-kochou-hello
# Mr.ポポ が MISSION.md をここに生成
spirit-room open --kochou ~/projects/python27-kochou-hello
```

## 参考: 仕様書の由来

この仕様書は `.planning/quick/260420-hkp-python-2-7-hello-world/` で quick task として作成された。Phase 6 (`spirit-room --kochou` 実装) の実演 / 検証用題材として設計。
