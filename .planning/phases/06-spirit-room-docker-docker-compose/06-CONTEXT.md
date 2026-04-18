# Phase 6: spirit-room に `--docker` フラグ (Docker Compose 対応) — Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

精神と時の部屋コンテナに opt-in の `--docker` フラグを追加し、部屋内から **DooD (Docker-out-of-Docker)** でホスト側の docker daemon を叩けるようにする。これにより Claude が `docker compose up` で **ホスト上の兄弟コンテナ** としてプロダクトを起動・操作できる。

**成果物:**
- `spirit-room/spirit-room` (CLI) — `cmd_open` / `cmd_kaio` に `--docker` フラグ、ヘルパー関数 `_docker_extra_args()`、`cmd_close` に兄弟コンテナ掃除ロジック
- `spirit-room/base/Dockerfile` — docker CLI + compose plugin のレイヤー追加 (Node/Bun の後、SSH 設定の前)
- `spirit-room/base/entrypoint.sh` — `SPIRIT_ROOM_DOCKER=1` 時の docker グループ動的合流と sudo フォールバック
- `spirit-room/base/catalog.md` — `## Docker Compose モード (SPIRIT_ROOM_DOCKER=1 時)` セクションを条件付きで追加。`${HOST_WORKSPACE}` の使い方と `host.docker.internal` でのサービス到達、セキュリティ注意、`COMPOSE_PROJECT_NAME` の推奨を明記

**非スコープ:**
- Sysbox ランタイムでの nested docker 安全化 (代替案は将来フェーズ)
- 共有 user-defined network への部屋参加方式
- Mac / Windows Docker Desktop の個別挙動調整 (Linux がシンプルパス、それ以外は catalog.md で sudo フォールバックへ誘導)
- `spirit-room monitor` など既存未実装機能との連携

</domain>

<decisions>
## Implementation Decisions

### Docker CLI の配置

- **D-01:** docker CLI + compose plugin は **`spirit-room-base:latest` に常時同梱** する。別イメージへの分離 (`spirit-room-docker:latest`) はしない。理由：PROJECT.md の Simplicity 制約 (イメージ管理の複雑化を避ける)、--docker 未使用時でも実害は CLI が在るだけで小さい (+100-150MB 程度)。
- **D-02:** インストール手段は **`curl -fsSL https://get.docker.com | sh`** を基本線とする (Claude 裁量範疇 — シンプルで docker-ce-cli + containerd + docker-compose-plugin が一度に入る。dockerd は起動しないので実害なし)。apt 公式 repo 手動追加でも OK だが、スクリプトの簡潔さを優先。
- **D-03:** Dockerfile 追加位置は **Node.js/Bun の後、SSH 設定の前** に新規レイヤー (例: `# ── レイヤー5.5: Docker CLI ──`) として挿入する。後続の SSH 設定 / Git 設定 / scripts コピーのキャッシュを壊さない。

### goku の docker.sock アクセス方式

- **D-04:** goku に `/var/run/docker.sock` を触らせる方式は **entrypoint でホストの docker GID を動的取得し、goku を該当 GID のグループに属させる** 方式を採用する。sock の permissions を 666 に緩めるのは不可 (ホスト側の perms を変える行為になる)。
- **D-05:** CLI が `--docker` 指定時に渡す環境変数は **`-e HOST_DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null)`**。Mac / Windows の Docker Desktop で stat が失敗する環境では空文字を渡す (後段の fallback が走る)。
- **D-06:** CLI は `-e HOST_DOCKER_GID` が空でも停止しない。entrypoint 側で次の fallback チェーンを実装:
  1. `HOST_DOCKER_GID` が非空 → `getent group $HOST_DOCKER_GID` で既存グループがあればその名前に `usermod -aG`、無ければ `groupadd -g $HOST_DOCKER_GID docker` して `usermod -aG docker goku`
  2. `HOST_DOCKER_GID` が空 → docker グループは作らない。catalog.md の Docker セクションで「`sudo docker ...` を使え (Phase 5 で goku は NOPASSWD:ALL 付き)」と明記
