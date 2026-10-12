# Brimholt repository instructions

- Brimholt is an original working name, not verified trademark/name clearance. Do not reuse proprietary Tibia artwork, maps, names, or code.
- Use Godot 4.5+, typed GDScript, and native ENet/MultiplayerAPI. No Node server, third-party APIs, paid services, or downloaded game assets.
- Open Tibia engines are high-level references, not dependencies: do not copy/translate GPL code without a licensing decision; MIT reuse needs file/dependency checks and applicable notices. Neither source license licenses proprietary Tibia assets. See README.md.
- The game is a small four-player LAN prototype: original 32-pixel tile map, cardinal grid movement, collision, smooth presentation, host/join, visibly equipped items, and a flat backpack with ground items and drag-and-drop.
- Keep combat, vocations, nested containers, loot/trading, death penalties, procedural caves, floor systems, persistence/authentication, and AI NPCs out unless the user selects them as a milestone.
- Peer 1 owns all gameplay state. Keep input ownership separate from node multiplayer authority. Validate RPC senders; clients request actions, never positions or authoritative appearance.
- Enforce movement timing, walkability, occupancy, item moves (reach, slot type, capacity, cooldown), and player limits on the server. Synchronize spawn, late-join, equipment, ground-item, and disconnect state reliably; send backpack contents only to their owner.
- Preserve host/client behavior parity. Use original layered placeholder drawings for gear rather than a separate asset for every combination.
- Inspect actual files and reuse existing helpers before editing. Make surgical changes, keep types explicit, and surface errors.
- Consult the relevant repository skill before gameplay, networking, equipment, or validation work.
- Check tooling before claiming results. Use bounded checks, report what actually ran, and never bypass denied permissions.
- Keep registered checkout paths stable. Do not publish a repository, add a remote, or install system-wide tools without authorization.
