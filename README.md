# SCAMഉണ്ടോ

A preventive security application that scans documents and links **before you open them**, and warns you if they look like a scam.

Phishing links and malicious files spread mostly through chat apps like WhatsApp and Telegram. SCAMഉണ്ടോ intercepts the content first, provides a clear security verdict (LOW / MEDIUM / CRITICAL risk) with a plain-language explanation, and raises an SOS-style alert overlay for highly dangerous threats.

---

## Architecture Overview

The SCAMഉണ്ടോ project relies on three primary, interoperating components:

1. **Flutter Mobile Application (Frontend):**
   - The user-facing app and background native scanner.
   - Includes a native Kotlin Android `NotificationListenerService` that actively intercepts and queues incoming URLs from notifications.
   - Includes a Flutter background isolate that polls the queue natively via `SharedPreferences` without user interaction.
   - Triggers an SOS system overlay window upon detection of `CRITICAL` threats.

2. **FastAPI Backend (Main API & Gateway):**
   - Typically runs on Port `8000`.
   - Handles the main `/scan-file`, `/issues`, and `/scan/url` endpoints.
   - Dispatches document extraction using custom binary file signatures (Magic Bytes validation) to prevent false classification of arbitrary ZIP files.
   - Saves scan histories directly to a PostgreSQL database.

3. **Flask ML Prediction Microservice:**
   - Typically runs on Port `8001`.
   - Executes the actual inferences for URL phishing detection (LightGBM/CatBoost) and Document heuristics.
   - Returns strict JSON schema reports back to the FastAPI gateway.

---

## Installation and Startup Instructions

### 1. Flask ML Prediction Service (Port 8001)
Navigate to the `backend/` directory, install requirements, and run the ML microservice:
```bash
cd backend
python -m pip install -r requirements.txt
python scamundo_api.py
```
*Note: The ML service runs by default on `http://127.0.0.1:8001`. It provides the `/predict` endpoint required for the FastAPI backend.*

### 2. FastAPI Gateway (Port 8000)
Navigate to the `app/` directory (or wherever your FastAPI router is located) and start the Uvicorn server:
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
*Note: You must correctly configure the Database URI via environment variables or Alembic `alembic.ini` for the API to record history.*

### 3. Flutter Mobile App (Android)
From the frontend root, resolve dependencies and build the app:
```bash
flutter pub get
flutter build apk --debug
flutter install
```

---

## Mobile Permissions & Configuration
The mobile app relies heavily on Android system permissions to function:
- **Notification Access:** Required for `NotificationScannerService` to read incoming URLs passively.
- **Display over other apps (SYSTEM_ALERT_WINDOW):** Required to display the SOS overlay immediately on detection.
- **Local Network Configuration:** The Flutter app connects to `http://<your-lan-ip>:8000`. Ensure your phone and the backend are on the same network, and configure the API url in `lib/services/api_config.dart`.

---

## Known Limitations & Diagnostics
- **Document Support:** Due to platform limitations, shared `content://` intents on Android strip file extensions. SCAMഉണ്ടോ correctly uses binary headers to resolve `application/pdf`, `msword` (legacy OLE), and `openxml` formats, explicitly blocking arbitrary ZIP files.
- **Background Isolate Polling:** The background dart isolate requires a manual `prefs.reload()` to see the URL array injected by the Kotlin service. This is by design.
- **Model Fallbacks:** If the ML Service (Port 8001) crashes, the FastAPI gateway natively maps predictions to "Unable to Verify" and displays "Unsupported" to the user, strictly preventing a safe bypass.

---

## Machine Learning Models

SCAMഉണ്ടോ uses two separate ML pipelines to assess potential threats before users open documents or links.
* **PDF & Document Threat Detection — Afshin Muhammed K P:** Uses a LightGBM classifier trained on document security features to identify potentially benign or malicious files. 
* **URL Phishing Detection — Abhinav S:** Uses a URL classification model to assess phishing risk based on URL structure and other extracted characteristics.

Detailed ML Model schemas and features are stored natively in the root directory in `PDF_DOCUMENT_ML_MODEL.txt` and `URL_PHISHING_ML_MODEL.txt`.

---

## Contributors
- Mobile app development: Anjana K R, Aneena O T
- Document ML Development: Afshin Muhammed K P
- URL ML Development: Abhinav S
