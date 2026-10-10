"""
Phase 5-8: Extract URL features from PhiUSIIL dataset.
Uses the EXISTING url_feature_extractor.py to ensure production compatibility.
Processes URLs in batches with progress reporting.
"""
import sys
import zipfile
import pandas as pd
import numpy as np
import json
import time
from pathlib import Path

# Add the backend to path so we can import the existing extractor
BACKEND_PATH = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\jansuraksha\backend")
sys.path.insert(0, str(BACKEND_PATH))

from feature_extraction.url_feature_extractor import extract_url_features, URL_FEATURE_COLUMNS

# Paths
ZIP_PATH = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\datasets\archive.zip")
OUTPUT_PATH = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\jansuraksha\ml_training\processed\url_features.csv")
REPORT_PATH = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\jansuraksha\ml_training\processed\url_data_report.json")

print("=" * 60)
print("PHASE 5-8: URL FEATURES EXTRACTION")
print("=" * 60)

# 1. Load the raw URL dataset
print("\n[1] Loading PhiUSIIL dataset from ZIP...")
with zipfile.ZipFile(ZIP_PATH, 'r') as zf:
    with zf.open('PhiUSIIL_Phishing_URL_Dataset.csv') as f:
        raw_df = pd.read_csv(f)

print(f"    Raw shape: {raw_df.shape}")
print(f"    Label column: 'label'")
print(f"    Label distribution:")
label_dist = raw_df['label'].value_counts()
print(f"      Legitimate (1): {label_dist.get(1, 0)}")
print(f"      Phishing (0): {label_dist.get(0, 0)}")

# 2. Extract only URL and label columns
print("\n[2] Extracting raw URLs...")
urls_df = raw_df[['URL', 'label']].copy()
urls_df = urls_df.dropna(subset=['URL'])
urls_df = urls_df[urls_df['URL'].str.strip() != '']
print(f"    Valid URLs: {len(urls_df)}")

# 3. Remove duplicate URLs
pre_dedup = len(urls_df)
urls_df = urls_df.drop_duplicates(subset=['URL'], keep='first')
print(f"    After URL dedup: {len(urls_df)} (removed {pre_dedup - len(urls_df)})")

# 4. Map labels: PhiUSIIL uses 1=legitimate, 0=phishing
# Our model uses 0=safe, 1=malicious/phishing
# So we need to INVERT: 1->0 (legitimate=safe), 0->1 (phishing=malicious)
urls_df['is_phishing'] = (urls_df['label'] == 0).astype(int)
print(f"\n[3] Label mapping (inverted for our schema):")
phishing_dist = urls_df['is_phishing'].value_counts()
print(f"    Safe (0): {phishing_dist.get(0, 0)}")
print(f"    Phishing (1): {phishing_dist.get(1, 0)}")

# 5. Extract features using existing extractor
print(f"\n[4] Extracting {len(urls_df)} URL features using production extractor...")
print(f"    Expected feature count: {len(URL_FEATURE_COLUMNS)}")
print(f"    This will take several minutes...")

all_features = []
errors = 0
start_time = time.time()
total = len(urls_df)

for idx, (_, row) in enumerate(urls_df.iterrows()):
    try:
        features = extract_url_features(row['URL'])
        features['is_phishing'] = row['is_phishing']
        features['original_url'] = row['URL'][:200]  # truncated for safety
        all_features.append(features)
    except Exception as e:
        errors += 1
        
    if (idx + 1) % 10000 == 0:
        elapsed = time.time() - start_time
        rate = (idx + 1) / elapsed
        remaining = (total - idx - 1) / rate
        print(f"    Progress: {idx+1}/{total} ({(idx+1)/total*100:.1f}%) | {rate:.0f} URLs/sec | ETA: {remaining:.0f}s | Errors: {errors}")

elapsed = time.time() - start_time
print(f"    Done! Processed {len(all_features)} URLs in {elapsed:.1f}s ({len(all_features)/elapsed:.0f} URLs/sec)")
print(f"    Errors: {errors}")

# 6. Create DataFrame
print("\n[5] Building feature DataFrame...")
features_df = pd.DataFrame(all_features)

# Verify feature columns match
produced_features = [c for c in features_df.columns if c in URL_FEATURE_COLUMNS]
missing_features = [c for c in URL_FEATURE_COLUMNS if c not in features_df.columns]
print(f"    Produced features: {len(produced_features)}/50")
if missing_features:
    print(f"    Missing: {missing_features}")

# 7. Check for nulls/infs
null_count = features_df[URL_FEATURE_COLUMNS].isnull().sum().sum()
inf_count = np.isinf(features_df[URL_FEATURE_COLUMNS].select_dtypes(include=[np.number])).sum().sum()
print(f"    Null values: {null_count}")
print(f"    Inf values: {inf_count}")

# 8. Save processed URL features
print("\n[6] Saving processed URL features...")
output_cols = URL_FEATURE_COLUMNS + ['is_phishing']
output_df = features_df[output_cols].copy()
output_df.to_csv(OUTPUT_PATH, index=False)
print(f"    Saved to: {OUTPUT_PATH}")
print(f"    Shape: {output_df.shape}")

# Final distribution
final_dist = output_df['is_phishing'].value_counts()

# 9. Save report
report = {
    "dataset": "PhiUSIIL_Phishing_URL_Dataset.csv",
    "raw_samples": int(raw_df.shape[0]),
    "valid_urls": int(len(urls_df)),
    "duplicates_removed": int(pre_dedup - len(urls_df)),
    "extraction_errors": int(errors),
    "final_samples": int(len(output_df)),
    "num_features": len(URL_FEATURE_COLUMNS),
    "feature_schema_match": len(missing_features) == 0,
    "safe_count": int(final_dist.get(0, 0)),
    "phishing_count": int(final_dist.get(1, 0)),
    "null_values": int(null_count),
    "infinite_values": int(inf_count),
    "extraction_time_seconds": round(elapsed, 1),
    "label_mapping": "PhiUSIIL label 1=legitimate->0=safe, label 0=phishing->1=phishing"
}

with open(REPORT_PATH, "w") as f:
    json.dump(report, f, indent=2)
print(f"    Report saved to: {REPORT_PATH}")

print(f"\n{'=' * 60}")
print("URL FEATURES EXTRACTION COMPLETE")
print(f"{'=' * 60}")
