# SCAMഉണ്ടോ (Scamundo)

A preventive security app that scans documents and links **before you open them**, and warns you if they look like a scam.

Phishing links and malicious files spread mostly through chat apps like WhatsApp and Telegram, and people usually open them within seconds. SCAMഉണ്ടോ checks the content first, gives a clear verdict (Green / Yellow / Red) with a simple explanation, and raises an SOS-style alert for dangerous content.

> **Status:** Work in progress. This README describes what the project is going to include.

---

## Features

### Document scanning
- Scans **PDF, DOCX/DOCM, PPTX and XLSX/XLSM** files
- Extracts structural and security features (metadata, embedded objects, macros, URLs, strings, entropy)
- ML model classifies each file as benign or malicious

### URL scanning
- Checks links for phishing and malicious behaviour
- URL structure features: length, dots, hyphens, digits, subdomains, IP address instead of domain, HTTPS
- Suspicious keywords (`login`, `verify`, `kyc`, `refund`, bank and brand names) and suspicious TLDs
- Lookalike domain detection (e.g. `amaz0n`, `paytm-secure`)
- Domain age and SSL certificate checks
- Short link expansion, so the final destination is what gets checked
- Blocklist and whitelist checks (Google Safe Browsing, PhishTank, OpenPhish, URLhaus)


### Risk verdict
- Confidence score for every scan
- **Green** (safe), **Orange** (suspicious), **Red** (malicious)
- Plain-language reasons, e.g. "Domain registered 3 days ago, imitates SBI"

### Alerts and reporting
- Full-screen warning with a recommended action
- SOS alert for high-risk content with beep sound
- Reporting of malicious content (planned integration with Cyberdome, 1930 and cybercrime.gov.in)

### Automatic interception (Android)
- Detects incoming documents and links before they are opened and scans them automatically

---

## How It Works

```
Incoming content (WhatsApp, Telegram, other apps)
            ↓
   Detect content type
     ↓            ↓
  Document        URL / QR
  scanner         scanner
     ↓            ↓
  Feature extraction
            ↓
     ML classification
            ↓
       Verdict engine
(score + risk level + explanation)
            ↓
 Green: allow | Orange: warn | Red: block + SOS
```

---

## Tech Stack

- **App:** Flutter (Android)
- **Backend:** Flask
- **ML:** Python (feature extraction and classifiers)

---

## Machine Learning Models

SCAMഉണ്ടോ uses two separate ML pipelines to assess potential threats before users open documents or links.

* **PDF & Document Threat Detection — Afshin Muhammed K P:** Uses a LightGBM classifier trained on document security features to identify potentially benign or malicious files. Extracted features include metadata, embedded objects, macros, URLs, strings and entropy.
* **URL Phishing Detection — Abhinav S:** Uses a URL classification model to assess phishing risk based on URL structure and other extracted characteristics.

The models contribute to SCAMഉണ്ടോ's risk verdict system, which presents a threat assessment and explanation to help users make safer decisions.

**Note:** An ML prediction is a risk estimate, not a guarantee that a file or URL is safe.

---

## Contribution
Mobile app development:Anjana K R,Aneena O T




    
