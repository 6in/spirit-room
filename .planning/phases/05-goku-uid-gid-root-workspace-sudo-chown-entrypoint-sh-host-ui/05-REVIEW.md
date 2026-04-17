---
phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
reviewed: 2026-04-17T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - spirit-room/base/Dockerfile
  - spirit-room/base/entrypoint.sh
  - spirit-room/spirit-room
findings:
  blocker: 0
  high: 2
  medium: 4
  low: 3
  info: 3
  total: 12
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-17
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found (high severity 2 件 — マージ前対応推奨)

## Summary

Phase 5 の 3 ファイル（`Dockerfile` / `entrypoint.sh` / `spirit-room` CLI）を standard 深度でレビューした。D-09 の順序や冪等性ガードなどの設計意図は概ね正しく実装されている。しかし以下の問題が見つかった:

- **HIGH-01**: Ubuntu 24.04 ベースイメージには既に `uid=1000 / gid=1000` の `ubuntu` ユーザーが存在し、**最も一般的なホスト UID=1000 のケースで UID/GID が衝突**する。`useradd -o` で作成自体は通るが、`/etc/passwd` に同じ UID を持つ 2 エントリ (`ubuntu`, `goku`) が並び、`id -un 1000` / `getent passwd 1000` / `whoami` が **`ubuntu` を返してしまう**リスクがある。`getent group "$HOST_GID" >/dev/null` が true を返すため `groupadd` はスキップされ、結果として goku は `goku:ubuntu` (primary group が `ubuntu`) になる。設計意図「goku で走る」を見かけ上破壊する可能性あり。
- **HIGH-02**: コンテナを異なる HOST_UID のホストで再利用した場合、`id goku` が true → ブロック全体スキップ → chown 先の UID は `$HOST_UID`（新）だが goku の UID は旧値のまま → **goku 自身が /workspace を所有しない状態**になる。volume を持ち越す前提だと UID 整合性が壊れる。
- **MEDIUM-01**: `_TRAINING_CMD` に `${ROOM_NAME}` を埋めたまま heredoc 経由で bash に再解釈させるためコマンドインジェクション経路が成立。ホスト側の `-e ROOM_NAME="$(basename $folder)"` はクォート無しなのでユーザーがフォルダ名に `'` や `$(...)` を入れると、コンテナ内で意図しないコマンドが実行されうる (信頼境界はユーザー本人なので実害は低いが、フォルダ名にスペースやシングルクォートが入ると起動が壊れる)。
- **MEDIUM-02/03/04**: chown のレース・`~/.profile` の値更新検知欠如・`claude auth status` が root で走り続ける旧仕様。

Phase 5 の実機検証 (Task 2.3 / Task 3.4) は worktree モード上で手動 checkpoint が skip されており、Dockerfile 再ビルド後の実地検証は **未実施**。HIGH-01 は再ビルド直後の 1 度の `docker run --rm spirit-room-base:latest id goku` で即検出できるので、マージ前にユーザー手元で確認することを強く推奨する。

---

## High

### HIGH-01: Ubuntu 24.04 既存 `ubuntu` ユーザー (uid=1000) との UID/GID 衝突で `whoami` が `ubuntu` を返す可能性

**File:** `spirit-room/base/entrypoint.sh:30-39`
**Issue:** Ubuntu 24.04 公式ベースイメージには `ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash` がデフォルトで存在する (確認済: `docker run --rm ubuntu:24.04 getent passwd 1000` で出力あり)。HOST_UID=1000 (Linux 一般ユーザーの最頻値) のとき:

1. `id goku &>/dev/null` → false (初回)
2. `getent group "$HOST_GID" >/dev/null` → true (`ubuntu` グループにマッチ) → **groupadd スキップされ `goku` グループは作られない**
3. `useradd -m -u 1000 -g 1000 -s /bin/bash -o goku` → `-o` で UID 重複許可。primary group=1000 (`ubuntu` グループ)。作成成功
4. `/etc/passwd` の状態: `ubuntu:x:1000:1000:...` (先) + `goku:x:1000:1000:...` (後)

