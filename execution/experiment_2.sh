#!/bin/bash

TUP_DOCKER_VERSION=main
TUP_DOCKER_IMAGE=ghcr.io/swt-forschungsprojekt/tup:$TUP_DOCKER_VERSION

# Check if at least one argument is passed
if [ $# -lt 8 ]; then
  echo "Usage: $0 FEED_NAME GTFS_URL TRIP_UPDATES_URL VEHICLE_POSITION_URL MIN_LATITUDE MAX_LATITUDE MIN_LONGITUDE MAX_LONGITUDE <PORT> <TRANSITIME_PORT>"
  exit 1
fi

FEED_NAME=$1
GTFS_URL=$2
TRIP_UPDATES_URL=$3
VEHICLE_POSITION_URL=$4
MIN_LATITUDE="$5"
MAX_LATITUDE="$6"
MIN_LONGITUDE="$7"
MAX_LONGITUDE="$8"

HOST_PORT=${9:-8000}
TRANSITIME_HOST_PORT=${10:-8001}

TUP_DOCKER_CONTAINER_NAME=2-$FEED_NAME-tup
TUP_PREDICTOR=schedule-based

echo Pulling latest docker image of tup: $TUP_DOCKER_IMAGE
docker pull $TUP_DOCKER_IMAGE


# download gtfs feed

# Ensure FEED_NAME is set
if [ -z "$FEED_NAME" ]; then
  echo "FEED_NAME is not set. Please set it first."
  exit 1
fi

EXPERIMENT_NUMBER=2
EXPERIMENT_FOLDER=${EXPERIMENT_NUMBER}_experiment/$FEED_NAME

mkdir -p $EXPERIMENT_FOLDER

DO_FRESH_SETUP=false

DB_FILE="$EXPERIMENT_FOLDER/$FEED_NAME.db"
ZIP_FILE="$EXPERIMENT_FOLDER/input.zip"

# Check if either file exists
if [ -f "$DB_FILE" ] || [ -f "$ZIP_FILE" ]; then
  echo "The following existing files were found:"
  [ -f "$DB_FILE" ] && echo " - $DB_FILE"
  [ -f "$ZIP_FILE" ] && echo " - $ZIP_FILE"

  read -p "Do you want to continue with these files? (y to continue / n to delete and start over): " response

  case "$response" in
    [Yy])
      echo "Continuing with existing files."
      ;;
    [Nn])
      echo "Deleting old files..."
      [ -f "$DB_FILE" ] && rm -f "$DB_FILE"
      [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE" && rm -rf "./$EXPERIMENT_FOLDER/input"
      echo "Old files deleted."
      DO_FRESH_SETUP=true
      ;;
    *)
      echo "Invalid input. Exiting."
      exit 1
      ;;
  esac
else
  DO_FRESH_SETUP=true
fi

# Run fresh setup if needed
if [ "$DO_FRESH_SETUP" = true ]; then
      echo "Starting fresh setup..."
      mkdir -p "./$EXPERIMENT_FOLDER/"
      wget -O "./$EXPERIMENT_FOLDER/input.zip" "$GTFS_URL"
      unzip "./$EXPERIMENT_FOLDER/input.zip" -d "./$EXPERIMENT_FOLDER/input"
      chmod u+rw ./$EXPERIMENT_FOLDER/input/*.txt
      # load gtfs feed into database
      back=$(pwd)
      cd ./$EXPERIMENT_FOLDER
      $back/load_gtfs.sh $FEED_NAME.db input.zip
      cd $back
fi

docker run --name $TUP_DOCKER_CONTAINER_NAME --user $(id -u):$(id -g) -v ./$EXPERIMENT_FOLDER/input/:/app/input/ -p $HOST_PORT:8000 -d $TUP_DOCKER_IMAGE ./tup-backend -P $TUP_PREDICTOR -i input -v $VEHICLE_POSITION_URL

echo Started docker container with name $TUP_DOCKER_CONTAINER_NAME on port $HOST_PORT

screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-tup" bash -c "./monitor_container.sh $TUP_DOCKER_CONTAINER_NAME"

# transitime go script
cd transitclockDocker
./go.sh $TRANSITIME_HOST_PORT $FEED_NAME 1 $FEED_NAME $GTFS_URL $VEHICLE_POSITION_URL $MIN_LATITUDE $MAX_LATITUDE $MIN_LONGITUDE $MAX_LONGITUDE
cd ..

echo Started docker container for transitime on port $TRANSITIME_HOST_PORT

screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-transitime" bash -c "./monitor_container.sh $FEED_NAME-transitime-server 2-$FEED_NAME-transitime-server.csv"
screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-transitime-db" bash -c "./monitor_container.sh $FEED_NAME-transitime-db 2-$FEED_NAME-transitime-db.csv"

echo "Starting gtfsrdb"

if [ -f "./$EXPERIMENT_FOLDER/$FEED_NAME-tup.db" ]; then
  echo "WARNING: The file './$EXPERIMENT_FOLDER/$FEED_NAME-tup.db' already exists."
  read -p "Continuing will overwrite this file. Do you want to proceed? (y/N): " confirm
  case "$confirm" in
    [Yy])
      echo "Proceeding..."
      ;;
    *)
      echo "Aborting to prevent overwrite."
      exit 1
      ;;
  esac
fi

cp ./$EXPERIMENT_FOLDER/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME-tup.db
cp ./$EXPERIMENT_FOLDER/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME-transitime.db
cp ./$EXPERIMENT_FOLDER/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME-origin.db
back=$(pwd)
cd $EXPERIMENT_FOLDER
# tup
$back/run_gtfsrdb.sh http://localhost:$HOST_PORT/tripUpdates "" $FEED_NAME-tup.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-tup
# transitime
TRANSITIME_API_KEY=$(docker container exec $FEED_NAME-transitime-server bash bin/get_api_key.sh)
$back/run_gtfsrdb.sh http://localhost:$TRANSITIME_HOST_PORT/api/v1/key/$TRANSITIME_API_KEY/agency/1/command/gtfs-rt/tripUpdates "" $FEED_NAME-transitime.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-transitime
echo Transitime TripUpdate URL: http://localhost:$TRANSITIME_HOST_PORT/api/v1/key/$TRANSITIME_API_KEY/agency/1/command/gtfs-rt/tripUpdates
# origin
$back/run_gtfsrdb.sh $TRIP_UPDATES_URL $VEHICLE_POSITION_URL $FEED_NAME-origin.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-origin
cd $back

