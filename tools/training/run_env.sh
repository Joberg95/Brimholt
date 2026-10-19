#!/bin/sh
# Runs the duel training environment for a trainer that is already listening on --port
# (train.py starts these itself; use this to attach a hand-run trainer or to debug).
#   tools/training/run_env.sh [--port=11008] [--arenas=16] [--env_seed=1] [--speedup=100]
cd "$(dirname "$0")/../.." || exit 1
exec "${GODOT:-godot}" --headless --path . res://tools/training/duel_env.tscn --action_repeat=1 --speedup=100 "$@"
