# Bot training: the PvP combat policy

Bots fight players with a small neural network trained by reinforcement learning on the game's
own rules, not with hand-written tactics. Everything else a bot does (travel, loot, selling,
quests, fighting monsters) stays in the LimboAI behavior tree.

## How it fits together

| Part | File | Role |
| --- | --- | --- |
| Encoding | `game/core/ai/pvp_brain.gd` | `observe()`: 93 numbers in [-1, 1] describing the fight from one bot's side; `apply()`: carries out a choice through `World.move`, `Combat.cast`, and `Combat.drink` only |
| Network | `game/core/ai/policy_net.gd` | Loads `game/data/policies/pvp_duel.json` and runs the forward pass in plain GDScript (no Python, ONNX, or .NET in the game) |
| Runtime | `Bots.run_policy`, `tasks/bt_run_policy.gd` | Fight = Sequence[PickTarget, Selector[RunPolicy, EngageTarget]]: the policy fights hostile players; anything else (or no policy file) falls back to the scripted fight |
| Difficulty | `Bots.DIFFICULTY`, start panel | Easy: 30% random actions, acts on two-turn-old sight. Normal: 10%, one turn. Hard: none |
| Arena | `tools/training/duel_arena.gd` | One duel on the real rules: fresh World/Combat/Bots, no monsters, a random class pair, a shared level of 10-50 in vendor gear, 1-6 tiles apart in a PvP zone |
| Environment | `tools/training/duel_env.tscn`, `duel_env.gd`, `duel_controller.gd` | Many arenas per headless Godot process, talking to the trainer through the vendored Godot RL Agents `Sync` node |
| Trainer | `tools/training/train.py`, `duel_vec_env.py` | PPO (stable-baselines3) over several Godot processes |
| Export | `tools/training/export_policy.py` | Model → JSON (hidden tanh layers + action logits), checked against torch |
| Evaluation | `tools/testing/duel_eval.gd` | Policy bot (through the real behavior tree) vs the scripted bot, per class pair and level |

Bots draw each choice from the policy's softmax, as in training, rather than always taking the
top score: the policy has no memory and mixes its actions on purpose (at one million steps the
sampled policy won 73% of duels against the scripted bot, the top-score one 31%).

**Observation** (`PvpBrain.observe`): for both fighters, health and mana shares, level, reach,
class, roots and slows, and time to their next step; its own zone and skull; the level gap,
whether the foe targets it, the direction and distance to the foe, who is in reach, and line of
sight; which action classes are ready and affordable, the spell-group cooldowns left, potions
ready and left; and a 7×7 grid of open tiles around the bot. Monsters are not observed (1v1 for
now).

**Actions**: two heads chosen together every bot turn (0.2 s):

- `act`: none, strongest ready attack spell, control (root/slow), self heal (heal/ward),
  support (buffs, marks, walls), health potion, mana potion. Each class maps these through its
  spells' kinds; an unready or unaffordable choice does nothing.
- `move`: stay, north, east, south, west, chase (a real path step toward the foe), back off.

Auto-attacks keep running on the bot's target as for any player.

**Reward** per step: damage dealt as a share of the foe's health, minus damage taken as a share
of its own, +1 for a kill, -1 for dying, -0.5 for leaving the PvP zones, -0.001 per step.
Duels end on a death, on leaving the zone, or after 150 s.

## Training

```sh
make train-setup                      # once: .tools/rl-venv (uv, Python 3.12, requirements.txt)
make train STEPS=20000000             # PPO; PROCESSES=8, RESUME=.tools/rl/pvp_duel.zip to continue
make export-policy                    # .tools/rl/pvp_duel.zip -> game/data/policies/pvp_duel.json
make duel-eval                        # policy vs scripted, per class pair (BASELINE=1: scripted vs scripted)
```

`train.py` starts `PROCESSES` headless Godot instances of `duel_env.tscn` (16 duels each, ports
from 11008) and connects to them itself, since Godot RL Agents' launcher only runs exported
games. On an M-series laptop eight processes give about 5,000 steps a second, so 20 million steps
take a bit over an hour. Checkpoints (every million steps), logs, and TensorBoard runs go to
`.tools/rl/` (ignored). `tools/training/run_env.sh` starts one environment by hand for a trainer
that is already listening.

Network: two hidden layers of 64 (tanh) for the policy and separately for the value estimate;
only the policy side is exported. A forward pass is about 11,000 multiply-adds (0.6 ms in GDScript), once per bot
turn that fights a player; bots take their turns in different frames.

Commit a new `pvp_duel.json` only when `make duel-eval` shows it beats the scripted bot. The
class matchups are uneven even between scripted bots (`make duel-eval BASELINE=1`), so compare
each pair with its baseline rather than with 50%.

**Self-play.** `SELF_PLAY=0.5` makes half the duels run against earlier snapshots of the policy
itself (`Snapshots` writes one to `.tools/rl/opponents/` every million steps and keeps the
latest few), so the bots also learn to beat play stronger than the scripted fight. The shipped
policy was trained 20 million steps against the scripted bot, then 20 million more with
`make train STEPS=20000000 RESUME=.tools/rl/pvp_duel_20m.zip SELF_PLAY=0.5`. Compare two
policies head to head with `make duel-eval POLICY=res://a.json RIVAL=res://b.json`.

### Results

`make duel-eval GAMES=10` at hard difficulty: 10 duels per class pair at levels 10, 20, 30, 40,
and 50 (800 duels). Rows are the policy bot's class, columns its foe's; cells are the row
class's win share.

| Row vs column | Warrior | Hunter | Sorcerer | Druid |
| --- | --- | --- | --- | --- |
| **Scripted vs scripted** (baseline, 49.5%) | | | | |
| Warrior | 38% | 57% | 4% | 100% |
| Hunter | 46% | 52% | 94% | 100% |
| Sorcerer | 92% | 6% | 54% | 99% |
| Druid | 0% | 2% | 2% | 46% |
| **20M steps vs scripted** (79.5%) | | | | |
| Warrior | 98% | 96% | 64% | 99% |
| Hunter | 94% | 96% | 97% | 100% |
| Sorcerer | 98% | 80% | 98% | 98% |
| Druid | 47% | 4% | 5% | 98% |
| **Shipped (+20M self-play) vs scripted** (82.9%) | | | | |
| Warrior | 100% | 96% | 74% | 100% |
| Hunter | 100% | 100% | 96% | 100% |
| Sorcerer | 100% | 80% | 98% | 98% |
| Druid | 69% | 7% | 8% | 100% |
| **Shipped vs the 20M policy** (67.2%) | | | | |
| Warrior | 77% | 98% | 3% | 100% |
| Hunter | 81% | 86% | 88% | 84% |
| Sorcerer | 99% | 41% | 70% | 90% |
| Druid | 18% | 31% | 17% | 92% |

Druids lose most duels by design: they are the healer class, balanced for solo hunting and
parties rather than 1v1 PvP.

## Plugin

The Godot side of [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) (MIT, commit
998c357) is vendored in `addons/godot_rl_agents/` for training only (`VENDORED.md`); export
presets exclude it. The Python side is the pinned `godot-rl` package.

## Next

Groups (2v2, 3v3) with a shared policy and team reward, and monsters in the observation.
