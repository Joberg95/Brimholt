#!/usr/bin/env python3
"""Bounded real-ENet integration; uses only the Python standard library."""

import argparse
import queue
import socket
import subprocess
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
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        if args.occupied_port:
            result = subprocess.run(
                [args.godot, "--headless", "--path", str(root), "--", "--host", f"--port={port}"],
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
            "--script", "res://tests/peer_test.gd", "--",
            mode, f"--port={port}", f"--test-role={test_role(role)}",
        ] + (["--vocation=druid"] if role == "client" else [])
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
                        print("PASS: dedicated ENet movement/equipment/inventory, ferry travel, combat and disconnect cleanup")
                    else:
                        print("PASS: real ENet host/client/late-join movement, authority, "
                              "collision, cooldown, equip/unequip, inventory/ground sync and disconnect cleanup")
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


if __name__ == "__main__":
    main()
