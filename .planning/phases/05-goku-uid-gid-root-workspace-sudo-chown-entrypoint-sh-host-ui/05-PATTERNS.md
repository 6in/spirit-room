# Phase 5: goku ユーザー作成 / ホスト UID-GID 一致 - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 3 (modify)
**Analogs found:** 3 / 3 (全て自己参照: 既存ファイル内の隣接ブロックが analog)

---

## File Classification

| 改修対象ファイル | Role | Data Flow | 最近接 Analog | Match Quality |
|------------------|------|-----------|--------------|---------------|
| `spirit-room/base/Dockerfile` | config (image build) | build-time | 同ファイル L52-56 (SSH設定) / L61-64 (git config) | exact (自己内隣接) |
| `spirit-room/base/entrypoint.sh` | startup-script | event-driven (container boot) | 同ファイル L18-33 (kaio 分岐) / L54-77 (tmux 起動) | exact (自己内隣接) |
| `spirit-room/spirit-room` | CLI (controller) | request-response (docker orchestration) | 同ファイル L77-86 (cmd_open) / L129-135 (認証同期 --rm) / L141-150 (cmd_kaio) / L177-196 (cmd_enter) | exact (自己内隣接) |

**判断根拠:** Phase 5 は完全に「既存ファイルへのブロック追加」であり、プロジェクト内に同種の機能を持つ別ファイルは存在しない。したがって pattern の参照先は**同じファイル内の既存ブロック**となる。Dockerfile・entrypoint・CLI はどれも唯一のインスタンスで、Phase 4 で確立した構造の上に重ねる形。

---

## Pattern Assignments

### 1. `spirit-room/base/Dockerfile` (config, build-time)

**Analog:** 同ファイル内の既存 SSH 設定レイヤー + git 設定レイヤー

#### Pattern A1 — SSH 設定ブロックの書換え位置 (L52-56)

**既存コード:**
```dockerfile
# ── SSH設定 ─────────────────────────────────────────────────
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```

**Phase 5 での変更指示:**
- L55 `PermitRootLogin yes` → `PermitRootLogin no` (sed で既存行を書換える方式。`sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config`)
- goku のパスワード設定はランタイム (entrypoint) 側で行う (D-01: ビルド時は UID 未知のため)
- `sudo` パッケージが既存 `apt-get install -y` (L9-23) に含まれているか確認し、なければ追加

#### Pattern A2 — レイヤーコメント形式 (L8, L28, L37, L42, L46, L49, L52, L58, L66)

**既存パターン:** `# ── レイヤーN: 説明 ────────────────────────────────`

Phase 5 で新規ブロックを追加する際はこのコメント形式に従う。ただし今回はレイヤー追加というより既存レイヤー (SSH 設定) の書換えなので、コメントのみ微修正で済む。

#### Pattern A3 — Git config の root 設定 (L58-64)

**既存コード:**
```dockerfile
# ── Git 設定 ─────────────────────────────────────────────────
# /workspace はホストからマウントされるため所有権が root と一致しない。
# git の dubious ownership エラーを回避するため全ディレクトリを safe に設定。
RUN git config --global --add safe.directory '*' \
    && git config --global user.email 'spirit-room@localhost' \
    && git config --global user.name 'Spirit Room' \
    && git config --global init.defaultBranch main
```

**Phase 5 での扱い:** このブロックは**そのまま残す** (D-12)。root HOME 側の設定は触らず、entrypoint 側で goku HOME にも同じ設定を追加する形で goku 用をミラーする。

---

### 2. `spirit-room/base/entrypoint.sh` (startup-script, event-driven)

**Analog:** 同ファイル内の既存 service 起動 + kaio 分岐 + tmux 起動

#### Pattern B1 — 冪等チェック + 分岐パターン (L23-33, kaio 判定)

**既存コード:**
```bash
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    echo "[INFO] 界王星モード: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    if [ -f /root/.claude-shared/.credentials.json ]; then
        ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
        echo "[INFO] 認証情報を symlink: $CLAUDE_CONFIG_DIR/.credentials.json → /root/.claude-shared/.credentials.json"
    else
        echo "[WARN] /root/.claude-shared/.credentials.json が見つからない。spirit-room auth を実行せよ"
    fi
fi
```

**Phase 5 でコピーすべきパターン:**
- `${VAR:-default}` による fallback (HOST_UID/HOST_GID 未指定時の 1000:1000 fallback に使う)
- `[ -f ... ] && ...` / `if [ -n ... ]` で存在チェックしてから処理する冪等構造
- `echo "[INFO] ..."` / `echo "[WARN] ..."` のメッセージ形式

