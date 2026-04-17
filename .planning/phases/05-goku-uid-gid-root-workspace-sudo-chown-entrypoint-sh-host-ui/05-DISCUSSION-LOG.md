# Phase 5: goku ユーザー作成 / ホスト UID-GID 一致 — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
**Areas discussed:** 認証ボリュームの移行戦略, SSH ログインユーザー, entrypoint の権限切替タイミング, kaio モード統合, (追加) sudo 粒度, git config, 既存コンテナ移行

---

## 議論対象の選定

| Option | Description | Selected |
|--------|-------------|----------|
| 認証ボリュームの移行戦略 | 既存 spirit-room-auth の root 所有ファイルをどう goku にするか | ✓ |
| SSH ログインユーザー | root / goku / 両方 の選択 | ✓ |
| entrypoint の権限切替タイミング | service 起動は root 必須、どこで goku に渡すか | ✓ |
| kaio モード統合 | CLAUDE_CONFIG_DIR と goku の共存、認証 symlink の所有権 | ✓ |

**User's choice:** 全 4 領域を議論

---

## 認証ボリュームの移行戦略

| Option | Description | Selected |
|--------|-------------|----------|
| entrypoint で毎回 chown -R (推奨) | 冪等で手動操作不要。数百 ms のコスト | ✓ |
| 新ボリューム名に切替 | spirit-room-auth-v2 で新規作成、旧は削除 | |
| spirit-room auth-migrate サブコマンド | 一度きりの移行コマンド追加 | |

**User's choice:** entrypoint で毎回 chown -R
**Notes:** 冪等性と手動操作不要の観点を優先

### chown 対象範囲

| Option | Description | Selected |
|--------|-------------|----------|
| 認証ボリュームのみ (推奨) | /root/.claude, /root/.claude-shared, /root/.config/opencode のみ | |
| /workspace も含める | 過去に root で作られたごみファイルも一度クリーンに | ✓ |
| 認証 vol + /home/goku | 明示的に安全側 | |

**User's choice:** /workspace も含める
**Notes:** 初回起動の遅さより、過去の root 所有ごみの掃除を優先

### HOST_UID/GID fallback

| Option | Description | Selected |
|--------|-------------|----------|
| 1000:1000 fallback (推奨) | Linux デスクトップの典型 UID。手動 run でも動く | ✓ |
| エラーで中断 | CLI 経由を強制 | |
| root 実行に fallback | 従来挙動を保証 | |

**User's choice:** 1000:1000 fallback
**Notes:** 柔軟性を優先。CLI が渡さないケースでも動作する

---

## SSH ログインユーザー

| Option | Description | Selected |
|--------|-------------|----------|
| goku のみ (推奨) | PermitRootLogin no、cmd_enter は ssh goku@localhost | ✓ |
| goku デフォルト + root も残す | --root オプションで root ログインも可能に | |
| root のまま、tmux 内で su - goku | SSH 設定は変えない | |

**User's choice:** goku のみ
**Notes:** シンプルさと Phase 5 の目的 (root 排除) に最も合致

### goku パスワード

| Option | Description | Selected |
|--------|-------------|----------|
| spiritroom (推奨) | root と同じパスワードで統一 | ✓ |
| 別パス (goku123 等) | 区別しやすいがドキュメント更新必要 | |
| パスワードなし | passwd -l goku + docker exec -u goku に切替 (大改修) | |

**User's choice:** spiritroom
**Notes:** 既存運用と統一

---

## entrypoint の権限切替タイミング

| Option | Description | Selected |
|--------|-------------|----------|
| tmux を su - goku -c で起動 (推奨) | service は root、tmux 以降は goku。シンプル | ✓ |
| exec gosu goku tmux | gosu 追加インストール必要 | |
| root のまま tmux、各 window で su | 既存構造に近いが root プロンプトが瞬間的に見える | |

**User's choice:** tmux を su - goku -c で起動

### goku 作成の冪等性

| Option | Description | Selected |
|--------|-------------|----------|
| id goku で存在チェック、なければ作成 (推奨) | 2 回目以降スキップ。HOST_UID 変更は usermod で追随 | ✓ |
| 毎回 useradd -o --force | 二重エラーを呼び込む | |
| 初回のみ作成 (UID 変更無視) | マルチユーザー環境でデバッグが難しい | |

**User's choice:** id goku で存在チェック、なければ作成

---

## kaio モード統合

| Option | Description | Selected |
|--------|-------------|----------|
| symlink も chown -h で goku 化 (推奨) | 実体と symlink 両方を chown。OAuth トークンリフレッシュが動く | ✓ |
| /workspace/.claude-home のみ goku、共有 vol は root | sudo なしで credentials 読めない問題 | |
| kaio だけ root 実行を維持 | Phase 5 の目的を半分達成 | |

**User's choice:** symlink も chown -h で goku 化
**Notes:** OAuth トークンのリフレッシュ動線を保つことを優先

### cmd_kaio のホスト認証同期処理

| Option | Description | Selected |
|--------|-------------|----------|
| chown + chmod に更新 (推奨) | cp && chown $HOST_UID:$HOST_GID && chmod 600 | ✓ |
| entrypoint 内で chown (簡易) | CLI は触らず、起動時の chown に任せる | |
| そのまま残す (root 所有のまま) | 実害出るか未検証 | |

**User's choice:** chown + chmod に更新
**Notes:** CLI と entrypoint の両方で所有権をきちんと揃える

---

## 追加論点

### goku の sudo 設定糒度

| Option | Description | Selected |
|--------|-------------|----------|
| NOPASSWD:ALL (推奨) | 修行コンテナ用途で粒度は絞らない | ✓ |
| apt/service/dpkg 等主要コマンドのみ | Cmnd_Alias で絞る | |

**User's choice:** NOPASSWD:ALL
**Notes:** todo 内の方針と整合。POC コンテナでは緊張度低い

### git config の goku HOME への設定

| Option | Description | Selected |
|--------|-------------|----------|
| entrypoint で goku として git config --global 再実行 (推奨) | su - goku -c で git config --global を流す | ✓ |
| /home/goku/.gitconfig を heredoc でファイル直接作成 | 静的でタイポ検出不可 | |
| Dockerfile で COPY .gitconfig /home/goku/ | goku はランタイム作成なので COPY 不可 | |

**User's choice:** entrypoint で goku として git config --global 再実行

### 既存コンテナの移行

| Option | Description | Selected |
|--------|-------------|----------|
| close → open 必須 (推奨) | リリースノートで案内 | ✓ |
| docker exec -u goku で後付け動作 | 用途限定 | |
| 透過: 何もしない | 次回 open まで放置 | |

**User's choice:** close → open 必須
**Notes:** Dockerfile 変更を伴うので image rebuild + 再 open は自然

---

## Claude's Discretion

- gosu vs su の最終選択 (基本線は su、PATH/env 問題が発覚したら gosu に切替可)
- UID 衝突回避 (useradd -o / 既存ユーザー退避) の具体手順
- start-training.sh の goku 実行時に export 等で env を継承する細部

## Deferred Ideas

- gosu への置換 (将来必要時)
- 複数ホストユーザーの切替サポート
- Windows / macOS ホスト対応
- root ログイン復活オプション (--root)
- sudoers 粒度の絞り込み
- 実行中コンテナのホットマイグレーション
- MISSION.md.template / KAIO-MISSION.md.template への注記追加
