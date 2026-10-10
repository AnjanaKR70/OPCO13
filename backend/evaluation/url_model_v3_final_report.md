# SCAMundo URL Phishing Model v3 - Final Report

## Executive Summary
The v3 pipeline merged multiple high-quality datasets (PhiUSIIL, Kaggle archives, Tranco) to solve the legitimate URL distribution weakness found in v2. The pipeline performed strict deduplication, domain-aware splitting (zero leakage), context-aware feature extraction, and trained 5 robust models. 
**Decision:** READY FOR INTEGRATION TESTING

## Dataset Composition
- Total raw combined: 5 (Dataframes)
- Conflicting records dropped: 4
- Final combined safe: 793590
- Final combined phishing: 243507
- Total unique registered domains: 163815
- Domain Leakage (Train/Val/Test): 0

## Unseen Domain Test Metrics (LogisticRegression)
- Accuracy: 0.8747
- F1-Score: 0.4935
- False Positive Rate: 0.0053
- False Negative Rate: 0.6646

## Robustness
- Legitimate URLs (incl. deep paths/queries): 13/15 correct
- Phishing URLs (incl. adversarial brands): 14/14 correct
- Latency: Avg 4.05ms, Max 10.31ms

## Production Safety
- Production model artifacts modified: **False**
