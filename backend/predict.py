import sys
import json
from pathlib import Path
from api.scanner import scan_file

def main():
    if len(sys.argv) < 2:
        print("Usage: python predict.py <filepath>")
        print("Examples:")
        print("  python predict.py suspicious_invoice.pdf")
        print("  python predict.py clean_document.docx")
        sys.exit(1)
        
    filepath = sys.argv[1]
    
    # Run scan
    verdict = scan_file(filepath)
    
    # Print clean formatted JSON to stdout
    print(json.dumps(verdict, indent=2))
    
    # Exit with code 0 if safe or unsupported fallback, 1 if dangerous, 2 if error
    if verdict.get("status") == "Dangerous":
        sys.exit(1)
    elif verdict.get("status") == "Error":
        sys.exit(2)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
