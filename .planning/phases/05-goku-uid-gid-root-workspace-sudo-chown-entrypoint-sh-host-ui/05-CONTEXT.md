# Phase 5: goku ユーザー作成 / ホスト UID-GID 一致 — Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

精神と時の部屋コンテナの内部実行ユーザーを `root` から `goku` に切り替え、ホストユーザーの UID/GID と一致させる。これにより:

- `/workspace` に修行中作られた成果物がホスト側で自分のユーザー所有として見え、`sudo chown -R` が不要になる
- root で走っていた Claude Code / opencode / tmux / git / npm 等すべてが goku で実行される
- 既存の「精神と時の部屋モード」と「界王星モード (kaio)」両方で同じ仕組みが効く

**成果物:**
- `spirit-room/base/Dockerfile` — goku 用の SSH 設定、sudoers、gosu 等の基盤
- `spirit-room/base/entrypoint.sh` — HOST_UID/HOST_GID 受け取り、goku 作成、chown、su - goku で tmux 起動
- `spirit-room/spirit-room` (CLI) — `cmd_open` / `cmd_kaio` / `cmd_enter` に UID/GID 渡し + ssh ユーザー切替
- 既存の認証ボリューム (`spirit-room-auth`, `spirit-room-opencode-auth`) は破棄せず、entrypoint の chown で継続利用

**非スコープ:** モニタリング UI、新しいトレーニングロジック、GSD 駆動ループ自体の挙動変更、opencode 検証。

</domain>

<decisions>
## Implementation Decisions

### ユーザー作成戦略

- **D-01:** goku は **entrypoint ランタイム作成**。Dockerfile ビルド時点では作らない (HOST_UID がホストごとに違うため)
- **D-02:** 作成スクリプトは**冪等**: `id goku &>/dev/null || useradd -m -u $HOST_UID -g $HOST_GID -s /bin/bash goku`。GID も既存なければ作る (`getent group $HOST_GID || groupadd -g $HOST_GID goku`)
- **D-03:** `HOST_UID` / `HOST_GID` が空の場合の fallback は **1000:1000**。エラーで止めず、手動 `docker run` / CI 環境でも動くようにする
- **D-04:** goku のパスワードは **`spiritroom`** (既存 root と同じ)。ドキュメント統一のため
- **D-05:** goku に **`NOPASSWD:ALL`** の sudo 権限を付与 (`echo 'goku ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/goku`)。POC コンテナ用途のため粒度は絞らない

### SSH / tmux の起動ユーザー

- **D-06:** SSH ログインは **goku のみ**。Dockerfile の `PermitRootLogin yes` を `no` に変更
- **D-07:** `cmd_enter` の `ssh -t root@localhost` を **`ssh -t goku@localhost`** に変更 (spirit-room:194 付近)
- **D-08:** tmux セッションは entrypoint 内で `su - goku -c 'tmux new-session -d -s spirit-room ...'` で起動。service ssh/redis は root で起動し終わってから権限を渡す

### Entrypoint の権限切替フロー

- **D-09:** 順序は「① root で service 起動 → ② goku 作成 → ③ 各種ディレクトリを chown → ④ git config を goku として再設定 → ⑤ `su - goku -c` で tmux 起動 → ⑥ `tail -f /dev/null` は root のまま (PID 1)」
- **D-10:** **chown 対象パス**: 認証ボリューム (`/root/.claude`, `/root/.claude-shared`, `/root/.config/opencode`) **および `/workspace`**。過去に root で作られた成果物があるプロジェクトも一度掃除する
- **D-11:** 起動ごとに chown を走らせる (= volume に root 所有のファイルが混じっていても一度で正常化する)。**専用の `spirit-room auth-migrate` コマンドは作らない**
- **D-12:** git config は Dockerfile に残した root 用設定はそのままにし、entrypoint で `su - goku -c "git config --global --add safe.directory '*'; git config --global user.email 'spirit-room@localhost'; git config --global user.name 'Spirit Room'; git config --global init.defaultBranch main"` を実行して goku HOME 側にも同じ設定を作る

### kaio モード統合

- **D-13:** kaio モードも同じ仕組み。`CLAUDE_CONFIG_DIR=/workspace/.claude-home` は goku 所有で OK (/workspace が goku なのと整合)
- **D-14:** entrypoint で credentials symlink を張ったあと、**symlink 自体も `chown -h goku:goku` で所有者変更**。実体ファイル `/root/.claude-shared/.credentials.json` も同じく chown。これで goku の `claude -p` が OAuth トークンリフレッシュを書き戻せる
- **D-15:** `cmd_kaio` のホスト認証同期 (`docker run --rm ... cp ... && chmod 600`) を **`cp && chown $HOST_UID:$HOST_GID && chmod 600`** に更新。CLI が `-e HOST_UID/-e HOST_GID` を渡す必要がある

