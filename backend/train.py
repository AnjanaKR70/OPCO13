import sys
import json
from pathlib import Path
from dataset import load_malware_dataset
from training import PreprocessingPipeline, ModelTrainer
from evaluation import ModelEvaluator
from utils import get_logger

logger = get_logger("train_entry")

def main():
    try:
        logger.info("Initializing SCAMഉണ്ടോ Malware Detection Training Pipeline...")
        
        # 1. Load Dataset
        X, y = load_malware_dataset()
        
        # 2. Preprocess Data
        preprocessor = PreprocessingPipeline()
        X_train, X_test, y_train, y_test = preprocessor.prepare_data(X, y)
        
        # Save preprocessing artifacts
        preprocessor.save_pipeline()
        
        # 3. Train Models
        trainer = ModelTrainer()
        # Splitting train further or using test directly for validation
        scores = trainer.train_all(X_train, y_train, X_test, y_test)
        
        # Save the best model
        model_path, meta_path = trainer.save_best_model(scores)
        
        # 4. Evaluate all models and build comparison plots
        evaluator = ModelEvaluator()
        results = evaluator.evaluate_all(trainer.trained_models, X_test, y_test)
        
        print("\n" + "="*50)
        print("SCAMഉണ്ടോ MODEL TRAINING REPORT")
        print("="*50)
        print(f"Rankings (F1 Score on validation):")
        sorted_ranks = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        for idx, (m_name, f1_val) in enumerate(sorted_ranks):
            marker = "--> (BEST)" if idx == 0 else ""
            print(f" {idx+1}. {m_name}: F1 = {f1_val:.4f} {marker}")
            
        print("\nBest Model saved to:   ", model_path)
        print("Plots generated in:    ", Path(model_path).parent.parent / "evaluation" / "plots")
        print("="*50 + "\n")
        
    except Exception as e:
        logger.critical(f"Critical training pipeline failure: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
