# Testing Patterns

**Analysis Date:** 2026-04-13

## Testing Strategy

This is a **Docker infrastructure project with no traditional unit testing framework**. Testing is **behavioral and integration-based**, performed through:

1. **Flag-based completion checks** - Container code validates success by creating marker files (`.prepared`, `.done`)
2. **Exit code validation** - Shell scripts rely on `set -e` and bash exit codes
3. **Manual/integration testing** - User-run shell commands must complete successfully
4. **Log-based verification** - Progress validation via `progress.log` inspection

## Test Framework

**No test runner installed:**
- No Jest, Vitest, Mocha, pytest, or similar
- No test discovery mechanism
- No coverage reporting tools

**Validation mechanism:**
- Bash `set -e` ensures script stops on first error
- Marker file existence (`-f` checks) for state validation
- Docker command exit codes for container operations
- Manual `status` command for inspection (see `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/status.sh`)

## Behavioral Test Pattern: Flag-Based Completion

The core testing pattern is **idempotent marker files** in `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`:

```bash
# PHASE 1: PREPARE
while true; do
    [ -f "$PREPARED_FLAG" ] && { log "PREPARE済み、スキップ"; break; }

    log "PREPARE開始 (engine: $ENGINE)"
    run_claude "$(cat $CATALOG_FILE)
---
$(cat $MISSION_FILE)

---
## あなたのタスク（PREPARE フェーズ）
MISSION.mdを読み、POCの実装に必要なパッケージ・ツールをすべてインストールせよ。
インストールが完了したら /workspace/.prepared ファイルを作成して終了せよ。"

    [ -f "$PREPARED_FLAG" ] && { log "PREPARE完了"; break; }
    log "PREPARE未完了、リトライ..."
    sleep 3
done
```

**Pattern:**
1. **Check first** (line 38): If completion marker exists, skip phase
2. **Run task** (lines 40-49): Invoke Claude with instructions
3. **Verify completion** (line 51): Check if marker was created
4. **Retry on failure** (lines 52-54): Wait 3 seconds, loop back
5. **Move to next phase** when marker exists (break at line 51)

**Why this works:**
- **Idempotent**: Safe to restart container without re-running completed work
- **Self-verifying**: Claude must create `/workspace/.prepared` or `/workspace/.done` to proceed
- **Resume-safe**: If Claude crashes mid-phase, loop retries automatically
- **Observable**: Markers live in shared `/workspace/` (visible from host)

## Test Invocation Pattern

**From within container:**
```bash
start-training              # Run both PREPARE and TRAINING phases with Claude
start-training opencode     # Same but with opencode engine
```

Located at: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`

**From host machine:**
```bash
spirit-room logs ~/projects/langgraph-poc  # Tail progress.log
spirit-room enter ~/projects/langgraph-poc # SSH + tmux attach for interactive debugging
```

Located at: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (CLI)

## Completion Criteria Pattern

User-facing test criteria are written in `MISSION.md` (template at `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/MISSION.md.template`):

```markdown
## 完了条件（これを全て満たすまで繰り返せ）

- [ ] `cd /workspace && python3 test_exit.py` が exit code 0 で終了する
- [ ] `/workspace/README.md` に以下が書かれている
  - 実装の概要
  - 学んだこと・ハマったこと
  - 応用可能なユースケース
```

**Pattern observations:**
- Concrete command execution, not abstract requirements
- File existence/content checks
- Exit code validation (line 18: `exit code 0 で終了する`)
- Repeatable: Same commands must consistently pass

**Agent-facing test instructions** (in `start-training.sh` lines 70-78):

```bash
## あなたのタスク（TRAINING フェーズ）
MISSION.mdの完了条件をすべて満たすまで実装・テストを繰り返せ。

## 繰り返しのルール
1. テストが失敗したらエラーを読んで原因を特定し修正せよ
2. 同じアプローチで2回連続失敗したら別の方法を試みよ
3. 詰まったら /catalog/catalog.md を読んで別ツールを検討せよ
4. 進捗は /workspace/.logs/progress.log に随時記録せよ
```

This guides Claude (the AI agent) through the test-driven development loop.

## Log-Based Verification

**Progress inspection:**

File: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/status.sh`

```bash
echo ""
echo "── 最新ログ (20行) ──────────────────────────"
tail -20 /workspace/.logs/progress.log 2>/dev/null || echo "ログなし"
```

**Log format** (from `start-training.sh` line 22):
```bash
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
```

**Log entries:**
- `[2026-04-13 10:28:15] === PHASE 1: PREPARE ===`
- `[2026-04-13 10:28:15] PREPARE開始 (engine: claude)`
- `[2026-04-13 10:28:45] PREPARE完了`
- `[2026-04-13 10:29:00] === PHASE 2: TRAINING ===`

