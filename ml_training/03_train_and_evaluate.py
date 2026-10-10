"""
Phase 9-16: Complete ML Training, Evaluation, and Comparison Pipeline.
Trains file and URL models, evaluates them, compares with existing production models,
and saves candidate models with metadata.
"""
import sys
import time
import json
import joblib
import warnings
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime

from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report
)

# Suppress warnings for cleaner output
warnings.filterwarnings('ignore')

# Try to import gradient boosting libs
try:
    from xgboost import XGBClassifier
    HAS_XGB = True
except ImportError:
    HAS_XGB = False
    print("WARNING: xgboost not installed")

try:
    from lightgbm import LGBMClassifier
    HAS_LGBM = True
except ImportError:
    HAS_LGBM = False
    print("WARNING: lightgbm not installed")

try:
    from catboost import CatBoostClassifier
    HAS_CATBOOST = True
except ImportError:
    HAS_CATBOOST = False
    print("WARNING: catboost not installed")

# Paths
BASE_DIR = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\jansuraksha\ml_training")
PROCESSED_DIR = BASE_DIR / "processed"
OUTPUT_DIR = BASE_DIR / "output_models"
SAVED_MODELS_DIR = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx\jansuraksha\backend\saved_models")

# Feature columns (must match production exactly)
FILE_FEATURE_COLUMNS = [
    "file_size", "entropy", "suspicious_strings_count", "url_count", "email_count",
    "age_days", "time_delta_days",
    "pdf_num_pages", "pdf_has_javascript", "pdf_js_count", "pdf_has_embedded_files",
    "pdf_embedded_files_count", "pdf_has_openaction", "pdf_has_launch_action",
    "pdf_num_objects", "pdf_num_streams", "pdf_has_metadata", "pdf_metadata_keys_count",
    "pdf_is_encrypted", "pdf_num_fonts", "pdf_num_images", "pdf_suspicious_keywords_count",
    "office_has_macros", "office_macro_count", "office_external_links_count",
    "office_ole_objects_count", "office_has_embedded_exe", "office_has_auto_open",
    "office_num_hidden_elements", "office_num_relationships", "office_has_metadata",
    "office_compression_ratio"
]

URL_FEATURE_COLUMNS = [
    'url_length', 'domain_length', 'path_length', 'query_length', 'fragment_length',
    'num_dots', 'num_hyphens', 'num_underscores', 'num_slashes', 'num_questionmarks',
    'num_equals', 'num_ats', 'num_ampersands', 'num_exclamation', 'num_tildes',
    'num_commas', 'num_plus', 'num_stars', 'num_hash', 'num_dollar', 'num_percent',
    'num_digits', 'num_letters', 'digit_ratio', 'special_char_ratio',
    'is_https', 'is_http', 'has_port',
    'is_ip_address', 'has_at_symbol', 'subdomain_count', 'domain_token_count',
    'tld_length', 'is_high_risk_tld', 'domain_entropy',
    'path_token_count', 'max_path_token_length',
    'query_param_count', 'query_value_max_length',
    'has_redirect', 'double_slash_redirect',
    'encoded_char_count', 'has_encoded_chars', 'obfuscation_score', 'url_decode_diff',
    'suspicious_keyword_count', 'has_suspicious_keywords',
    'brand_impersonation', 'url_entropy', 'is_shortened'
]


def evaluate_model(model, X_test, y_test, model_name):
    """Evaluate a model and return comprehensive metrics."""
    start = time.time()
    y_pred = model.predict(X_test)
    inference_time = (time.time() - start) / len(X_test) * 1000  # ms per sample
    
    if hasattr(model, 'predict_proba'):
        y_proba = model.predict_proba(X_test)[:, 1]
        roc_auc = roc_auc_score(y_test, y_proba)
    else:
        roc_auc = roc_auc_score(y_test, y_pred)
    
    tn, fp, fn, tp = confusion_matrix(y_test, y_pred).ravel()
    
    return {
        'model_name': model_name,
        'accuracy': round(accuracy_score(y_test, y_pred), 4),
        'precision': round(precision_score(y_test, y_pred, zero_division=0), 4),
        'recall': round(recall_score(y_test, y_pred, zero_division=0), 4),
        'f1': round(f1_score(y_test, y_pred, zero_division=0), 4),
        'roc_auc': round(roc_auc, 4),
        'true_positives': int(tp),
        'true_negatives': int(tn),
        'false_positives': int(fp),
        'false_negatives': int(fn),
        'fpr': round(fp / max(fp + tn, 1), 4),
        'fnr': round(fn / max(fn + tp, 1), 4),
        'inference_ms_per_sample': round(inference_time, 4),
    }


