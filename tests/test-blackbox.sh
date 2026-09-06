#!/usr/bin/env bash
# Proves the black box actually catches a hard death and does NOT cry wolf on
# a clean shutdown. Reproduction, not inspection: we run the real recorder,
# SIGKILL it (a lockup leaves no ExecStop), and require the report to say so.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BB="$HERE/../scripts/47os-blackbox"
FZ="$HERE/../scripts/47os-freeze"
TMP="$(mktemp -d)"; trap 'kill -9 $BBPID 2>/dev/null; rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }

export BLACKBOX_INTERVAL=0.2
FAKE="$TMP/blackbox.log"
sed "s#^LOG_DIR=/var/log/47os#LOG_DIR=$TMP#" "$BB" > "$TMP/bb"; chmod +x "$TMP/bb"
sed "s#^LOG=/var/log/47os/blackbox.log#LOG=$FAKE#" "$FZ" > "$TMP/fz"; chmod +x "$TMP/fz"
BBPID=""
# Redirect the recorder's stdio to a file. Backgrounding it inside a command
# substitution instead holds the substitution's stdout pipe open forever and
# the test hangs — which is exactly what happened the first time.
run_recorder() {  # $1 = seconds to let it run
    "$TMP/bb" >"$TMP/bb.out" 2>&1 &
    BBPID=$!
    sleep "$1"
}

echo "== 1. recorder writes heartbeats and survives missing hardware =="
run_recorder 1.2; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
n=$(grep -c '^20' "$FAKE" 2>/dev/null || true); n=${n:-0}
[ "$n" -ge 3 ] && ok "wrote $n heartbeats on a box with no battery and no dGPU" || no "only $n heartbeats"
grep -q 'aspm=' "$FAKE" && ok "records the PCIe ASPM policy" || no "no aspm field"
grep -q 'gpu=' "$FAKE" && ok "records dGPU runtime state" || no "no gpu field"

echo "== 2. a HARD death (SIGKILL, no ExecStop) is reported as a death =="
run_recorder 0.8; kill -KILL "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
run_recorder 0.8; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null  # a later boot closes the killed one
out=$("$TMP/fz" report 2>&1)
echo "$out" | grep -q 'died without shutting down' \
  && ok "report calls out the unexplained death" || { no "report missed the death"; echo "$out" | sed 's/^/      | /'; }
echo "$out" | grep -q 'State at the last heartbeat' \
  && ok "report prints the state at the moment of death" || no "no state dump"

echo "== 3. a CLEAN shutdown is NOT reported as a freeze =="
rm -f "$FAKE"
run_recorder 0.8; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
"$TMP/bb" --stop
run_recorder 0.5; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
out=$("$TMP/fz" report 2>&1)
echo "$out" | grep -q 'No unexplained deaths' \
  && ok "clean shutdown does not raise a false alarm" || { no "cried wolf on a clean shutdown"; echo "$out" | sed 's/^/      | /'; }

echo "== 4. crashwatch reports a lockup once, and never on a clean boot =="
CW="$HERE/../scripts/47os-crashwatch"
sed -e "s#^LOG=/var/log/47os/blackbox.log#LOG=$FAKE#" \
    -e "s#^CONF=/etc/47os/blackbox-report.conf#CONF=$TMP/report.conf#" \
    -e "s#^STAMP=/var/lib/47os/last-crash-reported#STAMP=$TMP/stamp#" \
    "$CW" > "$TMP/cw"; chmod +x "$TMP/cw"

# A clean-shutdown-only record must produce no report at all.
rm -f "$FAKE" "$TMP/stamp"
run_recorder 0.6; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
"$TMP/bb" --stop
run_recorder 0.4; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
"$TMP/cw" >/dev/null 2>&1
[ ! -s "$TMP/stamp" ] && ok "clean history: nothing reported" || no "reported a death that never happened"

# Now a real hard death, with a report endpoint configured.
rm -f "$FAKE" "$TMP/stamp"
run_recorder 0.6; kill -KILL "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
run_recorder 0.4; kill -TERM "$BBPID" 2>/dev/null; wait "$BBPID" 2>/dev/null
cat > "$TMP/report.conf" <<CONF
REPORT_URL=file://$TMP/never
CONF
"$TMP/cw" >/dev/null 2>&1
[ -s "$TMP/stamp" ] && ok "hard death: stamped $(cat "$TMP/stamp")" || no "did not detect the death"

# Second boot with the same record must NOT re-report the same death.
BEFORE="$(cat "$TMP/stamp" 2>/dev/null)"
"$TMP/cw" >/dev/null 2>&1
[ "$(cat "$TMP/stamp" 2>/dev/null)" = "$BEFORE" ] && ok "does not nag about the same death twice" || no "re-reported"

# And with NO config file it must still work and stay silent about the network.
rm -f "$TMP/report.conf" "$TMP/stamp"
"$TMP/cw" >/dev/null 2>&1 && ok "no config file: exits clean, no POST" || no "crashed without a config"

# The public repo must contain no owner constants. This is a dox check.
if grep -rEq '100\.(64|67|76|79)\.[0-9]+\.[0-9]+|deansabr|sabrtechnologies\.com|[0-9]{2} 18th Ave' "$CW" "$BB" "$FZ"; then
    no "OWNER CONSTANT LEAKED into a public-repo script"
else
    ok "no IPs, hostnames, usernames or domains in the shipped scripts"
fi

echo ""; echo "  final: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
