"""Godot processes running the duel training scene (tools/training/duel_env.tscn) as one
stable-baselines3 vector environment. godot_rl's own wrapper only launches exported games, so
this starts the project directly with the godot executable and connects a GodotEnv to each.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

import numpy as np
from godot_rl.core.godot_env import GodotEnv
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

REPO = Path(__file__).resolve().parents[2]
SCENE = "res://tools/training/duel_env.tscn"


def godot_binary() -> str:
    found = os.environ.get("GODOT") or shutil.which("godot")
    if not found:
        raise SystemExit("godot not found: put it on PATH or set GODOT=/path/to/godot")
    return found


class DuelVecEnv(StableBaselinesGodotEnv):
    """`processes` headless Godot instances with `arenas` duels each (num_envs = their product).
    With `opponents` (a directory of exported snapshots), `self_play` of the duels are against them.

    Each finished duel reports done with {"result": ...} in its info and immediately starts the
    next one, so observations after done belong to the new episode (SB3's auto-reset contract).
    """

    def __init__(
        self,
        processes: int,
        arenas: int,
        port: int,
        seed: int,
        log_dir: Path,
        speedup: int = 100,
        opponents: Path | None = None,
        self_play: float = 0.0,
    ) -> None:
        log_dir.mkdir(parents=True, exist_ok=True)
        self.procs: list[subprocess.Popen] = []
        self.envs = []
        for index in range(processes):
            log = open(log_dir / f"godot_{index}.log", "w")
            self.procs.append(
                subprocess.Popen(
                    [
                        godot_binary(), "--headless", "--path", str(REPO), SCENE,
                        f"--port={port + index}", f"--env_seed={seed + index}",
                        f"--arenas={arenas}", "--action_repeat=1", f"--speedup={speedup}",
                        *([f"--opponents={opponents}", f"--self_play={self_play}"] if opponents else []),
                    ],
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
            )
            # The scene waits a second before connecting; GodotEnv listens right away.
            self.envs.append(GodotEnv(env_path=None, port=port + index, seed=seed + index, convert_action_space=True))
        self.n_parallel = processes
        self._check_valid_action_space()
        self.results = None

    def step(self, action: np.ndarray) -> tuple[dict[str, np.ndarray], np.ndarray, np.ndarray, list[dict[str, Any]]]:
        obs, rewards, dones, infos = super().step(action)
        # Copies: the plugin may hand back one shared {} for every agent.
        return obs, rewards, dones, [dict(info) for info in infos]

    def seed(self, seed: int | None = None) -> list[None]:
        # Each Godot process was seeded at launch (--env_seed).
        return [None] * self.num_envs

    def close(self) -> None:
        for env in self.envs:
            try:
                env.close()
            except OSError:
                pass
        deadline = time.time() + 5
        for proc in self.procs:
            try:
                proc.wait(timeout=max(0.1, deadline - time.time()))
            except subprocess.TimeoutExpired:
                proc.kill()