def train_and_evaluate_models(X_train, y_train, X_test, y_test, model_type="file"):
    """Train multiple models, evaluate, and return results."""
    models = {}
    results = []
    
    if model_type == "file":
        candidates = {
            'RandomForest': RandomForestClassifier(n_estimators=200, max_depth=20, random_state=42, n_jobs=-1),
        }
        if HAS_XGB:
            candidates['XGBoost'] = XGBClassifier(n_estimators=200, max_depth=8, learning_rate=0.1, 
                                                   random_state=42, eval_metric='logloss', verbosity=0)
        if HAS_LGBM:
            candidates['LightGBM'] = LGBMClassifier(n_estimators=200, max_depth=15, learning_rate=0.1,
                                                     random_state=42, verbose=-1)
        if HAS_CATBOOST:
            candidates['CatBoost'] = CatBoostClassifier(iterations=200, depth=8, learning_rate=0.1,
                                                         random_seed=42, verbose=0)
    else:  # URL
        candidates = {
            'LogisticRegression': LogisticRegression(max_iter=1000, random_state=42),
            'RandomForest': RandomForestClassifier(n_estimators=200, max_depth=20, random_state=42, n_jobs=-1),
        }
        if HAS_XGB:
            candidates['XGBoost'] = XGBClassifier(n_estimators=200, max_depth=8, learning_rate=0.1,
                                                   random_state=42, eval_metric='logloss', verbosity=0)
        if HAS_LGBM:
            candidates['LightGBM'] = LGBMClassifier(n_estimators=200, max_depth=15, learning_rate=0.1,
                                                     random_state=42, verbose=-1)
        if HAS_CATBOOST:
            candidates['CatBoost'] = CatBoostClassifier(iterations=200, depth=8, learning_rate=0.1,
                                                         random_seed=42, verbose=0)
    
    for name, model in candidates.items():
        print(f"  Training {name}...")
        start = time.time()
        model.fit(X_train, y_train)
        train_time = time.time() - start
        print(f"    Trained in {train_time:.1f}s")
        
        # Cross-validation on training data
        cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        cv_scores = cross_val_score(model, X_train, y_train, cv=cv, scoring='f1')
        print(f"    CV F1: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
        
        # Evaluate on test set
        metrics = evaluate_model(model, X_test, y_test, name)
        metrics['cv_f1_mean'] = round(cv_scores.mean(), 4)
        metrics['cv_f1_std'] = round(cv_scores.std(), 4)
        metrics['train_time_seconds'] = round(train_time, 1)
        results.append(metrics)
        models[name] = model
        
        print(f"    Test: Acc={metrics['accuracy']}, F1={metrics['f1']}, Recall={metrics['recall']}, FN={metrics['false_negatives']}")
    
    return models, results


def evaluate_existing_model(model_path, imputer_path, scaler_path, cols_path, X_test, y_test, feature_cols, model_name):
    """Evaluate an existing production model on the new test set."""
    try:
        model = joblib.load(model_path)
        imputer = joblib.load(imputer_path)
        scaler = joblib.load(scaler_path)
        saved_cols = joblib.load(cols_path)
        
        # Align features
        X_aligned = X_test[feature_cols].copy()
        X_imputed = imputer.transform(X_aligned)
        X_scaled = scaler.transform(X_imputed)
        
        metrics = evaluate_model(model, X_scaled, y_test, f"EXISTING {model_name}")
        print(f"  Existing {model_name}: Acc={metrics['accuracy']}, F1={metrics['f1']}, Recall={metrics['recall']}, FN={metrics['false_negatives']}")
        return metrics
    except Exception as e:
        print(f"  ERROR evaluating existing {model_name}: {e}")
        return None


# ================================================================
# MAIN TRAINING PIPELINE
# ================================================================
print("=" * 70)
print("SCAMundo ML TRAINING & EVALUATION PIPELINE")
print(f"Started: {datetime.now().isoformat()}")
print("=" * 70)

all_results = {}

# ================================================================
# PART 1: FILE MALWARE MODELS
# ================================================================
print("\n" + "=" * 70)
print("PART 1: FILE MALWARE DETECTION MODELS")
print("=" * 70)

file_features_path = PROCESSED_DIR / "file_features.csv"
if not file_features_path.exists():
    print("ERROR: file_features.csv not found!")
    sys.exit(1)

df_file = pd.read_csv(file_features_path)
print(f"\nDataset: {len(df_file)} samples")
print(f"Features: {len(FILE_FEATURE_COLUMNS)}")
print(f"Labels: {df_file['is_malicious'].value_counts().to_dict()}")

# Prepare features
X_file = df_file[FILE_FEATURE_COLUMNS].copy()
y_file = df_file['is_malicious'].copy()

# 80/20 stratified split
X_train_f, X_test_f, y_train_f, y_test_f = train_test_split(
    X_file, y_file, test_size=0.2, random_state=42, stratify=y_file
)
print(f"\nTrain: {len(X_train_f)} | Test: {len(X_test_f)}")
print(f"Train label dist: {y_train_f.value_counts().to_dict()}")
print(f"Test label dist:  {y_test_f.value_counts().to_dict()}")

# Preprocessing
print("\nPreprocessing (impute + scale)...")
file_imputer = SimpleImputer(strategy='median')
file_scaler = StandardScaler()

X_train_f_imp = file_imputer.fit_transform(X_train_f)
X_train_f_scaled = file_scaler.fit_transform(X_train_f_imp)

X_test_f_imp = file_imputer.transform(X_test_f)
X_test_f_scaled = file_scaler.transform(X_test_f_imp)

# Evaluate EXISTING production file model
print("\n--- Existing Production File Model ---")
existing_file_metrics = evaluate_existing_model(
    SAVED_MODELS_DIR / "best_model.joblib",
    SAVED_MODELS_DIR / "imputer.joblib",
    SAVED_MODELS_DIR / "scaler.joblib",
    SAVED_MODELS_DIR / "feature_columns.joblib",
    X_test_f, y_test_f, FILE_FEATURE_COLUMNS,
    "File-LightGBM"
)

# Train new file models
print("\n--- Training New File Models ---")
file_models, file_results = train_and_evaluate_models(
    X_train_f_scaled, y_train_f, X_test_f_scaled, y_test_f, model_type="file"
)

if existing_file_metrics:
    file_results.insert(0, existing_file_metrics)

all_results['file'] = file_results

# Feature importance for best new model
best_file_model_name = max(
    [(r['model_name'], r['f1']) for r in file_results if not r['model_name'].startswith('EXISTING')],
    key=lambda x: x[1]
)[0]
best_file_model = file_models[best_file_model_name]

print(f"\nBest new file model: {best_file_model_name}")
if hasattr(best_file_model, 'feature_importances_'):
    importances = best_file_model.feature_importances_
    feat_imp = sorted(zip(FILE_FEATURE_COLUMNS, importances), key=lambda x: x[1], reverse=True)
    print("Top 10 important features:")
    for fname, fimp in feat_imp[:10]:
        print(f"  {fname}: {fimp:.4f}")


# ================================================================
# PART 2: URL PHISHING MODELS
# ================================================================
print("\n" + "=" * 70)
print("PART 2: URL PHISHING DETECTION MODELS")
print("=" * 70)

url_features_path = PROCESSED_DIR / "url_features.csv"
if not url_features_path.exists():
    print("ERROR: url_features.csv not found! Run 02_extract_url_features.py first.")
    sys.exit(1)

df_url = pd.read_csv(url_features_path)
print(f"\nDataset: {len(df_url)} samples")
print(f"Features: {len(URL_FEATURE_COLUMNS)}")
print(f"Labels: {df_url['is_phishing'].value_counts().to_dict()}")

# Prepare features
X_url = df_url[URL_FEATURE_COLUMNS].copy()
y_url = df_url['is_phishing'].copy()

# 80/20 stratified split
X_train_u, X_test_u, y_train_u, y_test_u = train_test_split(
    X_url, y_url, test_size=0.2, random_state=42, stratify=y_url
)
print(f"\nTrain: {len(X_train_u)} | Test: {len(X_test_u)}")
print(f"Train label dist: {y_train_u.value_counts().to_dict()}")
print(f"Test label dist:  {y_test_u.value_counts().to_dict()}")

# Preprocessing
print("\nPreprocessing (impute + scale)...")
url_imputer = SimpleImputer(strategy='median')
url_scaler = StandardScaler()

X_train_u_imp = url_imputer.fit_transform(X_train_u)
X_train_u_scaled = url_scaler.fit_transform(X_train_u_imp)

X_test_u_imp = url_imputer.transform(X_test_u)
X_test_u_scaled = url_scaler.transform(X_test_u_imp)

# Evaluate EXISTING production URL model
print("\n--- Existing Production URL Model ---")
existing_url_metrics = evaluate_existing_model(
    SAVED_MODELS_DIR / "url_model.joblib",
    SAVED_MODELS_DIR / "url_imputer.joblib",
    SAVED_MODELS_DIR / "url_scaler.joblib",
    SAVED_MODELS_DIR / "url_feature_columns.joblib",
    X_test_u, y_test_u, URL_FEATURE_COLUMNS,
    "URL-XGBoost"
)

# Train new URL models
print("\n--- Training New URL Models ---")
url_models, url_results = train_and_evaluate_models(
    X_train_u_scaled, y_train_u, X_test_u_scaled, y_test_u, model_type="url"
)

if existing_url_metrics:
    url_results.insert(0, existing_url_metrics)

all_results['url'] = url_results

# Feature importance for best new URL model
best_url_model_name = max(
    [(r['model_name'], r['f1']) for r in url_results if not r['model_name'].startswith('EXISTING')],
    key=lambda x: x[1]
)[0]
best_url_model = url_models[best_url_model_name]

print(f"\nBest new URL model: {best_url_model_name}")
if hasattr(best_url_model, 'feature_importances_'):
    importances = best_url_model.feature_importances_
    feat_imp = sorted(zip(URL_FEATURE_COLUMNS, importances), key=lambda x: x[1], reverse=True)
    print("Top 10 important features:")
    for fname, fimp in feat_imp[:10]:
        print(f"  {fname}: {fimp:.4f}")


# ================================================================
# PART 3: SAVE CANDIDATE MODELS
# ================================================================
print("\n" + "=" * 70)
print("PART 3: SAVING CANDIDATE MODELS")
print("=" * 70)

# Save best file model
file_model_path = OUTPUT_DIR / "file_model_candidate.joblib"
file_imputer_path = OUTPUT_DIR / "file_imputer.joblib"
file_scaler_path = OUTPUT_DIR / "file_scaler.joblib"
file_cols_path = OUTPUT_DIR / "file_feature_columns.joblib"

joblib.dump(best_file_model, file_model_path)
joblib.dump(file_imputer, file_imputer_path)
joblib.dump(file_scaler, file_scaler_path)
joblib.dump(FILE_FEATURE_COLUMNS, file_cols_path)
print(f"Saved file model: {file_model_path}")

# Save best URL model
url_model_path = OUTPUT_DIR / "url_model_candidate.joblib"
url_imputer_path_out = OUTPUT_DIR / "url_imputer.joblib"
url_scaler_path_out = OUTPUT_DIR / "url_scaler.joblib"
url_cols_path_out = OUTPUT_DIR / "url_feature_columns.joblib"

joblib.dump(best_url_model, url_model_path)
joblib.dump(url_imputer, url_imputer_path_out)
joblib.dump(url_scaler, url_scaler_path_out)
joblib.dump(URL_FEATURE_COLUMNS, url_cols_path_out)
print(f"Saved URL model: {url_model_path}")

# Save all trained models
for name, model in file_models.items():
    p = OUTPUT_DIR / f"file_{name.lower()}.joblib"
    joblib.dump(model, p)
    print(f"  Saved: {p.name}")

for name, model in url_models.items():
    p = OUTPUT_DIR / f"url_{name.lower()}.joblib"
    joblib.dump(model, p)
    print(f"  Saved: {p.name}")


# ================================================================
# PART 4: INTEGRATION COMPATIBILITY CHECK
# ================================================================
print("\n" + "=" * 70)
print("PART 4: INTEGRATION COMPATIBILITY CHECK")
print("=" * 70)

# Verify file model compatibility
print("\n--- File Model Compatibility ---")
loaded_model = joblib.load(file_model_path)
loaded_imp = joblib.load(file_imputer_path)
loaded_scl = joblib.load(file_scaler_path)
loaded_cols = joblib.load(file_cols_path)

assert len(loaded_cols) == 32, f"Expected 32 features, got {len(loaded_cols)}"
assert loaded_cols == FILE_FEATURE_COLUMNS, "Feature columns mismatch!"
assert loaded_imp.n_features_in_ == 32, f"Imputer expects {loaded_imp.n_features_in_} features"
assert loaded_scl.n_features_in_ == 32, f"Scaler expects {loaded_scl.n_features_in_} features"

# Test inference
test_vec = np.zeros((1, 32))
test_imp = loaded_imp.transform(test_vec)
test_scl = loaded_scl.transform(test_imp)
pred = loaded_model.predict(test_scl)
prob = loaded_model.predict_proba(test_scl)
print(f"  Feature count: 32 OK")
print(f"  Imputer: OK (n_features={loaded_imp.n_features_in_})")
print(f"  Scaler: OK (n_features={loaded_scl.n_features_in_})")
print(f"  Predict: OK (output={pred})")
print(f"  Predict_proba: OK (shape={prob.shape})")
print(f"  Classes: {loaded_model.classes_}")

# Verify URL model compatibility
print("\n--- URL Model Compatibility ---")
loaded_url_model = joblib.load(url_model_path)
loaded_url_imp = joblib.load(url_imputer_path_out)
loaded_url_scl = joblib.load(url_scaler_path_out)
loaded_url_cols = joblib.load(url_cols_path_out)

assert len(loaded_url_cols) == 50, f"Expected 50 features, got {len(loaded_url_cols)}"
assert loaded_url_cols == URL_FEATURE_COLUMNS, "Feature columns mismatch!"
assert loaded_url_imp.n_features_in_ == 50, f"Imputer expects {loaded_url_imp.n_features_in_} features"
assert loaded_url_scl.n_features_in_ == 50, f"Scaler expects {loaded_url_scl.n_features_in_} features"

test_vec_u = np.zeros((1, 50))
test_imp_u = loaded_url_imp.transform(test_vec_u)
test_scl_u = loaded_url_scl.transform(test_imp_u)
pred_u = loaded_url_model.predict(test_scl_u)
prob_u = loaded_url_model.predict_proba(test_scl_u)
print(f"  Feature count: 50 OK")
print(f"  Imputer: OK (n_features={loaded_url_imp.n_features_in_})")
print(f"  Scaler: OK (n_features={loaded_url_scl.n_features_in_})")
print(f"  Predict: OK (output={pred_u})")
print(f"  Predict_proba: OK (shape={prob_u.shape})")
print(f"  Classes: {loaded_url_model.classes_}")


# ================================================================
# PART 5: CONFIDENCE CALCULATION ANALYSIS
# ================================================================
print("\n" + "=" * 70)
print("PART 5: CONFIDENCE CALCULATION ANALYSIS")
print("=" * 70)

# File model confidence
print("\n--- File Model Confidence ---")
file_probs = best_file_model.predict_proba(X_test_f_scaled)
file_preds = best_file_model.predict(X_test_f_scaled)
file_confidences = [file_probs[i][file_preds[i]] * 100 for i in range(len(file_preds))]
print(f"  Method: predict_proba()[sample][predicted_class] * 100")
print(f"  Min confidence: {min(file_confidences):.1f}%")
print(f"  Max confidence: {max(file_confidences):.1f}%")
print(f"  Mean confidence: {np.mean(file_confidences):.1f}%")
print(f"  Median confidence: {np.median(file_confidences):.1f}%")
print(f"  Note: Confidence != accuracy. It is the model's predicted probability for its chosen class.")

# URL model confidence
print("\n--- URL Model Confidence ---")
url_probs = best_url_model.predict_proba(X_test_u_scaled)
url_preds = best_url_model.predict(X_test_u_scaled)
url_confidences = [url_probs[i][url_preds[i]] * 100 for i in range(len(url_preds))]
print(f"  Method: predict_proba()[sample][predicted_class] * 100")
print(f"  Min confidence: {min(url_confidences):.1f}%")
print(f"  Max confidence: {max(url_confidences):.1f}%")
print(f"  Mean confidence: {np.mean(url_confidences):.1f}%")
print(f"  Median confidence: {np.median(url_confidences):.1f}%")


# ================================================================
# PART 6: SAVE METADATA
# ================================================================
print("\n" + "=" * 70)
print("PART 6: SAVING METADATA AND RESULTS")
print("=" * 70)

metadata = {
    "training_date": datetime.now().isoformat(),
    "file_model": {
        "type": type(best_file_model).__name__,
        "module": type(best_file_model).__module__,
        "feature_count": 32,
        "feature_names": FILE_FEATURE_COLUMNS,
        "label_mapping": {"0": "safe", "1": "malicious"},
        "preprocessing": {"imputer": "SimpleImputer(median)", "scaler": "StandardScaler"},
        "dataset": "cic_evasive_pdfmal2022_features.csv",
        "dataset_size": len(df_file),
        "train_size": len(X_train_f),
        "test_size": len(X_test_f),
        "evaluation": [r for r in file_results if r['model_name'] == best_file_model_name][0],
    },
    "url_model": {
        "type": type(best_url_model).__name__,
        "module": type(best_url_model).__module__,
        "feature_count": 50,
        "feature_names": URL_FEATURE_COLUMNS,
        "label_mapping": {"0": "safe", "1": "phishing"},
        "preprocessing": {"imputer": "SimpleImputer(median)", "scaler": "StandardScaler"},
        "dataset": "PhiUSIIL_Phishing_URL_Dataset.csv (re-extracted)",
        "dataset_size": len(df_url),
        "train_size": len(X_train_u),
        "test_size": len(X_test_u),
        "evaluation": [r for r in url_results if r['model_name'] == best_url_model_name][0],
    },
    "all_file_results": file_results,
    "all_url_results": url_results,
    "confidence_analysis": {
        "method": "predict_proba()[sample][predicted_class] * 100",
        "note": "Confidence is the model's predicted probability for its chosen class, NOT model accuracy",
        "file_model_confidence_range": f"{min(file_confidences):.1f}% - {max(file_confidences):.1f}%",
        "url_model_confidence_range": f"{min(url_confidences):.1f}% - {max(url_confidences):.1f}%",
    }
}

with open(OUTPUT_DIR / "model_metadata.json", "w") as f:
    json.dump(metadata, f, indent=2, default=str)
print(f"Metadata saved to: {OUTPUT_DIR / 'model_metadata.json'}")


# ================================================================
# FINAL SUMMARY
# ================================================================
print("\n" + "=" * 70)
print("FINAL COMPARISON TABLES")
print("=" * 70)

def print_comparison_table(results, title):
    print(f"\n{title}")
    print("-" * 130)
    header = f"{'Model':<25} {'Accuracy':>8} {'Precision':>9} {'Recall':>8} {'F1':>8} {'ROC-AUC':>8} {'FP':>6} {'FN':>6} {'Infer(ms)':>10}"
    print(header)
    print("-" * 130)
    for r in results:
        line = f"{r['model_name']:<25} {r['accuracy']:>8.4f} {r['precision']:>9.4f} {r['recall']:>8.4f} {r['f1']:>8.4f} {r['roc_auc']:>8.4f} {r['false_positives']:>6} {r['false_negatives']:>6} {r['inference_ms_per_sample']:>10.4f}"
        print(line)
    print("-" * 130)

print_comparison_table(file_results, "FILE MALWARE DETECTION — Old vs New")
print_comparison_table(url_results, "URL PHISHING DETECTION — Old vs New")

print(f"\nBest new FILE model: {best_file_model_name}")
print(f"Best new URL model: {best_url_model_name}")
print(f"\nCandidate models saved to: {OUTPUT_DIR}")
print(f"Production models NOT modified.")
print(f"\nCompleted: {datetime.now().isoformat()}")