- **D-07:** GID 衝突時 (例: `HOST_DOCKER_GID=999` が `ping` 等と衝突) の扱いは **既存グループ名を getent で取得し、goku をそこに属させる**。`groupadd -o` で名前 `docker` を重複作成する方法は取らない (Phase 5 の `ubuntu` ユーザー混乱の教訓から、name-resolution の不整合を作らない)。
- **D-08:** goku が docker グループに入った後の確認ログを entrypoint で1行出す (`[INFO] docker grp: goku ∈ <groupname>(gid=$HOST_DOCKER_GID)` か `[INFO] docker grp: 利用不可 — sudo docker を使用せよ`)。

### CLI フラグ設計と cmd_kaio 対応

- **D-09:** `--docker` フラグは **`cmd_open` と `cmd_kaio` の両方に適用** する。POC (spirit-room) でも本格開発 (kaio) でも compose 操作は発生しうるので、片方だけに付けると将来追加の二度手間になる。
- **D-10:** `--docker` の共通ロジックは **ヘルパー関数 `_docker_extra_args()` に切り出し**、`cmd_open` / `cmd_kaio` の docker run 引数組み立ての中で `$(_docker_extra_args "$folder" "$docker_flag")` のように展開する。関数はフラグ ON 時に以下を echo する:
  - `-v /var/run/docker.sock:/var/run/docker.sock`
  - `--add-host=host.docker.internal:host-gateway`
  - `-e HOST_WORKSPACE="$(realpath "$folder")"`
  - `-e SPIRIT_ROOM_HOST_GATEWAY=host.docker.internal`
  - `-e SPIRIT_ROOM_DOCKER=1`
  - `-e COMPOSE_PROJECT_NAME=<room_name>` (D-14 参照)
  - `-e HOST_DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null)` (取得失敗時は空)
- **D-11:** フラグ解析は既存の `cmd_open()` / `cmd_kaio()` の先頭で **単純な while ループ (`case $1 in --docker) docker_flag=1; shift ;; esac`)** で扱う。getopts や外部パーサは使わない (Simplicity)。`--docker` が来たら `docker_flag=1`、残る引数を folder として扱う (例: `spirit-room open --docker /path` と `spirit-room open /path --docker` 両方を許可)。
- **D-12:** コンテナ側で Docker モードを認識する env は **`SPIRIT_ROOM_DOCKER=1`** (単一ソースオブトゥルース)。entrypoint・status・catalog.md が全てこの変数で分岐する。HOST_DOCKER_GID / HOST_WORKSPACE の有無での推測はしない (取得失敗 vs モード off が区別できなくなるため)。
- **D-13:** kaio モード側でも `--docker` を受け付けるが、kaio 固有の追加処理はない (CLAUDE_CONFIG_DIR や認証同期は Phase 4 / 5 のロジックをそのまま継承)。`cmd_kaio` は `_docker_extra_args()` を呼んで docker run に差し込むだけ。

### 兄弟コンテナのライフサイクル (close 時の掃除)

- **D-14:** `--docker` 指定時、CLI は **`-e COMPOSE_PROJECT_NAME=<room_name>`** を強制的に渡す (room_name は `folder_to_name()` の出力と同じ — `spirit-room-<basename>` 形式)。docker compose の project 優先順位では env var が最優先なので、compose.yaml 側の明示 project 指定より強い。
- **D-15:** `cmd_close` に兄弟コンテナ掃除ロジックを追加: **`docker ps -a --filter "label=com.docker.compose.project=<room_name>" -q | xargs -r docker rm -f`**。確認プロンプトは出さない (既に `cmd_close` は部屋本体を stop+rm している振る舞いに揃える)。掃除対象がゼロ件でも `xargs -r` で no-op。
- **D-16:** 掃除前後で情報ログを出す: `[INFO] 部屋に紐づく compose コンテナを検索中...` → 件数表示 → `[INFO] 兄弟コンテナ N 件を削除しました` (ゼロ件なら `[INFO] 兄弟コンテナは見つかりませんでした`)。
- **D-17:** `--with-siblings` 等の追加フラグは **導入しない**。close 時の自動掃除はデフォルト挙動。ユーザーが兄弟を残したい特殊ケースは本フェーズスコープ外 (deferred に残す)。
- **D-18:** `cmd_close` は `--docker` フラグを持たずに起動された部屋に対しても同じ filter クエリを走らせてよい (兄弟が無ければヒットしないだけ)。フラグ別の分岐を増やさない。

