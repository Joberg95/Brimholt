---
name: godot-lan-multiplayer
description: Use when implementing or changing Brimholt ENet hosting/joining, RPCs, server authority, movement timing, player lifecycle, or LAN state synchronization.
---

# Godot LAN multiplayer

1. Use native ENet with UDP port 1234 and at most twelve players (`World.MAX_PLAYERS`) including a playing host. The handshake carries the map signature and a vocation; validate both as untrusted Variants. Do not introduce a Node/WebSocket service.
2. Leave gameplay nodes under peer 1 authority. Record each character's input-owner peer ID separately.
3. Expose narrowly scoped reliable action RPCs. Validate the remote sender against a connected player; do not accept a client-supplied owner ID, position, speed, slot appearance, or arbitrary item data.
4. Route host actions directly through the same server validation used for remote requests. Never treat a remote sender ID of zero as a remote client.
5. Validate cardinal direction, server cooldown, bounds, map collision, and player occupancy. Validate item moves against the server's catalog and authoritative inventory/ground state, and ferry travel against range, routes, standing still, cooldown, and gold (`World.travel`). Combat requests (`request_target`, `request_spell`) go through `game/core/combat.gd`; replicate its events (creature updates, hits, missiles, areas, messages) from the host only.
6. Establish matching scene/RPC paths before joining. Send a reliable full snapshot after connection and serialize late-join state, including current movement, facing, equipment, ground items, and the joiner's own backpack.
7. Use reliable authoritative updates for accepted actions and explicit feedback for rejected actions. Preserve consistent rendering on the host and clients.
8. Allocate unique walkable spawns. Remove disconnected actors and reservations; close failed peers and show connection/server errors.
9. Keep headless host mode optional and share its state logic with the playing host. Check bind failures, capacity, unreachable host, host loss, and bounded peer cleanup.
10. Verify with a real two-peer session when Godot tooling is available. Never claim ENet interoperability from static inspection alone.

This is trusted-LAN prototyping, not Internet-ready authentication, encryption, anti-cheat, persistence, or an MMO backend.

Current implementation: `game/main.gd` holds the shared `/root/Main` RPC endpoint; `game/core/world.gd` owns deterministic rules. Run the actual ENet harness in `tools/testing/test_lan.py` with `make test-lan` (see `docs/testing.md`).
