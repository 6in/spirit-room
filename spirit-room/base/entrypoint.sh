#!/bin/bash
set -e

ROOM_NAME="${ROOM_NAME:-$(basename /workspace)}"
# MEDIUM-01 対応: ROOM_NAME は後段で tmux heredoc 経由の bash 再解釈に流れるため、
# シェルメタ文字を英数ハイフンアンダースコアに正規化する。
# 例: "test';touch /tmp/x;#" → "test__touch__tmp_x__"
ROOM_NAME="${ROOM_NAME//[^a-zA-Z0-9_-]/_}"

echo "
╔══════════════════════════════════════════════╗
║         精神と時の部屋 - Spirit Room         ║
║  部屋: $ROOM_NAME
╚══════════════════════════════════════════════╝
"

# ── サービス起動 ─────────────────────────────────────────────
service ssh start
service redis-server start
echo "[INFO] Redis起動完了"

# ── HOST_UID/GID 受け取り (fallback: 1000:1000) ─────────────
# 手動 docker run や CI 経由で HOST_UID/GID が渡されない場合も落ちないようにする。
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
echo "[INFO] HOST_UID/GID=${HOST_UID}:${HOST_GID}"

# ── goku ユーザーの冪等作成 ─────────────────────────────────
# D-01: ビルド時ではなくランタイムで作る (HOST_UID がホストごとに異なるため)
# D-02: 冪等。既に goku が居れば skip。GID も既存 group がなければ作る
# D-04: パスワードは root と同じ spiritroom
# D-05: NOPASSWD:ALL の sudo を付与 (POC 用途のため粒度は絞らない)
# useradd の -o は UID 重複許可 (既存ユーザー _apt 等と HOST_UID が衝突した場合の保険)
# HIGH-02 対応: 既に goku が居てもその UID/GID が HOST_UID/GID と一致するか確認し、
# 不一致 (別ホストでボリュームを使い回し、HOST_UID が変わった docker restart 等) なら
# usermod/groupmod で再割り当てする。原則 D-20 で「close → re-open」が推奨だが、
# docker start/restart を手動実行したケースの安全策として自動修復する。
if ! id goku &>/dev/null; then
    getent group "$HOST_GID" >/dev/null || groupadd -g "$HOST_GID" goku
    useradd -m -u "$HOST_UID" -g "$HOST_GID" -s /bin/bash -o goku
    echo 'goku:spiritroom' | chpasswd
    echo 'goku ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/goku
    # D-14: 胡蝶の夢モード (--kochou) env を sudo で preserve する (sudo docker compose で
    # COMPOSE_PROJECT_NAME が剥がれると spirit-room close の兄弟掃除が効かなくなるため)
    echo 'Defaults env_keep += "COMPOSE_PROJECT_NAME SPIRIT_ROOM_KOCHOU HOST_WORKSPACE SPIRIT_ROOM_HOST_GATEWAY HOST_DOCKER_GID TZ"' >> /etc/sudoers.d/goku
    chmod 0440 /etc/sudoers.d/goku
    echo "[INFO] goku ユーザーを作成 (UID=$HOST_UID GID=$HOST_GID)"
else
    # トップレベル実行のため local は使えない (bash 関数内専用)。通常変数で受ける。
    current_uid=$(id -u goku)
    current_gid=$(id -g goku)
    if [ "$current_uid" != "$HOST_UID" ] || [ "$current_gid" != "$HOST_GID" ]; then
        echo "[WARN] 既存 goku UID/GID=${current_uid}:${current_gid} が HOST_UID/GID=${HOST_UID}:${HOST_GID} と不一致。再割り当てします (運用上は 'spirit-room close' → 'open' 推奨)"
        # GID: 既存グループが無ければ作る。既に HOST_GID が別名で存在する場合は groupmod を試みる (失敗は無視)
        getent group "$HOST_GID" >/dev/null || groupadd -g "$HOST_GID" goku 2>/dev/null || true
        groupmod -g "$HOST_GID" goku 2>/dev/null || true
        # UID: -o で重複許可して再割り当て (HOST_UID が既に別ユーザーに使われていても許可する保険)
        usermod -u "$HOST_UID" -g "$HOST_GID" -o goku 2>/dev/null || true
        echo "[INFO] goku を UID=${HOST_UID} GID=${HOST_GID} に再割り当て完了。続く chown で所有権を再同期します"
    else
        echo "[INFO] goku ユーザーは既に存在 (UID/GID 一致 / skip)"
    fi