### セキュリティ警告 / UX

- **D-19:** `cmd_open` / `cmd_kaio` のバナー内 (既存の `╔═...═╗` ボックスの直下または内部) に、`docker_flag=1` の時のみ 1 行警告を表示する:
  ```
  [WARN] --docker モード: /var/run/docker.sock をマウントしました。
         コンテナ内から host の全 docker コンテナ操作が可能 = ホスト root 相当の権限です。
  ```
  - 確認プロンプト (y/n) は出さない (opt-in フラグで意思表示済み)。
  - 一度だけの ack ファイル (~/.spirit-room/docker-ack) は作らない (Simplicity)。
- **D-20:** catalog.md には `## Docker Compose モード (SPIRIT_ROOM_DOCKER=1 時)` として以下を含む**条件付きセクション**を追加する:
  1. モード判定: `[ "${SPIRIT_ROOM_DOCKER:-}" = "1" ]` の時のみこのセクションが有効
  2. **ボリューム記法**: `compose.yaml` では `./data:/app/data` ではなく `${HOST_WORKSPACE}/data:/app/data` を使う (ホスト dockerd が解釈するため)
  3. **サービス到達方式**: 部屋から compose サービスへアクセスする時は `host.docker.internal:<PORT>` または `${SPIRIT_ROOM_HOST_GATEWAY}:<PORT>` を使う
  4. **COMPOSE_PROJECT_NAME**: デフォルトで CLI から `-e COMPOSE_PROJECT_NAME=$ROOM_NAME` が渡されている。compose.yaml 内で明示的に project name を書かないこと (CLI の close 時掃除が効かなくなる)
  5. **docker グループ未取得時のフォールバック**: entrypoint ログで「docker grp: 利用不可」と出ていた場合は `sudo docker ...` を使う
  6. **セキュリティ注意**: コンテナ内からホストの全コンテナを操作できるので、ミッション範囲を超えた操作 (他の部屋を stop する等) は避けること
- **D-21:** 既存 `catalog.md` の /workspace > /room 優先順位は変えない。ユーザープロジェクトが `/workspace/catalog.md` を持っていれば従来どおりそれが使われる (その場合この Docker セクションを含めるかはプロジェクト側の判断)。

### Claude's Discretion

- `get.docker.com` のスクリプトがイメージビルド中に失敗した場合の retry 回数やタイムアウトは Claude が実装時に決める
- entrypoint で docker グループ合流に使う具体的なコマンドシーケンス (getent の引数 / usermod の書き方) は Claude 裁量
- catalog.md の Docker セクション内の例示 compose.yaml スニペット (具体的なサービス構成) は Claude が適切な POC 例を選ぶ
- `_docker_extra_args()` が echo で返すか配列で返すかの bash 実装方式 (cmd_open 側の展開方式に合うもの)

### Folded Todos

- **`.planning/todos/pending/2026-04-18-spirit-room-docker-docker-compose.md`** — この Phase 6 のドライバ todo そのもの。Problem (compose のボリュームパス問題 / ネットワーク到達問題) と Solution (CLI / Dockerfile / Catalog の 3 点改修) を上記決定にほぼ 1:1 で展開。完了時に `.planning/todos/completed/` へ移動する。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 変更対象コード (本フェーズで実際に編集するファイル)

- `spirit-room/spirit-room` §`cmd_open` (52-95行) — `--docker` フラグ解析、`_docker_extra_args()` 呼び出し、バナー警告追加
- `spirit-room/spirit-room` §`cmd_kaio` (101-167行) — 同様に `--docker` サポート、ヘルパー呼び出し
- `spirit-room/spirit-room` §`cmd_close` (214-228行) — 兄弟コンテナ掃除ロジック追加 (filter クエリ)
- `spirit-room/spirit-room` §`usage()` (14-33行) — `--docker` の使い方を例に追加
- `spirit-room/base/Dockerfile` — レイヤー5.5 (docker CLI + compose plugin) 追加、場所は Node/Bun レイヤーの後・SSH 設定の前
- `spirit-room/base/entrypoint.sh` — `HOST_UID/GID` 処理の近辺 (22-60行付近) に `SPIRIT_ROOM_DOCKER=1` 分岐を追加、docker GID 合流 + sudo フォールバック、ログ出力
- `spirit-room/base/catalog.md` — 末尾に `## Docker Compose モード (SPIRIT_ROOM_DOCKER=1 時)` セクションを追加