結果:
- `id -un 1000` → `ubuntu` (passwd の先頭一致)
- `ssh goku@localhost` → 認証は `goku` で通るが、login 後の `$USER` は goku。ただし `ls -la` のような uid→name 解決を伴う出力では `ubuntu` 表記に化ける可能性あり。
- `id` コマンドは `uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu)` のように `goku` の名前が見えない状況が出うる
- ホスト側で `/workspace` を ls すると uid=1000 のホストユーザー名で見えるので最終目的 (ホスト自分ユーザー所有) は達成されるが、**コンテナ内の観察が混乱**する
- sudoers は `goku ALL=(ALL) NOPASSWD:ALL` で goku 名前ベース → sudoers は UID ではなく username 解決するため、sudo そのものは `sudo -u goku` で動くはず。ただし `getpwuid(1000)` が `ubuntu` を返すと混乱の温床

**Fix:** Dockerfile 側で既存 `ubuntu` ユーザー/グループを事前削除する (Phase 5 スコープ内で最小差分):

```dockerfile
# ── SSH設定 ─────────────────────────────────────────────────
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true
```

または `entrypoint.sh` の goku 作成ブロック冒頭で:

```bash
if ! id goku &>/dev/null; then
    # Ubuntu 24.04 デフォルトの ubuntu (uid=1000) と衝突しないよう事前削除
    if getent passwd 1000 | grep -q '^ubuntu:'; then
        userdel -r ubuntu 2>/dev/null || true
    fi
    if getent group 1000 | grep -q '^ubuntu:'; then
        groupdel ubuntu 2>/dev/null || true
    fi
    getent group "$HOST_GID" >/dev/null || groupadd -g "$HOST_GID" goku
    useradd -m -u "$HOST_UID" -g "$HOST_GID" -s /bin/bash goku  # -o は不要に戻せる
    ...
fi
```

Dockerfile 側で削除する方が冪等性・再ビルドコスト両面で有利。

**Verification (ユーザー手元で実行):**
```bash
cd spirit-room && ./build-base.sh
docker run --rm -e HOST_UID=1000 -e HOST_GID=1000 --entrypoint /bin/bash spirit-room-base:latest \
  -c "getent group \$HOST_GID; \
      useradd -m -u \$HOST_UID -g \$HOST_GID -s /bin/bash -o goku 2>&1; \
      getent passwd 1000; id goku; id -un 1000"
# 現状: ubuntu:x:1000:1000 と goku:x:1000:1000 が両方出て、id -un 1000 が 'ubuntu' を返す
# 修正後: goku 行のみ、id -un 1000 が 'goku' を返す
```

---

### HIGH-02: HOST_UID が変わってもコンテナ内 goku の UID は変わらない (ホスト移行時に所有権が壊れる)

**File:** `spirit-room/base/entrypoint.sh:30-39`
**Issue:** `id goku &>/dev/null` が true の時点でブロック全体を skip する実装だが、同じ named volume (`spirit-room-auth`) を使い回したまま別ホスト (別 UID) で `docker run` すると、以下が起こる:

1. コンテナ初回起動: HOST_UID=1000 で goku 作成 (uid=1000)
2. コンテナ再起動 (同じコンテナ実体): goku 既存で skip → OK
3. **`docker rm` 後、別マシン (HOST_UID=1001) で同じ auth volume を使って新 docker run**: 新コンテナは `goku` を **uid=1001 で** 新規作成する (initial) → chown -R で `/root/.claude` 配下を uid=1001 所有に → 旧 volume が別 UID 所有だった場合、新 goku は所有者名が一致し再 chown は影響なし → OK

しかし:

4. **既存コンテナを restart するが HOST_UID が変わった場合 (docker run で `-e HOST_UID=新値` を渡した場合)**: `id goku` は true → skip (goku uid は旧値のまま)。しかし chown ブロックは走り、`/workspace` / `/root/.claude` は `$HOST_UID (新値):$HOST_GID` 所有に書き換え → **goku の uid と所有者 UID が不一致** → goku は /workspace / /root/.claude を所有しない状態に → sudo 権限が無いと書き込めない可能性

4 のシナリオは spirit-room CLI 経由では `cmd_open` → 新コンテナ作成なので起きないが、`docker start <container>` / `docker restart <container>` を手動実行するとヒットする。D-20 (close → re-open 必須) で運用ガイドはあるが、コード側の安全策が無い。

**Fix:** goku が既存の時も UID が `$HOST_UID` と一致するか確認し、不一致なら `usermod -u` で修正する。

```bash
if ! id goku &>/dev/null; then
    # 初回作成 (既存と同じ)
    ...
else
    # 既存 goku の UID が HOST_UID と一致するか確認。不一致なら usermod で再割り当て
    local current_uid=$(id -u goku)
    local current_gid=$(id -g goku)
    if [ "$current_uid" != "$HOST_UID" ] || [ "$current_gid" != "$HOST_GID" ]; then
        echo "[WARN] 既存 goku の UID/GID ($current_uid:$current_gid) が HOST_UID/GID ($HOST_UID:$HOST_GID) と不一致。再割り当て..."
        getent group "$HOST_GID" >/dev/null || groupmod -g "$HOST_GID" goku 2>/dev/null || true
        usermod -u "$HOST_UID" -g "$HOST_GID" goku 2>/dev/null || true
    else
        echo "[INFO] goku ユーザーは既に存在 (UID/GID 一致 / skip)"
    fi
fi
```

代替案: `id goku` check の代わりに毎回 `useradd` を試してエラー無視にすることで、HOST_UID 変更時に自動追従させる方式もあるが、ログがノイジーになるため上記 `usermod` 方式の方が明示的。

`local` キーワードは bash 関数内でのみ有効なので entrypoint.sh のトップレベルでは使えない。実装時は `local` を外すか、関数化する。

---

## Medium

### MEDIUM-01: `ROOM_NAME` が `_TRAINING_CMD` 経由で heredoc に埋め込まれ、コマンドインジェクション経路が成立

**File:** `spirit-room/base/entrypoint.sh:106, 119-132`
**Issue:** 

```bash
_TRAINING_CMD="echo '部屋[${ROOM_NAME}] 準備完了 | start-training(-kaio) で修行開始 | status で確認'"
...
su - goku -c "bash -s" << EOF
    ...
    tmux send-keys -t "${SESSION}:training" "${_TRAINING_CMD}" C-m
    ...
EOF
```

heredoc `<< EOF`（クォート無し）は親 shell で変数展開される。`_TRAINING_CMD` の値内にシングルクォート (`'`) や `$( )` が含まれると、heredoc 展開後の行を goku の bash が再解釈するときに構文が破綻する or コマンドが実行される。

Exploit 例: `ROOM_NAME="test';touch /tmp/pwned;#"` (スペースやシングルクォートを含むフォルダ名に由来)

- `_TRAINING_CMD` 代入後の値: `echo '部屋[test';touch /tmp/pwned;#] 準備完了 | ...'`
- heredoc 展開後: `tmux send-keys -t "spirit-room:training" "echo '部屋[test';touch /tmp/pwned;#] 準備完了 | ...'" C-m`
- goku bash 解釈: `tmux send-keys ... "echo '部屋[test'"` (最初のコマンド) + `;touch /tmp/pwned` (2 番目)  + `;#] ...` (コメント)
- 結果: goku として `/tmp/pwned` が作られる

信頼境界はホストユーザー自身なので**外部攻撃ではなく UX バグに近い**が、フォルダ名にスペース・シングルクォート・バックティックを入れるだけで起動が壊れる or 予期せぬ副作用を起こす。

派生問題:
- `spirit-room/spirit-room:80 / 148` の `-e ROOM_NAME="$(basename $folder)"` は `$folder` がクォート無し。`realpath` でサニタイズされているので path traversal は無いが、basename 自体はシェルメタ文字を保持する。