fi

# ── docker グループ合流 (胡蝶の夢モード / --kochou のみ) ─────
# D-04〜D-08: SPIRIT_ROOM_KOCHOU=1 時に HOST_DOCKER_GID に対応する
# グループに goku を追加し、docker.sock を sudo なしで触れるようにする。
# goku 冪等作成ブロックの直後に実行すること (usermod の前に goku が必要)。
if [ "${SPIRIT_ROOM_KOCHOU:-}" = "1" ]; then
    if [ -n "${HOST_DOCKER_GID:-}" ]; then
        # 既存グループ優先: GID が既にどこかのグループに使われている場合はその名前を使う
        # (D-07: 名前衝突を避けるため getent で既存グループを先に探し、なければ新規作成する)
        _dgrp_name=$(getent group "$HOST_DOCKER_GID" 2>/dev/null | cut -d: -f1 || true)
        if [ -z "$_dgrp_name" ]; then
            # 既存グループがない → docker という名前で新規作成
            if groupadd -g "$HOST_DOCKER_GID" docker 2>/dev/null; then
                _dgrp_name=docker
            else
                echo "[WARN] docker グループ (gid=$HOST_DOCKER_GID) の作成に失敗 — sudo docker を使用せよ"
            fi
        fi
        if [ -n "$_dgrp_name" ]; then
            usermod -aG "$_dgrp_name" goku 2>/dev/null || true
            echo "[INFO] docker grp: goku ∈ ${_dgrp_name}(gid=${HOST_DOCKER_GID})"
        else
            echo "[INFO] docker grp: 合流失敗 — sudo docker を使用せよ (Phase 5 NOPASSWD 前提)"
        fi
    else
        # HOST_DOCKER_GID が空 = stat が失敗した環境 (Mac 等) または --kochou 未指定時の誤起動
        echo "[INFO] docker grp: HOST_DOCKER_GID 未取得 — sudo docker を使用せよ"
    fi
fi

# ── 認証ボリュームと /workspace を goku 所有に ───────────────
# D-10/D-11: 起動ごとに chown を走らせ、既存の root 所有ファイルを一度で正常化する
# 対象: 認証ボリュームのマウント先 (通常モード: /root/.claude、kaio モード: /root/.claude-shared、opencode: /root/.config/opencode) および /workspace 本体
chown -R "$HOST_UID:$HOST_GID" /root/.claude 2>/dev/null || true
chown -R "$HOST_UID:$HOST_GID" /root/.config/opencode 2>/dev/null || true
[ -d /root/.claude-shared ] && chown -R "$HOST_UID:$HOST_GID" /root/.claude-shared 2>/dev/null || true
chown -R "$HOST_UID:$HOST_GID" /workspace 2>/dev/null || true
echo "[INFO] /workspace と認証ボリュームを $HOST_UID:$HOST_GID 所有に切替"

# ── goku HOME から認証ボリューム実体 (/root/*) への symlink ──
# docker run の -v マウント先は /root/.claude 等に固定されているため、goku で claude CLI
# を起動すると $HOME=/home/goku 配下を探しに行き credentials を見失う。goku HOME に
# symlink を張って両経路からアクセス可能にする (通常モード専用。kaio モードは下の
# CLAUDE_CONFIG_DIR 分岐で /workspace/.claude-home 経由の別ルートを取る)。
# /root は既定 drwx------ なので、listing は許さず traverse のみ許可する +x を付与する
# (symlink 先の実ファイル読取には +x が必要。中身の一覧禁止は +r を付けないことで維持)
chmod o+x /root 2>/dev/null || true
if [ -d /home/goku ]; then
    [ -d /root/.claude ] && [ ! -e /home/goku/.claude ] && \
        ln -s /root/.claude /home/goku/.claude && \
        chown -h "$HOST_UID:$HOST_GID" /home/goku/.claude
    [ -e /root/.claude.json ] && [ ! -e /home/goku/.claude.json ] && \
        ln -s /root/.claude.json /home/goku/.claude.json && \
        chown -h "$HOST_UID:$HOST_GID" /home/goku/.claude.json
    if [ -d /root/.config/opencode ]; then
        mkdir -p /home/goku/.config
        chown "$HOST_UID:$HOST_GID" /home/goku/.config 2>/dev/null || true
        [ ! -e /home/goku/.config/opencode ] && \
            ln -s /root/.config/opencode /home/goku/.config/opencode && \
            chown -h "$HOST_UID:$HOST_GID" /home/goku/.config/opencode
    fi
    echo "[INFO] goku HOME から認証ボリュームへの symlink を確認"