### 依存する過去フェーズの決定 (破壊しないこと)

- `.planning/phases/05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui/05-CONTEXT.md` — goku ユーザー設計、HOST_UID/HOST_GID パターン、`-e` での env 受け渡しの手法、sudo NOPASSWD:ALL (Docker セクションの sudo フォールバックは **この権限に依存**)。Phase 5 の D-16 (HOST_UID/GID を -e で渡す) をそのまま踏襲し、`HOST_DOCKER_GID` を並べて追加する形で拡張
- `.planning/phases/04-gsd-claude-config-dir-symlink-gsd-autonomous/04-CONTEXT.md` — kaio モードの CLAUDE_CONFIG_DIR 設計、`spirit-room kaio` の存在意義。cmd_kaio に `--docker` を足しても kaio 固有ロジックを壊さないこと
- `.planning/phases/02-auth-training-loop` / `03-end-to-end-flow` — 2 フェーズ修行ループ (`.prepared` / `.done`) と MISSION.md 運用。`SPIRIT_ROOM_DOCKER=1` は catalog.md に影響するが start-training.sh のフロー自体は無改修

### プロジェクト憲法

- `CLAUDE.md` — 応答言語 (日本語) / Tech Stack 制約 (**bash + Docker のみ、Node/Python 追加禁止**) / ブランチ戦略 (`phase/06-xxx` で作業 → main に squash merge) / Dragon Ball 命名規約
- `.planning/PROJECT.md` — コアバリュー「Mr.ポポにフレームワーク名と目的を伝えたら Claude Code が自律的に POC を実装して動くところまで完成させる」。Phase 6 は **既存の UX を opt-in で拡張** するだけで、デフォルト挙動は変えない (PROJECT.md の Simplicity 制約に照らしてこれが最重要)
- `.planning/REQUIREMENTS.md` — v1 要件 (AUTH-01/02, BUILD-01/02, RUN-01〜04, LOOP-01〜04) が `--docker` 未指定時も変わらず動くこと

### Phase 6 の駆動 todo

- `.planning/todos/pending/2026-04-18-spirit-room-docker-docker-compose.md` — Problem / Solution / 代替案を含むドライバ todo。実装タスクはこの Solution 節を上記決定で補強したものに展開

### Mr.ポポ側への波及 (通常は変更不要)

- `spirit-room-manager/CLAUDE.md` / `spirit-room-manager/skills/MR_POPO.md` — Mr.ポポは `spirit-room open [folder]` を呼ぶだけ。ユーザーが compose POC を希望した場合 `--docker` を付けるか Mr.ポポが判断する拡張は Phase 6 スコープ外。HANDOVER.md 相当の追記 (Docker モード対応した旨) は必要
- 各 MISSION.md テンプレート (`spirit-room/base/scripts/MISSION.md.template` 等) — compose POC 向けの記述項目 (compose.yaml の有無等) は Phase 6 ではテンプレ追記しない。必要なら deferred

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`cmd_open()` の docker run 構築** (spirit-room:77-88) — `-e HOST_UID/-e HOST_GID` を `-e` で直接書くパターンが既に確立。ここに `_docker_extra_args()` の展開結果を差し込むだけで済む
- **`folder_to_name()` ヘルパー** (spirit-room:36-40) — room_name の正規化が既にあるので `COMPOSE_PROJECT_NAME` の値源にそのまま使える
- **`resolve_running_name()` ヘルパー** (spirit-room:170-180) — kaio サフィックスの解決ロジックが既にあるので `cmd_close` で兄弟コンテナ掃除の対象室名 (`-kaio` 込み) を取得する時にそのまま使える
- **entrypoint.sh の HOST_UID/GID fallback パターン** (entrypoint.sh:22-26) — 空文字時に `:-1000` でデフォルト、echo でログ。同じ形式で `HOST_DOCKER_GID` を扱う
- **entrypoint.sh の idempotent ユーザー/グループ作成** (entrypoint.sh:28-60) — `id goku &>/dev/null || useradd` のパターンが `getent group $gid || groupadd` に横展開できる
- **バナー echo の定型** (spirit-room:64-71, 113-121) — `╔═...═╗` のボックスに警告行を 1 行挿入するだけ

