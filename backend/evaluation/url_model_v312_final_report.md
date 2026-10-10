# SCAMundo URL Phishing Model v3.12 — Final Report

**Decision: NEEDS FURTHER MODEL IMPROVEMENT**

**Reasons:**
- PhiUSIIL unavailable — dataset incomplete
- Legitimate robustness insufficient (8/15)

## A. Dataset Completeness
- **PhiUSIIL**: EXCLUDED: PhiUSIIL unavailable (accepted: 0)
- **archive(1)**: Recovered (accepted: 11430)
- **archive(2)**: Accepted benign+phishing (accepted: 618055)
- **archive(3)**: Benign only (accepted: 316254)
- **archive**: Binary labels (accepted: 160064)
- **tranco**: Reference/synthetic only (accepted: 50000)

## B. Label Mapping
0=SAFE, 1=PHISHING. malware/defacement excluded.

## C. Counts
SAFE: 799243 | PHISHING: 246500 | Conflicts: 4 | Dupes: 110050

## D. Domains
Unique: 167887

## E–F. Splits & Class Proportions
| Split | URLs | % | SAFE | PHISH | PHISH% |
|-------|------|---|------|-------|--------|
| Train | 742020 | 71.0% | 569469 | 172551 | 23.3% |
| Val | 156861 | 15.0% | 119887 | 36974 | 23.6% |
| Test | 156862 | 15.0% | 119887 | 36975 | 23.6% |

## G. Domain Leakage
TV=0 TT=0 VT=0

## H. Split Method
Greedy stratified domain assignment

## L. Selected
**LightGBM** @ threshold **0.3**

## M. Test Metrics
| Metric | Value |
|--------|-------|
| accuracy | 0.9206 |
| precision | 0.7624 |
| recall | 0.9633 |
| f1 | 0.8512 |
| roc_auc | 0.9894 |
| pr_auc | 0.9761 |
| tp | 35618 |
| tn | 108787 |
| fp | 11100 |
| fn | 1357 |
| fpr | 0.0926 |
| fnr | 0.0367 |
| safe_precision | 0.9877 |
| safe_recall | 0.9074 |
| phish_precision | 0.7624 |
| phish_recall | 0.9633 |

## Q. ECE
Weighted ECE: **0.0608**

## R. Latency
Avg:3.64ms Med:4.01ms p95:5.50ms Max:8.04ms

## S. Production
Modified: **False**

## T. Decision
**NEEDS FURTHER MODEL IMPROVEMENT**