**Fix:** heredoc 展開を避け、`_TRAINING_CMD` を環境変数として goku に渡してから利用する。

```bash
# 親 shell 側で cmd を決める
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]; then
    _TRAINING_CMD="start-training-kaio"
elif [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    _TRAINING_CMD="start-training"
else
    # printf でシングルクォートをエスケープしておく (bash %q は printf 専用)
    _TRAINING_CMD=$(printf 'echo %q' "部屋[${ROOM_NAME}] 準備完了 | start-training(-kaio) で修行開始 | status で確認")
fi

# 環境変数経由で goku に渡す (heredoc で文字列展開しない)
_TRAINING_CMD="$_TRAINING_CMD" SESSION="$SESSION" \
su - goku --whitelist-environment=_TRAINING_CMD,SESSION -c "bash -s" << 'EOF'
set -e
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux rename-window -t "$SESSION:0" "training"
tmux send-keys -t "$SESSION:training" "$_TRAINING_CMD" C-m
...
EOF
```

または最も安全な方法: heredoc を **quoted heredoc** (`<< 'EOF'`) にし、必要な値は `export` + `su --preserve-environment` や `sudo -E` で渡す。

代替: basename で ROOM_NAME をサニタイズ (`ROOM_NAME="${ROOM_NAME//[^a-zA-Z0-9_-]/_}"`) を entrypoint 先頭に入れるだけでも大幅に軽減する。

---

### MEDIUM-02: `~/.profile` 冪等チェックが値不一致を検出しない (古い CLAUDE_CONFIG_DIR が残り続ける)

**File:** `spirit-room/base/entrypoint.sh:115-117`
**Issue:**

```bash
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    su - goku -c "grep -q 'export CLAUDE_CONFIG_DIR=' ~/.profile 2>/dev/null || echo 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' >> ~/.profile" || true
fi
```

`grep -q 'export CLAUDE_CONFIG_DIR='` は固定文字列 `export CLAUDE_CONFIG_DIR=` の存在だけを見ている。もし以前のコンテナで `export CLAUDE_CONFIG_DIR=/old/path` が追記されていて、今回 `CLAUDE_CONFIG_DIR=/new/path` で起動した場合:

- grep → true → echo しない
- 結果: `~/.profile` に古い値が残り続ける

現状の spirit-room CLI では CLAUDE_CONFIG_DIR 値は kaio モードで常に `/workspace/.claude-home` に固定なので実害はないが、将来の拡張や手動 docker run で異なる値を指定した場合に bug を生む。

**Fix:** 値を含む完全一致で grep するか、既存 line を一度削除してから追記する:

```bash
su - goku -c "
    sed -i '/^export CLAUDE_CONFIG_DIR=/d' ~/.profile 2>/dev/null || true
    echo 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' >> ~/.profile
" || true
```

または値も含めて grep:
```bash
su - goku -c "grep -qxF 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' ~/.profile 2>/dev/null || { sed -i '/^export CLAUDE_CONFIG_DIR=/d' ~/.profile; echo 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' >> ~/.profile; }" || true
```

加えて、`${CLAUDE_CONFIG_DIR}` にシングルクォートが含まれると `echo '...'` のクォートが閉じてしまう (副次的な injection)。現状の値は固定なので実害なしだが、防御的に値側もエスケープ検討。

---

### MEDIUM-03: `claude auth status` が **root コンテキストで走る** ため認証判定が goku 用に機能しない可能性

**File:** `spirit-room/base/entrypoint.sh:72-81`
**Issue:** Phase 5 の全体目標は「goku で claude / opencode が走る」ことだが、認証チェックは依然 entrypoint (root) で実行される:

```bash
if ! claude auth status &>/dev/null 2>&1; then
    echo "未認証: SSH接続後に以下を実行してください"
    ...
fi
```