### Established Patterns

- **冪等化フラグ**: `.prepared` / `.done` の idempotent 思想は「起動ごとに chown を走らせる」 (Phase 5 D-11) と同じ系譜。Phase 6 も「起動ごとに docker グループ合流を試す」で同じ思想を踏襲
- **環境変数による分岐**: `CLAUDE_CONFIG_DIR` の有無で kaio 分岐 (entrypoint.sh:101)、`HOST_UID` の空 fallback。`SPIRIT_ROOM_DOCKER=1` の有無で Docker 分岐を同じパターンで増設
- **`docker ps --filter` + `--format`**: `cmd_list` (spirit-room:207-210) と `resolve_running_name` (172-175) で既に使用。close の兄弟掃除も同じ方式で検出 (`--filter "label=..."`)
- **chown -R の起動ごと実行**: Phase 5 D-11 の「起動ごとに正常化する」。docker グループ合流もそれと同じで、再起動時に HOST_DOCKER_GID が変わっていたら作り直す (usermod で再付与) を許容する

### Integration Points

- **docker run の env 引数**: spirit-room:77-88 (cmd_open), 145-156 (cmd_kaio), 131-139 (cmd_kaio の認証同期 docker run --rm) の 3 箇所。**--rm の認証同期側には docker グループは不要** (docker.sock を触らないため) — `_docker_extra_args` は cmd_open/cmd_kaio の本体 docker run でのみ呼ぶ
- **entrypoint の goku 作成直後**: entrypoint.sh:38-60 の直後に docker グループ合流ロジックを挿入するのが自然 (goku が既に存在した後でないと usermod が打てない)
- **cmd_close の docker stop/rm**: spirit-room:226-227 の直前 or 直後に兄弟コンテナ掃除を入れる。`docker stop "$name" && docker rm "$name"` が成功した後に filter クエリで兄弟を落とす順序が安全 (部屋本体に依存する compose サービスがあると先に落とすと失敗する可能性)
- **Dockerfile のレイヤー境界**: Dockerfile の `# ── レイヤー5: opencode ──` (line 50-51) の直後、`# ── SSH設定 ──` (line 53) の直前に新規レイヤーを追加する。これで SSH 設定以降のキャッシュを壊さない

</code_context>

<specifics>
## Specific Ideas

### `_docker_extra_args()` ヘルパーの実装骨子 (疑似)

```bash
# spirit-room の上部ヘルパー群 (find_free_port の近く)

# --docker フラグ時に docker run に追加する引数を echo する
# 引数: $1=folder (realpath 済み), $2=room_name
_docker_extra_args() {
    local folder="$1"
    local room_name="$2"
    local host_docker_gid
    host_docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")

    echo "-v /var/run/docker.sock:/var/run/docker.sock"
    echo "--add-host=host.docker.internal:host-gateway"
    echo "-e HOST_WORKSPACE=${folder}"
    echo "-e SPIRIT_ROOM_HOST_GATEWAY=host.docker.internal"
    echo "-e SPIRIT_ROOM_DOCKER=1"
    echo "-e COMPOSE_PROJECT_NAME=${room_name}"
    [ -n "$host_docker_gid" ] && echo "-e HOST_DOCKER_GID=${host_docker_gid}"
}
```

### `cmd_open` 側の差分 (疑似 diff)

