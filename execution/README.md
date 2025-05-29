# Experiment execution

This folder contains the bash scripts used to execute the experiments described in the paper. 
The scripts are designed to be run on a Linux system with docker installed.

Usually we first download the GTFS feed, load it with gtfsdb-load in a SQLite database.
Then we start the docker containers for either TUP or Transitime.
After that we start monitoring scripts to collect performance measurements such as CPU and memory usage.
Finally, we start gtfsrdb for each container to collect the tripupdates provided by the containers.

## Pre-requisites

1. Docker needs to be installed.
2. You need to login into the GitHub Container Registry (ghcr.io) to pull the docker images used in the experiments. You can do this with:
   ```bash
   docker login ghcr.io
   ```
   Use your GitHub credentials or a personal access token with the `read:packages` scope.
3. Python needs to be installed with python-venv.
4. Clone our modified transitclockDocker repository:
   ```bash
   git clone https://github.com/SWT-Forschungsprojekt/transitclockDocker.git
   ```

## Experiment 1
Can be started with:
```bash
./experiment_1.sh
```
But first go into the `experiment_1.sh` file and edit some parameters for your needs, such as FEED_NAME, GTFS_URL, TRIP_UPDATES_URL, VEHICLE_POSITION_URL, PROTOBUF_FOLDER 

## Experiment 2

Can be started with:
```bash
./experiment_2.sh FEED_NAME GTFS_URL TRIP_UPDATES_URL VEHICLE_POSITION_URL MIN_LATITUDE MAX_LATITUDE MIN_LONGITUDE MAX_LONGITUDE <PORT> <TRANSITIME_PORT>"
```
<PORT> and <TRANSITIME_PORT> are optional, default to 8080 and 8081 respectively, but needs to be changed when mutliple experiments are run in parallel.

## Results

The monitoring CSV files are stored in the folder `monitors`.
The files contains the experiment number and the container name in the filename, e.g. `docker_stats_2-Arriva-tup.csv`.
The SQLite databases containing the data collected by gtfsrdb for origin, tup and transotime are stored in the folder `EXPERIMENT_NUMBER_experiment/FEED_NAME/`.
The realtime-metrics script can be used to extract the metrics for these databases.