# Performance Plot Generation

This folder contains the ``generatePlots.py`` script, which is used to generate performance plots for the monitors CSV files, which monitored for a specific docker container their memory and CPU usage.

# Usage

First install the required dependencies by running:

```bash
pip install -r requirements.txt
```

To generate the plots, place the CSV files in a folder named input and run the following command:

```bash
python generatePlots.py
```

# Output

The script will generate PNG files for each input CSV file in a folder named output. The generated plots will show the CPU and memory usage over time.
