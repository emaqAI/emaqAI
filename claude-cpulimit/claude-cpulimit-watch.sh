#!/bin/bash
# Continuously caps every process belonging to the Claude desktop app at 50%
# of one core. Runs forever as a LaunchAgent; new Claude/helper processes are
# picked up within a few seconds of launch.

LIMIT=50
CPULIMIT=/usr/local/bin/cpulimit
declare -A seen

while true; do
    for pid in $(pgrep -f "/Applications/Claude.app/"); do
        if [[ -z "${seen[$pid]}" ]]; then
            seen[$pid]=1
            "$CPULIMIT" -l "$LIMIT" -p "$pid" -z >/dev/null 2>&1 &
        fi
    done

    for pid in "${!seen[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            unset 'seen[$pid]'
        fi
    done

    sleep 5
done