- root の claude コンフィグは Dockerfile で `/root/.claude` を使う想定だが、`chown -R` で `$HOST_UID:$HOST_GID` に変更されている。root は DAC 上どのファイルも読めるので技術的には動く。
- ただし claude CLI 側が「HOME 内の `.claude/` を読むが、HOME が root/ のまま → 共有ボリューム `/root/.claude` を参照する」という既存ロジックに依存している。goku 化してもここはそのままなので entrypoint レベルの判定は動作する。
- 本質的には goku での `claude auth status` を確認する方が Phase 5 の目標に整合する。ただし goku 認証チェックに変えると su - goku のオーバーヘッドと起動時間のトレードオフが発生する。

現状の実装は **動くが理想的でない**。Phase 5 としては許容範囲だが、次フェーズで修正を検討。

**Fix (次フェーズ候補):**
```bash
if ! su - goku -c "claude auth status" &>/dev/null 2>&1; then
    echo "未認証: ..."
fi
```

---

### MEDIUM-04: `chown -R /workspace` が大規模ツリーでは毎起動 N 秒ブロックしうる

**File:** `spirit-room/base/entrypoint.sh:47`
**Issue:** `chown -R "$HOST_UID:$HOST_GID" /workspace 2>/dev/null || true` は entrypoint が起動するたびに `/workspace` 全体を再帰的に chown する。POC 用途では小規模なため問題ないが、巨大なリポジトリ (node_modules 等) をマウントした場合、起動遅延やディスク I/O が無視できないほど増える可能性。

POC スコープでは許容範囲。パフォーマンス issue は v1 スコープ外のため info 以下に留めるべきだが、**既存ファイルの所有者が既に $HOST_UID:$HOST_GID の場合は skip する最適化**を簡単に入れられる:

**Fix (optional):**
```bash
# /workspace の最上位所有者が既に一致していればスキップ (簡易最適化)
if [ "$(stat -c %u:%g /workspace 2>/dev/null)" != "$HOST_UID:$HOST_GID" ]; then
    chown -R "$HOST_UID:$HOST_GID" /workspace 2>/dev/null || true
    echo "[INFO] /workspace を $HOST_UID:$HOST_GID 所有に再帰 chown"
fi
```

現状は機能的には OK。Medium にしたのは Phase 5 の起動 UX への影響観点。

---

## Low

### LOW-01: `useradd -o` を無条件で使うことで UID 衝突の検出チャンスを失う

**File:** `spirit-room/base/entrypoint.sh:32`
**Issue:** `-o` (non-unique UID 許可) は `_apt` 等のシステムユーザー衝突の保険として入っているが、HIGH-01 で述べたように `ubuntu` (uid=1000) 衝突時に sucess してしまい、後段の name resolution 問題を顕在化させる。

**Fix:** HIGH-01 を修正して `ubuntu` を事前削除する場合、`-o` は不要になる。もし `-o` を残すなら少なくとも衝突時にログを出す:

```bash
if existing=$(getent passwd "$HOST_UID"); then
    echo "[WARN] UID $HOST_UID は既に '${existing%%:*}' が使用中。useradd -o で重複許可で goku を追加"
fi
useradd -m -u "$HOST_UID" -g "$HOST_GID" -s /bin/bash -o goku
```

---

### LOW-02: `cmd_enter` に `sleep 2` の待機がないため、新規 `spirit-room open` 直後の enter がタイミングによって失敗しうる

**File:** `spirit-room/spirit-room:183-202`
**Issue:** `cmd_open` 完了直後にユーザーが `cmd_enter` を叩くと、`entrypoint.sh` がまだ goku 作成→chown→tmux 起動の途中 (特に `su - goku -c 'bash -s'` heredoc 実行中) のことがある。

- sshd は L14 の `service ssh start` 時点で上がっているが、goku ユーザーは L32 の useradd まで作られない → goku SSH login は goku 作成完了後しか成功しない
- さらに tmux セッションが L119 の `su - goku -c "bash -s" << EOF` で作られるまで `tmux attach -t spirit-room` は "session not found" エラー
- `cmd_enter` 側には `sleep` がないので、速いターミナル操作だと fail → ユーザーは再試行すれば成功するが UX が悪い

