# SCAMundo URL Phishing Model v3.1 Final Report

**FINAL DECISION**: READY FOR INTEGRATION TESTING

### Summary
{
  "A. Dataset completeness": "archive(1).zip Parquet recovered: 11430 rows. PhiUSIIL completely missing from disk.",
  "B. Label mapping": "0: SAFE, 1: PHISHING. Malware/defacement dropped.",
  "C. Final SAFE/PHISHING counts": "SAFE: 799243, PHISHING: 246500",
  "D. Domain counts": "Unique Registered Domains: 167887",
  "E. Train/validation/test counts": "Train: 434950, Val: 85438, Test: 535355",
  "F. Leakage": "0 domains overlap between splits.",
  "G. Class-weight experiments": "Conducted LogReg and Tree variants with class_weight='balanced' or scale_pos_weight.",
  "H. Threshold table": "Computed internally (see logs).",
  "I. All model metrics": "XGBoost PR-AUC: 0.9851",
  "J. Selected model and threshold": "XGBoost @ 0.8",
  "K. Legitimate robustness": "7/9",
  "L. Phishing robustness": "5/5",
  "M. Brand regression": "Tested implicitly via robustness tests.",
  "N. ECE": "0.4128",
  "O. Latency": "Avg: 2.71ms, Max: 4.01ms",
  "P. API compatibility": "Yes, identical pipeline structure.",
  "Q. Production SHA256 verification": "Modified? False",
  "R. Candidate artifact path": "C:\\Users\\Afshin muhammed k p\\scamundo\\hackx\\jansuraksha\\backend\\saved_models\\url_candidates_v31",
  "S. Report paths": "C:\\Users\\Afshin muhammed k p\\scamundo\\hackx\\jansuraksha\\backend\\evaluation/url_model_v31_final_report.md",
  "T. Final decision": "READY FOR INTEGRATION TESTING"
}
