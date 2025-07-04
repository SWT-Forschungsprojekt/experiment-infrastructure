#!/bin/bash



TUP_DOCKER_VERSION=main
TUP_DOCKER_IMAGE=ghcr.io/swt-forschungsprojekt/tup:$TUP_DOCKER_VERSION

EXPERIMENT_NUMBER=1
EXPERIMENT_FOLDER=${EXPERIMENT_NUMBER}_experiment

mkdir -p $EXPERIMENT_FOLDER

# Specify the feed
FEED_NAME=Arriva
GTFS_URL="http://gtfs.ovapi.nl/gtfs-nl.zip"
TRIP_UPDATES_URL=https://gtfs.ovapi.nl/nl/tripUpdates.pb
VEHICLE_POSITION_URL=https://gtfs.ovapi.nl/nl/vehiclePositions.pb

#FEED_NAME=TPBI
#GTFS_URL="https://gtfs.tpbi.ro/regional/BUCHAREST-REGION.zip"
#TRIP_UPDATES_URL=https://gtfs.tpbi.ro/api/gtfs-rt/tripUpdates
#VEHICLE_POSITION_URL=https://gtfs.tpbi.ro/api/gtfs-rt/vehiclePositions

HOST_PORT=${1:-9300}

TUP_PREDICTORS=( "gtfs-position-tracker" "schedule-based" "historic" )
# Specify the protobuf folder needed for the historic predictor
PROTOBUF_FOLDER=/opt/max/1_protobuf/protobufs

echo Pulling latest docker image of tup: $TUP_DOCKER_IMAGE
docker pull $TUP_DOCKER_IMAGE

# download gtfs feed

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


for predictor in "${TUP_PREDICTORS[@]}"; do
    echo "$predictor"
    CONTAINER_NAME=$EXPERIMENT_NUMBER-$FEED_NAME-tup-$predictor
    docker run --name $CONTAINER_NAME --user $(id -u):$(id -g) -v $PROTOBUF_FOLDER:/app/protobuf -v ./$EXPERIMENT_FOLDER/$FEED_NAME/input/:/app/input/ -p $HOST_PORT:8000 -d $TUP_DOCKER_IMAGE ./tup-backend -P $predictor --protobuf_input /app/protobuf -i input -v $VEHICLE_POSITION_URL

    echo Started docker container with name $CONTAINER_NAME on port $HOST_PORT

    screen -dmS "$EXPERIMENT_NUMBER-monitor-$FEED_NAME-tup-$predictor" bash -c "./monitor_container.sh $CONTAINER_NAME"

    cp ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME.db ./$EXPERIMENT_FOLDER/$FEED_NAME/$FEED_NAME-$predictor.db
    back=$(pwd)
    cd ./$EXPERIMENT_FOLDER/$FEED_NAME/
    $back/run_gtfsrdb.sh http://localhost:$HOST_PORT/tripUpdates "" $FEED_NAME-$predictor.db $EXPERIMENT_NUMBER-gtfsrdb-$FEED_NAME-tup-$predictor
    cd $back

    ((HOST_PORT += 1))

done