`cmd_kaio` では `sleep 2` が入っている (L165) が `cmd_open → cmd_enter` シーケンスではユーザー手動なので自然な遅延で隠れる。テスト時や CI 自動化で問題化する。

**Fix (Optional):** `cmd_enter` で ssh 前にポートと tmux セッションの準備を待つリトライループを入れる。または少なくとも `cmd_open` 末尾で `sleep 2` して後続 enter を助ける。

---

### LOW-03: Dockerfile の `root chpasswd` が残っている (Attack Surface)

**File:** `spirit-room/base/Dockerfile:57`
**Issue:** `echo 'root:spiritroom' | chpasswd` は保持されたまま。sshd は `PermitRootLogin no` で禁止されているので外部からの root login はできないが:

- `su root` は docker exec -u goku 経由で `su -` されると通る
- `docker exec -it ROOM bash` (デフォルト root) は設計上の管理用途なのでアクセス権は Docker socket 経由で十分 (パスワード不要)
- `spiritroom` というハードコードされたパスワードは既知 (README 等で公開) → 万一 PermitRootLogin が元に戻る regression があれば悪用されやすい

Phase 5 の目的は root SSH 禁止 (D-06) なので目的自体は達成。ただし root パスワードそのものは Phase 5 のスコープで削除を検討した方が防御的:

**Fix (防御的改善):**
```dockerfile
RUN mkdir /var/run/sshd \
    && passwd -l root \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```

`passwd -l root` で root パスワードをロック。`su - root` が goku からも通らなくなる → goku が必要なら `sudo` (NOPASSWD) 経由で。`docker exec -u root` は依然 root bash を得られる (Docker socket 経由の管理用途は維持)。

PLAN 01 の SUMMARY で「root chpasswd は残す: docker exec 経由の管理用途のため」と書かれているが、docker exec は UID 指定で直接 root shell になれるため chpasswd 自体は不要。PLAN 01 時点で議論済みの判断なので Low 扱い。

---

## Info

### IN-01: `ROOM_NAME` のデフォルト値が空の `/workspace` では空文字になる

**File:** `spirit-room/base/entrypoint.sh:4`
**Issue:** `ROOM_NAME="${ROOM_NAME:-$(basename /workspace)}"` は ROOM_NAME 未指定時に `basename /workspace` = `workspace` を返す → これ自体は問題ないが、`basename /workspace` は常に `workspace` 固定なので fallback がほぼ無意味 (元々の用途: `docker run` で ROOM_NAME 指定されなかった時のラベル)。

既存コードからの挙動なので Phase 5 では修正不要。Info レベル。

---

### IN-02: `su - goku -c` の login shell リセットに依存した `~/.profile` 経由 env 渡しは脆い

**File:** `spirit-room/base/entrypoint.sh:115-117`
**Issue:** 回避策としてうまく機能しているが、`~/.profile` の読み込み順序 (bash/sh の違い、`.bashrc` との相互作用) は goku の login shell が変わると動かなくなる可能性がある。将来 gosu に切り替える場合 (Deferred Idea にあり)、`~/.profile` export は不要になる。

**Fix (次フェーズ検討):** gosu 採用時に一括整理。

---

### IN-03: `cmd_open` 時にフォルダが存在しない場合の挙動

**File:** `spirit-room/spirit-room:52-55`
**Issue:** `folder=$(realpath "$folder")` は存在しないパスでもエラーを返さず (GNU realpath の `-e` なし) 存在しないパスを resolve する可能性。その後の `-v "${folder}:/workspace"` で docker がディレクトリを自動作成する (root 所有) → entrypoint の chown で回復。機能的には動く。

Phase 5 スコープ外。既存動作のまま。

---

## Phase-5 Specific Concerns Summary

