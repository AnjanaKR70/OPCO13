# SCAMundo URL Phishing Model v3.11 — Final Report

**Final Decision: NEEDS FURTHER MODEL IMPROVEMENT**

## Dataset Inventory

- **PhiUSIIL**: EXCLUDED: Dataset file not found anywhere on filesystem after recursive search. (accepted: 0)
- **archive(1)**: Recovered via disk extraction (accepted: 11430)
- **archive(2)**: Accepted benign+phishing only (accepted: 618055)
- **archive(3)**: Accepted benign only; malicious excluded (accepted: 316254)
- **archive**: Accepted binary features (accepted: 160064)
- **tranco**: Used as synthetic reference. NOT treated as complex SAFE URLs. (accepted: 50000)

## Counts
- SAFE: 799243
- PHISHING: 246500
- Conflicts: 4
- Duplicates: 110050
- Unique Domains: 167887

## Splits
- Train: 434950 | Val: 85438 | Test: 535355
- Domain Leakage: Train-Val=0, Train-Test=0, Val-Test=0

## Selected Model
- **CatBoost** at threshold **0.15**

## Test Metrics (Unseen Domains, One-Time Eval)

| Metric | Value |
|--------|-------|
| accuracy | 0.4226 |
| precision | 0.214 |
| recall | 0.9408 |
| f1 | 0.3487 |
| roc_auc | 0.7715 |
| pr_auc | 0.5294 |
| tp | 82760 |
| tn | 143487 |
| fp | 303902 |
| fn | 5206 |
| fpr | 0.6793 |
| fnr | 0.0592 |
| safe_precision | 0.965 |
| safe_recall | 0.3207 |
| phishing_precision | 0.214 |
| phishing_recall | 0.9408 |

## ECE
- Weighted ECE (10 bins): **0.4251**

## Robustness
- Legit: 9/15
- Phish: 14/14
- Brand Safe: 3/4
- Brand Phish: 4/4

## Latency
- Avg: 2.87ms | Median: 3.00ms | p95: 6.13ms | Max: 13.62ms

## Production Verification
- Modified: **False**

## Limitations
- PhiUSIIL dataset is missing from the filesystem and was not included.