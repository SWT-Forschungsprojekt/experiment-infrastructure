import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from pathlib import Path

# Ordner definieren
input_dir = Path("input")
output_dir = Path("output")
output_dir.mkdir(exist_ok=True)

def parse_memory(mem_str):
    try:
        value, _ = mem_str.split(' / ')
        if 'MiB' in value:
            return float(value.replace('MiB', ''))
        elif 'GiB' in value:
            return float(value.replace('GiB', '')) * 1024
    except:
        return 0
    return 0

def process_csv(csv_path):
    df = pd.read_csv(csv_path)

    df['datetime'] = pd.to_datetime(df['datetime'])
    df['cpu_usage_percent'] = df['cpu_usage_percent'].str.replace('%', '').astype(float)
    df['memory_usage_mib'] = df['memory_usage'].apply(parse_memory)

    # Plot
    fig, axs = plt.subplots(2, 1, figsize=(12, 8), sharex=True)

    axs[0].plot(df['datetime'], df['cpu_usage_percent'], label='CPU Usage (%)', color='tab:blue')
    axs[0].set_ylabel('CPU Usage (%)')
    axs[0].set_title('CPU Usage Over Time')
    axs[0].grid(True)

    axs[1].plot(df['datetime'], df['memory_usage_mib'], label='Memory Usage (MiB)', color='tab:green')
    axs[1].set_ylabel('Memory Usage (MiB)')
    axs[1].set_title('Memory Usage Over Time')
    axs[1].grid(True)

    axs[1].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
    plt.xticks(rotation=45)
    plt.tight_layout()

    output_file = output_dir / (csv_path.stem + ".png")
    plt.savefig(output_file, dpi=300)
    plt.close()

# Alle CSV-Dateien im Input-Ordner verarbeiten, sofern noch kein PNG existiert
for csv_file in input_dir.glob("*.csv"):
    output_file = output_dir / (csv_file.stem + ".png")
    if not output_file.exists():
        print(f"Verarbeite: {csv_file.name}")
        process_csv(csv_file)
    else:
        print(f"Überspringe (bereits vorhanden): {csv_file.name}")