### CLI 側の変更 (spirit-room)

- **D-16:** `cmd_open` / `cmd_kaio` の `docker run` に **`-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)`** を追加
- **D-17:** `cmd_kaio` の `docker run --rm` (129-135 行付近の認証同期) も同じ env を渡す
- **D-18:** `cmd_enter` は `ssh ... -t root@localhost` → **`ssh ... -t goku@localhost`**。tmux session 名 (`spirit-room`) は変更なし

### 既存状態のマイグレーション

- **D-19:** 既存の認証ボリューム (`spirit-room-auth`, `spirit-room-opencode-auth`) は**破棄せず、entrypoint の chown で上書き更新**。ユーザー操作は不要
- **D-20:** 既存に起動中の `spirit-room-*` コンテナは **close → 再 open 必須**。Phase 5 のリリースノート (`HANDOVER.md` 追記) に「spirit-room close で一度落としてから新イメージで open し直してください」と明記

### Folded Todos

- **2026-04-17-goku-uid.md** — この todo が Phase 5 のドライバそのもの。`files:` に挙がった `Dockerfile` / `entrypoint.sh` / `spirit-room` が実装対象と一致。Solution セクションの 1-5 をほぼそのまま採用し、上記決定で補強した

### Claude's Discretion

- gosu を使うか su を使うかの最終選択: **su - goku -c** を基本線として合意済み。ただし tmux の起動時に PATH や環境変数引き継ぎで不具合が出た場合、gosu への切替を plan フェーズで検討可
- goku の UID/GID 衝突時の扱い (ホスト UID がイメージ内の既存ユーザー _apt 等と衝突する場合) の具体回避 (`-o` オプション使用 / 既存ユーザー削除など) は実装で判断

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 変更対象コード
- `spirit-room/base/Dockerfile` — ① `PermitRootLogin yes` → `no` (55行目付近), ② goku:spiritroom のパスワード設定を追加, ③ sudo パッケージが既にあるか確認 (必要なら追加), ④ gosu 採用時はここでインストール
- `spirit-room/base/entrypoint.sh` — メイン改修対象。goku 作成 + chown + git config 再設定 + `su - goku -c` で tmux 起動。現行のファイルは 1-83 行
- `spirit-room/spirit-room` — ① `cmd_open` (52-93行) と `cmd_kaio` (99-161行) に `-e HOST_UID -e HOST_GID` 追加, ② `cmd_enter` (177-196行) の SSH ユーザーを goku に, ③ `cmd_kaio` の docker run --rm (129-135行) の cp に chown 追加, ④ `cmd_auth` (233-265行) の docker run --rm にも必要なら chown
- `spirit-room/base/scripts/start-training.sh` — goku で走る前提で git config が効く必要あり。Dockerfile の root HOME から goku HOME への移行が entrypoint 側で完了していれば変更不要だが、`init_git_workspace()` の safe.directory 設定は goku HOME に書かれることを確認すること

### 依存する過去フェーズの決定 (破壊しないこと)
- `.planning/phases/04-gsd-claude-config-dir-symlink-gsd-autonomous/04-CONTEXT.md` — kaio モードの `CLAUDE_CONFIG_DIR=/workspace/.claude-home` 設計、credentials symlink 戦略、共有ボリュームを `/root/.claude-shared` にマウントする設計。Phase 5 はこの仕組みに goku 所有を重ねる形で拡張する
- `.planning/phases/04-gsd-claude-config-dir-symlink-gsd-autonomous/04-PLAN.md` (存在すれば) — 実装済みのフック位置を確認し、同じ場所に goku 化を差し込む

### プロジェクト憲法
- `CLAUDE.md` — 応答言語 (日本語) / Tech Stack 制約 (bash + Docker のみ) / ブランチ戦略 (`phase/05-xxx` で作業 → main に squash merge) / Dragon Ball 命名規約
- `.planning/PROJECT.md` — コアバリュー「Mr.ポポにフレームワーク名と目的を伝えたら、Claude Code が自律的に POC を実装して動くところまで完成させる」。Phase 5 はこの UX の裏方改善で、コアバリューを壊してはいけない
- `.planning/REQUIREMENTS.md` — v1 要件一覧。Phase 5 は既存要件の破壊がないこと (AUTH-01/02, LOOP-01〜04 が Phase 5 リリース後も動く) を確認する必要あり

