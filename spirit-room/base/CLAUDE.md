# CLAUDE.md — 精神と時の部屋（修行コンテナ用）

このファイルは修行コンテナ内で動く Claude Code 向けの利用可能ツール一覧と作業規約だ。すべての修行フェーズ（RESEARCH / PREPARE / TRAINING / REPORT）で参照される。

---

## 部屋の構造

| パス | 役割 |
|------|------|
| `/workspace/` | 成果物を置く場所（ホストと共有マウント） |
| `/room/` | 部屋の共有リソース（catalog.md, CLAUDE.md, scripts, 読み取り専用） |
| `/workspace/.logs/progress.log` | 進捗ログ（必ず追記すること） |
| `/workspace/MISSION.md` | 修行課題（読み取り専用扱い） |
| `/workspace/RESEARCH.md` | PHASE 0 で生成する調査レポート |
| `/workspace/.journal.md` | PHASE 2 で追記する作業ジャーナル |
| `/workspace/REPORT.md` | PHASE 3 で生成する振り返りレポート |

---

## 利用可能ツール

### コード/AI エージェント

| コマンド | 用途 |
|---|---|
| `claude` | Claude Code（自分自身） |
| `opencode` | マルチプロバイダー対応 AI コーディングエージェント |

### 検索・ファイル操作

| コマンド | 用途 |
|---|---|
| `rg` (ripgrep) | **高速ファイル内容検索**。`grep -r` の代わりに常用 |
| `fd` | **高速ファイル名検索**。`find` の代わりに常用 |
| `fzf` | 対話的ファジー検索 |
| `bat` | シンタックスハイライト付き `cat` |
| `tree` | ディレクトリツリー表示 |
| `less` | ページャ |

### JSON / YAML

| コマンド | 用途 |
|---|---|
| `jq` | JSON 処理 |
| `yq` | YAML 処理（Go 版、jq 互換構文） |

### HTTP / Web

| コマンド | 用途 |
|---|---|
| `curl` / `wget` | 汎用 HTTP |
| `http` (HTTPie) | 人間に優しい HTTP クライアント。`http GET example.com` |

### Git 周辺

| コマンド | 用途 |
|---|---|
| `git` | バージョン管理 |
| `delta` | 美麗な git diff 表示。`git config core.pager delta` で有効化 |
| `shellcheck` | シェルスクリプトの静的解析 |

### 言語ランタイム / パッケージ管理

| コマンド | 用途 |
|---|---|
| `python3` / `pip3` | Python 3.x（Ubuntu 24.04 では `--break-system-packages` 必須） |
| `python3 -m venv` | 仮想環境 |
| `pipx` | Python ツールを隔離環境にインストール |
| `uv` | **超高速** Python パッケージマネージャー（Astral 社） |
| `node` / `npm` / `npx` | Node.js 20.x |
| `bun` | 高速 JS ランタイム + パッケージマネージャー |

### システム調査

| コマンド | 用途 |
|---|---|
| `htop` | プロセスモニタ |
| `ncdu` | 対話的ディスク使用量 |
| `lsof` | オープンファイル一覧 |
| `dig` / `nslookup` | DNS 問い合わせ |
| `ping` | 疎通確認 |
| `nc` (netcat) | ポート疎通・簡易サーバ |

### アーカイブ

| コマンド | 用途 |
|---|---|
| `unzip` / `zip` | ZIP |
| `xz` / `unxz` | XZ 圧縮 |
| `7z` (p7zip) | 7-Zip |
| `tar` | TAR |

### データベース / キャッシュ

| コマンド | 用途 |
|---|---|
| `sqlite3` | 組み込み RDB |
| `redis-cli` | Redis（コンテナ内で起動済み） |

### セッション管理

| コマンド | 用途 |
|---|---|
| `tmux` | ターミナルマルチプレクサ（部屋起動時に自動起動済み） |

---

## Claude Code スキル（プロジェクトローカル）

部屋起動時に `/workspace/.claude/skills/` に以下のスキルが自動インストールされる:

| スキル | 用途 |
|---|---|
| `find-skills` | 他のスキルを検索・追加インストールするメタスキル |

### スキルを追加するには

タスクに必要そうなスキルが既存スキルにない時、`find-skills` を使って探せ。

```bash
# 対話的に検索
npx -y skills find <キーワード>

# 検索結果から直接インストール（プロジェクトローカル）
cd /workspace
npx -y skills add <owner/repo> --skill <skill-name>

# 例: React パフォーマンス改善スキルを追加
cd /workspace
npx -y skills add vercel-labs/agent-skills --skill vercel-react-best-practices
```

インストールされたスキルは次の Claude Code 起動時から自動的に読み込まれる。

---

## オンデマンドで追加できるもの

ベースイメージを軽く保つため、以下は MISSION で必要になった時にインストールせよ。

### Web UI 確認 / E2E テスト

```bash
# Playwright + Chromium のみ（軽量）
npm install -D playwright @playwright/test
npx playwright install --with-deps chromium

# スクショ取得や UI スモークテストに活用可。REPORT.md に貼れる
```

### Python ツール

```bash
# uv を使うと超高速
uv pip install <package>

# 通常の pip
pip3 install <package> --break-system-packages

# 隔離環境
python3 -m venv /workspace/.venv
source /workspace/.venv/bin/activate
pip install <package>
```

### Node.js / TypeScript

```bash
npm install -g <package>
# または
bun add -g <package>
```

---

## ツール選択の指針

- **検索**: `grep -r` ではなく `rg`、`find` ではなく `fd` を使う（10〜100倍速い）
- **JSON 操作**: パイプで `jq`、複雑なら `python3 -c`
- **HTTP デバッグ**: 単発なら `curl`、対話的に試すなら `http` (HTTPie)
- **ファイル一覧**: ツリー把握なら `tree -L 3`、サイズ把握なら `ncdu`
- **Python 環境**: 速さ重視なら `uv`、CLI ツールなら `pipx`、互換性重視なら従来の pip

---

## 修行作業の規約

1. **進捗ログ**: 重要な操作のたびに `/workspace/.logs/progress.log` に追記
2. **PHASE 2 のジャーナル**: `[TRY] / [STUCK] / [PIVOT] / [AHA] / [DONE]` の5タグで `.journal.md` に追記
3. **git commit**: `/workspace` は git 管理下。Journal エントリと対応させてこまめにコミット
4. **同じ失敗を繰り返さない**: 2回連続で同じアプローチが失敗したら方針を変えよ（[PIVOT] を記録）
5. **詰まったら**: `/room/CLAUDE.md` と `/room/catalog.md` を読み返して別ツールを検討

---

## バージョン情報

- Ubuntu 24.04 LTS
- Node.js 20.x / Bun (latest) / Python 3.x
- ベースイメージ: `spirit-room-base:latest`
