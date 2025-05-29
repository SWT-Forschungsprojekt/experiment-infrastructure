if [ $# -lt 2 ]; then
  echo "Usage: $0 DATABASE_NAME GTFS_ZIP_FILE"
  exit 1
fi

DATABASE_NAME=$1
GTFS_ZIP_FILE=$2

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install --upgrade pip setuptools
pip install git+https://github.com/1Maxnet1/gtfsdb.git@patch-1 setuptools

echo "Loading $GTFS_ZIP_FILE into databse $DATABASE_NAME ..."

gtfsdb-load --database_url "sqlite:///${DATABASE_NAME}" "$GTFS_ZIP_FILE"

echo "Loaded gtfs into database $DATABASE_NAME"
