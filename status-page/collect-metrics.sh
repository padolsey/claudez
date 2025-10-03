#!/usr/bin/env bash
# Collects metrics from all provision containers and outputs JSON
set -euo pipefail

OUTPUT_FILE="${1:-/opt/status-page/metrics.json}"
TEMP_FILE="${OUTPUT_FILE}.tmp"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Get current timestamp
TIMESTAMP=$(date -Iseconds)

# Get host-level metrics
HOST_MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_SWAP_FREE=$(awk '/SwapFree/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_COMMIT_LIMIT=$(awk '/CommitLimit/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_COMMITTED=$(awk '/Committed_AS/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
HOST_DISK_USAGE=$(df /opt/apps 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")

# Ensure values are not empty
[ -z "$HOST_MEM_TOTAL" ] && HOST_MEM_TOTAL="0"
[ -z "$HOST_MEM_AVAILABLE" ] && HOST_MEM_AVAILABLE="0"
[ -z "$HOST_SWAP_TOTAL" ] && HOST_SWAP_TOTAL="0"
[ -z "$HOST_SWAP_FREE" ] && HOST_SWAP_FREE="0"
[ -z "$HOST_COMMIT_LIMIT" ] && HOST_COMMIT_LIMIT="0"
[ -z "$HOST_COMMITTED" ] && HOST_COMMITTED="0"
[ -z "$HOST_DISK_USAGE" ] && HOST_DISK_USAGE="0"

# Build initial JSON using jq
jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg mem_total "$HOST_MEM_TOTAL" \
  --arg mem_available "$HOST_MEM_AVAILABLE" \
  --arg swap_total "$HOST_SWAP_TOTAL" \
  --arg swap_free "$HOST_SWAP_FREE" \
  --arg commit_limit "$HOST_COMMIT_LIMIT" \
  --arg committed "$HOST_COMMITTED" \
  --arg disk_usage "$HOST_DISK_USAGE" \
  '{
    timestamp: $timestamp,
    host: {
      memory_total_kb: ($mem_total | tonumber),
      memory_available_kb: ($mem_available | tonumber),
      swap_total_kb: ($swap_total | tonumber),
      swap_free_kb: ($swap_free | tonumber),
      commit_limit_kb: ($commit_limit | tonumber),
      committed_kb: ($committed | tonumber),
      disk_usage_percent: ($disk_usage | tonumber)
    },
    containers: []
  }' > "$TEMP_FILE"

# Get all containers with names ending in -app
CONTAINERS=$(docker ps -a --filter "name=-app$" --format "{{.Names}}" 2>/dev/null || echo "")

if [ -z "$CONTAINERS" ]; then
  mv "$TEMP_FILE" "$OUTPUT_FILE"
  exit 0
fi

# Collect stats for each container
STATS_JSON="[]"
for container in $CONTAINERS; do
  # Extract app name (remove -app suffix)
  APP_NAME="${container%-app}"

  # Get container state
  STATE=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
  HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
  STARTED_AT=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null || echo "")
  RESTART_COUNT=$(docker inspect -f '{{.RestartCount}}' "$container" 2>/dev/null || echo "0")

  # Get memory limits from Docker (in bytes)
  MEM_LIMIT_BYTES=$(docker inspect -f '{{.HostConfig.Memory}}' "$container" 2>/dev/null || echo "0")
  MEM_RESERVATION_BYTES=$(docker inspect -f '{{.HostConfig.MemoryReservation}}' "$container" 2>/dev/null || echo "0")

  # Convert to MB
  MEM_LIMIT_CONFIG=$(awk -v bytes="$MEM_LIMIT_BYTES" 'BEGIN {printf "%.0f", bytes/1024/1024}')
  MEM_RESERVATION_CONFIG=$(awk -v bytes="$MEM_RESERVATION_BYTES" 'BEGIN {printf "%.0f", bytes/1024/1024}')

  # Get resource stats (only if running)
  MEM_USAGE="0"
  MEM_LIMIT="0"
  MEM_PERCENT="0"
  CPU_PERCENT="0"

  if [ "$STATE" = "running" ]; then
    STATS=$(docker stats --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}" "$container" 2>/dev/null || echo "0B / 0B|0%")
    MEM_RAW=$(echo "$STATS" | cut -d'|' -f1)
    CPU_RAW=$(echo "$STATS" | cut -d'|' -f2)

    # Parse memory with units (e.g., "123.4MiB / 2GiB")
    MEM_USAGE_STR=$(echo "$MEM_RAW" | awk '{print $1}')
    MEM_LIMIT_STR=$(echo "$MEM_RAW" | awk '{print $3}')

    # Convert to MB, handling different units
    MEM_USAGE=$(echo "$MEM_USAGE_STR" | awk '
      /GiB$/ {gsub(/GiB/,""); print $0 * 1024; exit}
      /MiB$/ {gsub(/MiB/,""); print $0; exit}
      /KiB$/ {gsub(/KiB/,""); print $0 / 1024; exit}
      /GB$/ {gsub(/GB/,""); print $0 * 1000; exit}
      /MB$/ {gsub(/MB/,""); print $0; exit}
      /KB$/ {gsub(/KB/,""); print $0 / 1000; exit}
      {print "0"; exit}
    ' || echo "0")

    MEM_LIMIT=$(echo "$MEM_LIMIT_STR" | awk '
      /GiB$/ {gsub(/GiB/,""); print $0 * 1024; exit}
      /MiB$/ {gsub(/MiB/,""); print $0; exit}
      /KiB$/ {gsub(/KiB/,""); print $0 / 1024; exit}
      /GB$/ {gsub(/GB/,""); print $0 * 1000; exit}
      /MB$/ {gsub(/MB/,""); print $0; exit}
      /KB$/ {gsub(/KB/,""); print $0 / 1000; exit}
      {print "0"; exit}
    ' || echo "0")

    # Ensure values are not empty
    [ -z "$MEM_USAGE" ] && MEM_USAGE="0"
    [ -z "$MEM_LIMIT" ] && MEM_LIMIT="0"

    # Calculate percentage
    if [ "$MEM_USAGE" != "0" ] && [ "$MEM_LIMIT" != "0" ]; then
      MEM_PERCENT=$(awk -v u="$MEM_USAGE" -v l="$MEM_LIMIT" 'BEGIN {printf "%.1f", (u/l)*100}' || echo "0")
    fi

    CPU_PERCENT=$(echo "$CPU_RAW" | sed 's/%//g' || echo "0")
    [ -z "$CPU_PERCENT" ] && CPU_PERCENT="0"
  fi

  # Get workspace disk usage
  WORKSPACE_PATH="/opt/apps/${APP_NAME}/workspace"
  DISK_USAGE_MB="0"
  if [ -d "$WORKSPACE_PATH" ]; then
    DISK_USAGE_KB=$(du -s "$WORKSPACE_PATH" 2>/dev/null | awk '{print $1}' || echo "0")
    [ -z "$DISK_USAGE_KB" ] && DISK_USAGE_KB="0"
    DISK_USAGE_MB=$(awk -v kb="$DISK_USAGE_KB" 'BEGIN {printf "%.0f", kb/1024}' || echo "0")
  fi

  # Get recent memory pressure events
  MEMORY_LOG="${WORKSPACE_PATH}/.debug/memory.log"
  MEMORY_EVENTS="[]"
  if [ -f "$MEMORY_LOG" ]; then
    # Get last 5 pressure events (lines starting with ===)
    EVENTS=$(grep "^===" "$MEMORY_LOG" 2>/dev/null | tail -5 || echo "")
    if [ -n "$EVENTS" ]; then
      MEMORY_EVENTS=$(echo "$EVENTS" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi
  fi

  # Get PM2 processes (if container is running)
  PM2_PROCESSES="[]"
  if [ "$STATE" = "running" ]; then
    # pm2 jlist outputs banner text to stderr, so redirect stderr and only get JSON from stdout
    # Also filter to only lines that look like JSON (start with [ or {)
    PM2_JSON=$(docker exec "$container" su -m appuser -c "PM2_HOME=/home/appuser/.pm2 pm2 jlist 2>/dev/null" | grep -E '^\[|^\{' | head -1 || echo "[]")
    if [ "$PM2_JSON" != "[]" ] && [ -n "$PM2_JSON" ]; then
      PM2_PROCESSES=$(echo "$PM2_JSON" | jq -c '[.[] | {name: .name, status: .pm2_env.status, uptime: .pm2_env.pm_uptime, cpu: .monit.cpu, memory: .monit.memory}]' 2>/dev/null || echo "[]")
    fi
  fi

  # Build container JSON
  CONTAINER_JSON=$(jq -n \
    --arg name "$APP_NAME" \
    --arg state "$STATE" \
    --arg health "$HEALTH" \
    --arg started "$STARTED_AT" \
    --arg restart_count "$RESTART_COUNT" \
    --arg mem_usage "$MEM_USAGE" \
    --arg mem_limit "$MEM_LIMIT" \
    --arg mem_percent "$MEM_PERCENT" \
    --arg mem_limit_config "$MEM_LIMIT_CONFIG" \
    --arg mem_reservation_config "$MEM_RESERVATION_CONFIG" \
    --arg cpu_percent "$CPU_PERCENT" \
    --arg disk_mb "$DISK_USAGE_MB" \
    --argjson memory_events "$MEMORY_EVENTS" \
    --argjson pm2_processes "$PM2_PROCESSES" \
    '{
      name: $name,
      state: $state,
      health: $health,
      started_at: $started,
      restart_count: ($restart_count | tonumber),
      memory_usage_mb: ($mem_usage | tonumber),
      memory_limit_mb: ($mem_limit | tonumber),
      memory_percent: ($mem_percent | tonumber),
      memory_limit_config_mb: ($mem_limit_config | tonumber),
      memory_reservation_mb: ($mem_reservation_config | tonumber),
      cpu_percent: ($cpu_percent | tonumber),
      disk_usage_mb: ($disk_mb | tonumber),
      memory_pressure_events: $memory_events,
      pm2_processes: $pm2_processes
    }')

  # Append to stats array
  STATS_JSON=$(echo "$STATS_JSON" | jq --argjson container "$CONTAINER_JSON" '. += [$container]')
done

# Merge containers into final JSON
jq --argjson containers "$STATS_JSON" '.containers = $containers' "$TEMP_FILE" > "$OUTPUT_FILE"

# Cleanup
rm -f "$TEMP_FILE"
