import os
import shutil
import datetime
from pathlib import Path

def replace_models():
    base_dir = Path(r"c:\Users\Afshin muhammed k p\scamundo\hackx")
    saved_models_dir = base_dir / "jansuraksha" / "backend" / "saved_models"
    output_models_dir = base_dir / "jansuraksha" / "ml_training" / "output_models"
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = saved_models_dir / f"backup_{timestamp}"
    
    print(f"Creating backup directory: {backup_dir}")
    os.makedirs(backup_dir, exist_ok=True)
    
    # Files to backup and replace
    file_mapping = {
        "file_model_candidate.joblib": "best_model.joblib",
        "file_imputer.joblib": "imputer.joblib",
        "file_scaler.joblib": "scaler.joblib",
        "file_feature_columns.joblib": "feature_columns.joblib",
        "url_model_candidate.joblib": "url_model.joblib",
        "url_imputer.joblib": "url_imputer.joblib",
        "url_scaler.joblib": "url_scaler.joblib",
        "url_feature_columns.joblib": "url_feature_columns.joblib",
        "model_metadata.json": "model_metadata.json"
    }
    
    # 1. Backup existing files
    print("\nBacking up existing models...")
    for target_name in file_mapping.values():
        target_path = saved_models_dir / target_name
        if target_path.exists():
            backup_path = backup_dir / target_name
            shutil.copy2(target_path, backup_path)
            print(f"  Backed up: {target_name}")
            
    # 2. Copy new models
    print("\nDeploying new models...")
    for source_name, target_name in file_mapping.items():
        source_path = output_models_dir / source_name
        target_path = saved_models_dir / target_name
        
        if source_path.exists():
            shutil.copy2(source_path, target_path)
            print(f"  Deployed: {source_name} -> {target_name}")
        else:
            print(f"  ERROR: Source file not found: {source_path}")

    print("\nModel replacement complete!")
    print("NOTE: You may need to restart the Flask ML Microservice (port 8001) if models are cached in memory.")

if __name__ == "__main__":
    replace_models()
