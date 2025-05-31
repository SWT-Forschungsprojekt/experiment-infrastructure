#!/bin/bash

TUP_DOCKER_VERSION=main
TUP_DOCKER_IMAGE=ghcr.io/swt-forschungsprojekt/tup:$TUP_DOCKER_VERSION

EXPERIMENT_NUMBER=3
EXPERIMENT_FOLDER=${EXPERIMENT_NUMBER}_experiment

mkdir -p $EXPERIMENT_FOLDER

FEED_NAME=TPBI
GTFS_URL="https://gtfs.tpbi.ro/regional/BUCHAREST-REGION.zip"
TRIP_UPDATES_URL=https://gtfs.tpbi.ro/api/gtfs-rt/tripUpdates
VEHICLE_POSITION_URL=https://gtfs.tpbi.ro/api/gtfs-rt/vehiclePositions


HOST_PORT=${1:-9400}
TRANSITIME_HOST_PORT=${2:-9401}

MIN_LATITUDE=43.02
MAX_LATITUDE=48.78
MIN_LONGITUDE=19.57
MAX_LONGITUDE=30.23

echo Pulling latest docker image of tup: $TUP_DOCKER_IMAGE
docker pull $TUP_DOCKER_IMAGE

# Ensure FEED_NAME is set
if [ -z "$FEED_NAME" ]; then
  echo "FEED_NAME is not set. Please set it first."
  exit 1
fi

DO_FRESH_SETUP=false

DB_FILE="$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db"
ZIP_FILE="$EXPERIMENT_FOLDER/$FEED_NAME/input.zip"

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
      [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE" && rm -rf "./$EXPERIMENT_FOLDER/$FEED_NAME/input"
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
      mkdir -p "./$EXPERIMENT_FOLDER/$FEED_NAME/"
      wget -O "./$EXPERIMENT_FOLDER/$FEED_NAME/input.zip" "$GTFS_URL"
fi

# check if input folder exists
if [ ! -d "./$EXPERIMENT_FOLDER/$FEED_NAME/input" ]; then
  echo "Input folder does not exist. Unzipping it..."
  unzip "./$EXPERIMENT_FOLDER/$FEED_NAME/input.zip" -d "./$EXPERIMENT_FOLDER/$FEED_NAME/input"
fi

# check if $FEED_NAME.db exists
if [ ! -f "./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db" ]; then
  echo "Database file $FEED_NAME.db does not exist."
  # load gtfs feed into database
  back=$(pwd)
  cd ./$EXPERIMENT_FOLDER/$FEED_NAME
  $back/load_gtfs.sh $FEED_NAME.db input.zip
  cd $back
fi


TUP_DOCKER_CONTAINER_NAME=$EXPERIMENT_NUMBER-$FEED_NAME-tup-historic
TUP_PREDICTOR=historic

docker run --name $TUP_DOCKER_CONTAINER_NAME --user $(id -u):$(id -g) -v ./$EXPERIMENT_FOLDER/$FEED_NAME/input/:/app/input/ -p $HOST_PORT:8000 -d $TUP_DOCKER_IMAGE ./tup-backend -P $TUP_PREDICTOR -i input -v $VEHICLE_POSITION_URL

echo Started docker container with name $TUP_DOCKER_CONTAINER_NAME on port $HOST_PORT

screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-tup" bash -c "./monitor_container.sh $TUP_DOCKER_CONTAINER_NAME"

# transitime go script
cd transitclockDocker
./go.sh $TRANSITIME_HOST_PORT $FEED_NAME 1 $FEED_NAME $GTFS_URL $VEHICLE_POSITION_URL $MIN_LATITUDE $MAX_LATITUDE $MIN_LONGITUDE $MAX_LONGITUDE
cd ..

echo Started docker container for transitime on port $TRANSITIME_HOST_PORT

screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-transitime" bash -c "./monitor_container.sh $FEED_NAME-transitime-server $EXPERIMENT_NUMBER-$FEED_NAME-transitime-server.csv"
screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-transitime-db" bash -c "./monitor_container.sh $FEED_NAME-transitime-db $EXPERIMENT_NUMBER-$FEED_NAME-transitime-db.csv"

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

echo Copying database files for gtfsrdb from $EXPERIMENT_FOLDER/$FEED_NAME.db
cp ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME-tup.db
cp ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME-transitime.db
cp ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME-origin.db
back=$(pwd)
cd $EXPERIMENT_FOLDER/$FEED_NAME
# tup
$back/run_gtfsrdb.sh http://localhost:$HOST_PORT/tripUpdates "" $FEED_NAME-tup.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-tup
# transitime
TRANSITIME_API_KEY=$(docker container exec $FEED_NAME-transitime-server bash bin/get_api_key.sh)
$back/run_gtfsrdb.sh http://localhost:$TRANSITIME_HOST_PORT/api/v1/key/$TRANSITIME_API_KEY/agency/1/command/gtfs-rt/tripUpdates "" $FEED_NAME-transitime.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-transitime
echo Transitime TripUpdate URL: http://localhost:$TRANSITIME_HOST_PORT/api/v1/key/$TRANSITIME_API_KEY/agency/1/command/gtfs-rt/tripUpdates

cd $back

