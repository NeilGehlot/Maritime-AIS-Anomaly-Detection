import pandas as pd
from pathlib import Path

data_dir = Path(__file__).resolve().parent.parent / "data"

jan = pd.read_csv(data_dir / "gulf_ais_jan.csv")
feb = pd.read_csv(data_dir / "gulf_ais_feb.csv")
mar = pd.read_csv(data_dir / "gulf_ais_march.csv")

all_data = pd.concat([jan, feb, mar], ignore_index=True)
all_data.columns = ['mmsi', 'base_datetime', 'lat', 'lon', 'sog', 'cog', 'heading']

vessel_counts = all_data['mmsi'].value_counts()
good_vessels = vessel_counts[vessel_counts >= 50].index

print(f"Total qualifying vessels: {len(good_vessels)}")

sample_vessels = pd.Series(good_vessels).sample(n=8000, random_state=42)
medium_data = all_data[all_data['mmsi'].isin(sample_vessels)]

print(medium_data.shape)
medium_data.to_csv(data_dir / "gulf_ais_sample.csv", index=False)