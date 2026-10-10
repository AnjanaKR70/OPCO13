import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
from typing import Dict, Any
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score, roc_auc_score,
    confusion_matrix, roc_curve
)
from config import PLOTS_DIR
from utils.logger import get_logger

# Set plot style safely
try:
    sns.set_theme(style="whitegrid")
except Exception:
    pass

logger = get_logger("evaluator")

class ModelEvaluator:
    """
    Computes performance metrics for multiple models and generates comparison plots:
    - ROC curves comparison
    - Bar charts for F1, Recall, Precision, Accuracy
    - Confusion matrices heatmaps
    """
    def __init__(self):
        pass

    @staticmethod
    def compute_metrics(y_true: pd.Series, y_pred: pd.Series, y_prob: np.ndarray) -> Dict[str, Any]:
        """
        Computes standard classification metrics.
        """
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        
        return {
            "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
            "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 4),
            "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 4),
            "f1_score": round(float(f1_score(y_true, y_pred, zero_division=0)), 4),
            "roc_auc": round(float(roc_auc_score(y_true, y_prob)), 4),
            "confusion_matrix": {
                "true_negative": int(tn),
                "false_positive": int(fp),
                "false_negative": int(fn),
                "true_positive": int(tp)
            }
        }

    def evaluate_all(self, models: Dict[str, Any], X_test: pd.DataFrame, y_test: pd.Series) -> Dict[str, Dict[str, Any]]:
        """
        Runs evaluation on all trained models, logs metrics, and generates comparison plots.
        """
        PLOTS_DIR.mkdir(parents=True, exist_ok=True)
        results = {}
        
        # Save metrics for plotting later
        metrics_df_list = []
        
        plt.figure(figsize=(10, 8)) # For unified ROC curve plot
        
        for name, model in models.items():
            logger.info(f"Evaluating {name} model...")
            try:
                preds = model.predict(X_test)
                if hasattr(model, "predict_proba"):
                    probs = model.predict_proba(X_test)[:, 1]
                else:
                    # SVMS/Decision trees without predict_proba fallback
                    probs = preds
                    
                metrics = self.compute_metrics(y_test, preds, probs)
                results[name] = metrics
                
                logger.info(
                    f"{name} Metrics -> Acc: {metrics['accuracy']}, Prec: {metrics['precision']}, Rec: {metrics['recall']}, F1: {metrics['f1_score']}, AUC: {metrics['roc_auc']}"
                )
                
                # Append to plotting dataframe list
                metrics_df_list.append({
                    "Model": name,
                    "Accuracy": metrics["accuracy"],
                    "Precision": metrics["precision"],
                    "Recall": metrics["recall"],
                    "F1 Score": metrics["f1_score"]
                })
                
                # Plot ROC curve for model
                fpr, tpr, _ = roc_curve(y_test, probs)
                plt.plot(fpr, tpr, label=f"{name} (AUC = {metrics['roc_auc']:.3f})")
                
                # Draw separate Confusion Matrix Heatmap
                self._plot_confusion_matrix(name, metrics["confusion_matrix"])
                
            except Exception as e:
                logger.error(f"Error evaluating {name}: {e}")
                
        # Finalize and save ROC Curve
        plt.plot([0, 1], [0, 1], 'k--', label="Random Guessing")
        plt.xlabel("False Positive Rate")
        plt.ylabel("True Positive Rate")
        plt.title("ROC Curve Analysis — Model Comparison")
        plt.legend(loc="lower right")
        roc_path = PLOTS_DIR / "roc_curve_comparison.png"
        plt.savefig(roc_path, dpi=120)
        plt.close()
        logger.info(f"Unified ROC Curve comparison plot saved to {roc_path}")
        
        # Generate metrics comparison bar chart
        if metrics_df_list:
            self._plot_metrics_comparison(metrics_df_list)

        return results

    def _plot_confusion_matrix(self, model_name: str, cm_dict: Dict[str, int]):
        """Generates and saves a confusion matrix heatmap."""
        cm_arr = np.array([
            [cm_dict["true_negative"], cm_dict["false_positive"]],
            [cm_dict["false_negative"], cm_dict["true_positive"]]
        ])
        
        plt.figure(figsize=(6, 5))
        sns.heatmap(
            cm_arr, annot=True, fmt="d", cmap="Blues", 
            xticklabels=["Safe", "Malicious"], 
            yticklabels=["Safe", "Malicious"]
        )
        plt.ylabel("Actual Label")
        plt.xlabel("Predicted Label")
        plt.title(f"Confusion Matrix — {model_name}")
        plt.tight_layout()
        
        cm_path = PLOTS_DIR / f"{model_name.lower()}_confusion_matrix.png"
        plt.savefig(cm_path, dpi=100)
        plt.close()
        logger.debug(f"Saved {model_name} confusion matrix to {cm_path}")

    def _plot_metrics_comparison(self, metrics_df_list: list):
        """Generates group bar chart comparing key metrics across classifiers."""
        df = pd.DataFrame(metrics_df_list)
        df_melted = df.melt(id_vars="Model", var_name="Metric", value_name="Score")
        
        plt.figure(figsize=(10, 6))
        sns.barplot(data=df_melted, x="Metric", y="Score", hue="Model", palette="muted")
        plt.ylim(0, 1.05)
        plt.title("Performance Metric Comparison across Classifiers")
        plt.ylabel("Score")
        plt.xlabel("Metric Category")
        plt.legend(title="Classifier", loc="lower right")
        plt.tight_layout()
        
        comparison_path = PLOTS_DIR / "model_metrics_comparison.png"
        plt.savefig(comparison_path, dpi=120)
        plt.close()
        logger.info(f"Model metrics comparison bar chart saved to {comparison_path}")