| チェック項目 | 結果 |
|---|---|
| 1. Shell injection / escaping (sudoers heredoc, chown, su - goku -c) | **MEDIUM-01 (ROOM_NAME → heredoc injection)** / sudoers 本体は固定文字列なので OK / chown 引数は quote 済みで OK |
| 2. User creation correctness (useradd / groupadd collisions) | **HIGH-01 (ubuntu uid=1000 衝突)** / **HIGH-02 (HOST_UID 変更追従なし)** / useradd 途中失敗は set -e で entrypoint 全体が落ちる → PID 1 が起動しないがコンテナ自体は Exit code 非0で落ちる (検知可能) |
| 3. Chown ordering (D-09 遵守) | OK: HOST_UID → goku 作成 → chown /workspace + auth volumes → kaio symlink → goku git config → tmux as goku → tail -f root の順序が守られている |
| 4. Idempotency (id goku short-circuit, chown idempotent, sudoers overwrite) | OK: `id goku` ガード、chown は毎回走る (冪等)、sudoers は `>` で上書き (冪等) / HOST_UID 変更時の非冪等性は HIGH-02 |
| 5. PID 1 invariant (tail -f /dev/null as root) | OK: L137 `tail -f /dev/null` はヒアドキュメントの外で root 実行 |
| 6. SSH (PermitRootLogin no, goku login) | OK: Dockerfile で `sed -i` 書換え、root chpasswd は残存 (LOW-03 で passwd -l 推奨) |
| 7. CLI bash (HOST_UID/HOST_GID, cmd_enter goku 化) | OK: `$(id -u)` / `$(id -g)` は double quote 内なので安全 (ヘッドレスでも動く) / cmd_enter の ~/.claude 参照は無し (SSH 後は goku HOME になる) |
| 8. Regression risk (auth flow, kaio sync) | OK: cmd_auth は非変更 (entrypoint が毎回 chown で吸収) / kaio sync に chown 追加済み / 既存 volume 破棄は不要 / MEDIUM-03 の claude auth status 実行コンテキストは目標達成的には合格だが厳密には goku context での確認が望ましい |

---

## Recommendations

**マージ前対応推奨 (HIGH):**
- HIGH-01: Dockerfile に `userdel -r ubuntu || true` + `groupdel ubuntu || true` を追加し、Ubuntu 24.04 既存ユーザーとの衝突を根絶する。5 分程度の修正。
- HIGH-02: `id goku` ブロックの else 節に `usermod -u` / `groupmod -g` を入れて HOST_UID 変更時の UID 整合性を自動修復する。10 分程度の修正。

**マージ後の次フェーズで検討 (MEDIUM):**
- MEDIUM-01: `ROOM_NAME` サニタイズ or heredoc を quoted にして env 変数で goku に渡す方式に切り替え。フォルダ名制約を明文化 (英数 + ハイフンのみ等) するのも一案。
- MEDIUM-02: `~/.profile` の `sed -i '/^export CLAUDE_CONFIG_DIR=/d'` で古い値を消してから追記する方式に統一。
- MEDIUM-03: `claude auth status` を `su - goku -c` で実行する形に変更 (次フェーズ / gosu 移行と合わせて)。
- MEDIUM-04: `/workspace` の chown を既存所有者一致時に skip する簡易最適化 (パフォーマンス issue、v1 スコープ外の情報提供として)。

**将来的な改善 (LOW / INFO):**
- LOW-03: `passwd -l root` で Dockerfile 側から root パスワードをロックする (docker exec は影響なし)。
- Phase 全体の実機検証 (Task 2.3 / Task 3.4) がすべて checkpoint skip になっているため、HIGH-01 / HIGH-02 の検証と合わせてユーザー手元で 1 サイクルを完走させる手順を HANDOVER に明記する (Plan 01 SUMMARY の Next Phase Readiness に既に引き継ぎはあるが、HIGH の 2 項目を含める形に更新推奨)。

---

_Reviewed: 2026-04-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
