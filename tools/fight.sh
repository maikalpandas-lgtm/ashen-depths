#!/usr/bin/env bash
# Launch straight into a fight, skipping title and hero select.
#
#   tools/fight.sh                 mines, floor 1, default hero
#   tools/fight.sh --forest        forest
#   tools/fight.sh --floor 4       floor 4 (deeper = Навь + scaled stats)
#   tools/fight.sh --hero volhv
#
# Verifying combat art used to mean clicking through two menus and then hunting
# for a pack. Anything that makes a visual check cheap gets used; anything that
# does not, does not.
set -e
cd "$(dirname "$0")/.."
pkill -f "godot --path $(pwd)" 2>/dev/null || true
sleep 1
nohup godot --path "$(pwd)" -- --fight "$@" > /tmp/godot_run.log 2>&1 &
for _ in $(seq 1 60); do
  if python3 -c "
import socket,sys
s=socket.socket(); s.settimeout(1)
try: s.connect(('127.0.0.1',9090)); sys.exit(0)
except: sys.exit(1)" 2>/dev/null; then echo "готово: порт 9090 открыт"; exit 0; fi
  sleep 1
done
echo "не поднялась, лог:"; tail -20 /tmp/godot_run.log; exit 1
