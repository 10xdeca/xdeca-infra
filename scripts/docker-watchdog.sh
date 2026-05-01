#!/bin/bash
# Restart any stopped containers and log Docker health
LOG=/var/log/docker-watchdog.log

STOPPED=$(docker ps -a --filter "status=exited" --filter "label=com.docker.compose.project" --format "{{.Names}}" 2>/dev/null)

if [ -n "$STOPPED" ]; then
    echo "$(date): Restarting stopped containers: $STOPPED" >> "$LOG"
    for name in $STOPPED; do
        docker start "$name" 2>/dev/null
    done
fi

# Log container count as proof of activity
RUNNING=$(docker ps -q 2>/dev/null | wc -l)
echo "$(date): $RUNNING containers running" >> "$LOG"

# Rotate
tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
