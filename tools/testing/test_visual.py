#!/usr/bin/env python3
"""Run the graphical check offscreen and write an HTML report of its captures.

The game renders into an offscreen buffer; Godot only opens a 64x64, unfocused window
in a screen corner. Open the printed report (for example in an editor's browser panel)
to inspect the frames. Python standard library only.
"""

import argparse
import datetime
import html
import subprocess
import sys
from pathlib import Path

CAPTURES = (
    ("visual-weapons.png", "15 hunting weapons: native and 2x icons, four facings, stand and both walk poses"),
    ("visual-wardrobe.png", "Cape-free base, armor only, cape only, armor + cape; four facings and three poses each"),
    ("visual.png", "Equipped: four facings, gear layers, ground item, oblique walls"),
    ("visual-unequipped.png", "Unequipped: gear layers removed, items back in the backpack"),
    ("visual-forest.png", "Forest: trees drawn in depth order around a character"),
    ("visual-landing.png", "Cinder Landing: pier, ferryman, trees, beach, minimap"),
    ("visual-isle.png", "Blackreed Isle: PvP zone banner, action bar, red minimap"),
    ("visual-map.png", "World map (M) with the PvP island"),
    ("visual-combat.png", "Combat: locked target, nameplates, health/mana bars, floating damage"),
    ("visual-waystone.png", "Waystone outside Cinder Crossing: a carved standing stone with a glowing rune"),
    ("visual-spellbook.png", "Spell book (B): each spell's rune, unlock level, effect, damage or healing, mana, and cooldown"),
    ("visual-character.png", "Character window (C) from the micro menu right of the action bar: stats explained and status"),
    ("visual-trainer.png", "Training hall: Ranger Tamsin offers the Hunter class to an Adventurer who passed the trial"),
    ("visual-lexicon.png", "Lexicon (K) searched for silk: the spiders, where they live, and their drop chances"),
    ("visual-quest-marks.png", "Cinder Landing at level 12: Harbourmaster Ilse's ! and the quest list's next stop"),
    ("visual-bots.png", "Bots panel (host only): a level-30 Warrior bot added beside you, listed with its stance and place"),
    ("visual-quests.png", "Quest list: a task in progress and one ready to turn in, with giver and town"),
    ("visual-tooltip.png", "Item tooltip: rarity grade in the name colour and frame (no coloured slot edge)"),
    ("visual-swing.png", "Attack: the weapon hand strikes toward the target"),
    ("visual-roofs.png", "Ashford from the plaza: roofs over the houses, a hanging shop sign, no names through roofs"),
    ("visual-roofs-near.png", "Beside Ashford's shop: its roof turns see-through, the wooden door and the merchant show"),
    ("visual-ore.png", "A copper vein near Cinder Crossing: orange ore in the mountain's cliff face"),
    ("visual-shop-inside.png", "Inside Ashford's shop: its roof fades away and the merchant shows"),
    ("visual-cellar.png", "Cinder cellar: entered by the town stairway; rats and the Rat King in a private copy"),
    ("visual-torches.png", "Night in town: wall torches burn beside the doors and light the walls"),
    ("visual-cave-mouth.png", "Silkhollow's mouth in Thornfield Wilds: a rock ring round the stairway, Trapper Maud beside it"),
    ("visual-cave.png", "Silkhollow without a torch: only an arm's length of lantern light"),
    ("visual-cave-torch.png", "Silkhollow with a torch in the off hand: a wide warm light"),
    ("visual-mine.png", "Highmoor deep mine: cave rock walls and floor"),
    ("visual-rain.png", "Rain at noon over Cinder Crossing: pixel drops, splashes, dimmer light"),
    ("visual-rain-night.png", "Rain at night: lanterns light the wet street"),
    ("visual-desert.png", "The Dunmere desert in a storm elsewhere: dry sand, cacti, and thorn scrub"),
    ("visual-hollow-gate.png", "The Hollow Reach: obsidian wall, gate, dusk soil, dead trees"),
    ("visual-hollow-throne.png", "The Hollow Sanctum: Vaelith on the obsidian throne room floor"),
    ("visual-night.png", "Night: darker world, the player's lantern, unlit names and UI"),
    ("visual-particles.png", "Particles: critical-hit stars and a fire spell's sparks and flash"),
    ("visual-relics.png", "Relics: claimed from Ysolde's quest window; glowing relic gear, a relic on the ground, glowing bosses"),
)


## The full visual run takes about 40 seconds; allow for a busy machine.
VISUAL_TIMEOUT = 120


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", default="godot", help="Godot 4 executable")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    tools = root / ".tools"
    tools.mkdir(exist_ok=True)
    for name, _ in CAPTURES:
        (tools / name).unlink(missing_ok=True)
    command = [
        args.godot, "--position", "99999,99999", "--resolution", "64x64",
        "--path", str(root), "--script", "res://tests/visual/visual_test.gd",
    ]
    try:
        result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=VISUAL_TIMEOUT)
    except subprocess.TimeoutExpired:
        print(f"FAIL: visual check timed out after {VISUAL_TIMEOUT} seconds")
        return 1
    lines = [line for line in result.stdout.splitlines() if "BRIMHOLT" in line or "ERROR" in line]
    print("\n".join(lines))
    passed = result.returncode == 0 and any(line.startswith("BRIMHOLT_VISUAL_PASS") for line in lines)
    figures = "".join(
        f'<figure><img src="{name}?{datetime.datetime.now().timestamp():.0f}"><figcaption>{html.escape(caption)}'
        "</figcaption></figure>"
        for name, caption in CAPTURES if (tools / name).exists()
    )
    report = tools / "visual-report.html"
    report.write_text(f"""<!doctype html><meta charset="utf-8"><title>Brimholt visual check</title>
<style>body{{background:#11151a;color:#dfe4ea;font:14px system-ui;margin:16px}}
img{{width:100%;image-rendering:pixelated;border:1px solid #333}}figure{{margin:0 0 20px}}
.pass{{color:#9ccea4}}.fail{{color:#e48a8a}}pre{{white-space:pre-wrap;color:#a7b0b8}}</style>
<h2 class="{'pass' if passed else 'fail'}">Visual check {'passed' if passed else 'FAILED'}</h2>
<p>{datetime.datetime.now():%Y-%m-%d %H:%M:%S}</p><pre>{html.escape(chr(10).join(lines))}</pre>{figures}
""")
    print(f"Report: {report.as_uri()}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