```bash
cmd_open() {
    local docker_flag=0
    # 簡易フラグパース (--docker はどの位置でも OK)
    local args=()
    for a in "$@"; do
        case "$a" in
            --docker) docker_flag=1 ;;
            *) args+=("$a") ;;
        esac
    done
    local folder="${args[0]:-$(pwd)}"
    folder=$(realpath "$folder")
    local name=$(folder_to_name "$folder")
    local port=$(find_free_port)
    # ... (既存の起動チェック + バナー echo)

    if [ "$docker_flag" = "1" ]; then
        echo "[WARN] --docker モード: /var/run/docker.sock をマウントしました。"
        echo "       コンテナ内から host の全 docker コンテナ操作が可能 = ホスト root 相当の権限です。"
    fi

    # 追加引数の配列化 (空白区切り文字列を eval or read -a)
    local docker_extra=()
    if [ "$docker_flag" = "1" ]; then
        while IFS= read -r line; do docker_extra+=($line); done < <(_docker_extra_args "$folder" "$name")
    fi

    docker run -d \
        --name "$name" \
        --hostname "$name" \
        -e ROOM_NAME="$(basename $folder)" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        "${docker_extra[@]}" \
        -p "${port}:22" \
        -v "${folder}:/workspace" \
        # ... (以下同じ)
}
```

### entrypoint.sh の追加差分 (疑似)

```bash
# entrypoint.sh の goku 作成ブロックの直後 (L60 あたり) に挿入

# ── docker グループ合流 (--docker モードのみ) ─────────────────
if [ "${SPIRIT_ROOM_DOCKER:-}" = "1" ]; then
    if [ -n "${HOST_DOCKER_GID:-}" ]; then
        # 既存グループ優先 (名前は何でもよい、GID 番号だけ合わせる)
        _dgrp_name=$(getent group "$HOST_DOCKER_GID" | cut -d: -f1 || true)
        if [ -z "$_dgrp_name" ]; then
            groupadd -g "$HOST_DOCKER_GID" docker 2>/dev/null && _dgrp_name=docker || _dgrp_name=""
        fi
        if [ -n "$_dgrp_name" ]; then
            usermod -aG "$_dgrp_name" goku
            echo "[INFO] docker grp: goku ∈ ${_dgrp_name}(gid=${HOST_DOCKER_GID})"
        else
            echo "[INFO] docker grp: 合流失敗 — sudo docker を使用せよ (Phase 5 NOPASSWD 前提)"
        fi
    else
        echo "[INFO] docker grp: HOST_DOCKER_GID 未取得 — sudo docker を使用せよ"
    fi
fi
```

### cmd_close の兄弟掃除ロジック

```bash
cmd_close() {
    local folder="${1:-$(pwd)}"
    folder=$(realpath "$folder")
    local base=$(folder_to_name "$folder")
    local name=$(resolve_running_name "$base")

    if [ -z "$name" ]; then
        echo "[ERROR] 部屋 '$base' (または '${base}-kaio') は起動していません"
        exit 1
    fi

    echo "[INFO] 部屋 '$name' を閉じます..."
    docker stop "$name" && docker rm "$name"

    # 兄弟 compose コンテナがあれば掃除 (ラベルで検出)
    local siblings
    siblings=$(docker ps -a --filter "label=com.docker.compose.project=${name}" -q)
    if [ -n "$siblings" ]; then
        local count
        count=$(echo "$siblings" | wc -l)
        echo "[INFO] 部屋に紐づく compose 兄弟コンテナを ${count} 件発見 — 削除します"
        echo "$siblings" | xargs -r docker rm -f
        echo "[INFO] 兄弟コンテナ ${count} 件を削除しました"
    else
        echo "[INFO] 兄弟コンテナは見つかりませんでした"
    fi

    echo "[INFO] 完了（workspaceのファイルはフォルダに残っています）"
}
```

### catalog.md 追加セクションの骨子

