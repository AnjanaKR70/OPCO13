# SCAMundo URL Model Diagnostic Report: Feature Mismatch Investigation

> [!NOTE]
> **Root Cause Status:** **FEATURE MISMATCH NOT FOUND** & **MODEL/DATASET ISSUE PROVEN**
> The extraction code is 100% identical between training and production. The failure is caused by an extreme dataset distribution mismatch where the training data does not resemble real-world legitimate traffic.

---

## 1. Feature Extraction Pipeline Analysis
- **Training Extractor**: `hackx/jansuraksha/ml_training/02_extract_url_features.py`
- **Runtime Extractor**: `hackx/jansuraksha/backend/feature_extraction/url_feature_extractor.py`

**Finding:** The training script `02_extract_url_features.py` does not contain its own extraction logic. It directly `import`s the runtime `extract_url_features` function from the backend.
**Conclusion:** A logic mismatch is **impossible**. The exact same Python function produced the dataset features and the runtime features.

## 2. Deterministic Feature Comparison
We extracted features for `https://www.google.com/search?q=hello` using the shared extraction logic.

**Raw Extraction Example (Google):**
- `url_length`: 37
- `num_questionmarks`: 1
- `has_suspicious_keywords`: 1 (triggered because "google" is hardcoded in the `PHISHING_KEYWORDS` list)
- `special_char_ratio`: 0.0541

The feature order (50 columns), names, and numeric types are identical and properly formatted. No infinite or NaN values were produced.

## 3. Scaler and Distribution Investigation
The issue becomes obvious when we pass the raw features through the saved `url_scaler.joblib` (StandardScaler) which normalizes data based on the training dataset's distribution.

**Anomalous Scaled Values for Google:**
- `num_questionmarks` (Mean: 0.029, Scale: 0.192) → **Scaled Value: +5.03**
- `has_suspicious_keywords` (Mean: 0.071, Scale: 0.258) → **Scaled Value: +3.59**
- `special_char_ratio` (Mean: 0.009, Scale: 0.019) → **Scaled Value: +2.28**

**What this proves:**
1. **Query Parameters:** In the entire 235,000-row training dataset, the average number of question marks per URL is 0.029. This means **almost zero legitimate URLs in the dataset have a query string (`?`)**. Thus, the model learned that any URL with a `?` is highly suspicious.
2. **Brand Keywords:** The extractor intentionally flags words like `google`, `apple`, and `login` as `has_suspicious_keywords=1` to catch impersonators. However, because the dataset's legitimate URLs apparently do not include real Google or Apple URLs, the dataset's mean for this feature is only 0.07. The model learned that having a brand keyword is almost exclusively a phishing trait.

## 4. Label Mapping Verification
- **Training Label Mapping**: `0` = Safe, `1` = Phishing.
- **Model Output**: The XGBoost model's internal `classes_` array is exactly `[0, 1]`.
- **Finding:** The mapping is fully consistent. The model predicts `1` for Google with 99.996% probability because its scaled feature vector mathematically places it deep inside the dataset's phishing boundary.

## 5. Conclusion & Evidence
**The root cause is a Dataset/Feature Design flaw, not a code mismatch.**

The PhiUSIIL dataset is heavily biased. Its legitimate URLs are likely simple domains without query parameters, paths, or brand keywords. 
Meanwhile, our `url_feature_extractor.py` considers standard brand names (Google, Apple, Microsoft) as "Phishing Keywords". Because the dataset lacks legitimate URLs containing these words, the model was forced to conclude that any URL containing "google" or a question mark is malicious.

**To fix this, we must:**
1. Modify `url_feature_extractor.py` to differentiate between the actual domain (e.g., `google.com` = safe) and subdomains/paths (e.g., `google.login.evil.com` = suspicious).
2. Augment the training dataset with thousands of real, complex, legitimate URLs (with query parameters, long paths, and brand names).
