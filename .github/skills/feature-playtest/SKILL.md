---
name: feature-playtest
description: Use when a Brimholt feature build is finished and needs its one verification pass (tests, visual capture, soak, bot playthrough), or when deciding whether a check is worth running mid-build. Run the full pass once at the end of a feature, not after every increment.
---

# End-of-feature playtest

Verification is the slow, token-heavy part of a build. Run it **once**, when every piece of
the feature is written, instead of after each step. While building, only run what catches the
mistake you are about to make next.

## While building (cheap, as often as needed)

| When | Run | Time |
| --- | --- | --- |
| After editing any `.gd` | `make lint` | ~5 s |
| After changing rules, data, or the map | `make test-unit` | ~5 s |
| After adding a PNG or a new `preload` | `make import` first (a missing `.ctex` looks like a script parse error) | ~10 s |
| After changing sprite art | regenerate, then look at one targeted capture (see "Art" below) | ~30 s |

Do **not** run the visual check, soak, LAN tests, or the bot playthrough mid-build. Do not
take a screenshot after every tweak: batch art changes and look once.

## The end-of-feature pass

Run these in order and stop at the first failure. Fix it, then re-run **that step and the
later ones**, not the whole list.

1. `make import`: must print no `ERROR` lines about the project's own files.
2. `make lint`: `LINT <n> scripts, 0 failed`.
3. `make test-unit`: `BRIMHOLT_RULES: <n> checks, 0 failures`.
4. Pick the slow checks from what the feature touched:

| The feature touched | Also run |
| --- | --- |
| Anything drawn (sprites, UI, HUD, lighting, map art) | `make test-visual`, then **open the captures** in `.tools/` |
| Spawns, monster counts, nodes, caches, pools, per-player state | `make soak` |
| RPCs, replication, snapshots, join/leave, item moves | `make test-lan` |
| The main loop (combat, levelling, travel, quests, party, PvP, bots) | `make playtest`, then read `.tools/playtest/report.html` findings |
| Balance numbers | `make fight-sim` / `make duel-sim` for the affected monsters or classes |

5. Write down which commands ran and their result lines. Say plainly what was **not** run
   and why (for example: no LAN test, nothing networked changed).

## Reading results

- Pass/fail lines: `LINT`, `BRIMHOLT_RULES`, `BRIMHOLT_VISUAL_PASS`, `BRIMHOLT_SOAK_PASS`.
  A zero exit code without its pass line is not a pass. The playthrough has no pass line:
  read each step's ok / fail / finding in its report.
- A failing visual check that also fails on the previous commit is pre-existing: confirm with
  `git stash`, run it, `git stash pop`, and report it separately rather than "fixing" it blind.
- A visual check that fails only with your change: find out what the assertion compares
  before changing it. Change an assertion only when it tests the wrong property (say why in
  the commit), never just to turn it green.
- Playtest **findings** (slow levelling, a bot stuck, a death loop) matter even when the run
  passes. Read them.
- Headless checks never prove that something looks right. For anything visual, open the PNG.

## Art

For a sprite change, render only what changed instead of the whole visual suite:
`python3 tools/generators/make_sprites.py --preview .tools/sprite-preview.png`, or a
throw-away `SceneTree` script that draws the one control or tile and saves a PNG. Keep such
scripts outside the repo (or delete them), and run them with a window (`--position
99999,99999 --resolution 64x64`); headless mode cannot render. See the `art-direction`
skill for what to look for.

## Windows without make or Python

`make` and `python3` may be missing. Call Godot directly with the same arguments the Makefile
uses, for example:

```powershell
$g = "<path to Godot_v4.x_console.exe>"
& $g --headless --path . --editor --quit                                   # import
& $g --headless --path . --script res://tools/testing/lint.gd              # lint
& $g --headless --path . --script res://tests/unit/rules_test.gd           # unit
& $g --position 99999,99999 --resolution 64x64 --path . --script res://tests/visual/visual_test.gd
& $g --position 99999,99999 --resolution 64x64 --path . --script res://tests/integration/soak_test.gd
```

Windows PowerShell 5.1 wraps native stderr lines and cuts them off. To read a full error,
run Godot with `Start-Process -NoNewWindow -Wait -RedirectStandardOutput a.txt
-RedirectStandardError b.txt` and search the files. Never edit tracked files through
`Get-Content`/`Set-Content` round trips: they re-encode UTF-8 (a `·` becomes `Â·`). Use the
editor tools instead.

## Finish

Commit once the pass is green, with the checks that ran in your report to the user. Update
`docs/testing.md` only if you added or changed a check.
