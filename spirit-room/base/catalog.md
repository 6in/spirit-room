# 利用可能ツールカタログ

あなたはこのカタログに記載されたツールを自由に組み合わせて使うことができる。
タスクの性質に応じて最適なものを自分で選択せよ。

> **注**: ベースイメージにプリインストールされているツールの完全な一覧と利用指針は `/room/CLAUDE.md` を参照せよ。このカタログはエージェントツール（claude / opencode）の使い分けと、追加インストール手順を中心に扱う。

---

## Claude Code (`claude`)
**得意領域**: コード生成・編集・リファクタリング・ファイル操作全般  
**起動**: `claude -p "..."` または対話モード `claude`  
**向いている場面**: コードベース全体を把握しながら実装を進めたい時  
**備考**: 現在の実行環境そのもの

---

## opencode (`opencode`)
**得意領域**: マルチプロバイダー対応、並列処理  
**起動**: `opencode -p "..."`  
**向いている場面**: 複数の実装案を試したい時、別プロバイダーを使いたい時  
**認証**: `opencode auth` で設定

---

## 標準ツール（常時利用可能）
| コマンド | 用途 |
|---|---|
| `python3` | スクリプト実行・テスト |
| `node` / `npm` | JS/TSの実行・パッケージ管理 |
| `git` | バージョン管理 |
| `curl` / `wget` | HTTP通信・API確認 |
| `jq` | JSON処理 |
| `tmux` | セッション管理・並列作業 |

---

## ディレクトリ規約
```
/workspace/     ← 成果物はここに置く（ホストと共有）
/mission/       ← MISSION.md（読み取り専用として扱う）
/catalog/       ← このファイル
/logs/          ← progress.log に進捗を記録すること
```

---

## 追加ツールのインストール
必要であれば以下でインストールできる。インストールしたものはcatalog.mdへの追記を推奨。

```bash
# Node.js パッケージ
npm install -g <package>

# Python パッケージ（Ubuntu 24.04 では --break-system-packages が必要）
pip3 install <package> --break-system-packages

# または venv を使う場合
python3 -m venv /workspace/.venv
source /workspace/.venv/bin/activate
pip install <package>
```