**新規追加ブロック挿入位置:** L17 (Redis 起動完了メッセージの次) と L33 (kaio 分岐終了直後) の間、もしくは L33 直後の新セクションとして挿入。順序は CONTEXT.md D-09 に従う:
1. service 起動 (L14-16) — 既存のまま
2. HOST_UID/GID 受け取り (新規, L17 と L18 の間 or L33 直後)
3. goku 作成 (新規)
4. chown (新規)
5. kaio credentials の chown 追加 (既存 L23-33 に追記)
6. git config 再設定 (新規)
7. tmux 起動を `su - goku -c` でラップ (L54-77 を包む)

#### Pattern B2 — service 起動ブロック (L13-16)

**既存コード:**
```bash
# ── サービス起動 ─────────────────────────────────────────────
service ssh start
service redis-server start
echo "[INFO] Redis起動完了"
```

**Phase 5 ルール:** この root 特権サービスの起動は**先行させる** (D-09 の①)。goku 作成よりも前。sshd と redis は root でしか listen できないため。

#### Pattern B3 — tmux 3 pane 構築 (L54-77)

**既存コード:**
```bash
# ── tmuxセッション ───────────────────────────────────────────
SESSION="spirit-room"
tmux new-session -d -s "$SESSION" -x 220 -y 50

tmux rename-window -t "$SESSION:0" "training"
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]; then
    tmux send-keys -t "$SESSION:training" "start-training-kaio" C-m
elif [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    tmux send-keys -t "$SESSION:training" "start-training" C-m
else
    tmux send-keys -t "$SESSION:training" \
        "echo '部屋[$ROOM_NAME] 準備完了 | start-training(-kaio) で修行開始 | status で確認'" C-m
fi

tmux new-window -t "$SESSION" -n "logs"
tmux send-keys -t "$SESSION:logs" \
    "tail -f /workspace/.logs/progress.log 2>/dev/null || (echo 'ログ待機中...'; while true; do sleep 2; tail -f /workspace/.logs/progress.log 2>/dev/null && break; done)" C-m

tmux new-window -t "$SESSION" -n "workspace"
tmux send-keys -t "$SESSION:workspace" \
    "watch -n 2 'tree /workspace -L 3 -I .logs 2>/dev/null || ls -la /workspace'" C-m

tmux select-window -t "$SESSION:training"
```

**Phase 5 でのラップ方針 (D-08):**

ブロック全体を `su - goku -c "..."` で包む。ヒアドキュメントにすると変数展開の escape が増えるため、以下のどちらかを plan フェーズで選択:

- **案 A (heredoc):** `su - goku -c "bash -s" << 'EOF' ... EOF` — 環境変数 `$SESSION` / `$ROOM_NAME` / `$CLAUDE_CONFIG_DIR` を goku セッションに渡すには `<< EOF` (クォート無し) にして親 shell で展開するか、`su - goku -c "bash"` に export 済み env を引き継ぐ
- **案 B (単一コマンド連結):** 現状の tmux コマンド列を `&&` / `; ` で連結し 1 行の文字列にして `su - goku -c '...'` に渡す
- **環境変数引き継ぎの注意点:** `su - goku` は `-` (login shell) なので PATH が goku 用になる。Claude Code / opencode は `/usr/local/bin` に linked されているため問題ない。但し `CLAUDE_CONFIG_DIR` は su login で失われるので `su - goku -c "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR tmux ..."` のように明示再渡しが必要

**Claude の discretion (CONTEXT.md 参照):** su で env 引き継ぎが破綻したら gosu に切替可。まずは su 線。

#### Pattern B4 — PID 1 保持 (L83)

**既存コード:**
```bash
tail -f /dev/null
```

**Phase 5 ルール:** この行は**root のまま残す** (D-09 の⑥)。PID 1 を goku にすると SIGTERM ハンドリングが怪しくなるため、最後の `tail -f /dev/null` は root で。

---

### 3. `spirit-room/spirit-room` (CLI, request-response)

**Analog:** 同ファイル内の `cmd_open` / `cmd_kaio` / `cmd_enter` / 認証同期 `--rm` コンテナ

#### Pattern C1 — `docker run -d` 構築パターン (L77-86, cmd_open)

**既存コード:**
```bash
docker run -d \
    --name "$name" \
    --hostname "$name" \
    -e ROOM_NAME="$(basename $folder)" \
    -p "${port}:22" \
    -v "${folder}:/workspace" \
    -v "${AUTH_VOLUME}:/root/.claude" \
    -v "${OPENCODE_AUTH_VOLUME}:/root/.config/opencode" \
    -v "${HOME}/.claude.json:/root/.claude.json:ro" \
    "$BASE_IMAGE"
```

**Phase 5 差分 (D-16):**
既存の `-e ROOM_NAME=...` (L80) の直後に以下を追加:
```bash
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
```

