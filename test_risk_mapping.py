import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path("backend").resolve()))

from api.scanner import scan_file
import app.services.scan_service as ss

# We want to test how different risk scores map to status and then to risk_level.
# Let's mock a model output in scan_file logic.

def test_mapping(prediction, probs):
    confidence = float(probs[prediction] * 100)
    risk_score = float(probs[1] * 100)
    
    if prediction == 1:
        status = "Dangerous" if risk_score >= 80.0 else "Suspicious"
    else:
        status = "Suspicious" if risk_score >= 30.0 else "Safe"
        
    print(f"Pred={prediction}, prob[1]={probs[1]:.2f} -> risk_score={risk_score:.1f}, status={status}")
    
    verdict_lower = status.lower()
    
    # scan_service map logic
    if verdict_lower == "safe":
        risk_level = "low"
    elif verdict_lower == "suspicious":
        risk_level = "medium"
    elif verdict_lower in ["malicious", "dangerous", "phishing"]:
        risk_level = "critical"
    else:
        risk_level = "medium"
        
    print(f"   -> mapped risk_level={risk_level}\n")

print("Testing boundary conditions for PDF classification:\n")
test_mapping(0, [0.80, 0.20]) # risk_score 20 (below 30)
test_mapping(0, [0.70, 0.30]) # risk_score 30
test_mapping(1, [0.40, 0.60]) # risk_score 60
test_mapping(1, [0.21, 0.79]) # risk_score 79
test_mapping(1, [0.20, 0.80]) # risk_score 80
test_mapping(1, [0.05, 0.95]) # risk_score 95 (above 80)
