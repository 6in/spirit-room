#!/bin/bash
#
# install-skills.sh
#
# /room/skills/ 配下にバンドルされたスキルを /workspace/.claude/skills/ に
# プロジェクトローカルインストールする。
#
# - /root/.claude/skills/ は spirit-room-auth ボリュームに隠されるため使わない
# - /workspace/.claude/skills/ は Claude Code が CWD からの探索で認識する
# - 既にインストール済みのスキルは上書きしない
#
# 起動時に start-training.sh から呼び出される。
#

set -e

SKILLS_SRC="/room/skills"
SKILLS_DEST="/workspace/.claude/skills"

if [ ! -d "$SKILLS_SRC" ]; then
    echo "[skills] バンドルされたスキルが見つからない: $SKILLS_SRC"
    exit 0
fi

mkdir -p "$SKILLS_DEST"

installed=0
skipped=0
for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    if [ -d "$SKILLS_DEST/$name" ]; then
        skipped=$((skipped + 1))
        continue
    fi
    cp -r "$skill_dir" "$SKILLS_DEST/$name"
    echo "[skills] installed: $name"
    installed=$((installed + 1))
done

echo "[skills] complete: ${installed} installed, ${skipped} skipped (already present)"
echo "[skills] location: $SKILLS_DEST"
echo "[skills] 追加スキルを入れたい場合: cd /workspace && npx -y skills add <owner/repo> --skill <name>"