#### Pattern C2 — `docker run -d` (cmd_kaio 版, L141-150)

**既存コード:**
```bash
docker run -d \
    --name "$name" \
    --hostname "$name" \
    -e ROOM_NAME="$(basename $folder)" \
    -e CLAUDE_CONFIG_DIR=/workspace/.claude-home \
    -p "${port}:22" \
    -v "${folder}:/workspace" \
    -v "${AUTH_VOLUME}:/root/.claude-shared" \
    -v "${HOME}/.claude.json:/root/.host-claude.json:ro" \
    "$BASE_IMAGE"
```

**Phase 5 差分 (D-16):**
`-e CLAUDE_CONFIG_DIR=...` (L145) の直後に `-e HOST_UID / -e HOST_GID` を追加。cmd_open と同じパターン。

#### Pattern C3 — `docker run --rm` 認証同期パターン (L129-135, cmd_kaio 内)

**既存コード:**
```bash
docker run --rm \
    -v "${AUTH_VOLUME}:/dst" \
    -v "${host_creds}:/src/.credentials.json:ro" \
    --entrypoint /bin/bash \
    "$BASE_IMAGE" \
    -c "cp /src/.credentials.json /dst/.credentials.json && chmod 600 /dst/.credentials.json" \
    > /dev/null 2>&1 || echo "[WARN] 認証情報同期に失敗"
```

**Phase 5 差分 (D-15, D-17):**
- `-e HOST_UID="$(id -u)"` と `-e HOST_GID="$(id -g)"` を `--entrypoint /bin/bash` の前に追加
- `-c` の中に `&& chown $HOST_UID:$HOST_GID /dst/.credentials.json` を追加。位置は `cp` の後 `chmod 600` の前 or 後どちらでも可 (順番不問)
- bash の変数展開は `\$HOST_UID` (エスケープ必須) — `-c "..."` が bash で展開されるのでコンテナ内展開にしたい場合はエスケープする

#### Pattern C4 — `docker run --rm` 認証コピーパターン (cmd_auth, L240-245)

**既存コード:**
```bash
docker run --rm \
    -v "${AUTH_VOLUME}:/root/.claude" \
    -v "${creds}:/src/.credentials.json:ro" \
    --entrypoint /bin/bash \
    "$BASE_IMAGE" \
    -c "cp /src/.credentials.json /root/.claude/.credentials.json"
```

**Phase 5 差分 (CONTEXT.md canonical_refs の「必要なら」):**
cmd_auth の実行タイミングでは goku ボリュームが存在する前の可能性があるため、**chown 追加は entrypoint 側で冪等に行う方針で吸収** (D-11)。よってここは**変更不要の可能性が高い**。plan フェーズで「entrypoint が毎回 chown するので cmd_auth は触らなくて OK」と判断可。

#### Pattern C5 — SSH 接続パターン (cmd_enter, L192-195)

**既存コード:**
```bash
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -t root@localhost -p "$port" \
    "tmux attach -t spirit-room || tmux new-session -s spirit-room"
```

**Phase 5 差分 (D-07, D-18):**
L194: `root@localhost` → `goku@localhost` (1 単語変更のみ)。他の options は触らない。パスワードは goku でも `spiritroom` (D-04) なので UX は変わらない。

---

## Shared Patterns

### 冪等化フラグ / 存在チェックパターン

**Source:** `spirit-room/base/scripts/start-training.sh` L101, L159, L191 / `spirit-room/base/entrypoint.sh` L27
**Apply to:** entrypoint.sh の新規ブロック (goku 作成, chown)

**典型コード:**
```bash
# start-training.sh 風
[ -f "$PREPARED_FLAG" ] && { log "PREPARE済み、スキップ"; break; }

# entrypoint.sh 風
if ! id goku &>/dev/null; then
    # goku を作る処理
fi

[ -d /root/.claude-shared ] && chown -R "$HOST_UID:$HOST_GID" /root/.claude-shared
```

Phase 5 では `id goku &>/dev/null` / `getent group $HOST_GID` を冪等ガードにする (D-02)。chown は「毎回走らせて上書きで最新化」する冪等性 (D-11) — フラグを付けない。

### エラー許容 `|| true` パターン

**Source:** `spirit-room/spirit-room` L74-75 / L229
**Apply to:** entrypoint.sh の chown (`2>/dev/null || true`)

**典型コード:**
```bash
docker volume create "$AUTH_VOLUME"         > /dev/null 2>&1 || true
tail -f "$folder/.logs/progress.log" 2>/dev/null || echo "ログなし..."
```

Phase 5 の chown で対象ディレクトリが存在しない可能性があるパス (`/root/.claude-shared` など) は `2>/dev/null || true` で吸収。

