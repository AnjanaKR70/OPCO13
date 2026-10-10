import os
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).resolve().parent
DATASET_DIR = BASE_DIR / "dataset"
MODELS_DIR = BASE_DIR / "saved_models"
EVALUATION_DIR = BASE_DIR / "evaluation"
PLOTS_DIR = EVALUATION_DIR / "plots"
LOG_DIR = BASE_DIR / "logs"

# Ensure directories exist
for directory in [DATASET_DIR, MODELS_DIR, EVALUATION_DIR, PLOTS_DIR, LOG_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

# Feature definitions for ML model alignment
# By defining exact expected feature names, we guarantee consistency between training and inference.
GENERAL_FEATURES = [
    "file_size",
    "entropy",
    "suspicious_strings_count",
    "url_count",
    "email_count",
    "age_days",              # Derived from creation_time
    "time_delta_days"        # Difference between modification and creation time
]

PDF_FEATURES = [
    "pdf_num_pages",
    "pdf_has_javascript",
    "pdf_js_count",
    "pdf_has_embedded_files",
    "pdf_embedded_files_count",
    "pdf_has_openaction",
    "pdf_has_launch_action",
    "pdf_num_objects",
    "pdf_num_streams",
    "pdf_has_metadata",
    "pdf_metadata_keys_count",
    "pdf_is_encrypted",
    "pdf_num_fonts",
    "pdf_num_images",
    "pdf_suspicious_keywords_count"
]

OFFICE_FEATURES = [
    "office_has_macros",
    "office_macro_count",
    "office_external_links_count",
    "office_ole_objects_count",
    "office_has_embedded_exe",
    "office_has_auto_open",
    "office_num_hidden_elements",  # sheets for xlsx, slides for pptx
    "office_num_relationships",
    "office_has_metadata",
    "office_compression_ratio"
]

# Combined numerical/boolean features that the model will train on
FEATURE_COLUMNS = GENERAL_FEATURES + PDF_FEATURES + OFFICE_FEATURES

# Target label
LABEL_COLUMN = "is_malicious"

# Training parameters
RANDOM_STATE = 42
TEST_SIZE = 0.2

# Logging layout
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s"
LOG_FILE = LOG_DIR / "scamundo.log"
