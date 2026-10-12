#!/usr/bin/env python3
"""Bounded real-ENet integration; uses only the Python standard library."""

import argparse
import queue
import secrets
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot", help="Godot 4 executable")
    scenario = parser.add_mutually_exclusive_group()
    scenario.add_argument("--dedicated", action="store_true", help="Exercise a dedicated host and client")
    scenario.add_argument("--host-loss", action="store_true", help="Verify host loss is reported and state cleared")
    scenario.add_argument("--occupied-port", action="store_true", help="Verify hosting fails on an occupied UDP port")
    scenario.add_argument("--persistence", action="store_true",
                          help="Verify a character survives a host restart and cannot log in twice")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.persistence:
        persistence(args.godot, root)
        return
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        if args.occupied_port:
            result = subprocess.run(
                [args.godot, "--headless", "--path", str(root), "--", "--host", f"--port={port}", "--no-save"],
                cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, timeout=10,
            )
            print(result.stdout, end="")
            if result.returncode != 1 or f"Cannot host on UDP port {port}:" not in result.stdout \
                    or "BRIMHOLT_HOST_READY" in result.stdout or "SCRIPT ERROR:" in result.stdout:
                raise RuntimeError("Occupied UDP port did not produce an explicit startup failure")
            print("PASS: occupied UDP port reports a hosting error and exits with status 1")
            return
    events = queue.Queue()
    processes = {}
    output = {}
    expected_roles = {"host", "client"} if args.dedicated or args.host_loss else {"host", "client", "late"}

    def test_role(role):
        if args.host_loss:
            return f"loss_{role}"
        return f"dedicated_{role}" if args.dedicated else role

    def launch(role):
        mode = ("--headless-server" if args.dedicated else "--host") if role == "host" else "--join=127.0.0.1"
        command = [
            args.godot, "--headless", "--path", str(root),
            "--script", "res://tests/integration/peer_test.gd", "--",
            mode, f"--port={port}", f"--test-role={test_role(role)}",
            "--fresh-identity",
        ] + (["--no-save"] if role == "host" else []) + (["--vocation=druid"] if role == "client" else [])
        process = subprocess.Popen(
            command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )
        processes[role] = process
        output[role] = []

        def read():
            for line in process.stdout:
                events.put((role, line.rstrip()))
            events.put((role, None))

        threading.Thread(target=read, daemon=True).start()

    try:
        launch("host")
        deadline = time.monotonic() + 30
        passed = set()
        exited = set()
        while time.monotonic() < deadline:
            try:
                role, line = events.get(timeout=0.2)
            except queue.Empty:
                continue
            if line is None:
                exited.add(role)
                if processes[role].wait(timeout=2) != 0 or role not in passed:
                    raise RuntimeError(f"{role} exited without passing")
                if exited == expected_roles:
                    if args.host_loss:
                        print("PASS: host loss is reported and stale client state is cleared")
                    elif args.dedicated:
                        print("PASS: dedicated ENet movement/equipment/inventory, level-gated ring, ferry travel, combat, relic quest, vendor/potion/bank/depot/task RPCs and disconnect cleanup")
                    else:
                        print("PASS: real ENet host/client/late-join movement, authority, "
                              "collision, cooldown, equip/unequip, inventory/ground sync, party invite/join and disconnect cleanup")
                    return
                continue
            output[role].append(line)
            print(f"[{role}] {line}", flush=True)
            expected_loss = args.host_loss and role == "client" and line == (
                "ERROR: The host disconnected. Your LAN session has ended."
            )
            if "SCRIPT ERROR:" in line or ("ERROR:" in line and not expected_loss):
                raise RuntimeError(f"{role} emitted a Godot error")
            if line.startswith("BRIMHOLT_HOST_READY") and "client" not in processes:
                launch("client")
            if line == "BRIMHOLT_CLIENT_EQUIPPED" and "late" not in processes:
                launch("late")
            if line == f"BRIMHOLT_TEST_PASS {test_role(role)}":
                passed.add(role)
        raise RuntimeError("ENet integration timed out after 30 seconds")
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
        for process in processes.values():
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)


def persistence(godot, root):
    """A druid joins a dedicated host with a temporary save folder, moves, equips, and leaves.
    The host is restarted on the same folder; the same identity (now asking for a knight) must
    get its druid back, and a second login with that identity must be refused."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    saves = tempfile.mkdtemp(prefix="brimholt-saves-")
    token = secrets.token_hex(32)
    events = queue.Queue()
    processes, passed, exited = {}, set(), set()
    duplicate_error = "ERROR: That character is already in the world."

    def launch(name, role, extra):
        command = [godot, "--headless", "--path", str(root), "--script", "res://tests/integration/peer_test.gd", "--",
                   f"--port={port}", f"--test-role={role}"] + extra
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        processes[name] = process

        def read():
            for line in process.stdout:
                events.put((name, line.rstrip()))
            events.put((name, None))
        threading.Thread(target=read, daemon=True).start()

    host = ["--headless-server", f"--save-dir={saves}"]
    client = ["--join=127.0.0.1", f"--token={token}"]
    try:
        launch("host1", "persist_host", host)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            try:
                name, line = events.get(timeout=0.2)
            except queue.Empty:
                continue
            if line is None:
                exited.add(name)
                if processes[name].wait(timeout=2) != 0 or name not in passed:
                    raise RuntimeError(f"{name} exited without passing")
                if {"host1", "first"} <= exited and "host2" not in processes:
                    launch("host2", "persist_host", host)
                if exited == {"host1", "first", "host2", "return", "duplicate"}:
                    print("PASS: a saved character survives a host restart (position, vocation, equipment) "
                          "and a second login with the same identity is refused")
                    return
                continue
            print(f"[{name}] {line}", flush=True)
            if "SCRIPT ERROR:" in line or ("ERROR:" in line and not (name == "duplicate" and line == duplicate_error)):
                raise RuntimeError(f"{name} emitted a Godot error")
            if line.startswith("BRIMHOLT_HOST_READY"):
                if name == "host1":
                    launch("first", "persist_first", client + ["--vocation=druid"])
                else:
                    launch("return", "persist_return", client + ["--vocation=knight"])
            if line == "BRIMHOLT_PERSIST_IN":
                launch("duplicate", "persist_duplicate", client)
            if line.startswith("BRIMHOLT_TEST_PASS"):
                passed.add(name)
        raise RuntimeError("Persistence scenario timed out after 45 seconds")
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
        for process in processes.values():
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
        shutil.rmtree(saves, ignore_errors=True)


if __name__ == "__main__":
    main()
