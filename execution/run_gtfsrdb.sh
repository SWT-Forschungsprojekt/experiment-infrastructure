#!/bin/bash

TRIP_UPDATES_URL=$1
VEHICLE_POSITION_URL=$2
DATABASE=$3
SCREEN_NAME=$4

# Check that at least one URL is provided
if [ -z "$TRIP_UPDATES_URL" ] && [ -z "$VEHICLE_POSITION_URL" ]; then
    echo "Error: You must specify at least one of TRIP_UPDATES_URL or VEHICLE_POSITION_URL."
    exit 1
fi

# Check that database path is provided
if [ -z "$DATABASE" ]; then
    echo "Error: DATABASE argument is required."
    exit 1
fi

if [ -z "$SCREEN_NAME" ]; then
    echo "Error: SCREEN_NAME argument is required."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "gtfsrdb_venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv gtfsrdb_venv
fi

# Activate virtual environment command (for screen, we run this inside the command string)
ACTIVATE_CMD="source $(pwd)/gtfsrdb_venv/bin/activate"
PIP_INSTALL_CMD="pip install git+https://github.com/public-transport/gtfsrdb"


# Build gtfsrdb command with conditionals
GTFSRDB_CMD="gtfsrdb"
[ -n "$TRIP_UPDATES_URL" ] && GTFSRDB_CMD+=" -t $TRIP_UPDATES_URL"
[ -n "$VEHICLE_POSITION_URL" ] && GTFSRDB_CMD+=" -p $VEHICLE_POSITION_URL"
GTFSRDB_CMD+=" -d sqlite:///$DATABASE -c -v"

# Full command to run inside screen (activate venv and run gtfsrdb)
FULL_CMD="$ACTIVATE_CMD && $PIP_INSTALL_CMD && $GTFSRDB_CMD"

echo "Starting gtfsrdb in detached screen session named '$SCREEN_NAME'..."
echo "Command: $FULL_CMD"

# Check if a screen session with the same name already exists
if screen -list | grep -q "[.]$SCREEN_NAME"; then
  echo "A screen session named '$SCREEN_NAME' already exists."
  echo "Use 'screen -r $SCREEN_NAME' to reattach or 'screen -XS $SCREEN_NAME quit' to terminate it."
  exit 1
fi

# Run in detached screen session
screen -dmS "$SCREEN_NAME" bash -c "$FULL_CMD"

echo "You can reattach with: screen -r $SCREEN_NAME"