```markdown
## Docker Compose モード (SPIRIT_ROOM_DOCKER=1 時)

> **このセクションは `SPIRIT_ROOM_DOCKER=1` 環境変数が設定されている時のみ適用される。**
> `env | grep SPIRIT_ROOM_DOCKER` で確認せよ。未設定ならこのセクションは無視してよい。

### 使える挙動

- ホスト側の docker daemon が叩ける (socket マウント済み)
- `docker compose up` でホスト上に兄弟コンテナを起動できる
- 部屋から兄弟コンテナへは `host.docker.internal:<PORT>` でアクセス可能

### 重要なルール

**ボリュームパスは ${HOST_WORKSPACE} を使う**

compose.yaml は **ホスト dockerd** が解釈するので、コンテナ内パス (`/workspace/data`) ではなく**ホスト側の絶対パス**が必要。

❌ `./data:/app/data` (部屋の実行ディレクトリはホストから見た `${HOST_WORKSPACE}` ではない可能性)
✅ `${HOST_WORKSPACE}/data:/app/data`

**COMPOSE_PROJECT_NAME は CLI から渡されている**

既に `$COMPOSE_PROJECT_NAME` が部屋名にセットされている。compose.yaml で `name:` を書くと上書きされて `spirit-room close` の兄弟掃除が効かなくなるので、**書かないこと**。

**サービスへのアクセスは host.docker.internal**

部屋内から compose サービスの `localhost:PORT` は見えない (兄弟コンテナはホストから見た別名前空間)。`${SPIRIT_ROOM_HOST_GATEWAY:-host.docker.internal}:<PORT>` を使う。

**docker グループが使えない場合は sudo**

起動ログに `docker grp: 合流失敗` とあれば、`sudo docker ...` / `sudo docker compose ...` を使う (Phase 5 で goku に NOPASSWD:ALL 付与済み)。

### セキュリティ注意

socket マウント = ホスト root 相当。ミッション範囲外の操作 (他の部屋を stop する、ホストのシステムコンテナを触る等) はしないこと。
```

### 検証手順 (plan フェーズで参考)

1. `./spirit-room/build-base.sh` でリビルド (+100-150MB 増加するはず)
2. `docker run --rm spirit-room-base:latest docker --version` で CLI が入っているか
3. `spirit-room open --docker ./test-compose-proj` で起動 → バナーに警告行が出るか
4. コンテナ内で `docker ps` が (sudo なしで) 通るか → 通れば docker グループ合流成功
5. 通らなければ `sudo docker ps` を試す → 通ればフォールバックパス成功
6. `env | grep -E "SPIRIT_ROOM_DOCKER|HOST_WORKSPACE|HOST_DOCKER_GID|COMPOSE_PROJECT_NAME"` で env が揃っているか
7. 簡単な compose.yaml (nginx だけ等) を `docker compose up -d` → `curl host.docker.internal:8080` で到達できるか
8. `spirit-room close ./test-compose-proj` で部屋本体 + 兄弟 nginx が両方消えるか
9. `spirit-room open ./test-compose-proj` (--docker 無し) で従来挙動が壊れていないか (SPIRIT_ROOM_DOCKER=1 が無いこと、docker コマンドはあるが sock 無いので失敗する)

</specifics>

<deferred>
## Deferred Ideas

本フェーズスコープ外。必要になったら別フェーズ or バックログ:

- **Sysbox ランタイムでの nested docker 安全化** — DooD より強いアイソレーションが必要になったら検討 (todo の代替案)
- **共有 user-defined network 方式** — `host.docker.internal` ではなく、部屋と compose サービスを同じ user-defined network に参加させる方式 (todo の代替案)
- **`--with-siblings` や `--keep-siblings` 等の close オプション** — 今は自動掃除固定。ユーザーが「この兄弟だけ残したい」ニーズを出してから
- **Mr.ポポが MISSION 内容から `--docker` を自動判定** — ユーザーが compose プロダクトと言ったら自動で `--docker` 付きで開く。今は Mr.ポポからは手動指定
- **Docker Desktop (Mac / Windows) 固有の詳細調整** — stat が失敗するケースは sudo フォールバックで動くはず。詳細対応は必要が出てから
- **MISSION.md.template に compose POC 用テンプレート追加** — compose.yaml の有無記入欄等
- **`spirit-room close` の dry-run モード** — 兄弟コンテナ一覧を出すだけのオプション
- **同ラベル compose を部屋外で立てている場合の衝突回避** — room_name が ` spirit-room-<basename>` なので通常衝突しにくいが、異常ケース対応は必要が出てから
- **build-base.sh の `--with-docker` 専用タグ出力オプション** — 今回は常時同梱で決着したが、イメージを軽くしたいプロジェクトが出てきたら分割

### Reviewed Todos (not folded)

なし (Phase 6 関連 todo は `2026-04-18-spirit-room-docker-docker-compose.md` 1 件のみで、すべて本フェーズに折り込んだ)

</deferred>

---

*Phase: 06-spirit-room-docker-docker-compose*
*Context gathered: 2026-04-18*