fi

# ── 界王星モード: CLAUDE_CONFIG_DIR 分岐 ─────────────────────
# CLAUDE_CONFIG_DIR が設定されている = 界王星モード。
# 共有認証ボリュームは /root/.claude-shared にマウントされている前提 (spirit-room kaio 側で -v 指定)。
# その中の .credentials.json を $CLAUDE_CONFIG_DIR/.credentials.json に symlink することで、
# トークンリフレッシュが共有ボリュームに戻り、他の部屋にも伝播する。
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    echo "[INFO] 界王星モード: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"
    # D-13: CLAUDE_CONFIG_DIR 自身も goku 所有にする (/workspace 下なので整合)
    chown "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR" 2>/dev/null || true

    if [ -f /root/.claude-shared/.credentials.json ]; then
        ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
        # D-14: symlink 自体の所有者を goku に (chown -h)。実体ファイルは上の chown -R /root/.claude-shared で既に goku 所有
        chown -h "$HOST_UID:$HOST_GID" "$CLAUDE_CONFIG_DIR/.credentials.json" 2>/dev/null || true
        echo "[INFO] 認証情報を symlink: $CLAUDE_CONFIG_DIR/.credentials.json → /root/.claude-shared/.credentials.json (goku 所有)"
    else
        echo "[WARN] /root/.claude-shared/.credentials.json が見つからない。spirit-room auth を実行せよ"
    fi
fi

# ── 認証チェック ─────────────────────────────────────────────
# MEDIUM-03 対応: Phase 5 の目的は「goku で claude が走る」ことなので、auth status も
# goku コンテキストで確認する。kaio モードの CLAUDE_CONFIG_DIR は環境変数として明示的に
# 引き継がないと login shell でリセットされるため、su -c の先頭で一時的に付与する。
_auth_env=""
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    # 値は上流 (docker run -e) 由来なので Phase 5 では信頼済み。将来拡張でユーザー入力を混ぜる場合は %q 検討
    _auth_env="CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR} "
fi
if ! su - goku -c "${_auth_env}claude auth status" &>/dev/null 2>&1; then
    echo "
╔══════════════════════════════════════════════╗
║  未認証: SSH接続後に以下を実行してください   ║
║  $ claude auth login                         ║
╚══════════════════════════════════════════════╝
"
else
    echo "[INFO] Claude Code 認証済み (goku context)"
fi

# ── catalog.mdの優先順位: /workspace > /room ─────────────────
if [ -f /workspace/catalog.md ]; then
    echo "[INFO] catalog.md: /workspace/catalog.md を使用"
else
    echo "[INFO] catalog.md: デフォルト(/room/catalog.md)を使用"
fi

# ── goku として git config (goku HOME に root 側と同じ設定をミラー) ─
# D-12: Dockerfile L58-64 の root 用 git config はそのまま。goku HOME 側にも
# safe.directory='*' / user.email / user.name / init.defaultBranch を設定し、
# start-training.sh が goku で走っても dubious ownership エラーを出さないようにする。
su - goku -c "git config --global --add safe.directory '*' && \
    git config --global user.email 'spirit-room@localhost' && \
    git config --global user.name 'Spirit Room' && \
    git config --global init.defaultBranch main" || echo "[WARN] goku 用 git config 設定に失敗"

# ── tmuxセッション (goku として起動) ─────────────────────────
# D-08/D-09 ⑤: tmux は goku として起動。CLAUDE_CONFIG_DIR など環境変数は親 shell で展開して埋め込む
# (su - は login shell のため env が goku デフォルトにリセットされる)
# Pattern B3 L146: bash ではなく bash -s を使う (stdin script を明示的に指示)
SESSION="spirit-room"

# 分岐判定は親 shell (root) 側でフラグ化し、ヒアドキュメント内で展開する
# MEDIUM-01 対応: `_TRAINING_CMD` は後段の unquoted heredoc で親展開され、goku の bash に
# 再解釈される (tmux send-keys の第二引数)。値に '/$/` が含まれると injection 経路が成立するので、
# printf -v '%q' で bash 解釈安全な形に事前エスケープする。デフォルトメッセージの `[${ROOM_NAME}]`
# も同様にエスケープ済み文字列を組み立てる。
_default_msg="部屋[${ROOM_NAME}] 準備完了 | start-training(-kaio) で修行開始 | status で確認"
printf -v _default_msg_q '%q' "$_default_msg"
_TRAINING_CMD="echo $_default_msg_q"
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f /workspace/KAIO-MISSION.md ] && [ ! -f /workspace/.kaio-done ]; then
    _TRAINING_CMD="start-training-kaio"
