# Godot RL Agents (Godot side), vendored for training only

Source: https://github.com/edbeeching/godot_rl_agents_plugin at commit
998c357a0cd09b37f40a36d70c7867fc9f682338, MIT licensed (see `LICENSE`, kept unchanged).

Files kept, unmodified: `sync.gd`, `controller/ai_controller_2d.gd`, and
`onnx/wrapper/ONNX_wrapper.gd` (only so the `ONNXModel` class that `sync.gd` names exists; the
C# ONNX runtime is left out and never used). Sensors, rewards, the 3D controller, and the editor
plugin are left out.

Brimholt uses this only in `tools/training/` (the headless duel environment that the Python
trainer talks to). The game never loads it, and the Windows export excludes this folder.
