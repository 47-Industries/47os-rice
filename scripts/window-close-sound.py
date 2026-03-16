#!/usr/bin/env python3
"""Plays a sound when windows are closed. Polls window list."""
import subprocess
import time
import os
import sys

# Prevent duplicate instances
LOCK_FILE = "/tmp/window-close-sound.lock"
if os.path.exists(LOCK_FILE):
    try:
        old_pid = int(open(LOCK_FILE).read().strip())
        os.kill(old_pid, 0)  # Check if process is alive
        sys.exit(0)  # Already running, exit
    except (ProcessLookupError, ValueError, PermissionError):
        pass  # Stale lock, continue
with open(LOCK_FILE, "w") as f:
    f.write(str(os.getpid()))

CLOSE_SOUND = os.environ["HOME"] + "/Documents/47industries/sounds/close.mp3"
POLL_INTERVAL = 0.15

def get_windows():
    try:
        out = subprocess.check_output(["wmctrl", "-l"], text=True, timeout=2)
        return set(line.split()[0] for line in out.strip().split("\n") if line.strip())
    except Exception:
        return set()

def play(sound):
    subprocess.Popen(["47sound", "play", sound], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

known = get_windows()

while True:
    time.sleep(POLL_INTERVAL)
    current = get_windows()
    closed = known - current
    if closed and len(closed) <= 3:
        play(CLOSE_SOUND)
    known = current
