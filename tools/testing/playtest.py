#!/usr/bin/env python3
"""Automated full-game playthrough: a real dedicated server and two bot clients (Knight and
Sorcerer, tests/integration/playthrough.gd) play through every system over ENet. Bots render offscreen;
Godot only opens two 64x64 windows in a screen corner. Writes .tools/playtest/report.html.
Python standard library only."""

import argparse
import datetime
import html
import queue
import shutil
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

DEADLINE = 600


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", default="godot", help="Godot 4 executable")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = root / ".tools" / "playtest"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    events = queue.Queue()
    processes = {}
    log = []
    started = time.monotonic()

    def launch(name, command):
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, bufsize=1)
        processes[name] = process

        def read():
            for line in process.stdout:
                events.put((name, line.rstrip()))
            events.put((name, None))
        threading.Thread(target=read, daemon=True).start()

    launch("server", [args.godot, "--headless", "--path", str(root), "--", "--headless-server", f"--port={port}"])
    rows, shots, errors, done = [], [], [], set()
    try:
        while time.monotonic() - started < DEADLINE and done != {"knight", "sorcerer"}:
            try:
                name, line = events.get(timeout=0.5)
            except queue.Empty:
                continue
            if line is None:
                if name != "server":
                    done.add(name)
                continue
            stamp = time.monotonic() - started
            log.append(f"{stamp:6.1f} [{name}] {line}")
            if "SCRIPT ERROR" in line or (line.startswith("ERROR:") and "You are dead" not in line):
                errors.append(f"[{name}] {line}")
            if line.startswith("BRIMHOLT_HOST_READY") and "knight" not in processes:
                for role, slot in (("knight", 2), ("sorcerer", 1)):
                    launch(role, [args.godot, "--position", "99999,99999", "--resolution", "64x64", "--path", str(root),
                                  "--script", "res://tests/integration/playthrough.gd", "--", "--join=127.0.0.1", f"--port={port}",
                                  f"--vocation={role}", f"--bot={role}"])
            if line.startswith("PLAYTEST_SHOT "):
                file, caption = line[len("PLAYTEST_SHOT "):].split(" ", 1)
                shots.append((file, caption))
            elif line.startswith("PLAYTEST ") and not line.startswith("PLAYTEST_"):
                _, role, phase, kind, detail = line.split(" ", 4)
                if kind != "info" or detail != "started":
                    rows.append((stamp, role, phase, kind, detail))
                    print(f"{stamp:6.1f}s {role:9} {phase:12} {kind:8} {detail}", flush=True)
            elif line.startswith("PLAYTEST_DONE "):
                done.add(line.split(" ", 1)[1])
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
        for process in processes.values():
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
    timed_out = done != {"knight", "sorcerer"}
    failures = [row for row in rows if row[3] == "fail"]
    findings = [row for row in rows if row[3] == "finding"]
    passed = not failures and not errors and not timed_out
    colors = {"ok": "#9ccea4", "fail": "#e48a8a", "finding": "#f0c674", "info": "#a7b0b8"}
    table = "".join(
        f"<div class='row'><b style='color:{colors.get(kind, '#ddd')}'>{kind}</b> · {stamp:.0f}s · {role} · {phase}"
        f"<div>{html.escape(detail)}</div></div>" for stamp, role, phase, kind, detail in rows)
    gallery = "".join(f"<figure><img src='{file}'><figcaption>{html.escape(caption)}</figcaption></figure>"
                      for file, caption in shots)
    problems = "".join(f"<li>{html.escape(line)}</li>" for line in errors) + (
        "<li>Timed out before both bots finished</li>" if timed_out else "")
    (out / "report.html").write_text(f"""<!doctype html><meta charset="utf-8"><title>Brimholt playthrough</title>
<style>body{{background:#11151a;color:#dfe4ea;font:13px system-ui;margin:14px}}.row{{padding:5px 6px;border-bottom:1px solid #222a33}}.row div{{color:#c9d1d9;margin-top:2px}}img{{width:100%;image-rendering:pixelated;border:1px solid #333}}
figure{{margin:0 0 16px}}h2{{color:{'#9ccea4' if passed else '#e48a8a'}}}pre{{white-space:pre-wrap;color:#7d8790;font-size:11px}}</style>
<h2>Playthrough {'passed' if passed else 'found problems'}</h2>
<p>{datetime.datetime.now():%Y-%m-%d %H:%M} · {time.monotonic() - started:.0f} s · {len(failures)} failures ·
{len(findings)} findings · {len(errors)} engine errors</p><ul>{problems}</ul>
<div>{table}</div><h3>Screenshots</h3>{gallery}
<details><summary>Full log</summary><pre>{html.escape(chr(10).join(log))}</pre></details>""")
    print(f"Report: {(out / 'report.html').as_uri()}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