**Verification approach:**
- Read logs to verify phase transitions
- Look for timestamps to check progress
- Check for error messages (none in logs means success)

## Integration Test Structure

**End-to-end test sequence:**

1. **Host preparation** (in `spirit-room` CLI):
   ```bash
   spirit-room open ~/projects/langgraph-poc
   ```
   - Creates Docker container
   - Mounts project folder at `/workspace`
   - Maps SSH port
   - Starts services (SSH, Redis, tmux)

2. **Container startup** (in `entrypoint.sh`):
   ```bash
   service ssh start
   service redis-server start
   echo "[INFO] tmux '$SESSION' 起動完了"
   ```
   - Validates authentication (`claude auth status`)
   - Loads catalog (project or default)
   - Starts tmux with 3 panes (training, logs, workspace)

3. **Phase 1: PREPARE** (agent-executed):
   - Install dependencies
   - Create `/workspace/.prepared` marker
   - Loop retries if marker not created

4. **Phase 2: TRAINING** (agent-executed):
   - Implement per MISSION.md requirements
   - Run tests repeatedly until passing
   - Create `/workspace/.done` marker
   - Loop retries if marker not created

5. **Host verification**:
   ```bash
   tail -f /workspace/.logs/progress.log
   cat /workspace/README.md
   ls /workspace/.done  # Should exist
   ```

## Error Handling in Tests

**Script-level error handling:**

From `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`:

```bash
set -e  # Exit immediately on error

if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "[ERROR] 部屋 '$name' は起動していません"
    echo "  起動: spirit-room open $folder"
    exit 1  # Explicit error exit
fi
```

**Retry logic in test phases:**

From `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`:

```bash
while true; do
    [ -f "$DONE_FLAG" ] && { log "修行完了済み"; break; }

    log "TRAINING開始 (engine: $ENGINE)"
    run_claude "... MISSION.md ... complete all conditions ..."

    [ -f "$DONE_FLAG" ] && break
    log "TRAINING未完了、リトライ..."
    sleep 3
done
```

**Pattern:**
- `set -e` stops on first error within command execution
- Bash control flow (`while`, `if`, `&&`, `||`) continues at script level
- Failures trigger sleep + retry (line 82-83)
- Completion markers break the loop

## Mocking / Test Doubles

**No mocking framework.** Testing uses:

1. **Real Docker containers** - Entire Ubuntu + services environment
2. **Real file operations** - Read/write actual files in `/workspace`
3. **Real command execution** - Bash scripts run actual `docker`, `npm`, `python3`, etc.
4. **Real Claude calls** - Agent makes actual API calls to Claude (not stubbed)

**Isolation via containers:**
- Each test room is separate Docker container
- Container shutdown cleans up resources
- Volumes persist results for inspection

## Test Data / Fixtures

**MISSION.md as test specification:**

File: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/MISSION.md.template`

```markdown
# MISSION: [フレームワーク名] POC

## 目的
[何を実装するか]

## 完了条件（これを全て満たすまで繰り返せ）
- [ ] `cd /workspace && python3 test_exit.py` が exit code 0 で終了する
- [ ] `/workspace/README.md` に以下が書かれている
```

**Pattern:**
- User fills in template with specific framework/goal
- Agent reads MISSION.md as test specification
- Agent writes code until all conditions satisfied
- MISSION.md + `/workspace/README.md` + test_exit.py = complete test suite

**Fixture location:**
- `/workspace/` - Shared mount between host and container
- `.logs/` - Test output logs (appended during execution)
- `catalog.md` - Available within container (project override or default)

## Coverage

**No coverage tracking.** Project evaluates success by:

1. **Behavioral pass/fail** - All MISSION.md conditions met (yes/no)
2. **Code review** - Generated code quality inspection
3. **Documentation** - README.md explains implementation

**Not measured:**
- Line coverage
- Branch coverage
- Function coverage

## Test Execution Environment

**Accessible at:**

From host: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`

**Commands available in container:**
- `start-training` → Run phases 1-2 with Claude
- `start-training opencode` → Run phases 1-2 with opencode
- `status` → Inspect progress
- `tail -f /workspace/.logs/progress.log` → Monitor logs
- `tmux attach -t spirit-room` → Interactive debugging

**Container layout:**
```
/workspace/         ← Project files, MISSION.md, outputs
/room/              ← Read-only scripts and catalog
/logs/              ← Symlink target for progress.log
/root/.claude       ← Claude Code auth (shared volume)
```

---

*Testing analysis: 2026-04-13*
