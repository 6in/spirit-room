---
phase: 06-spirit-room-docker-docker-compose
plan: "01"
subsystem: Dockerfile
tags: [docker-cli, compose-plugin, DooD, dockerfile-layer]
dependency_graph:
  requires: []
  provides: [docker-cli-in-image, compose-plugin]
  affects: [spirit-room/base/Dockerfile]
tech_stack:
  added: ["docker CLI (docker-ce-cli via get.docker.com)", "docker-compose-plugin"]
  patterns: ["curl | sh インストール (既存 nodesource/bun と同方式)"]
key_files:
  created: []
  modified:
    - spirit-room/base/Dockerfile
decisions:
  - "D-01: docker CLI を spirit-room-base:latest に常時同梱 (別イメージ分離なし)"
  - "D-02: get.docker.com | sh でインストール (シンプル & compose plugin 同梱)"
  - "D-03: レイヤー5 (opencode) 直後・SSH設定前に挿入 (後続キャッシュ維持)"
metrics:
  duration: "3 分"
  completed_date: "2026-04-18"
  tasks_completed: 1
  files_modified: 1
---

# Phase 06 Plan 01: Dockerfile に docker CLI レイヤーを追加 — Summary

**One-liner:** get.docker.com 経由で docker CLI + compose plugin をレイヤー5.5 として常時同梱し、DooD (--docker フラグ) 対応の基盤を Dockerfile に追加した。

## 完了タスク

| # | タスク名 | コミット | 変更ファイル |
|---|---------|---------|------------|
| 1 | Dockerfile にレイヤー5.5 (docker CLI + compose plugin) を追加 | 3bce03d | spirit-room/base/Dockerfile |

## 実装内容

`spirit-room/base/Dockerfile` の `# ── レイヤー5: opencode ──` ブロック直後、`# ── SSH設定 ──` ブロック直前に以下の新規レイヤーを挿入した:

```dockerfile
# ── レイヤー5.5: Docker CLI (compose plugin 込み) ─────────────
# dockerd は起動しない。CLI と compose plugin だけ使う (DooD 用)。
# --docker フラグ未使用時も常時同梱 (実害: CLI があるだけ。+~100MB)
RUN curl -fsSL https://get.docker.com | sh \
    && docker --version
```

## Acceptance Criteria 確認

| 条件 | 結果 |
|-----|------|
| `grep -c 'get\.docker\.com'` が 1 | OK (1 件) |
| `grep -c 'docker --version'` が 1 | OK (1 件) |
| `grep -n 'レイヤー5.5'` がヒットする | OK (line 53) |
| opencode → レイヤー5.5 → SSH設定 の順序 | OK (lines 50→53→59) |
| `groupadd docker` が Dockerfile にない | OK |
| `DOCKER_HOST` が Dockerfile にない | OK |
| `# ── SSH設定 ──` コメント行が消えていない | OK (line 59) |

## ビルド確認 (Wave 3 担当)

`docker build` は Plan 06-05 (E2E wave) で実施する。以下は Wave 3 で確認予定:
- `docker run --rm spirit-room-base:latest docker --version` で CLI 応答
- `docker run --rm spirit-room-base:latest docker compose version` で compose plugin 応答

## Deviations from Plan

なし — プランの指示通りに実行した。

## Threat Flags

なし — 新規ネットワークエンドポイントや認証パスの追加なし。get.docker.com への curl は既存の nodesource/bun と同等のリスクで、脅威モデル (T-06-01-01) に既記録。

## Self-Check: PASSED

- [x] `spirit-room/base/Dockerfile` が存在し get.docker.com が含まれる
- [x] コミット 3bce03d が存在する
- [x] 意図しないファイル削除なし
