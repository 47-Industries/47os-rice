#!/usr/bin/env bash
# Regression test for the battery applet's paint logic.
# Runs the real applet.js against a synthetic /sys battery tree, so charging,
# discharging, full, battery-saver and no-battery are all proven without
# needing a laptop in a particular state.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/BAT0" "$T/home/.config/47industries"
seed() {
    printf 'Battery'    > "$T/BAT0/type"
    printf '%s\n' "$1"  > "$T/BAT0/capacity"
    printf '%s\n' "$2"  > "$T/BAT0/status"
    printf '30000000\n' > "$T/BAT0/energy_now"
    printf '45000000\n' > "$T/BAT0/energy_full"
    printf '50000000\n' > "$T/BAT0/energy_full_design"
    printf '%s\n' "$3"  > "$T/BAT0/power_now"
    printf '%s\n' "$4"  > "$T/home/.config/47industries/power-mode"
}
run() { node applet-harness.js ../applets/fake-battery@custom/applet.js "$T" 2>&1; }
check() { if echo "$1" | grep -qF "$2"; then echo "  ok   $3"; else echo "  FAIL $3 — wanted: $2"; echo "$1"; FAILED=1; fi; }
absent() { if echo "$1" | grep -qF "$2"; then echo "  FAIL $3 — should NOT contain: $2"; echo "$1"; FAILED=1; else echo "  ok   $3"; fi; }
FAILED=0

seed 67 Charging 12000000 balanced
OUT=$(run); check "$OUT" '["label","67%"]'                   "charging label is a plain percent"
# Regression guard for 2026-09-05: the icon battery-*-charging-symbolic ALREADY
# draws a bolt. A second text bolt in the label was a visible duplicate. If
# anyone re-adds one, this fails.
absent "$OUT" '⚡'                                       "no duplicate text bolt in the label"
check "$OUT" 'battery-good-charging-symbolic'                "charging uses the charging icon"
check "$OUT" 'until full'                                    "charging shows time to full"

seed 67 Discharging 9000000 balanced
OUT=$(run); check "$OUT" '["label","67%"]'                   "on battery shows plain percent"
check "$OUT" 'left'                                          "on battery shows time remaining"

seed 67 Discharging 9000000 saver
OUT=$(run); check "$OUT" '["label","ECO 67%"]'               "battery saver shows ECO"
check "$OUT" 'Battery Saver ON'                              "battery saver shown in tooltip"

seed 100 Full 0 balanced
OUT=$(run); check "$OUT" 'battery-full-charged-symbolic'     "full uses the charged icon"

rm -rf "$T/BAT0"
OUT=$(run); check "$OUT" 'Always Plugged In'                 "no battery falls back to AC"

[ "$FAILED" = 0 ] && echo "battery applet: all checks passed" || { echo "battery applet: FAILURES"; exit 1; }
