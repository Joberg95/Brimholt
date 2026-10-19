"""Writes a trained PPO model's policy as the JSON the game runs (game/core/ai/policy_net.gd).

    .tools/rl-venv/bin/python tools/training/export_policy.py [--model .tools/rl/pvp_duel.zip]
        [--out game/data/policies/pvp_duel.json]

Only the action side is kept: the policy's hidden layers (tanh) and the action layer, whose
outputs are each head's logits one after another (the env's action order: act, then move). The
exporter checks its own numpy forward pass against torch before writing.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from stable_baselines3 import PPO

REPO = Path(__file__).resolve().parents[2]
HEADS = ["act", "move"]


def layers_of(model: PPO) -> list[dict]:
    policy = model.policy
    layers: list[dict] = []
    modules = list(policy.mlp_extractor.policy_net)
    for index, module in enumerate(modules):
        if isinstance(module, torch.nn.Linear):
            following = modules[index + 1] if index + 1 < len(modules) else None
            if not isinstance(following, torch.nn.Tanh):
                raise SystemExit(f"expected tanh after hidden layer {index}, found {following}")
            layers.append(_linear(module, "tanh"))
    layers.append(_linear(policy.action_net, "linear"))
    return layers


def _linear(module: torch.nn.Linear, activation: str) -> dict:
    weights = module.weight.detach().cpu().numpy().astype(np.float32)
    return {
        "inputs": int(weights.shape[1]),
        "outputs": int(weights.shape[0]),
        "activation": activation,
        "weights": [round(float(value), 6) for value in weights.reshape(-1)],
        "biases": [round(float(value), 6) for value in module.bias.detach().cpu().numpy()],
    }


def forward(layers: list[dict], obs: np.ndarray) -> np.ndarray:
    values = obs.astype(np.float64)
    for layer in layers:
        weights = np.array(layer["weights"]).reshape(layer["outputs"], layer["inputs"])
        values = weights @ values + np.array(layer["biases"])
        if layer["activation"] == "tanh":
            values = np.tanh(values)
    return values


def policy_data(model: PPO) -> dict:
    """The model's action side in the game's JSON layout, checked against torch."""
    sizes = [int(size) for size in model.action_space.nvec]
    obs_size = int(model.observation_space["obs"].shape[0])
    if len(sizes) != len(HEADS):
        raise SystemExit(f"model has {len(sizes)} action heads, expected {HEADS}")
    layers = layers_of(model)
    rng = np.random.default_rng(0)
    for _ in range(16):
        obs = rng.uniform(-1, 1, obs_size).astype(np.float32)
        with torch.no_grad():
            tensor = {"obs": torch.as_tensor(obs[None], device=model.device)}
            features = model.policy.extract_features(tensor, model.policy.pi_features_extractor)
            expected = model.policy.action_net(model.policy.mlp_extractor.forward_actor(features)).cpu().numpy()[0]
        if not np.allclose(forward(layers, obs), expected, atol=1e-3):
            raise SystemExit("exported forward pass does not match the model")
    return {
        "version": 1,
        "obs_size": obs_size,
        "heads": [{"name": name, "size": size} for name, size in zip(HEADS, sizes)],
        "layers": layers,
    }


def write_policy(model: PPO, path: Path) -> dict:
    data = policy_data(model)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, separators=(",", ":")) + "\n")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", type=Path, default=REPO / ".tools" / "rl" / "pvp_duel.zip")
    parser.add_argument("--out", type=Path, default=REPO / "game" / "data" / "policies" / "pvp_duel.json")
    args = parser.parse_args()

    data = write_policy(PPO.load(args.model, device="cpu"), args.out)
    print(f"wrote {args.out} ({data['obs_size']} inputs, {[layer['outputs'] for layer in data['layers']]})")


if __name__ == "__main__":
    main()