### Phase 5 の駆動 todo
- `.planning/todos/pending/2026-04-17-goku-uid.md` — Problem / Solution / 懸念点の 3 節を含むドライバ todo。plan フェーズは Solution の 1-5 ステップを計画タスクに展開すること。完了時に `.planning/todos/completed/` へ移動

### Mr.ポポ側への波及 (確認のみ、通常は変更不要)
- `spirit-room-manager/CLAUDE.md` / `spirit-room-manager/skills/MR_POPO.md` — Mr.ポポが `spirit-room open` / `spirit-room kaio` を呼ぶだけなので、CLI 側の引数が変わらなければ無改修。HANDOVER.md に追記する

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Dockerfile の既存レイヤー構造** (`spirit-room/base/Dockerfile`): 既に SSH / tmux / bash / git の基盤が整っている。goku 化は SSH 設定の 1 行書換と sudoers ファイル追加で最小差分
- **entrypoint.sh の既存構造** (`spirit-room/base/entrypoint.sh`): CLAUDE_CONFIG_DIR 分岐 (18-33行), tmux 3 ペイン構築 (54-77行) が完成済み。goku 化はこの前後にフックを挿入するだけ
- **spirit-room CLI の `cmd_open` / `cmd_kaio`** (`spirit-room/spirit-room`): docker run の構築パターンが確立。`-e HOST_UID/-e HOST_GID` を 1 行追加するだけで済む
- **認証ボリューム共有の仕組み**: `-v "${AUTH_VOLUME}:/root/.claude"` (spirit-room:83) と、kaio の `-v "${AUTH_VOLUME}:/root/.claude-shared"` (spirit-room:148) の 2 形態がある。entrypoint 側で両方を chown 対象に含める
- **git config --global --add safe.directory '*'** (Dockerfile:61-64, start-training.sh:51): パターンは確立済み。goku HOME 用に entrypoint で再実行するだけ

### Established Patterns
- **chown と chmod の実行パターン**: `cmd_auth` (spirit-room:240-245) と `cmd_kaio` (spirit-room:129-135) で `docker run --rm --entrypoint /bin/bash ... -c "cp ... && chmod 600 ..."` のパターンが定着。ここに `&& chown $HOST_UID:$HOST_GID` を追加するだけで goku 対応
- **冪等化フラグ**: `.prepared` / `.done` / `.researched` / `.reported` の idempotent フラグパターンが start-training.sh で使われている。goku 作成にも同じ思想 (`id goku` で存在チェック) を適用
- **環境変数による分岐**: CLAUDE_CONFIG_DIR の有無で kaio 分岐 (entrypoint.sh:23)。HOST_UID の有無で fallback 分岐を同じパターンで

### Integration Points
- **docker run の env 引数**: spirit-room:77-86 (cmd_open), spirit-room:141-150 (cmd_kaio), spirit-room:129-135 (認証同期用 --rm コンテナ) の 3 箇所で統一的に HOST_UID/GID 渡し
- **SSH 接続ポイント**: spirit-room:192-195 (cmd_enter の ssh コマンド) のユーザー名変更 1 箇所
- **entrypoint の tmux 起動**: entrypoint.sh:55-80 の tmux 関連行を `su - goku -c '...'` でラップ
- **既存 Phase 4 の entrypoint 改修部 (18-33行)**: credentials symlink 処理がある。ここに `chown -h goku:goku $CLAUDE_CONFIG_DIR/.credentials.json` を追加

</code_context>

<specifics>
## Specific Ideas

### entrypoint.sh 改修骨子 (疑似コード)

```bash
#!/bin/bash
set -e

# 既存の ROOM_NAME 設定 + バナー表示
# ...

# service を root で起動
service ssh start
service redis-server start

# ── HOST_UID/GID 受け取り (fallback: 1000:1000) ────────────────
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"

# ── goku ユーザーの冪等作成 ────────────────────────────────
if ! id goku &>/dev/null; then
    getent group "$HOST_GID" >/dev/null || groupadd -g "$HOST_GID" goku
    useradd -m -u "$HOST_UID" -g "$HOST_GID" -s /bin/bash -o goku
    echo 'goku:spiritroom' | chpasswd
    echo 'goku ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/goku
    chmod 0440 /etc/sudoers.d/goku
fi

# ── chown: 認証ボリュームと /workspace ─────────────────────
chown -R "$HOST_UID:$HOST_GID" /root/.claude /root/.config/opencode 2>/dev/null || true
[ -d /root/.claude-shared ] && chown -R "$HOST_UID:$HOST_GID" /root/.claude-shared
chown -R "$HOST_UID:$HOST_GID" /workspace

# ── kaio の credentials symlink (既存ロジックの後に chown -h 追加) ──
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    mkdir -p "$CLAUDE_CONFIG_DIR"
    chown "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR"
    if [ -f /root/.claude-shared/.credentials.json ]; then
        ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
        chown -h "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR/.credentials.json"
    fi
fi

# ── goku として git config ─────────────────────────────────
su - goku -c "git config --global --add safe.directory '*' && \
    git config --global user.email 'spirit-room@localhost' && \
    git config --global user.name 'Spirit Room' && \
    git config --global init.defaultBranch main"

# ── tmux セッションを goku として起動 ──────────────────────
# (既存の 3 pane tmux 構築を su - goku -c でラップ)
su - goku -c "
tmux new-session -d -s spirit-room -x 220 -y 50
tmux rename-window -t spirit-room:0 training
# ... (既存の分岐 + send-keys をそのまま)
"

# PID 1 を保持
tail -f /dev/null
```

