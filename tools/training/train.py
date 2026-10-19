"""Trains the bots' PvP duel policy with PPO (stable-baselines3) on the real game rules.

    make train STEPS=20000000          # or: .tools/rl-venv/bin/python tools/training/train.py --steps ...
    make export-policy                 # writes game/data/policies/pvp_duel.json
    make duel-eval                     # policy bot against the scripted bot, per vocation pair

Godot runs tools/training/duel_env.tscn headless in several processes (duel_vec_env.py); each
process holds many duels. Checkpoints, the latest model, and logs go to .tools/rl/.
"""

from __future__ import annotations

import argparse
import collections
from pathlib import Path

import torch
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback, CallbackList, CheckpointCallback
from stable_baselines3.common.vec_env import VecMonitor

from duel_vec_env import REPO, DuelVecEnv
from export_policy import write_policy

OUT = REPO / ".tools" / "rl"
MODEL = OUT / "pvp_duel.zip"
OPPONENTS = OUT / "opponents"


class DuelStats(BaseCallback):
    """Logs the share of finished duels the learner won, lost, drew, or fled, per opponent."""

    def __init__(self) -> None:
        super().__init__()
        self.results: dict[str, collections.Counter[str]] = collections.defaultdict(collections.Counter)

    def _on_step(self) -> bool:
        for done, info in zip(self.locals["dones"], self.locals["infos"]):
            if done and "result" in info:
                self.results[info.get("opponent", "scripted")][info["result"]] += 1
        return True

    def _on_rollout_end(self) -> None:
        for opponent, results in self.results.items():
            total = sum(results.values())
            prefix = "duel" if opponent == "scripted" else f"duel_{opponent}"
            for result in ("win", "loss", "draw", "fled"):
                self.logger.record(f"{prefix}/{result}", results[result] / total)
            self.logger.record(f"{prefix}/episodes", total)
        self.results.clear()


class Snapshots(BaseCallback):
    """Every `every` steps, writes the current policy to OPPONENTS for self-play (keeps `keep`)."""

    def __init__(self, every: int, keep: int) -> None:
        super().__init__()
        self.every = every
        self.keep = keep
        self.last = 0

    def _on_training_start(self) -> None:
        if not any(OPPONENTS.glob("*.json")):
            self._write()

    def _on_step(self) -> bool:
        if self.num_timesteps - self.last >= self.every:
            self._write()
        return True

    def _write(self) -> None:
        self.last = self.num_timesteps
        OPPONENTS.mkdir(parents=True, exist_ok=True)
        target = OPPONENTS / f"pvp_{self.num_timesteps:011d}.json"
        partial = target.with_suffix(".part")
        write_policy(self.model, partial)
        partial.rename(target)
        for old in sorted(OPPONENTS.glob("*.json"))[: -self.keep]:
            old.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--steps", type=int, default=10_000_000)
    parser.add_argument("--processes", type=int, default=8)
    parser.add_argument("--arenas", type=int, default=16, help="duels per Godot process")
    parser.add_argument("--port", type=int, default=11008)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--resume", type=Path, help="continue training this model (.zip)")
    parser.add_argument("--learning-rate", type=float, default=3e-4)
    parser.add_argument("--n-steps", type=int, default=256, help="steps per duel per rollout")
    parser.add_argument("--batch-size", type=int, default=4096)
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--gamma", type=float, default=0.995)
    parser.add_argument("--ent-coef", type=float, default=0.01)
    parser.add_argument("--self-play", type=float, default=0.0, help="share of duels against earlier snapshots")
    parser.add_argument("--snapshot-every", type=int, default=2_000_000)
    parser.add_argument("--keep-snapshots", type=int, default=8)
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(2)
    env = VecMonitor(
        DuelVecEnv(
            args.processes, args.arenas, args.port, args.seed, OUT / "logs",
            opponents=OPPONENTS if args.self_play > 0 else None, self_play=args.self_play,
        )
    )
    try:
        if args.resume:
            model = PPO.load(args.resume, env=env, device="cpu")
        else:
            model = PPO(
                "MultiInputPolicy",
                env,
                learning_rate=args.learning_rate,
                n_steps=args.n_steps,
                batch_size=args.batch_size,
                n_epochs=args.epochs,
                gamma=args.gamma,
                gae_lambda=0.95,
                ent_coef=args.ent_coef,
                clip_range=0.2,
                policy_kwargs={"net_arch": {"pi": [64, 64], "vf": [64, 64]}, "activation_fn": torch.nn.Tanh},
                tensorboard_log=str(OUT / "tensorboard"),
                seed=args.seed,
                device="cpu",
                verbose=1,
            )
        checkpoints = CheckpointCallback(
            save_freq=max(1, 1_000_000 // env.num_envs), save_path=str(OUT / "checkpoints"), name_prefix="pvp_duel"
        )
        model.learn(
            total_timesteps=args.steps,
            callback=CallbackList(
                [checkpoints, DuelStats()] + ([Snapshots(args.snapshot_every, args.keep_snapshots)] if args.self_play > 0 else [])
            ),
            reset_num_timesteps=args.resume is None,
            tb_log_name="pvp_duel",
        )
        model.save(MODEL)
        print(f"saved {MODEL}")
    finally:
        env.close()


if __name__ == "__main__":
    main()