elif [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    _TRAINING_CMD="start-training"
fi

# kaio モード時は CLAUDE_CONFIG_DIR を goku セッション内でも使えるよう ~/.profile 経由で export
# (su - goku が login shell なので .profile が読まれる。冪等化のため重複追加を避ける)
# MEDIUM-02 対応: 固定 prefix grep だと過去起動で別の値が書き込まれていても検出できず古い値が残る。
# 既存の `export CLAUDE_CONFIG_DIR=` 行を一度削除してから最新値を追記する方式で、
# 値が異なるケースも確実に追従させる。
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    su - goku -c "
        touch ~/.profile
        sed -i '/^export CLAUDE_CONFIG_DIR=/d' ~/.profile 2>/dev/null || true
        echo 'export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR}' >> ~/.profile
    " || true
fi

# TZ を goku login shell にも確実に伝える (Dockerfile ENV + /etc/environment で十分なはずだが、
# docker run -e TZ=... で上書きされた場合に PAM 経路より先に .profile で固めておく)
su - goku -c "
    touch ~/.profile
    sed -i '/^export TZ=/d' ~/.profile 2>/dev/null || true
    echo 'export TZ=${TZ:-Asia/Tokyo}' >> ~/.profile
" || true

# D-12: 胡蝶の夢モード (--kochou) env を goku login shell に引き継ぐ (tmux / SSH ログイン後も利用可能にする)
# catalog.md 側で [ "$SPIRIT_ROOM_KOCHOU" = "1" ] 等で分岐するため必須
if [ "${SPIRIT_ROOM_KOCHOU:-}" = "1" ]; then
    su - goku -c "
        touch ~/.profile
        sed -i '/^export SPIRIT_ROOM_KOCHOU=/d' ~/.profile 2>/dev/null || true
        sed -i '/^export HOST_WORKSPACE=/d' ~/.profile 2>/dev/null || true
        sed -i '/^export SPIRIT_ROOM_HOST_GATEWAY=/d' ~/.profile 2>/dev/null || true
        sed -i '/^export COMPOSE_PROJECT_NAME=/d' ~/.profile 2>/dev/null || true
        echo 'export SPIRIT_ROOM_KOCHOU=1' >> ~/.profile
        echo 'export HOST_WORKSPACE=${HOST_WORKSPACE}' >> ~/.profile
        echo 'export SPIRIT_ROOM_HOST_GATEWAY=${SPIRIT_ROOM_HOST_GATEWAY:-host.docker.internal}' >> ~/.profile
        echo 'export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}' >> ~/.profile
    " || true
fi

# MEDIUM-01 対応: _TRAINING_CMD は printf %q でエスケープ済みの bash 用 1-word 表記なので、
# heredoc 内で tmux send-keys の第二引数としてそのまま展開 (double-quote で追加包装しない)。
# 他の tmux send-keys 第二引数 (ログ tail / workspace watch) は固定文字列のため従来通り double-quote で OK。
su - goku -c "bash -s" << EOF
    set -e
    tmux new-session -d -s "${SESSION}" -x 220 -y 50
    tmux rename-window -t "${SESSION}:0" "training"
    tmux send-keys -t "${SESSION}:training" ${_TRAINING_CMD} C-m

    tmux new-window -t "${SESSION}" -n "logs"
    tmux send-keys -t "${SESSION}:logs" "tail -f /workspace/.logs/progress.log 2>/dev/null || (echo 'ログ待機中...'; while true; do sleep 2; tail -f /workspace/.logs/progress.log 2>/dev/null && break; done)" C-m

    tmux new-window -t "${SESSION}" -n "workspace"
    tmux send-keys -t "${SESSION}:workspace" "watch -n 2 'tree /workspace -L 3 -I .logs 2>/dev/null || ls -la /workspace'" C-m

    tmux select-window -t "${SESSION}:training"
EOF

echo "[INFO] tmux '$SESSION' 起動完了 (user=goku)"
echo "[INFO] 接続: tmux attach -t $SESSION (goku で接続すること)"

tail -f /dev/null
