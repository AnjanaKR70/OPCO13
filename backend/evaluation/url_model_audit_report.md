# SCAMundo URL ML Model Verification & Training Audit Report

> [!WARNING]
> **CONCLUSION: NEEDS RETRAINING**
> The current URL model is suffering from extreme data leakage and over-fitting, rendering it unusable for production. It fails fundamentally on real-world legitimate URLs, predicting nearly everything as phishing. 

---

## 1. Current Model Summary
- **Type**: `XGBClassifier` (xgboost.sklearn)
- **Model Metadata**: Found in `saved_models/model_metadata.json`
- **Training Date**: 2026-09-03T05:22:11.138972
- **Feature Count**: 50 input features.
- **Dependencies**: `SimpleImputer(median)`, `StandardScaler`
- **Label Mapping**: `0` -> Safe, `1` -> Phishing
- **Verification**: The deployed model exactly matches the saved model files. The 50 feature names and order are fully intact. The model loads successfully via the cached loading functions.

## 2. Dataset Summary
- **Dataset**: `PhiUSIIL_Phishing_URL_Dataset.csv (re-extracted)`
- **Shape**: 235,370 records with 51 columns (50 features + 1 label).
- **Class Distribution**: 134,850 Legitimate (0) vs 100,520 Phishing (1).
- **Missing Values**: 0 missing values detected.
- **Raw URLs**: Raw URLs were **not** preserved in the processed training set, preventing domain-aware or string-level deduplication.
- **Duplicates**: **128,174 duplicate feature vectors** detected across the dataset.

> [!CAUTION]
> Over 50% of the dataset consists of duplicate feature vectors. This heavily compromises the training process.

## 3. Data Leakage Findings
- **Overlap**: **10,483 unique duplicate feature vectors** appear in **BOTH** the training and testing sets.
- **Impact**: Because the dataset was randomly split via `train_test_split` while containing massive amounts of duplicates, the test set is highly contaminated with samples the model already saw during training. The evaluation metrics are completely inflated and do not represent real-world generalization.

## 4. Reproduce Evaluation (On Leaked Test Set)
Using the existing evaluation pipeline on the preserved test set (which we proved contains leaked samples):
- **Accuracy**: 99.82%
- **Precision**: 99.99%
- **Recall**: 99.58%
- **F1-Score**: 99.79%
- **ROC-AUC**: 0.9988
- **Inference Time**: 0.0035 ms per URL

**Confusion Matrix:**
- **True Negatives**: 26,968
- **False Positives**: 2
- **False Negatives**: 84
- **True Positives**: 20,020

*Note: These metrics are artificial due to the data leakage.*

## 5. Independent and Robustness Testing
A manual test suite of diverse URLs was processed through the model's exact inference pipeline (`extract_url_features` -> `SimpleImputer` -> `StandardScaler` -> `XGBClassifier`).

> [!CAUTION]
> **100% False Positive Rate on Real-World Data**
> Every single URL, including standard legitimate URLs, was classified as **Phishing** with ~100% confidence.

**Test Cases (All predicted as Phishing):**
1. **Normal Legitimate**: `https://www.google.com/search?q=hello` (100% Conf)
2. **Long URL**: `https://www.example.com/aaaaa...` (100% Conf)
3. **URL with IP**: `http://192.168.1.100/login` (100% Conf)
4. **Suspicious subdomains**: `https://paypal.verification.update.evil.com/login` (100% Conf)
5. **Brand-like terms**: `https://amazon-security-alert.tk/` (100% Conf)
6. **Query parameters**: `https://example.com?user=admin&token=123&session=abc` (98% Conf)
7. **Legit with suspicious keywords**: `https://blog.security-research.com/phishing-examples` (100% Conf)
8. **Clearly suspicious**: `http://secure-update-login-appleid.com.br/login.php` (100% Conf)

*There were no system crashes, feature dimension mismatches, or infinite NaN values.*

## 6. API Integration Results
- The Flask `scamundo_api.py` endpoint correctly imports the inference logic.
- Input validation handles form data and JSON gracefully.
- The 50 features generate correctly in the expected order without causing exceptions.
- However, the underlying router `handle_incoming_intent` applies an application-level whitelist (e.g., returning `ALLOW` when monitoring is disabled for specific apps), which bypasses ML evaluation entirely in some scenarios.

## 7. Confidence and Calibration
- **Methodology**: The API utilizes raw `predict_proba()[sample][predicted_class] * 100`.
- **Calibration**: Uncalibrated. The model outputs extreme probabilities (e.g., 99.6% - 100.0%) regardless of whether the URL is safe or actually malicious. It cannot be used to gauge reliable risk thresholds in its current state.

## 8. Limitations & Recommended Next Steps

### Limitations
1. **Model Reliability**: High test scores are an illusion caused by duplicate leakage.
2. **Real-world Robustness**: Fails basic negative controls (Google, Example.com).
3. **Feature Extraction Disconnect**: The 50 features generated during API inference likely follow a completely different scale or distribution than the extracted features provided in the original PhiUSIIL dataset, causing the `StandardScaler` to map real-world inputs to malicious regions of the vector space.

### Recommended Next Steps
1. **Perform String-Level Deduplication**: Re-process the dataset ensuring that no two identical raw URLs exist *before* extracting features.
2. **Implement GroupKFold Split**: Split the dataset grouped by base domain to ensure the model learns URL structure instead of memorizing specific domains.
3. **Align Feature Extraction**: Ensure that the `extract_url_features` code running in production exactly matches the script that generated the training CSV. 
4. **Recalibrate**: Use `CalibratedClassifierCV` or isotonic regression to output true probabilities instead of raw tree ensemble margins.

*(No existing production model or inference script was modified during this audit.)*