### `[INFO]` / `[WARN]` / `[ERROR]` プレフィックスメッセージ

**Source:** `spirit-room/base/entrypoint.sh` 全体 / `spirit-room/spirit-room` 全体
**Apply to:** entrypoint.sh 新規ブロックの全ユーザー向け出力

goku 作成成功: `echo "[INFO] goku ユーザーを作成 (UID=$HOST_UID GID=$HOST_GID)"`
chown 実行: `echo "[INFO] /workspace と認証ボリュームを goku 所有に切替"`
fallback 時: `echo "[WARN] HOST_UID/GID 未指定 → 1000:1000 で作成"`

### 4 space インデント / `#!/bin/bash` + `set -e`

**Source:** `spirit-room/base/entrypoint.sh` L1-2 / `spirit-room/spirit-room` L8
**Apply to:** すべての新規追加ブロック

4 空白インデント、`"$var"` の quote、`local` の使用は CLAUDE.md の Code Style 通り。

### セクションセパレータ `# ── 説明 ────`

**Source:** `spirit-room/base/entrypoint.sh` L13, L18, L35, L47, L54 / `spirit-room/spirit-room` L35, L42, L51, L95 等
**Apply to:** entrypoint.sh 新規ブロックの見出し

例:
```bash
# ── HOST_UID/GID 受け取り (fallback: 1000:1000) ─────────────
# ── goku ユーザーの冪等作成 ─────────────────────────────────
# ── 認証ボリュームと /workspace を goku 所有に ──────────────
# ── goku として git config ─────────────────────────────────
```

### docker volume create の前置きパターン

**Source:** `spirit-room/spirit-room` L74-75
**Apply to:** Phase 5 では**追加不要** (既存のまま)

```bash
docker volume create "$AUTH_VOLUME"         > /dev/null 2>&1 || true
docker volume create "$OPENCODE_AUTH_VOLUME" > /dev/null 2>&1 || true
```

ボリュームは流用する (D-19) ため create の再修正は不要。chown は entrypoint 側で吸収。

---

## No Analog Found

プロジェクト内にまったく先例がない概念:

| 概念 | 理由 | Planner が参考にすべき参照 |
|------|------|-----------------------------|
| `useradd -o -u $HOST_UID -g $HOST_GID goku` | これまで単一の root 前提で動いていたため UID 動的作成の先行例なし | CONTEXT.md `<specifics>` L148-155 の疑似コードをほぼそのまま採用。Docker コミュニティでの定番パターン (fixuid / gosu と同系) |
| `/etc/sudoers.d/goku` への `NOPASSWD:ALL` 書出し | sudoers ファイル生成は未経験 | CONTEXT.md D-05 と specifics L153-154 の疑似コードをそのまま。`chmod 0440` を忘れずに |
| `su - goku -c "tmux ..."` で tmux をユーザー起動 | 現状すべて root 前提で tmux が走っていたため先例なし | CONTEXT.md D-08 と specifics L179-184。環境変数引き継ぎに注意 (CLAUDE_CONFIG_DIR / ROOM_NAME など) |
| `chown -h` による symlink 自体の所有者変更 | 今まで symlink を goku 所有にする必要がなかった | CONTEXT.md D-14 と specifics L168 — `chown -h` は symlink の target ではなく symlink 自体の所有者を変える |

これらは RESEARCH.md / CONTEXT.md の疑似コードを第一参照とする。

---

## Metadata

**Analog search scope:**
- `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile`
- `/home/parallels/workspaces/spirit-room-full/spirit-room/base/entrypoint.sh`
- `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`
- `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training-kaio.sh` (存在確認のみ、必要なら plan フェーズで参照)
- `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`
- `/home/parallels/workspaces/spirit-room-full/spirit-room/base/CLAUDE.md`

**Files scanned:** 6

**Pattern extraction date:** 2026-04-17

**Planner への Hand-off 要点:**
1. **全変更は「同ファイル内の既存パターンを踏襲した追加」** — 新規ファイルは 1 つもない
2. **entrypoint.sh の改修順序は D-09 に厳密に従う** (service → goku 作成 → chown → kaio symlink chown → git config → `su - goku -c` で tmux)
3. **CLI は 4 箇所だけの最小差分** (cmd_open の env、cmd_kaio の env、cmd_kaio --rm の env + chown、cmd_enter の SSH user)
4. **Dockerfile は SSH 1 行書換えのみ** (他の goku 関連処理はすべて entrypoint ランタイム)
5. **既存 git config (Dockerfile L58-64) / 既存 Auth volume / `.claude.json:ro` マウントは触らない** — 破壊しないことが D-19 / canonical_refs で保証されている
