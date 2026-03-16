#!/usr/bin/env python3
import sys, os, random, time, select, termios, tty, shutil

TEMPLATE = os.path.expanduser("~/.local/share/47industries/ascii-art.txt")
CHARS = "0123456789@#$%&*+=?><}{~^"

with open(TEMPLATE) as f:
    raw = [l.rstrip('\n') for l in f.readlines()]

# Remove trailing empty lines
while raw and not raw[-1].strip():
    raw.pop()

max_w = max(len(l) for l in raw)
lines = [l.ljust(max_w) for l in raw]
height = len(lines)

# Precompute mask
mask = []
for line in lines:
    mask.append([c == '@' for c in line])

# System info
def cmd(c):
    try:
        return os.popen(c + " 2>/dev/null").read().strip()
    except:
        return ""

# Static info (gathered once)
static_info = [
    "OS: " + cmd("grep '^PRETTY_NAME' /etc/os-release | cut -d'\"' -f2"),
    "Kernel: " + cmd("uname -r"),
    "CPU: " + cmd("lscpu | grep 'Model name' | sed 's/.*: *//'"),
    "GPU: " + cmd("lspci | grep -i vga | sed 's/.*: //' | head -1"),
    "Shell: bash " + os.environ.get("BASH_VERSION", ""),
    "WM: Muffin (X11)",
    "DE: " + os.environ.get("XDG_CURRENT_DESKTOP", ""),
    "Disk (/): " + cmd("df -h / | awk 'NR==2{print $3 \" / \" $2 \" (\" $5 \")\"}'"),
    "Packages: " + cmd("dpkg --list | grep -c '^ii'") + " (dpkg)",
]

# Dynamic info indices (these get refreshed)
DYNAMIC_START = 1  # insert after OS line
DYNAMIC_LABELS = ["Uptime", "Memory", "CPU Temp", "GPU Temp"]

def get_dynamic():
    cpu_temp = cmd("sensors 2>/dev/null | grep -i 'Package id 0\\|Tctl' | awk '{print $4}'") or "N/A"
    gpu_temp = cmd("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null")
    gpu_temp = (gpu_temp + "°C") if gpu_temp else "N/A"
    return [
        "Uptime: " + cmd("uptime -p").replace("up ", ""),
        "Memory: " + cmd("free -h | awk '/Mem:/{print $3 \" / \" $2}'"),
        "CPU Temp: " + cpu_temp,
        "GPU Temp: " + gpu_temp,
    ]

def get_info():
    dyn = get_dynamic()
    return static_info[:DYNAMIC_START] + dyn + static_info[DYNAMIC_START:]

info = get_info()
last_refresh = time.time()

GAP = "    "
W = "\033[1;97m"
C = "\033[1;36m"
R = "\033[0m"

def build_frame(cols):
    out = []
    for l in range(height):
        row = []
        for i in range(max_w):
            if mask[l][i]:
                row.append(random.choice(CHARS))
            else:
                row.append(' ')
        logo = "".join(row)
        if l < len(info):
            full = logo + GAP + info[l]
        else:
            full = logo
        # Truncate to terminal width to prevent wrapping
        if len(full) > cols:
            full = full[:cols]
        else:
            full = full.ljust(cols)
        out.append(full)
    return out

fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
tty.setcbreak(fd)

sys.stdout.write("\033[?25l\033[2J")
sys.stdout.flush()

try:
    while True:
        if select.select([sys.stdin], [], [], 0)[0]:
            sys.stdin.read(1)
            break
        # Refresh dynamic stats every 1 second
        now = time.time()
        if now - last_refresh >= 1.0:
            info = get_info()
            last_refresh = now
        cols = shutil.get_terminal_size().columns
        frame = build_frame(cols)
        sys.stdout.write("\033[H")
        for i, line in enumerate(frame):
            logo_part = line[:max_w]
            rest = line[max_w:]
            # Color the info: label in cyan, value in white
            if rest.strip() and ":" in rest:
                colon_pos = rest.index(":")
                label = rest[:colon_pos + 1]
                value = rest[colon_pos + 1:]
                sys.stdout.write(f"{W}{logo_part}{R}{C}{label}{W}{value}{R}")
            else:
                sys.stdout.write(f"{W}{logo_part}{R}{rest}")
            if i < height - 1:
                sys.stdout.write("\n")
        sys.stdout.flush()
        time.sleep(0.08)
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)
    sys.stdout.write("\033[?25h\033[2J\033[H")
    sys.stdout.flush()
