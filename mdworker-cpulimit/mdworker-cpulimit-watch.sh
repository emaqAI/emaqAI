#!/bin/bash
# Continuously caps every mdworker_shared (Spotlight indexing) process at 5%
# of one core. Runs forever as a LaunchAgent.

LIMIT=5
CPULIMIT=/usr/local/bin/cpulimit
declare -A seen

while true; do
    for pid in $(pgrep -x mdworker_shared); do
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
