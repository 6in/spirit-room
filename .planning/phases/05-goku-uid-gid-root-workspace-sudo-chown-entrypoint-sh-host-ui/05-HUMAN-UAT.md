---
status: resolved
phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
source: [05-VERIFICATION.md]
started: 2026-04-17T14:00:00Z
updated: 2026-04-18T01:10:00Z
---

## Current Test

[all tests completed]

## Tests

### 1. 界王星 (kaio) モード E2E 検証
expected: `spirit-room kaio` の docker run --rm 認証同期 (chown 込み) + 本体起動 (entrypoint の kaio 分岐で chown -h が走る) + cmd_enter (goku SSH) がすべて成功。credentials symlink が goku 所有で、実体も goku 所有。
result: passed (2026-04-17) — GSD autonomous チェーンが goku コンテキストで完走し KAIO v1.0 を ship、35/35 tests passing、/workspace/.kaio-done が作成された。credentials symlink + auth status は goku で機能 (完走した事実で実証)。副次: start-training-kaio.sh PHASE 3 の /create-report skill 不足を検出 → 別 todo `2026-04-18-kaio-create-report-skill-missing` に記録 (Phase 5 非回帰)

**Test procedure:**
```bash
# 前提: spirit-room auth を先に実行して ~/.claude/.credentials.json が存在
mkdir -p /tmp/spirit-room-phase5-kaio
./spirit-room/spirit-room kaio /tmp/spirit-room-phase5-kaio
# 自動で cmd_enter 経由で tmux attach される。tmux 内で:
whoami                                              # 期待: goku
sudo whoami                                         # 期待: root
ls -la /workspace/.claude-home/.credentials.json    # 期待: lrwxrwxrwx ... goku goku ... -> /root/.claude-shared/.credentials.json
ls -la /root/.claude-shared/.credentials.json       # 期待: goku:goku 所有
```

### 2. start-training ループが goku 完走するか (NON_REGRESSION-LOOP-01 live)
expected: LOOP-01/02/03/04 の PHASE1→PHASE2 サイクルが goku コンテキストで完走、git commit も goku の user.email/name で残る。/workspace 成果物が goku:goku 所有でホスト側から sudo なしで扱える。
result: passed (2026-04-18) — RESEARCH → PREPARE → TRAINING が完走、修行終了後にホスト側で /workspace 成果物を現在ユーザー権限で直接確認できた (sudo chown 不要)。Phase 5 core goal 達成。途中で "Not logged in" ループに陥る問題を検出し、goku HOME → /root/.claude への symlink fix (commit 9875d56) で解消済み

**Test procedure:**
```bash
mkdir -p /tmp/spirit-room-phase5-loop
cat > /tmp/spirit-room-phase5-loop/MISSION.md <<'EOF'
# POC: goku smoke
## 目的
touch /workspace/phase5-goku-smoke を実行して .done を作る
## 完了条件
- /workspace/phase5-goku-smoke が存在
- /workspace/.done が存在
EOF
./spirit-room/spirit-room open /tmp/spirit-room-phase5-loop
./spirit-room/spirit-room enter /tmp/spirit-room-phase5-loop
# tmux 内で start-training 完走を待つ。終了後:
cd /workspace && git log --format='%an <%ae>' | head -3
# 期待: 'Spirit Room <spirit-room@localhost>' が author
ls -la /workspace/.done /workspace/phase5-goku-smoke
# 期待: 両方 goku:goku 所有
```

### 3. HOST_UID 変更時の自動修復 (HIGH-02 fix 挙動)
expected: 既存コンテナを別 HOST_UID で restart したとき、goku の UID/GID が自動的に再マップされ、/workspace/auth volumes が新 UID で chown される。
result: skipped (観察のみ項目、Gate ではない) — コードレビュー fix (commit ec6f27b) で usermod/groupmod による再割当ロジックを追加済み。entrypoint.sh 内静的検証済み。live 実行は今回の通常ユーザー環境 (UID=1000 のみ) では再現困難のため後日 /gsd-verify-work で検証

**Test procedure:**
```bash
# 通常ユーザー (UID=1000) でコンテナ起動
./spirit-room/spirit-room open /tmp/spirit-room-phase5-uid
docker exec spirit-room-spirit-room-phase5-uid id goku
# 期待: uid=1000(goku) gid=1000(goku)

# 一度 stop してから HOST_UID=1234 で再起動 (docker start では env 再注入されないので、
# docker rm してから docker run が現実的。D-20 は close → re-open を推奨)
# 代替シナリオ: 別 HOST_UID ホストから volume を引き継いだ場合を想定
docker stop spirit-room-spirit-room-phase5-uid
docker rm spirit-room-spirit-room-phase5-uid
HOST_UID=1234 HOST_GID=1234 docker run -d --name phase5-uid-test \
  -e HOST_UID=1234 -e HOST_GID=1234 -e ROOM_NAME=phase5-uid-test \
  -v /tmp/spirit-room-phase5-uid:/workspace -v spirit-room-auth:/root/.claude \
  spirit-room-base:latest
sleep 3
docker exec phase5-uid-test id goku
# 期待: uid=1234(goku) gid=1234(goku)
docker exec phase5-uid-test ls -ld /workspace
# 期待: 1234:1234 所有

docker rm -f phase5-uid-test
```

### 4. spirit-room open → enter 連続操作 UX (LOW-02, 情報観察のみ)
expected: `spirit-room open` 直後に `spirit-room enter` すると、警告なく goku@localhost に SSH 接続でき tmux attach される。
result: passed (2026-04-18) — UAT #2 実行時に open → enter を連続実行、tmux に goku でアタッチ成功 (start-training が goku コンテキストで起動して完走したことで間接確認)

## Summary

total: 4
passed: 3
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

- gap-01: start-training が "Not logged in" でループする (goku HOME から /root/.claude に届かない)
  severity: high
  status: resolved
  resolution: commit 9875d56 で goku HOME → /root/{.claude, .claude.json, .config/opencode} への symlink + chmod o+x /root を entrypoint.sh に追加。通常モード UAT #2 で再検証済み、kaio モード UAT #1 でも GSD chain 完走により間接確認済み。

- gap-02: kaio モード PHASE 3 の /create-report skill 不足
  severity: medium
  status: deferred
  note: Phase 5 の回帰ではない既存問題。別 todo `2026-04-18-kaio-create-report-skill-missing` に登録済み。REPORT.md 自体はフォールバック生成されるためワークフローはブロックされない。
