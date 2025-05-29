#!/bin/bash

# Name of the container to monitor
CONTAINER_NAME="$1"
OUTPUT_FILE_NAME=${2:-"$CONTAINER_NAME.csv"}

mkdir -p monitors

# Output CSV file
OUTPUT_FILE="monitors/docker_stats_${OUTPUT_FILE_NAME}"

# Check if container name is provided
if [ -z "$CONTAINER_NAME" ]; then
  echo "Usage: $0 <container_name>"
  exit 1
fi

# Write CSV header if the file doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "container_name,datetime,cpu_usage_percent,memory_usage" >> "$OUTPUT_FILE"
fi

# Infinite loop to log stats every second
while true; do
  # Get stats for the container (one-shot, no streaming)
  STATS=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" "$CONTAINER_NAME")

  echo "Stats: $STATS"

  # If the container is not found
  if [ -z "$STATS" ]; then
    echo "Container '$CONTAINER_NAME' not found."
    exit 1
  fi

  # Current date and time
  NOW=$(date +"%Y-%m-%d %H:%M:%S")

  # Parse and format the output
  IFS=',' read -r NAME CPU MEM <<< "$STATS"
  echo "$NAME,$NOW,$CPU,$MEM" >> "$OUTPUT_FILE"

  sleep 1
done