### spirit-room CLI の差分 (疑似 diff)

```bash
# cmd_open
docker run -d \
    --name "$name" \
    --hostname "$name" \
    -e ROOM_NAME="$(basename $folder)" \
    -e HOST_UID="$(id -u)" \           # 追加
    -e HOST_GID="$(id -g)" \           # 追加
    -p "${port}:22" \
    # ... (以下同じ)

# cmd_kaio (通常の docker run と、docker run --rm の認証同期両方)
docker run --rm \
    -v "${AUTH_VOLUME}:/dst" \
    -v "${host_creds}:/src/.credentials.json:ro" \
    -e HOST_UID="$(id -u)" \           # 追加
    -e HOST_GID="$(id -g)" \           # 追加
    --entrypoint /bin/bash \
    "$BASE_IMAGE" \
    -c "cp /src/.credentials.json /dst/.credentials.json && \
        chown \$HOST_UID:\$HOST_GID /dst/.credentials.json && \
        chmod 600 /dst/.credentials.json"

# cmd_enter
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -t goku@localhost -p "$port" \     # root → goku
    "tmux attach -t spirit-room || tmux new-session -s spirit-room"
```

### Dockerfile の差分

```Dockerfile
# ── SSH設定 ─────────────────────────────────────────────────
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
# 注: goku のパスワード設定と UID 割当は entrypoint.sh のランタイム処理
```

### 検証手順 (plan フェーズで参考)

1. `./spirit-room/build-base.sh` でリビルド
2. `spirit-room close` で既存コンテナを破棄
3. `spirit-room open ./test-folder` → `spirit-room enter ./test-folder` で goku プロンプトが表示されるか
4. コンテナ内で `touch /workspace/test.txt` → ホスト側で `ls -la ./test-folder/test.txt` が自分のユーザー所有になっているか
5. `start-training` を走らせて git commit が goku 名義で残るか
6. `spirit-room kaio ./test-kaio` で kaio モードも同様の挙動か
7. 2 つ目の部屋を開いて、`spirit-room-auth` ボリュームが競合なく共有できるか (chown が冪等に効くか)

</specifics>

<deferred>
## Deferred Ideas

以下は Phase 5 スコープ外。必要になったら別フェーズ or バックログへ:

- **gosu への置換**: su - goku が PATH/env 引き継ぎで問題を起こした場合の代替として保留。現状は su 基本線で進める
- **複数ホストユーザーの切替**: HOST_UID を都度 `id -u` で取る設計なので原理上は動くが、同じボリュームを UID の違うユーザーから順に使うと chown 合戦になる可能性あり。必要になったら専用対応
- **Windows / macOS (非 Linux) ホスト対応**: UID/GID の概念が違うため動作保証しない。当面 Linux ホスト前提
- **root ログイン復活オプション (`spirit-room enter --root`)**: デバッグ時の緊急窓として欲しくなるかもしれないが、最初の実装はシンプルに goku のみ
- **sudoers 粒度の絞り込み**: 現状 NOPASSWD:ALL。セキュリティ要件が出てきたら Cmnd_Alias で絞る別フェーズに
- **既存コンテナのホットマイグレーション**: 実行中コンテナの docker exec で後付け goku 化するスクリプト。Phase 5 では close → open で運用回避
- **MISSION.md / KAIO-MISSION.md.template 側の調整**: 「goku で走ります」等の注記を入れるかは運用開始後に判断

### Reviewed Todos (not folded)
なし (このフェーズに関連する todo は `2026-04-17-goku-uid.md` のみで、すべて本フェーズに折り込んだ)

</deferred>

---

*Phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui*
*Context gathered: 2026-04-17*
