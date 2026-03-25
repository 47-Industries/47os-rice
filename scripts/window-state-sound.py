#!/usr/bin/env python3
"""Plays sounds on window minimize/maximize/restore. Polls window states."""
import subprocess
import time
import os
import sys
import atexit
import signal

# Prevent duplicate instances
LOCK_FILE = "/tmp/window-state-sound.lock"
if os.path.exists(LOCK_FILE):
    try:
        old_pid = int(open(LOCK_FILE).read().strip())
        os.kill(old_pid, 0)  # Check if process is alive
        sys.exit(0)  # Already running, exit
    except (ProcessLookupError, ValueError, PermissionError):
        pass  # Stale lock, continue
with open(LOCK_FILE, "w") as f:
    f.write(str(os.getpid()))

def cleanup():
    try:
        os.remove(LOCK_FILE)
    except OSError:
        pass

atexit.register(cleanup)
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

MINIMIZE_SOUND = os.environ["HOME"] + "/Documents/47industries/sounds/minimize.ogg"
MAXIMIZE_SOUND = os.environ["HOME"] + "/Documents/47industries/sounds/maximize.ogg"
POLL_INTERVAL = 0.15

def get_state(wid):
    try:
        out = subprocess.check_output(
            ["xprop", "-id", wid, "_NET_WM_STATE"],
            text=True, stderr=subprocess.DEVNULL, timeout=1
        )
        s = set()
        if "_NET_WM_STATE_HIDDEN" in out:
            s.add("minimized")
        if "_NET_WM_STATE_MAXIMIZED_VERT" in out:
            s.add("maximized")
        return s
    except Exception:
        return None

def get_windows():
    try:
        out = subprocess.check_output(["wmctrl", "-l"], text=True, timeout=2)
        return [line.split()[0] for line in out.strip().split("\n") if line.strip()]
    except Exception:
        return []

def play(sound):
    subprocess.Popen(["47sound", "play", sound], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

prev = {}
for wid in get_windows():
    s = get_state(wid)
    if s is not None:
        prev[wid] = s

while True:
    time.sleep(POLL_INTERVAL)
    windows = get_windows()

    for wid in windows:
        new = get_state(wid)
        if new is None:
            continue
        old = prev.get(wid, set())

        if old == new:
            prev[wid] = new
            continue

        if "minimized" in new and "minimized" not in old:
            play(MINIMIZE_SOUND)
        elif "minimized" in old and "minimized" not in new:
            play(MAXIMIZE_SOUND)
        elif "maximized" in new and "maximized" not in old:
            play(MAXIMIZE_SOUND)
        elif "maximized" in old and "maximized" not in new:
            play(MINIMIZE_SOUND)

        prev[wid] = new

    # Clean up
    current = set(windows)
    for wid in list(prev):
        if wid not in current:
            del prev[wid]
