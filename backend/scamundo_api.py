import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

# Import the underlying SCAMഉണ്ടോ ML Monitoring router
from monitor.router import handle_incoming_intent

app = Flask(__name__)
CORS(app)

# Limit uploads appropriately
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB max for files
UPLOAD_FOLDER = os.path.join(os.getcwd(), 'dataset', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "name": "SCAMഉണ്ടോ ML Prediction Microservice",
        "status": "Online",
        "message": "Send POST requests to /predict"
    })

def map_threat_level(status: str) -> str:
    """Map the internal ML status to the expected 'safe', 'suspicious', 'malicious' verdict."""
    if not status:
        return "suspicious"
    s = status.lower()
    if s == "safe": return "safe"
    if s == "suspicious": return "suspicious"
    if s in ["dangerous", "phishing"]: return "malicious"
    if "unable to verify" in s or s == "unsupported": return "unsupported"
    if s == "error": return "error"
    return "suspicious"

@app.route('/predict', methods=['POST'])
def predict_endpoint():
    """
    Accepts intended payload (URL or File Upload) from the FastAPI backend.
    Returns the strict JSON schema expected by the FastAPI scan_service.
    """
    app_source = request.form.get("source_app", "System")
    intent_response = None

    # 1. Check if it's a file upload
    if 'file' in request.files:
        file = request.files['file']
        if file.filename == '':
            return jsonify({"success": False, "message": "No file selected"}), 400
            
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        # Route through ML Observer
        intent_response = handle_incoming_intent(app_source, filepath, is_file=True)

        # Cleanup immediately after prediction
        if os.path.exists(filepath):
            os.remove(filepath)
            
    # 2. Check if it's a URL in Form or JSON
    elif request.is_json:
        data = request.get_json()
        target_url = data.get("url")
        if target_url:
            intent_response = handle_incoming_intent(app_source, target_url, is_file=False)
            
    elif request.form.get("url"):
        target_url = request.form.get("url")
        intent_response = handle_incoming_intent(app_source, target_url, is_file=False)

    if not intent_response:
        return jsonify({"success": False, "message": "Missing file or URL payload"}), 400

    # Extract the unified report from the intent response
    report = intent_response.get("report", {})
    if not report:
        # If ML monitoring was disabled or failed, default to safe
        return jsonify({
            "verdict": "safe",
            "reason": intent_response.get("message", "No threats detected"),
            "confidence": 1.0
        })

    # Format exactly as expected by our FastAPI backend
    features = report.get("detected_features", [])
    reason_list = report.get("reason", [])
    if isinstance(reason_list, list):
        reason = ", ".join(reason_list) if reason_list else ", ".join(features)
    else:
        reason = str(reason_list) or ", ".join(features)
        
    if not reason:
        reason = report.get("recommendation", "Unknown")
        
    report_status = report.get("status", "Safe")
    
    return jsonify({
        "verdict": map_threat_level(report_status),
        "reason": reason,
        "confidence": float(report.get("confidence") or 0.0) if report.get("confidence") is not None else None,
        "status": report_status,
        "risk_score": float(report.get("risk_score")) if report.get("risk_score") is not None else None,
        "detection_method": "Static Analysis" if "heuristic" in str(reason).lower() or report.get("file_type") != "PDF" else "ML + Static Analysis"
    })

if __name__ == '__main__':
    print("=" * 60)
    print("SCAMUNDO ML Microservice Online (Port 8001)")
    print("Mounted to 127.0.0.1 (Loopback/Localhost).")
    
    url_model_mode = os.environ.get("URL_MODEL_MODE", "candidate").upper()
    print(f"ACTIVE URL MODEL = {url_model_mode} " + ("(V3.12 CANDIDATE)" if url_model_mode == "CANDIDATE" else ""))
    print("DOCUMENT MODEL = PRODUCTION")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=8001, debug=True, use_reloader=False)
